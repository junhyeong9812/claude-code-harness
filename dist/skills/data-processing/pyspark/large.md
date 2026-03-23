# PySpark 대규모 프로젝트 가이드

## 매칭 조건

- 데이터 플랫폼 수준 운영
- 데이터: 수백 GB ~ PB
- Delta Lake, Structured Streaming
- 비용 최적화, 거버넌스
- 팀 규모 10명+ / 다수 팀

## 1. 프로젝트 구조

```
pyspark-large/
├── configs/
│   ├── base.yaml
│   ├── cluster/
│   │   ├── dev.yaml
│   │   ├── staging.yaml
│   │   └── prod.yaml
│   ├── jobs/
│   │   ├── ingestion.yaml
│   │   ├── transformation.yaml
│   │   └── streaming.yaml
│   └── delta/
│       └── table_configs.yaml
├── src/
│   ├── __init__.py
│   ├── platform/
│   │   ├── __init__.py
│   │   ├── catalog.py            # 데이터 카탈로그
│   │   ├── lineage.py            # 리니지 추적
│   │   └── governance.py         # 거버넌스
│   ├── ingestion/
│   │   ├── __init__.py
│   │   ├── batch.py              # 배치 수집
│   │   └── streaming.py          # 스트리밍 수집
│   ├── transformers/
│   │   ├── __init__.py
│   │   ├── bronze.py             # 메달리온: 브론즈
│   │   ├── silver.py             # 메달리온: 실버
│   │   └── gold.py               # 메달리온: 골드
│   ├── delta/
│   │   ├── __init__.py
│   │   ├── table_manager.py      # Delta 테이블 관리
│   │   ├── maintenance.py        # OPTIMIZE, VACUUM
│   │   └── cdc.py                # Change Data Capture
│   ├── streaming/
│   │   ├── __init__.py
│   │   ├── kafka_consumer.py
│   │   └── processors.py
│   ├── quality/
│   │   ├── __init__.py
│   │   └── expectations.py
│   ├── monitoring/
│   │   ├── __init__.py
│   │   ├── metrics.py
│   │   ├── cost_tracker.py
│   │   └── alerts.py
│   └── utils/
│       ├── __init__.py
│       └── secrets.py
├── jobs/
│   ├── batch/
│   │   ├── ingest_raw.py
│   │   ├── bronze_to_silver.py
│   │   └── silver_to_gold.py
│   ├── streaming/
│   │   └── kafka_to_delta.py
│   └── maintenance/
│       ├── optimize_tables.py
│       └── vacuum_tables.py
├── dags/
│   ├── batch_pipeline.py
│   └── maintenance_dag.py
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── deploy/
│   ├── databricks/
│   │   ├── clusters.json
│   │   └── jobs.json
│   ├── emr/
│   │   └── bootstrap.sh
│   └── terraform/
├── pyproject.toml
├── Makefile
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 메달리온 아키텍처 (Bronze / Silver / Gold)

```python
# src/transformers/bronze.py
from pyspark.sql import DataFrame, SparkSession
from pyspark.sql import functions as F
from delta.tables import DeltaTable
import logging

logger = logging.getLogger(__name__)


class BronzeLayer:
    """브론즈 레이어: 원본 데이터 그대로 수집"""

    def __init__(self, spark: SparkSession, base_path: str):
        self.spark = spark
        self.base_path = base_path

    def ingest(self, source_path: str, table_name: str, source_format: str = "json"):
        """원본 데이터 수집 (메타데이터 추가)"""
        df = (
            self.spark.read
            .format(source_format)
            .load(source_path)
        )

        # 수집 메타데이터 추가
        bronze_df = df.withColumns({
            "_ingested_at": F.current_timestamp(),
            "_source_file": F.input_file_name(),
            "_raw_data": F.to_json(F.struct("*")),  # 원본 보존
        })

        # Delta Lake로 저장 (append)
        target = f"{self.base_path}/bronze/{table_name}"
        (
            bronze_df.write
            .format("delta")
            .mode("append")
            .partitionBy("_ingested_at")
            .save(target)
        )

        logger.info(f"브론즈 수집 완료: {table_name} ({bronze_df.count():,}건)")
        return bronze_df
