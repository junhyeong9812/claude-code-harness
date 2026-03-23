# Pandas 대규모 프로젝트 가이드

## 매칭 조건

- 대규모 파이프라인 (수십 GB 이상)
- Modin / Polars 대안 고려
- Airflow 등 오케스트레이션 사용
- 팀 규모 10명+ / 다수 팀 협업
- 데이터 플랫폼 수준의 운영

## 1. 프로젝트 구조

```
pandas-large/
├── configs/
│   ├── base.yaml
│   ├── pipelines/
│   │   ├── daily_etl.yaml
│   │   ├── weekly_report.yaml
│   │   └── monthly_aggregation.yaml
│   └── environments/
│       ├── dev.yaml
│       ├── staging.yaml
│       └── prod.yaml
├── src/
│   ├── __init__.py
│   ├── core/
│   │   ├── __init__.py
│   │   ├── engine.py             # 처리 엔진 추상화 (Pandas/Polars/Modin)
│   │   ├── pipeline.py           # 파이프라인 프레임워크
│   │   └── registry.py           # 파이프라인 레지스트리
│   ├── extractors/
│   │   ├── __init__.py
│   │   ├── base.py
│   │   ├── database.py
│   │   ├── s3.py
│   │   └── api.py
│   ├── transformers/
│   │   ├── __init__.py
│   │   ├── base.py
│   │   ├── cleaning/
│   │   ├── enrichment/
│   │   └── aggregation/
│   ├── loaders/
│   │   ├── __init__.py
│   │   ├── base.py
│   │   ├── database.py
│   │   ├── s3.py
│   │   └── bigquery.py
│   ├── validators/
│   │   ├── __init__.py
│   │   ├── great_expectations.py
│   │   └── custom.py
│   ├── monitoring/
│   │   ├── __init__.py
│   │   ├── metrics.py
│   │   └── alerts.py
│   └── utils/
│       ├── __init__.py
│       ├── logging.py
│       └── secrets.py
├── dags/
│   ├── daily_etl_dag.py
│   ├── weekly_report_dag.py
│   └── utils/
│       └── dag_factory.py
├── great_expectations/
│   ├── great_expectations.yml
│   ├── expectations/
│   │   ├── sales_suite.json
│   │   └── customer_suite.json
│   └── checkpoints/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── docker/
│   ├── Dockerfile.pipeline
│   └── Dockerfile.airflow
├── k8s/
│   └── airflow/
├── terraform/
│   └── data_infra.tf
├── pyproject.toml
├── Makefile
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 처리 엔진 추상화

```python
# src/core/engine.py
from abc import ABC, abstractmethod
from enum import Enum
import pandas as pd


class EngineType(Enum):
    PANDAS = "pandas"
    POLARS = "polars"
    MODIN = "modin"


class DataFrameEngine(ABC):
    """데이터프레임 처리 엔진 추상화"""

    @abstractmethod
    def read_parquet(self, path: str, **kwargs):
        ...

    @abstractmethod
    def read_csv(self, path: str, **kwargs):
        ...

    @abstractmethod
    def to_parquet(self, df, path: str, **kwargs):
        ...


class PandasEngine(DataFrameEngine):
    def read_parquet(self, path, **kwargs):
        return pd.read_parquet(path, **kwargs)

    def read_csv(self, path, **kwargs):
        return pd.read_csv(path, **kwargs)

    def to_parquet(self, df, path, **kwargs):
        df.to_parquet(path, **kwargs)


class PolarsEngine(DataFrameEngine):
    def read_parquet(self, path, **kwargs):
        import polars as pl
        return pl.read_parquet(path, **kwargs)

    def read_csv(self, path, **kwargs):
        import polars as pl
        return pl.read_csv(path, **kwargs)

    def to_parquet(self, df, path, **kwargs):
        df.write_parquet(path, **kwargs)


def get_engine(engine_type: str = "pandas") -> DataFrameEngine:
    engines = {
        "pandas": PandasEngine,
        "polars": PolarsEngine,
    }
    return engines[engine_type]()
```

### 2.2 Polars 활용 (성능 최적화)

```python
# Pandas 대비 10~100배 빠른 처리
import polars as pl

# Lazy evaluation으로 최적화
result = (
    pl.scan_parquet("data/sales/*.parquet")
    .filter(pl.col("amount") > 0)
    .with_columns([
        (pl.col("amount") * pl.col("quantity")).alias("total"),
        pl.col("order_date").str.to_date().alias("order_date"),
    ])
    .group_by("category")
    .agg([
        pl.col("total").sum().alias("total_revenue"),
        pl.col("order_id").n_unique().alias("order_count"),
        pl.col("customer_id").n_unique().alias("customer_count"),
    ])
    .sort("total_revenue", descending=True)
    .collect()  # 실행 시점에 최적화된 쿼리 플랜으로 처리
)

# Pandas와 호환
pandas_df = result.to_pandas()

