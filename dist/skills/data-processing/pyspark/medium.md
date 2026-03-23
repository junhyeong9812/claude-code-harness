# PySpark 중규모 프로젝트 가이드

## 매칭 조건

- 클러스터 기반 배치 잡
- 데이터: 수 GB ~ 수백 GB
- 파티셔닝 전략, UDF 최적화
- 정기 스케줄링 및 모니터링
- 팀 규모: 3~10명

## 1. 프로젝트 구조

```
pyspark-medium/
├── configs/
│   ├── base.yaml
│   ├── dev.yaml
│   ├── staging.yaml
│   └── prod.yaml
├── src/
│   ├── __init__.py
│   ├── core/
│   │   ├── __init__.py
│   │   ├── spark_factory.py      # SparkSession 팩토리
│   │   └── job_runner.py         # 잡 실행기
│   ├── extractors/
│   │   ├── __init__.py
│   │   ├── jdbc.py               # JDBC 소스
│   │   ├── s3.py                 # S3 소스
│   │   └── kafka.py              # Kafka 소스
│   ├── transformers/
│   │   ├── __init__.py
│   │   ├── cleaning.py
│   │   ├── enrichment.py
│   │   ├── aggregation.py
│   │   └── udfs.py               # UDF 정의
│   ├── loaders/
│   │   ├── __init__.py
│   │   ├── parquet.py
│   │   ├── jdbc.py
│   │   └── hive.py
│   ├── validators/
│   │   ├── __init__.py
│   │   └── data_quality.py
│   └── utils/
│       ├── __init__.py
│       ├── logging.py
│       └── metrics.py
├── jobs/
│   ├── daily_etl.py
│   ├── aggregation.py
│   └── data_quality_check.py
├── tests/
│   ├── unit/
│   │   ├── conftest.py           # SparkSession fixture
│   │   ├── test_transformers.py
│   │   └── test_udfs.py
│   └── integration/
│       └── test_jobs.py
├── deploy/
│   ├── submit.sh                 # spark-submit 스크립트
│   ├── Dockerfile
│   └── cluster_config.yaml
├── .github/workflows/ci.yml
├── pyproject.toml
├── Makefile
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 SparkSession 팩토리

```python
# src/core/spark_factory.py
from pyspark.sql import SparkSession
from omegaconf import DictConfig


def create_spark_session(cfg: DictConfig) -> SparkSession:
    """환경별 SparkSession 생성"""
    builder = (
        SparkSession.builder
        .appName(cfg.app_name)
    )

    # 클러스터 설정
    spark_configs = {
        "spark.sql.shuffle.partitions": str(cfg.spark.shuffle_partitions),
        "spark.sql.adaptive.enabled": "true",
        "spark.sql.adaptive.coalescePartitions.enabled": "true",
        "spark.sql.adaptive.skewJoin.enabled": "true",
        "spark.serializer": "org.apache.spark.serializer.KryoSerializer",
        "spark.sql.parquet.compression.codec": "snappy",
        "spark.sql.session.timeZone": "Asia/Seoul",
        # 메모리 설정
        "spark.executor.memory": cfg.spark.executor_memory,
        "spark.executor.cores": str(cfg.spark.executor_cores),
        "spark.executor.instances": str(cfg.spark.executor_instances),
        "spark.driver.memory": cfg.spark.driver_memory,
        # 동적 할당
        "spark.dynamicAllocation.enabled": "true",
        "spark.dynamicAllocation.minExecutors": "2",
        "spark.dynamicAllocation.maxExecutors": str(cfg.spark.max_executors),
    }

    for key, value in spark_configs.items():
        builder = builder.config(key, value)

    if cfg.get("hive_support", False):
        builder = builder.enableHiveSupport()

    return builder.getOrCreate()
```

### 2.2 파티셔닝 전략

```python
# src/transformers/enrichment.py
from pyspark.sql import DataFrame
from pyspark.sql import functions as F


def repartition_by_key(df: DataFrame, key_col: str, target_partitions: int = None) -> DataFrame:
    """키 기반 리파티셔닝 (조인 최적화)"""
    if target_partitions:
        return df.repartition(target_partitions, key_col)
    return df.repartition(key_col)


def write_partitioned(df: DataFrame, path: str, partition_cols: list[str]):
    """파티션 기반 저장"""
    (
        df.write
        .mode("overwrite")
        .partitionBy(*partition_cols)
        .option("maxRecordsPerFile", 1_000_000)  # 파일당 최대 행 수
        .parquet(path)
    )


def read_with_partition_filter(spark, path: str, partition_filter: dict) -> DataFrame:
    """파티션 프루닝을 활용한 읽기"""
    df = spark.read.parquet(path)

    for col, value in partition_filter.items():
        if isinstance(value, list):
            df = df.filter(F.col(col).isin(value))
        else:
            df = df.filter(F.col(col) == value)

    return df
```

### 2.3 UDF 최적화

```python
# src/transformers/udfs.py
from pyspark.sql import functions as F
from pyspark.sql.types import StringType, ArrayType, MapType
import json