```

```python
# src/transformers/silver.py
class SilverLayer:
    """실버 레이어: 정제/스키마 적용/중복 제거"""

    def __init__(self, spark: SparkSession, base_path: str):
        self.spark = spark
        self.base_path = base_path

    def process_sales(self):
        """매출 데이터 정제 (Bronze -> Silver)"""
        bronze_df = self.spark.read.format("delta").load(
            f"{self.base_path}/bronze/sales"
        )

        silver_df = (
            bronze_df
            # 스키마 적용 및 타입 변환
            .select(
                F.col("order_id").cast("string"),
                F.col("customer_id").cast("string"),
                F.col("product_id").cast("string"),
                F.col("amount").cast("double"),
                F.col("quantity").cast("int"),
                F.to_timestamp("order_date").alias("order_date"),
                F.col("category").cast("string"),
            )
            # 정제
            .filter(F.col("order_id").isNotNull())
            .filter(F.col("amount") >= 0)
            .dropDuplicates(["order_id"])
            # 파생 컬럼
            .withColumns({
                "order_year": F.year("order_date"),
                "order_month": F.month("order_date"),
                "_processed_at": F.current_timestamp(),
            })
        )

        # Delta Lake MERGE (upsert)
        target_path = f"{self.base_path}/silver/sales"

        if DeltaTable.isDeltaTable(self.spark, target_path):
            target = DeltaTable.forPath(self.spark, target_path)
            (
                target.alias("target")
                .merge(silver_df.alias("source"), "target.order_id = source.order_id")
                .whenMatchedUpdateAll()
                .whenNotMatchedInsertAll()
                .execute()
            )
        else:
            (
                silver_df.write
                .format("delta")
                .partitionBy("order_year", "order_month")
                .save(target_path)
            )

        logger.info(f"실버 처리 완료: sales ({silver_df.count():,}건)")
```

```python
# src/transformers/gold.py
class GoldLayer:
    """골드 레이어: 비즈니스 집계/마트"""

    def __init__(self, spark: SparkSession, base_path: str):
        self.spark = spark
        self.base_path = base_path

    def build_daily_sales_summary(self):
        """일별 매출 요약 마트"""
        sales = self.spark.read.format("delta").load(
            f"{self.base_path}/silver/sales"
        )

        daily = (
            sales
            .groupBy(
                F.col("order_date").cast("date").alias("date"),
                "category",
            )
            .agg(
                F.sum("amount").alias("total_revenue"),
                F.count("*").alias("order_count"),
                F.countDistinct("customer_id").alias("unique_customers"),
                F.avg("amount").alias("avg_order_value"),
                F.percentile_approx("amount", 0.5).alias("median_order_value"),
            )
            .withColumn("_built_at", F.current_timestamp())
        )

        (
            daily.write
            .format("delta")
            .mode("overwrite")
            .option("overwriteSchema", "true")
            .save(f"{self.base_path}/gold/daily_sales_summary")
        )

        logger.info(f"골드 빌드 완료: daily_sales_summary ({daily.count():,}건)")
```

### 2.2 Delta Lake 관리

```python
# src/delta/table_manager.py
from delta.tables import DeltaTable
from pyspark.sql import SparkSession
import logging

logger = logging.getLogger(__name__)


class DeltaTableManager:
    """Delta Lake 테이블 관리"""

    def __init__(self, spark: SparkSession):
        self.spark = spark

    def optimize(self, table_path: str, z_order_cols: list[str] = None):
        """OPTIMIZE 실행 (파일 압축)"""
        dt = DeltaTable.forPath(self.spark, table_path)
        if z_order_cols:
            dt.optimize().executeZOrderBy(*z_order_cols)
            logger.info(f"OPTIMIZE + Z-ORDER 완료: {table_path} ({z_order_cols})")
        else:
            dt.optimize().executeCompaction()
            logger.info(f"OPTIMIZE 완료: {table_path}")

    def vacuum(self, table_path: str, retention_hours: int = 168):
        """VACUUM 실행 (오래된 파일 삭제)"""
        dt = DeltaTable.forPath(self.spark, table_path)
        dt.vacuum(retention_hours)
        logger.info(f"VACUUM 완료: {table_path} (보존: {retention_hours}시간)")

    def time_travel(self, table_path: str, version: int = None, timestamp: str = None):
        """타임 트래블 (과거 버전 읽기)"""
        reader = self.spark.read.format("delta")
        if version is not None:
            return reader.option("versionAsOf", version).load(table_path)
        elif timestamp:
            return reader.option("timestampAsOf", timestamp).load(table_path)

    def get_history(self, table_path: str, limit: int = 10):
        """테이블 히스토리 조회"""
        dt = DeltaTable.forPath(self.spark, table_path)
        return dt.history(limit)

    def create_table_with_schema_evolution(self, df, table_path: str):
        """스키마 진화 지원 테이블 생성/업데이트"""
        (
            df.write
            .format("delta")
            .mode("append")
            .option("mergeSchema", "true")
            .save(table_path)
        )
