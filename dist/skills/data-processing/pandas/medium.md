# Pandas 중규모 프로젝트 가이드

## 매칭 조건

- 정기 ETL 배치 처리
- 데이터: 수 GB ~ 수십 GB
- 데이터 검증 (validation) 포함
- 청크 기반 처리, 로깅
- 팀 규모: 3~10명

## 1. 프로젝트 구조

```
pandas-medium/
├── configs/
│   ├── dev.yaml
│   ├── staging.yaml
│   └── prod.yaml
├── src/
│   ├── __init__.py
│   ├── extractors/
│   │   ├── __init__.py
│   │   ├── csv_extractor.py
│   │   ├── db_extractor.py
│   │   └── api_extractor.py
│   ├── transformers/
│   │   ├── __init__.py
│   │   ├── base.py               # 변환 기본 클래스
│   │   ├── cleaning.py
│   │   ├── feature_engineering.py
│   │   └── aggregation.py
│   ├── loaders/
│   │   ├── __init__.py
│   │   ├── csv_loader.py
│   │   ├── db_loader.py
│   │   └── parquet_loader.py
│   ├── validators/
│   │   ├── __init__.py
│   │   ├── schema.py             # 스키마 검증
│   │   └── quality.py            # 데이터 품질 검증
│   └── utils/
│       ├── __init__.py
│       ├── logging.py
│       └── config.py
├── pipelines/
│   ├── __init__.py
│   ├── daily_sales_etl.py
│   └── weekly_report.py
├── tests/
│   ├── unit/
│   │   ├── test_transformers.py
│   │   └── test_validators.py
│   ├── integration/
│   │   └── test_pipeline.py
│   └── fixtures/
│       └── sample_data.csv
├── scripts/
│   ├── run_pipeline.py
│   └── backfill.py
├── .github/workflows/ci.yml
├── pyproject.toml
├── Makefile
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 ETL 파이프라인 기본 구조

```python
# pipelines/daily_sales_etl.py
from dataclasses import dataclass
from datetime import date
import logging
import time
import pandas as pd
from omegaconf import DictConfig

from src.extractors.db_extractor import DBExtractor
from src.transformers.cleaning import SalesCleaner
from src.transformers.feature_engineering import SalesFeatureEngineer
from src.validators.quality import QualityValidator
from src.loaders.parquet_loader import ParquetLoader

logger = logging.getLogger(__name__)


@dataclass
class PipelineResult:
    """파이프라인 실행 결과"""
    success: bool
    input_rows: int
    output_rows: int
    filtered_rows: int
    duration_seconds: float
    validation_errors: list[str]


class DailySalesETL:
    """일간 매출 ETL 파이프라인"""

    def __init__(self, cfg: DictConfig):
        self.cfg = cfg
        self.extractor = DBExtractor(cfg.source)
        self.cleaner = SalesCleaner()
        self.feature_eng = SalesFeatureEngineer()
        self.validator = QualityValidator(cfg.validation)
        self.loader = ParquetLoader(cfg.target)

    def run(self, target_date: date) -> PipelineResult:
        """파이프라인 실행"""
        start_time = time.time()
        errors = []

        logger.info(f"파이프라인 시작: {target_date}")

        # Extract
        logger.info("데이터 추출 중...")
        raw_df = self.extractor.extract(target_date)
        input_rows = len(raw_df)
        logger.info(f"추출 완료: {input_rows:,}건")

        # Validate (입력)
        logger.info("입력 데이터 검증 중...")
        input_validation = self.validator.validate_input(raw_df)
        if not input_validation.is_valid:
            errors.extend(input_validation.errors)
            logger.warning(f"입력 검증 경고: {input_validation.errors}")

        # Transform
        logger.info("데이터 변환 중...")
        cleaned_df = self.cleaner.transform(raw_df)
        featured_df = self.feature_eng.transform(cleaned_df)
        filtered_rows = input_rows - len(featured_df)
        logger.info(f"변환 완료: {len(featured_df):,}건 (필터링: {filtered_rows:,}건)")

        # Validate (출력)
        logger.info("출력 데이터 검증 중...")
        output_validation = self.validator.validate_output(featured_df)
        if not output_validation.is_valid:
            errors.extend(output_validation.errors)
            if output_validation.is_critical:
                logger.error(f"치명적 검증 실패: {output_validation.errors}")
                return PipelineResult(
                    success=False,
                    input_rows=input_rows,
                    output_rows=0,
                    filtered_rows=filtered_rows,
                    duration_seconds=time.time() - start_time,
                    validation_errors=errors,
                )

        # Load
        logger.info("데이터 적재 중...")
        self.loader.load(featured_df, partition_date=target_date)
        output_rows = len(featured_df)
        logger.info(f"적재 완료: {output_rows:,}건")

        duration = time.time() - start_time
        logger.info(f"파이프라인 완료: {duration:.1f}초")

        return PipelineResult(
            success=True,
            input_rows=input_rows,
            output_rows=output_rows,
            filtered_rows=filtered_rows,
            duration_seconds=duration,
            validation_errors=errors,
        )