# 나쁜 예: Python UDF (느림, 직렬화 비용)
@F.udf(StringType())
def parse_json_udf(json_str):
    try:
        data = json.loads(json_str)
        return data.get("name", "unknown")
    except Exception:
        return "unknown"

# 좋은 예 1: 내장 함수 사용
def parse_json_native(df, col_name):
    return df.withColumn(
        "name",
        F.get_json_object(F.col(col_name), "$.name")
    )

# 좋은 예 2: Pandas UDF (Arrow 기반, 벡터화)
from pyspark.sql.functions import pandas_udf
import pandas as pd

@pandas_udf(StringType())
def normalize_text_pandas(texts: pd.Series) -> pd.Series:
    """텍스트 정규화 (Pandas UDF - 벡터화)"""
    return (
        texts
        .str.strip()
        .str.lower()
        .str.replace(r"\s+", " ", regex=True)
        .str.replace(r"[^\w\s]", "", regex=True)
    )

# 적용
df = df.withColumn("clean_text", normalize_text_pandas(F.col("text")))


# 좋은 예 3: mapInPandas (그룹 처리)
def process_group(key, pdf_iterator):
    """그룹별 Pandas 처리"""
    for pdf in pdf_iterator:
        pdf["score"] = pdf["amount"].rank(pct=True)
        yield pdf

result = df.groupBy("category").applyInPandas(
    process_group,
    schema=df.schema.add("score", "double"),
)
```

### 2.4 데이터 품질 체크

```python
# src/validators/data_quality.py
from pyspark.sql import DataFrame
from pyspark.sql import functions as F
from dataclasses import dataclass, field
import logging

logger = logging.getLogger(__name__)


@dataclass
class QualityReport:
    table_name: str
    row_count: int = 0
    checks: list[dict] = field(default_factory=list)

    @property
    def passed(self) -> bool:
        return all(c["passed"] for c in self.checks)


class SparkDataQualityChecker:
    """Spark DataFrame 품질 검증"""

    def __init__(self, df: DataFrame, table_name: str):
        self.df = df
        self.report = QualityReport(table_name=table_name)
        self.report.row_count = df.count()

    def check_not_null(self, columns: list[str]):
        for col in columns:
            null_count = self.df.filter(F.col(col).isNull()).count()
            passed = null_count == 0
            self.report.checks.append({
                "check": f"not_null_{col}",
                "passed": passed,
                "details": {"null_count": null_count},
            })
            if not passed:
                logger.warning(f"{col}: {null_count:,}개 null 발견")
        return self

    def check_unique(self, columns: list[str]):
        total = self.report.row_count
        distinct = self.df.select(columns).distinct().count()
        passed = total == distinct
        self.report.checks.append({
            "check": f"unique_{','.join(columns)}",
            "passed": passed,
            "details": {"total": total, "distinct": distinct, "duplicates": total - distinct},
        })
        return self

    def check_range(self, column: str, min_val=None, max_val=None):
        conditions = []
        if min_val is not None:
            conditions.append(F.col(column) < min_val)
        if max_val is not None:
            conditions.append(F.col(column) > max_val)

        if conditions:
            from functools import reduce
            from operator import or_
            out_of_range = self.df.filter(reduce(or_, conditions)).count()
        else:
            out_of_range = 0

        passed = out_of_range == 0
        self.report.checks.append({
            "check": f"range_{column}",
            "passed": passed,
            "details": {"out_of_range": out_of_range, "min": min_val, "max": max_val},
        })
        return self

    def check_row_count(self, min_count: int):
        passed = self.report.row_count >= min_count
        self.report.checks.append({
            "check": "min_row_count",
            "passed": passed,
            "details": {"actual": self.report.row_count, "expected_min": min_count},
        })
        return self

    def run(self) -> QualityReport:
        logger.info(f"품질 검증 결과: {'통과' if self.report.passed else '실패'}")
        for check in self.report.checks:
            status = "PASS" if check["passed"] else "FAIL"
            logger.info(f"  [{status}] {check['check']}: {check['details']}")
        return self.report


# 사용 예시
report = (
    SparkDataQualityChecker(df, "sales")
    .check_not_null(["order_id", "customer_id", "amount"])
    .check_unique(["order_id"])
    .check_range("amount", min_val=0, max_val=10_000_000)
    .check_row_count(min_count=1000)
    .run()
)
```

### 2.5 잡 실행기

```python
# src/core/job_runner.py
from abc import ABC, abstractmethod
from pyspark.sql import SparkSession
from omegaconf import DictConfig
import time
import logging

logger = logging.getLogger(__name__)


class SparkJob(ABC):
    """Spark 잡 기본 클래스"""

    def __init__(self, spark: SparkSession, cfg: DictConfig):
        self.spark = spark
        self.cfg = cfg

    def run(self) -> dict:
        """잡 실행"""
        start_time = time.time()
        logger.info(f"잡 시작: {self.__class__.__name__}")

        try:
            result = self.execute()
            duration = time.time() - start_time
            logger.info(f"잡 완료: {duration:.1f}초")
            return {"success": True, "duration": duration, **result}
        except Exception as e:
            duration = time.time() - start_time
            logger.error(f"잡 실패: {e} ({duration:.1f}초)")
            return {"success": False, "duration": duration, "error": str(e)}

    @abstractmethod
    def execute(self) -> dict:
        """실제 잡 로직 (서브클래스에서 구현)"""
        ...