```

### 2.3 Structured Streaming

```python
# src/streaming/kafka_consumer.py
from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType, DoubleType
import logging

logger = logging.getLogger(__name__)


class KafkaToDeltaStreamer:
    """Kafka -> Delta Lake 스트리밍 파이프라인"""

    def __init__(self, spark: SparkSession, cfg):
        self.spark = spark
        self.cfg = cfg

    def start(self):
        """스트리밍 시작"""
        # Kafka에서 읽기
        raw_stream = (
            self.spark.readStream
            .format("kafka")
            .option("kafka.bootstrap.servers", self.cfg.kafka.bootstrap_servers)
            .option("subscribe", self.cfg.kafka.topic)
            .option("startingOffsets", "latest")
            .option("maxOffsetsPerTrigger", 100_000)
            .load()
        )

        # 스키마 정의
        event_schema = StructType([
            StructField("event_id", StringType()),
            StructField("event_type", StringType()),
            StructField("user_id", StringType()),
            StructField("amount", DoubleType()),
            StructField("timestamp", StringType()),
        ])

        # 변환
        parsed = (
            raw_stream
            .select(
                F.from_json(F.col("value").cast("string"), event_schema).alias("data"),
                F.col("timestamp").alias("kafka_timestamp"),
            )
            .select("data.*", "kafka_timestamp")
            .withColumn("event_timestamp", F.to_timestamp("timestamp"))
            .withColumn("event_date", F.to_date("event_timestamp"))
            .withWatermark("event_timestamp", "10 minutes")
        )

        # Delta Lake로 저장
        query = (
            parsed.writeStream
            .format("delta")
            .outputMode("append")
            .option("checkpointLocation", self.cfg.streaming.checkpoint_path)
            .partitionBy("event_date")
            .trigger(processingTime="1 minute")
            .start(self.cfg.streaming.output_path)
        )

        logger.info(f"스트리밍 시작: {self.cfg.kafka.topic} -> Delta")
        return query

    def start_with_aggregation(self):
        """윈도우 집계 스트리밍"""
        raw_stream = self._read_kafka()

        # 5분 텀블링 윈도우 집계
        aggregated = (
            raw_stream
            .withWatermark("event_timestamp", "10 minutes")
            .groupBy(
                F.window("event_timestamp", "5 minutes"),
                "event_type",
            )
            .agg(
                F.count("*").alias("event_count"),
                F.sum("amount").alias("total_amount"),
                F.approx_count_distinct("user_id").alias("unique_users"),
            )
        )

        query = (
            aggregated.writeStream
            .format("delta")
            .outputMode("update")
            .option("checkpointLocation", f"{self.cfg.streaming.checkpoint_path}/agg")
            .trigger(processingTime="1 minute")
            .start(f"{self.cfg.streaming.output_path}_aggregated")
        )

        return query
```

### 2.4 비용 최적화

```python
# src/monitoring/cost_tracker.py
from pyspark.sql import SparkSession
import logging

logger = logging.getLogger(__name__)