```

### 2.2 데이터 검증

```python
# src/validators/schema.py
from dataclasses import dataclass, field
import pandas as pd
import pandera as pa
from pandera import Column, Check, DataFrameSchema


# Pandera 스키마 정의
sales_schema = DataFrameSchema(
    columns={
        "order_id": Column(str, Check.str_matches(r"^ORD-\d{8}$"), nullable=False),
        "customer_id": Column(str, nullable=False),
        "product_id": Column(str, nullable=False),
        "amount": Column(float, Check.ge(0), nullable=False),
        "quantity": Column(int, Check.in_range(1, 10000), nullable=False),
        "order_date": Column(pd.Timestamp, nullable=False),
        "category": Column(
            str,
            Check.isin(["electronics", "clothing", "food", "others"]),
            nullable=False,
        ),
    },
    coerce=True,
    strict=False,  # 추가 컬럼 허용
)


def validate_schema(df: pd.DataFrame) -> tuple[bool, list[str]]:
    """스키마 검증"""
    try:
        sales_schema.validate(df, lazy=True)
        return True, []
    except pa.errors.SchemaErrors as e:
        errors = [str(err) for err in e.failure_cases.to_dict("records")]
        return False, errors
```

```python
# src/validators/quality.py
from dataclasses import dataclass, field
import pandas as pd


@dataclass
class ValidationResult:
    is_valid: bool
    is_critical: bool = False
    errors: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)
    stats: dict = field(default_factory=dict)


class QualityValidator:
    """데이터 품질 검증"""

    def __init__(self, cfg):
        self.cfg = cfg

    def validate_input(self, df: pd.DataFrame) -> ValidationResult:
        """입력 데이터 품질 검증"""
        errors = []
        warnings = []
        stats = {}

        # 빈 데이터프레임 체크
        if len(df) == 0:
            return ValidationResult(is_valid=False, is_critical=True,
                                    errors=["빈 데이터프레임"])

        # 결측치 비율 체크
        for col in df.columns:
            null_ratio = df[col].isnull().mean()
            stats[f"null_ratio_{col}"] = null_ratio
            if null_ratio > self.cfg.max_null_ratio:
                errors.append(f"{col} 결측치 비율 초과: {null_ratio:.1%}")
            elif null_ratio > self.cfg.warn_null_ratio:
                warnings.append(f"{col} 결측치 비율 주의: {null_ratio:.1%}")

        # 중복 체크
        dup_ratio = df.duplicated(subset=self.cfg.unique_keys).mean()
        stats["duplicate_ratio"] = dup_ratio
        if dup_ratio > self.cfg.max_duplicate_ratio:
            errors.append(f"중복 비율 초과: {dup_ratio:.1%}")

        # 건수 범위 체크
        stats["row_count"] = len(df)
        if len(df) < self.cfg.min_row_count:
            warnings.append(f"행 수 부족: {len(df):,} < {self.cfg.min_row_count:,}")

        return ValidationResult(
            is_valid=len(errors) == 0,
            errors=errors,
            warnings=warnings,
            stats=stats,
        )

    def validate_output(self, df: pd.DataFrame) -> ValidationResult:
        """출력 데이터 품질 검증"""
        errors = []

        # 결측치 없어야 함
        null_cols = df.columns[df.isnull().any()].tolist()
        if null_cols:
            errors.append(f"출력에 결측치 존재: {null_cols}")

        # 필수 컬럼 존재
        missing = set(self.cfg.required_output_columns) - set(df.columns)
        if missing:
            errors.append(f"필수 컬럼 누락: {missing}")

        return ValidationResult(
            is_valid=len(errors) == 0,
            is_critical=len(errors) > 0,
            errors=errors,
        )
```

### 2.3 청크 기반 처리

```python
# src/transformers/base.py
import pandas as pd
from abc import ABC, abstractmethod
from pathlib import Path
import logging

logger = logging.getLogger(__name__)