# 대용량 CSV 고속 읽기
df = pl.read_csv(
    "data/large_file.csv",
    dtypes={"id": pl.Utf8, "amount": pl.Float32},
    n_threads=8,
    low_memory=True,
)

# 스트리밍 모드 (메모리 제한 환경)
result = (
    pl.scan_csv("data/huge_file.csv")
    .filter(pl.col("status") == "active")
    .group_by("region")
    .agg(pl.col("revenue").sum())
    .collect(streaming=True)
)
```

### 2.3 Airflow DAG

```python
# dags/daily_etl_dag.py
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.operators.empty import EmptyOperator
from airflow.utils.task_group import TaskGroup


default_args = {
    "owner": "data-team",
    "depends_on_past": False,
    "email_on_failure": True,
    "email": ["data-team@example.com"],
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
}


def extract_sales(**context):
    from src.extractors.database import DBExtractor
    target_date = context["ds"]
    extractor = DBExtractor.from_config("prod")
    df = extractor.extract(target_date)
    df.to_parquet(f"/tmp/sales_{target_date}.parquet")
    return len(df)


def validate_input(**context):
    import pandas as pd
    target_date = context["ds"]
    df = pd.read_parquet(f"/tmp/sales_{target_date}.parquet")

    from src.validators.quality import QualityValidator
    validator = QualityValidator.from_config("prod")
    result = validator.validate_input(df)

    if not result.is_valid:
        raise ValueError(f"입력 검증 실패: {result.errors}")

    return result.stats


def transform(**context):
    import pandas as pd
    target_date = context["ds"]
    df = pd.read_parquet(f"/tmp/sales_{target_date}.parquet")

    from src.transformers.cleaning import SalesCleaner
    from src.transformers.feature_engineering import SalesFeatureEngineer

    df = SalesCleaner().transform(df)
    df = SalesFeatureEngineer().transform(df)

    output_path = f"/data/processed/sales/dt={target_date}/data.parquet"
    df.to_parquet(output_path, index=False)
    return len(df)


def validate_output(**context):
    import pandas as pd
    target_date = context["ds"]
    df = pd.read_parquet(f"/data/processed/sales/dt={target_date}/data.parquet")

    from src.validators.quality import QualityValidator
    validator = QualityValidator.from_config("prod")
    result = validator.validate_output(df)

    if not result.is_valid:
        raise ValueError(f"출력 검증 실패: {result.errors}")


with DAG(
    dag_id="daily_sales_etl",
    default_args=default_args,
    description="일간 매출 ETL 파이프라인",
    schedule_interval="0 2 * * *",  # 매일 02:00 UTC
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["etl", "sales", "daily"],
) as dag:

    start = EmptyOperator(task_id="start")

    extract = PythonOperator(
        task_id="extract_sales",
        python_callable=extract_sales,
    )

    validate_in = PythonOperator(
        task_id="validate_input",
        python_callable=validate_input,
    )

    transform_task = PythonOperator(
        task_id="transform",
        python_callable=transform,
    )

    validate_out = PythonOperator(
        task_id="validate_output",
        python_callable=validate_output,
    )

    end = EmptyOperator(task_id="end")

    start >> extract >> validate_in >> transform_task >> validate_out >> end
```

### 2.4 Great Expectations 통합

```python
# src/validators/great_expectations.py
import great_expectations as gx


def create_sales_expectation_suite():
    """매출 데이터 검증 스위트 생성"""
    context = gx.get_context()

    suite = context.add_expectation_suite("sales_suite")

    # 필수 컬럼 존재
    suite.add_expectation(
        gx.expectations.ExpectTableColumnsToMatchSet(
            column_set=["order_id", "customer_id", "amount", "order_date"]
        )
    )

    # 결측치 제한
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToNotBeNull(column="order_id")
    )

    # 값 범위
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToBeBetween(
            column="amount", min_value=0, max_value=100_000_000
        )
    )

    # 유니크 키
    suite.add_expectation(
        gx.expectations.ExpectColumnValuesToBeUnique(column="order_id")
    )

    return suite


def validate_with_ge(df, suite_name: str) -> dict:
    """Great Expectations으로 검증"""
    context = gx.get_context()
    validator = context.get_validator(
        batch_request=gx.RuntimeBatchRequest(
            datasource_name="runtime",
            data_connector_name="default",
            data_asset_name="sales",
            runtime_parameters={"batch_data": df},
        ),
        expectation_suite_name=suite_name,
    )

    results = validator.validate()
    return {
        "success": results.success,
        "statistics": results.statistics,
        "results": [
            {
                "expectation": r.expectation_config.expectation_type,
                "success": r.success,
                "result": r.result,
            }
            for r in results.results
        ],
    }
```

### 2.5 모니터링 및 알림

```python
# src/monitoring/metrics.py
from dataclasses import dataclass, field
from datetime import datetime
import json
import logging

logger = logging.getLogger(__name__)


