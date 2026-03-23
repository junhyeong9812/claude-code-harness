# PySpark 소규모 프로젝트 가이드

## 매칭 조건

- Local mode로 PySpark 학습/프로토타이핑
- 데이터: 수 MB ~ 수 GB
- 기본 DataFrame 연산
- 간단한 배치 잡
- 팀 규모: 1~2명

## 1. 프로젝트 구조

```
pyspark-small/
├── notebooks/
│   ├── 01_explore.ipynb          # 데이터 탐색
│   └── 02_transform.ipynb        # 변환 실험
├── data/
│   ├── input/
│   └── output/
├── src/
│   ├── __init__.py
│   ├── spark_session.py          # SparkSession 생성
│   ├── transformations.py        # 변환 함수
│   └── utils.py
├── jobs/
│   └── simple_etl.py             # ETL 잡
├── requirements.txt
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 SparkSession 생성

```python
# src/spark_session.py
from pyspark.sql import SparkSession


def get_spark(app_name: str = "local-app") -> SparkSession:
    """로컬 모드 SparkSession 생성"""
    spark = (
        SparkSession.builder
        .appName(app_name)
        .master("local[*]")                    # 모든 코어 사용
        .config("spark.driver.memory", "4g")
        .config("spark.sql.shuffle.partitions", "8")
        .config("spark.sql.session.timeZone", "Asia/Seoul")
        .getOrCreate()
    )
    spark.sparkContext.setLogLevel("WARN")
    return spark


spark = get_spark()
print(f"Spark 버전: {spark.version}")
```

### 2.2 기본 DataFrame 연산

```python
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType, DoubleType, TimestampType

# 스키마 정의
schema = StructType([
    StructField("order_id", StringType(), False),
    StructField("customer_id", StringType(), False),
    StructField("product_id", StringType(), False),
    StructField("amount", DoubleType(), False),
    StructField("order_date", StringType(), False),
    StructField("category", StringType(), True),
])

# CSV 읽기
df = (
    spark.read
    .option("header", "true")
    .option("encoding", "UTF-8")
    .schema(schema)
    .csv("data/input/sales.csv")
)

# 기본 확인
df.printSchema()
df.show(5)
print(f"행 수: {df.count():,}")

# 필터링
active_orders = df.filter(
    (F.col("amount") > 0) & (F.col("category").isNotNull())
)

# 컬럼 변환
transformed = df.withColumns({
    "order_date": F.to_date(F.col("order_date")),
    "year_month": F.date_format(F.col("order_date"), "yyyy-MM"),
    "amount_category": F.when(F.col("amount") > 10000, "high")
                        .when(F.col("amount") > 1000, "medium")
                        .otherwise("low"),
})

# 집계
summary = (
    transformed
    .groupBy("category")
    .agg(
        F.sum("amount").alias("total_amount"),
        F.avg("amount").alias("avg_amount"),
        F.countDistinct("customer_id").alias("unique_customers"),
        F.count("*").alias("order_count"),
    )
    .orderBy(F.desc("total_amount"))
)

summary.show()
```

### 2.3 데이터 정제

```python
# src/transformations.py
from pyspark.sql import DataFrame
from pyspark.sql import functions as F


def clean_data(df: DataFrame) -> DataFrame:
    """기본 데이터 정제"""
    return (
        df
        # 중복 제거
        .dropDuplicates(["order_id"])
        # 결측치 처리
        .na.fill({"category": "unknown"})
        .na.drop(subset=["order_id", "customer_id", "amount"])
        # 이상치 제거
        .filter(F.col("amount").between(0, 10_000_000))
        # 타입 변환
        .withColumn("order_date", F.to_date("order_date"))
        # 트리밍
        .withColumn("category", F.trim(F.lower(F.col("category"))))
    )


def add_derived_columns(df: DataFrame) -> DataFrame:
    """파생 컬럼 추가"""
    return df.withColumns({
        "year": F.year("order_date"),
        "month": F.month("order_date"),
        "day_of_week": F.dayofweek("order_date"),
        "is_weekend": F.dayofweek("order_date").isin([1, 7]).cast("int"),
    })


def compute_customer_stats(df: DataFrame) -> DataFrame:
    """고객별 통계"""
    return (
        df.groupBy("customer_id")
        .agg(
            F.min("order_date").alias("first_order"),
            F.max("order_date").alias("last_order"),
            F.count("*").alias("total_orders"),
            F.sum("amount").alias("total_spent"),
            F.avg("amount").alias("avg_order_amount"),
        )
        .withColumn(
            "days_since_first",
            F.datediff(F.current_date(), F.col("first_order")),
        )
    )