class ChunkedProcessor:
    """대용량 CSV 청크 기반 처리"""

    def __init__(self, chunk_size: int = 100_000):
        self.chunk_size = chunk_size

    def process_file(
        self,
        input_path: str,
        output_path: str,
        transform_fn,
        **read_kwargs,
    ) -> dict:
        """파일을 청크 단위로 읽어 처리"""
        stats = {"total_input": 0, "total_output": 0, "chunks": 0}
        output = Path(output_path)
        first_chunk = True

        for chunk in pd.read_csv(input_path, chunksize=self.chunk_size, **read_kwargs):
            stats["chunks"] += 1
            stats["total_input"] += len(chunk)

            processed = transform_fn(chunk)
            stats["total_output"] += len(processed)

            # 첫 청크는 헤더 포함, 이후는 append
            processed.to_csv(
                output_path,
                mode="w" if first_chunk else "a",
                header=first_chunk,
                index=False,
            )
            first_chunk = False

            logger.info(
                f"청크 {stats['chunks']}: {len(chunk):,} -> {len(processed):,}건"
            )

        logger.info(
            f"처리 완료: {stats['total_input']:,} -> {stats['total_output']:,}건 "
            f"({stats['chunks']} 청크)"
        )
        return stats
```

### 2.4 변환 파이프라인

```python
# src/transformers/cleaning.py
import pandas as pd
import logging

logger = logging.getLogger(__name__)


class TransformPipeline:
    """순차적 변환 파이프라인"""

    def __init__(self):
        self.steps: list[tuple[str, callable]] = []

    def add_step(self, name: str, fn: callable):
        self.steps.append((name, fn))
        return self

    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        result = df.copy()
        for name, fn in self.steps:
            before = len(result)
            result = fn(result)
            after = len(result)
            if before != after:
                logger.info(f"  [{name}] {before:,} -> {after:,}건")
            else:
                logger.info(f"  [{name}] 완료")
        return result


class SalesCleaner:
    """매출 데이터 정제"""

    def __init__(self):
        self.pipeline = (
            TransformPipeline()
            .add_step("중복 제거", self._remove_duplicates)
            .add_step("결측치 처리", self._handle_missing)
            .add_step("이상치 제거", self._remove_outliers)
            .add_step("타입 변환", self._convert_types)
        )

    def transform(self, df: pd.DataFrame) -> pd.DataFrame:
        return self.pipeline.transform(df)

    def _remove_duplicates(self, df):
        return df.drop_duplicates(subset=["order_id"])

    def _handle_missing(self, df):
        df = df.dropna(subset=["order_id", "customer_id", "amount"])
        df["category"] = df["category"].fillna("others")
        return df

    def _remove_outliers(self, df):
        return df[df["amount"].between(0, 10_000_000)]

    def _convert_types(self, df):
        df["order_date"] = pd.to_datetime(df["order_date"])
        df["amount"] = df["amount"].astype("float32")
        return df
```

### 2.5 데이터베이스 연동

```python
# src/extractors/db_extractor.py
import pandas as pd
from sqlalchemy import create_engine, text
from datetime import date
import logging

logger = logging.getLogger(__name__)


class DBExtractor:
    """데이터베이스에서 데이터 추출"""

    def __init__(self, cfg):
        self.engine = create_engine(
            cfg.connection_string,
            pool_size=5,
            pool_recycle=3600,
        )

    def extract(self, target_date: date) -> pd.DataFrame:
        """날짜 기준 데이터 추출"""
        query = text("""
            SELECT order_id, customer_id, product_id,
                   amount, quantity, order_date, category
            FROM sales
            WHERE order_date = :target_date
        """)

        with self.engine.connect() as conn:
            df = pd.read_sql(query, conn, params={"target_date": target_date})

        logger.info(f"DB 추출: {len(df):,}건 ({target_date})")
        return df

    def extract_chunked(self, query: str, chunk_size: int = 50_000):
        """청크 단위 추출"""
        with self.engine.connect() as conn:
            for chunk in pd.read_sql(query, conn, chunksize=chunk_size):
                yield chunk
```

### 2.6 실행 스크립트

```python
# scripts/run_pipeline.py
import hydra
from omegaconf import DictConfig
from datetime import date, timedelta
import logging

from pipelines.daily_sales_etl import DailySalesETL

logger = logging.getLogger(__name__)


@hydra.main(config_path="../configs", config_name="prod", version_base=None)
def main(cfg: DictConfig):
    pipeline = DailySalesETL(cfg)

    # 어제 날짜 처리
    target_date = date.today() - timedelta(days=1)
    result = pipeline.run(target_date)

    if result.success:
        logger.info(
            f"성공: {result.input_rows:,} -> {result.output_rows:,}건, "
            f"{result.duration_seconds:.1f}초"
        )
    else:
        logger.error(f"실패: {result.validation_errors}")
        raise RuntimeError("파이프라인 실패")