```

### 2.6 spark-submit 스크립트

```bash
#!/bin/bash
# deploy/submit.sh

spark-submit \
    --master yarn \
    --deploy-mode cluster \
    --name "daily-etl" \
    --num-executors 10 \
    --executor-cores 4 \
    --executor-memory 8g \
    --driver-memory 4g \
    --conf spark.sql.adaptive.enabled=true \
    --conf spark.sql.shuffle.partitions=200 \
    --conf spark.dynamicAllocation.enabled=true \
    --conf spark.dynamicAllocation.maxExecutors=20 \
    --py-files dist/src.zip \
    jobs/daily_etl.py \
    --config configs/prod.yaml \
    --date "2024-06-15"
```

## 3. 테스트/검증 전략

### 테스트 설정

```python
# tests/unit/conftest.py
import pytest
from pyspark.sql import SparkSession


@pytest.fixture(scope="session")
def spark():
    """테스트용 SparkSession"""
    spark = (
        SparkSession.builder
        .master("local[2]")
        .appName("test")
        .config("spark.sql.shuffle.partitions", "4")
        .config("spark.driver.bindAddress", "127.0.0.1")
        .getOrCreate()
    )
    yield spark
    spark.stop()
```

### 변환 함수 테스트

```python
# tests/unit/test_transformers.py
from chispa import assert_df_equality  # pip install chispa
from pyspark.sql import Row


def test_aggregation(spark):
    data = [
        Row(category="A", amount=100.0),
        Row(category="A", amount=200.0),
        Row(category="B", amount=300.0),
    ]
    df = spark.createDataFrame(data)
    result = aggregate_by_category(df)

    expected = spark.createDataFrame([
        Row(category="A", total=300.0, count=2),
        Row(category="B", total=300.0, count=1),
    ])

    assert_df_equality(result, expected, ignore_row_order=True)


def test_udf_normalize_text(spark):
    data = [Row(text="  Hello   WORLD  ")]
    df = spark.createDataFrame(data)
    result = df.withColumn("clean", normalize_text_pandas(F.col("text")))
    assert result.collect()[0]["clean"] == "hello world"
```

## 4. 성능 최적화

### AQE (Adaptive Query Execution)

```python
# Spark 3.0+ 기본 활성화
spark.conf.set("spark.sql.adaptive.enabled", "true")
spark.conf.set("spark.sql.adaptive.coalescePartitions.enabled", "true")
spark.conf.set("spark.sql.adaptive.skewJoin.enabled", "true")
```

### 조인 최적화

```python
# 브로드캐스트 조인 (작은 테이블 < 10MB)
from pyspark.sql.functions import broadcast
result = large_df.join(broadcast(small_df), "key")

# Bucket 조인 (반복 조인 시)
df.write.bucketBy(256, "key").sortBy("key").saveAsTable("bucketed_table")

# 스큐 핸들링 (AQE 또는 salting)
from pyspark.sql import functions as F

# salting 기법: 핫키에 랜덤 suffix 추가
salt_range = 10
skewed_df = df.withColumn("salt", (F.rand() * salt_range).cast("int"))
small_df_exploded = small_df.crossJoin(
    spark.range(salt_range).withColumnRenamed("id", "salt")
)
result = skewed_df.join(small_df_exploded, ["key", "salt"])
```

### 캐싱 전략

```python
# 반복 사용 데이터 캐싱
from pyspark import StorageLevel

df.persist(StorageLevel.MEMORY_AND_DISK)
df.count()  # 캐시 트리거

# 사용 후 해제
df.unpersist()
```

### 실행 계획 분석

```python
# 논리적/물리적 실행 계획 확인
df.explain(mode="extended")

# Spark UI에서 확인할 항목:
# - Shuffle Read/Write 크기
# - 스큐 여부 (태스크 시간 편차)
# - Spill (메모리 부족으로 디스크 사용)
```

## 5. 체크리스트

### 프로젝트 셋업
- [ ] SparkSession 팩토리 구성
- [ ] 환경별 설정 파일 작성
- [ ] 테스트 인프라 구축 (chispa)
- [ ] CI/CD (spark-submit 자동화)

### 개발
- [ ] 스키마 명시적 정의
- [ ] 내장 함수 우선 사용 (UDF 최소화)
- [ ] Pandas UDF로 벡터화 처리
- [ ] AQE 활성화

### 파티셔닝
- [ ] 적절한 파티션 키 선택
- [ ] 파일당 최대 행 수 설정
- [ ] 파티션 프루닝 활용
- [ ] 스큐 핸들링

### 운영
- [ ] spark-submit 스크립트 준비
- [ ] 동적 할당 설정
- [ ] 모니터링 (Spark UI, 메트릭)
- [ ] 데이터 품질 체크 통합