@dataclass
class PipelineMetrics:
    pipeline_name: str
    run_date: str
    start_time: datetime = field(default_factory=datetime.now)
    end_time: datetime | None = None
    input_rows: int = 0
    output_rows: int = 0
    filtered_rows: int = 0
    error_count: int = 0
    custom_metrics: dict = field(default_factory=dict)

    @property
    def duration_seconds(self) -> float:
        if self.end_time:
            return (self.end_time - self.start_time).total_seconds()
        return 0

    @property
    def filter_ratio(self) -> float:
        if self.input_rows == 0:
            return 0
        return self.filtered_rows / self.input_rows

    def finish(self):
        self.end_time = datetime.now()

    def to_dict(self) -> dict:
        return {
            "pipeline_name": self.pipeline_name,
            "run_date": self.run_date,
            "duration_seconds": self.duration_seconds,
            "input_rows": self.input_rows,
            "output_rows": self.output_rows,
            "filtered_rows": self.filtered_rows,
            "filter_ratio": round(self.filter_ratio, 4),
            "error_count": self.error_count,
            **self.custom_metrics,
        }

    def emit(self):
        """메트릭을 로깅/모니터링 시스템에 전송"""
        logger.info(f"Pipeline metrics: {json.dumps(self.to_dict())}")

        # Prometheus 전송 (선택)
        # from prometheus_client import Gauge
        # gauge = Gauge("pipeline_rows", "Pipeline rows", ["pipeline", "type"])
        # gauge.labels(self.pipeline_name, "input").set(self.input_rows)
        # gauge.labels(self.pipeline_name, "output").set(self.output_rows)
```

## 3. 테스트/검증 전략

### E2E 파이프라인 테스트

```python
# tests/e2e/test_daily_etl.py
import pytest
from datetime import date
from unittest.mock import patch


@pytest.mark.e2e
def test_full_daily_pipeline(mock_database, tmp_path):
    """전체 일간 파이프라인 E2E 테스트"""
    from pipelines.daily_sales_etl import DailySalesETL
    from omegaconf import OmegaConf

    cfg = OmegaConf.load("configs/dev.yaml")
    cfg.target.base_path = str(tmp_path)

    pipeline = DailySalesETL(cfg)
    result = pipeline.run(date(2024, 6, 15))

    assert result.success
    assert result.output_rows > 0
    assert result.filter_ratio < 0.1  # 10% 미만 필터링

    # 출력 파일 검증
    import pandas as pd
    output = pd.read_parquet(tmp_path / "dt=2024-06-15" / "data.parquet")
    assert len(output) == result.output_rows
    assert output["amount"].ge(0).all()
```

## 4. 성능 최적화

### Pandas vs Polars vs Modin 벤치마크

```python
import time

def benchmark(name, fn):
    start = time.time()
    result = fn()
    elapsed = time.time() - start
    print(f"{name}: {elapsed:.2f}초, {len(result):,}건")
    return elapsed

# Pandas
benchmark("Pandas", lambda: (
    pd.read_csv("data.csv")
    .query("amount > 0")
    .groupby("category")
    .agg({"amount": "sum"})
))

# Polars
benchmark("Polars", lambda: (
    pl.scan_csv("data.csv")
    .filter(pl.col("amount") > 0)
    .group_by("category")
    .agg(pl.col("amount").sum())
    .collect()
))
```

### Parquet 파티셔닝

```python
import pyarrow as pa
import pyarrow.parquet as pq

# 파티션 기반 저장 (날짜별)
table = pa.Table.from_pandas(df)
pq.write_to_dataset(
    table,
    root_path="data/processed/sales",
    partition_cols=["year", "month"],
    compression="snappy",
)

# 파티션 필터링으로 읽기 (불필요한 파일 스킵)
df = pd.read_parquet(
    "data/processed/sales",
    filters=[("year", "=", 2024), ("month", ">=", 6)],
)
```

## 5. 체크리스트

### 아키텍처
- [ ] 처리 엔진 선택 (Pandas / Polars / Modin)
- [ ] 파이프라인 프레임워크 설계
- [ ] 데이터 파티셔닝 전략
- [ ] 오케스트레이션 도구 (Airflow / Prefect / Dagster)

### 데이터 품질
- [ ] Great Expectations / Pandera 도입
- [ ] 입력/출력 검증 스위트 작성
- [ ] 검증 결과 대시보드
- [ ] 알림 설정 (Slack / PagerDuty)

### 운영
- [ ] Airflow DAG 구성 및 스케줄링
- [ ] 백필 전략 수립
- [ ] 모니터링 (처리 건수, 소요 시간, 에러율)
- [ ] SLA 정의 및 추적

### 인프라
- [ ] Docker 이미지 빌드 자동화
- [ ] K8s 배포 (Airflow on K8s)
- [ ] 스토리지 비용 최적화 (Parquet, 파티셔닝)
- [ ] 접근 제어 (IAM / RBAC)

### 거버넌스
- [ ] 데이터 카탈로그 등록
- [ ] 데이터 리니지 추적
- [ ] 데이터 보존 정책
- [ ] 감사 로그 설정