class CostOptimizer:
    """Spark 비용 최적화 유틸리티"""

    def __init__(self, spark: SparkSession):
        self.spark = spark

    def analyze_partition_skew(self, df):
        """파티션 스큐 분석"""
        partition_sizes = (
            df.withColumn("partition_id", F.spark_partition_id())
            .groupBy("partition_id")
            .count()
        )

        stats = partition_sizes.select(
            F.min("count").alias("min"),
            F.max("count").alias("max"),
            F.avg("count").alias("avg"),
            F.stddev("count").alias("stddev"),
        ).collect()[0]

        skew_ratio = stats["max"] / stats["avg"] if stats["avg"] > 0 else 0
        logger.info(
            f"파티션 스큐 분석 - min: {stats['min']}, max: {stats['max']}, "
            f"avg: {stats['avg']:.0f}, skew ratio: {skew_ratio:.2f}"
        )

        if skew_ratio > 3:
            logger.warning(f"파티션 스큐 감지! (ratio: {skew_ratio:.2f})")

        return {"skew_ratio": skew_ratio, **{k: v for k, v in stats.asDict().items()}}

    def estimate_storage_cost(self, path: str, price_per_gb: float = 0.023):
        """스토리지 비용 추정 (S3 기준)"""
        from py4j.java_gateway import java_import
        java_import(self.spark._jvm, "org.apache.hadoop.fs.FileSystem")
        java_import(self.spark._jvm, "org.apache.hadoop.fs.Path")

        fs = self.spark._jvm.FileSystem.get(self.spark._jsc.hadoopConfiguration())
        status = fs.getContentSummary(self.spark._jvm.Path(path))
        size_gb = status.getLength() / (1024 ** 3)
        monthly_cost = size_gb * price_per_gb

        logger.info(f"스토리지: {size_gb:.2f} GB, 월 비용: ${monthly_cost:.2f}")
        return {"size_gb": size_gb, "monthly_cost": monthly_cost}

    def suggest_optimizations(self, df):
        """최적화 제안"""
        suggestions = []

        # 파티션 수 확인
        num_partitions = df.rdd.getNumPartitions()
        row_count = df.count()
        rows_per_partition = row_count / num_partitions if num_partitions > 0 else 0

        if rows_per_partition < 10_000:
            suggestions.append(
                f"파티션 수가 너무 많음 ({num_partitions}). "
                f"coalesce({max(1, num_partitions // 10)}) 권장"
            )
        elif rows_per_partition > 10_000_000:
            suggestions.append(
                f"파티션이 너무 큼 ({rows_per_partition:,.0f}행/파티션). "
                f"repartition({num_partitions * 4}) 권장"
            )

        for s in suggestions:
            logger.info(f"최적화 제안: {s}")

        return suggestions
```

### 2.5 Kubernetes 잡 설정

```yaml
# deploy/databricks/jobs.json
{
  "name": "daily-etl-pipeline",
  "tasks": [
    {
      "task_key": "bronze_ingest",
      "spark_python_task": {
        "python_file": "jobs/batch/ingest_raw.py"
      },
      "new_cluster": {
        "spark_version": "13.3.x-scala2.12",
        "node_type_id": "i3.xlarge",
        "num_workers": 4,
        "spark_conf": {
          "spark.sql.adaptive.enabled": "true"
        }
      }
    },
    {
      "task_key": "silver_transform",
      "depends_on": [{"task_key": "bronze_ingest"}],
      "spark_python_task": {
        "python_file": "jobs/batch/bronze_to_silver.py"
      },
      "existing_cluster_id": "shared-cluster-id"
    },
    {
      "task_key": "gold_aggregate",
      "depends_on": [{"task_key": "silver_transform"}],
      "spark_python_task": {
        "python_file": "jobs/batch/silver_to_gold.py"
      }
    }
  ],
  "schedule": {
    "quartz_cron_expression": "0 0 2 * * ?",
    "timezone_id": "Asia/Seoul"
  }
}
```

## 3. 테스트/검증 전략

### Delta Lake 테스트

```python
# tests/integration/test_delta.py
import pytest
from delta import configure_spark_with_delta_pip


@pytest.fixture(scope="session")
def spark():
    builder = (
        SparkSession.builder
        .master("local[2]")
        .config("spark.sql.extensions", "io.delta.sql.DeltaSparkSessionExtension")
        .config("spark.sql.catalog.spark_catalog", "org.apache.spark.sql.delta.catalog.DeltaCatalog")
    )
    spark = configure_spark_with_delta_pip(builder).getOrCreate()
    yield spark
    spark.stop()