```

### 2.4 간단한 ETL 잡

```python
# jobs/simple_etl.py
from src.spark_session import get_spark
from src.transformations import clean_data, add_derived_columns
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def main():
    spark = get_spark("simple-etl")

    # Extract
    logger.info("데이터 읽기...")
    df = spark.read.option("header", "true").csv("data/input/sales.csv")
    logger.info(f"입력: {df.count():,}건")

    # Transform
    logger.info("변환 중...")
    cleaned = clean_data(df)
    result = add_derived_columns(cleaned)
    logger.info(f"출력: {result.count():,}건")

    # Load
    logger.info("저장 중...")
    (
        result.write
        .mode("overwrite")
        .partitionBy("year", "month")
        .parquet("data/output/cleaned_sales")
    )

    logger.info("ETL 완료!")
    spark.stop()


if __name__ == "__main__":
    main()
```

### 2.5 조인 및 윈도우 함수

```python
# 조인
orders = spark.read.parquet("data/orders")
products = spark.read.parquet("data/products")

enriched = orders.join(products, on="product_id", how="left")

# 윈도우 함수
from pyspark.sql.window import Window

window_spec = Window.partitionBy("customer_id").orderBy("order_date")

ranked = df.withColumns({
    "row_num": F.row_number().over(window_spec),
    "running_total": F.sum("amount").over(window_spec),
    "prev_amount": F.lag("amount", 1).over(window_spec),
})

# 최근 N건만 가져오기
latest_3 = (
    ranked
    .filter(F.col("row_num") <= 3)
    .orderBy("customer_id", "order_date")
)
```

### 2.6 결과 저장

```python
# Parquet (기본 추천)
df.write.mode("overwrite").parquet("data/output/result")

# 파티션 기반 저장
df.write.mode("overwrite").partitionBy("year", "month").parquet("data/output/result")

# CSV (외부 공유용)
df.coalesce(1).write.mode("overwrite").option("header", "true").csv("data/output/result_csv")

# 단일 Pandas DataFrame으로 변환
pandas_df = df.toPandas()
```

## 3. 테스트/검증 전략

### 변환 함수 테스트

```python
# tests/test_transformations.py
import pytest
from pyspark.sql import SparkSession
from pyspark.sql import Row
from src.transformations import clean_data


@pytest.fixture(scope="session")
def spark():
    return SparkSession.builder.master("local[2]").appName("test").getOrCreate()


def test_clean_data_removes_duplicates(spark):
    data = [
        Row(order_id="1", customer_id="C1", amount=100.0, category="food", order_date="2024-01-01"),
        Row(order_id="1", customer_id="C1", amount=100.0, category="food", order_date="2024-01-01"),
    ]
    df = spark.createDataFrame(data)
    result = clean_data(df)
    assert result.count() == 1


def test_clean_data_removes_negative_amounts(spark):
    data = [
        Row(order_id="1", customer_id="C1", amount=-50.0, category="food", order_date="2024-01-01"),
        Row(order_id="2", customer_id="C2", amount=100.0, category="food", order_date="2024-01-01"),
    ]
    df = spark.createDataFrame(data)
    result = clean_data(df)
    assert result.count() == 1
    assert result.collect()[0]["order_id"] == "2"
```

### 데이터 검증

```python
def validate_output(df, expected_schema=None):
    """출력 데이터 검증"""
    assert df.count() > 0, "빈 데이터프레임"

    # 결측치 확인
    for col_name in ["order_id", "customer_id", "amount"]:
        null_count = df.filter(F.col(col_name).isNull()).count()
        assert null_count == 0, f"{col_name}에 {null_count}개 null"

    # 값 범위
    stats = df.select(
        F.min("amount").alias("min_amount"),
        F.max("amount").alias("max_amount"),
    ).collect()[0]

    assert stats["min_amount"] >= 0, f"음수 금액: {stats['min_amount']}"
    print(f"검증 통과 ({df.count():,}건)")
```

## 4. 성능 최적화

### 기본 튜닝

```python
# 셔플 파티션 수 조정 (로컬에서는 작게)
spark.conf.set("spark.sql.shuffle.partitions", 8)

# 캐싱 (반복 사용 데이터)
df.cache()
df.count()  # 캐시 트리거

# 파티션 수 확인 및 조정
print(f"파티션 수: {df.rdd.getNumPartitions()}")
df = df.repartition(4)   # 파티션 증가
df = df.coalesce(1)      # 파티션 감소 (셔플 없음)
```

### 실행 계획 확인

```python
# 쿼리 실행 계획 확인
df.explain(mode="formatted")

# 브로드캐스트 조인 (작은 테이블)
from pyspark.sql.functions import broadcast
result = big_df.join(broadcast(small_df), on="key")
```

## 5. 체크리스트

### 시작 시
- [ ] PySpark 로컬 설치 확인
- [ ] SparkSession 설정 (메모리, 파티션)
- [ ] 입력 데이터 스키마 확인
- [ ] 데이터 크기/파티션 수 확인

### 개발 시
- [ ] 스키마 명시적 정의
- [ ] null 처리 전략 수립
- [ ] 변환 함수 단위 테스트
- [ ] explain()으로 실행 계획 확인

### 완료 시
- [ ] 출력 데이터 검증
- [ ] Parquet 포맷 저장
- [ ] SparkSession 종료
- [ ] 로컬 실행 성공 확인