if __name__ == "__main__":
    main()
```

## 3. 테스트/검증 전략

### 단위 테스트

```python
# tests/unit/test_transformers.py
import pytest
import pandas as pd
import numpy as np
from src.transformers.cleaning import SalesCleaner


@pytest.fixture
def sample_data():
    return pd.DataFrame({
        "order_id": ["ORD-001", "ORD-002", "ORD-002", "ORD-003"],
        "customer_id": ["C001", "C002", "C002", None],
        "amount": [100.0, 200.0, 200.0, -50.0],
        "category": ["food", None, None, "electronics"],
        "order_date": ["2024-01-01"] * 4,
    })


def test_sales_cleaner(sample_data):
    cleaner = SalesCleaner()
    result = cleaner.transform(sample_data)

    # 중복 제거 확인
    assert result["order_id"].nunique() == len(result)

    # 결측치 처리 확인
    assert result["customer_id"].isnull().sum() == 0
    assert (result["category"] == "others").any()

    # 이상치 제거 확인
    assert (result["amount"] >= 0).all()


def test_pipeline_idempotent(sample_data):
    """파이프라인 멱등성 확인"""
    cleaner = SalesCleaner()
    result1 = cleaner.transform(sample_data)
    result2 = cleaner.transform(result1)
    pd.testing.assert_frame_equal(result1, result2)
```

### 통합 테스트

```python
# tests/integration/test_pipeline.py
def test_daily_pipeline(tmp_path, mock_db):
    """전체 파이프라인 통합 테스트"""
    from pipelines.daily_sales_etl import DailySalesETL
    from omegaconf import OmegaConf

    cfg = OmegaConf.create({
        "source": {"connection_string": mock_db.url},
        "target": {"base_path": str(tmp_path)},
        "validation": {
            "max_null_ratio": 0.1,
            "warn_null_ratio": 0.05,
            "max_duplicate_ratio": 0.01,
            "min_row_count": 1,
            "unique_keys": ["order_id"],
            "required_output_columns": ["order_id", "amount"],
        },
    })

    pipeline = DailySalesETL(cfg)
    result = pipeline.run(date(2024, 1, 15))

    assert result.success
    assert result.output_rows > 0
    assert result.output_rows <= result.input_rows
```

## 4. 성능 최적화

### 메모리 최적화

```python
# Parquet 사용 (CSV 대비 70%+ 메모리 절약)
df.to_parquet("output.parquet", engine="pyarrow", compression="snappy")

# 필요한 컬럼만 읽기
df = pd.read_parquet("data.parquet", columns=["col1", "col2"])

# 카테고리 타입 활용
for col in low_cardinality_cols:
    df[col] = df[col].astype("category")
```

### 처리 속도

```python
# 벡터화 연산 우선 사용
# 나쁜 예: iterrows
for idx, row in df.iterrows():
    df.loc[idx, "total"] = row["price"] * row["qty"]

# 좋은 예: vectorized
df["total"] = df["price"] * df["qty"]

# 문자열 연산도 벡터화
df["full_name"] = df["first_name"].str.cat(df["last_name"], sep=" ")

# groupby + agg 조합
result = df.groupby("category").agg(
    total_amount=("amount", "sum"),
    avg_amount=("amount", "mean"),
    order_count=("order_id", "nunique"),
)
```

## 5. 체크리스트

### 프로젝트 셋업
- [ ] 설정 파일 (dev/staging/prod) 구성
- [ ] 로깅 설정
- [ ] CI/CD 파이프라인 설정
- [ ] 테스트 데이터 (fixtures) 준비

### ETL 구현
- [ ] Extract: 데이터 소스 연결 및 추출 로직
- [ ] Transform: 정제/변환 파이프라인 구현
- [ ] Load: 대상 저장소 적재 로직
- [ ] Validate: 입력/출력 데이터 검증

### 품질 관리
- [ ] 스키마 검증 (Pandera)
- [ ] 데이터 품질 메트릭 수집
- [ ] 멱등성 보장
- [ ] 에러 핸들링 및 알림

### 운영
- [ ] 스케줄러 설정 (cron / Airflow)
- [ ] 모니터링 (처리 건수, 소요 시간)
- [ ] 백필 스크립트 준비
- [ ] 문서화 (데이터 사전, 파이프라인 플로우)