def test_silver_upsert(spark, tmp_path):
    """Silver 레이어 upsert 테스트"""
    silver = SilverLayer(spark, str(tmp_path))

    # 초기 데이터
    initial = spark.createDataFrame([
        {"order_id": "1", "amount": 100.0, "order_date": "2024-01-01"},
    ])
    initial.write.format("delta").save(f"{tmp_path}/silver/sales")

    # 업데이트 데이터
    update = spark.createDataFrame([
        {"order_id": "1", "amount": 150.0, "order_date": "2024-01-01"},  # 업데이트
        {"order_id": "2", "amount": 200.0, "order_date": "2024-01-02"},  # 신규
    ])

    silver.upsert(update)

    result = spark.read.format("delta").load(f"{tmp_path}/silver/sales")
    assert result.count() == 2
    assert result.filter("order_id = '1'").collect()[0]["amount"] == 150.0
```

### 스트리밍 테스트

```python
# tests/integration/test_streaming.py
def test_streaming_pipeline(spark, tmp_path):
    """스트리밍 파이프라인 테스트"""
    from pyspark.sql.types import StructType, StructField, StringType

    schema = StructType([StructField("value", StringType())])

    # 메모리 소스로 테스트
    input_df = spark.readStream.format("rate").option("rowsPerSecond", 10).load()

    query = (
        input_df.writeStream
        .format("delta")
        .outputMode("append")
        .option("checkpointLocation", f"{tmp_path}/checkpoint")
        .start(f"{tmp_path}/output")
    )

    query.processAllAvailable()
    query.stop()

    result = spark.read.format("delta").load(f"{tmp_path}/output")
    assert result.count() > 0
```

## 4. 성능 최적화

### Delta Lake 최적화

```python
# Z-ORDER (쿼리 패턴에 맞춰 정렬)
spark.sql(f"OPTIMIZE delta.`{table_path}` ZORDER BY (customer_id, order_date)")

# Auto Compaction (Databricks)
spark.conf.set("spark.databricks.delta.autoCompact.enabled", "true")
spark.conf.set("spark.databricks.delta.optimizeWrite.enabled", "true")

# Liquid Clustering (Delta 3.0+)
spark.sql(f"""
    CREATE TABLE sales USING DELTA
    CLUSTER BY (customer_id, order_date)
    LOCATION '{table_path}'
""")
```

### 클러스터 비용 최적화

```python
# Spot 인스턴스 활용 (EMR/Databricks)
# 동적 할당으로 리소스 절약
spark.conf.set("spark.dynamicAllocation.enabled", "true")
spark.conf.set("spark.dynamicAllocation.minExecutors", "2")
spark.conf.set("spark.dynamicAllocation.maxExecutors", "50")
spark.conf.set("spark.dynamicAllocation.executorIdleTimeout", "60s")
```

## 5. 체크리스트

### 아키텍처
- [ ] 메달리온 아키텍처 설계 (Bronze/Silver/Gold)
- [ ] Delta Lake 테이블 설계 (파티셔닝, Z-ORDER)
- [ ] 스트리밍 vs 배치 결정
- [ ] 데이터 리니지 추적 구조

### Delta Lake
- [ ] 스키마 진화 전략
- [ ] MERGE (upsert) 패턴 구현
- [ ] OPTIMIZE 스케줄링
- [ ] VACUUM 정책 설정
- [ ] 타임 트래블 활용 방안

### 스트리밍
- [ ] 체크포인트 관리
- [ ] 워터마크 설정
- [ ] Exactly-once 보장
- [ ] 장애 복구 전략

### 비용 최적화
- [ ] 동적 할당 설정
- [ ] Spot 인스턴스 활용
- [ ] 파티션 스큐 해소
- [ ] 스토리지 비용 모니터링
- [ ] Auto Compaction 활성화

### 거버넌스
- [ ] 데이터 카탈로그 (Unity Catalog 등)
- [ ] 접근 제어 (테이블/컬럼 레벨)
- [ ] 데이터 보존 정책
- [ ] 감사 로그 설정
