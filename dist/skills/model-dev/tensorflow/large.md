# TensorFlow 대규모 프로젝트 가이드

## 매칭 조건

- 팀 규모 10명 이상 / 다수 팀 협업
- 데이터: 수백 GB ~ TB 이상
- TFX 파이프라인, 분산 학습 전략
- TF Serving / Vertex AI 배포
- 완전 자동화된 MLOps

## 1. 프로젝트 구조

```
tf-large/
├── configs/
│   ├── pipeline/
│   │   ├── training.yaml
│   │   ├── serving.yaml
│   │   └── monitoring.yaml
│   ├── model/
│   │   └── large_model.yaml
│   └── infra/
│       ├── vertex_ai.yaml
│       └── gke.yaml
├── src/
│   ├── __init__.py
│   ├── data/
│   │   ├── __init__.py
│   │   ├── schema.py             # 데이터 스키마 정의
│   │   ├── preprocessing.py      # 전처리 (TFX Transform)
│   │   └── validation.py         # 데이터 검증 (TFDV)
│   ├── models/
│   │   ├── __init__.py
│   │   ├── model.py
│   │   └── layers/
│   ├── training/
│   │   ├── __init__.py
│   │   ├── trainer.py
│   │   ├── distributed.py        # 분산 전략
│   │   └── tuner.py              # 하이퍼파라미터 튜닝
│   ├── serving/
│   │   ├── __init__.py
│   │   ├── model_server.py
│   │   └── preprocessing.py      # 서빙용 전처리
│   └── pipeline/
│       ├── __init__.py
│       ├── tfx_pipeline.py       # TFX 파이프라인 정의
│       └── components/
│           ├── custom_trainer.py
│           └── custom_evaluator.py
├── pipeline/
│   ├── Dockerfile
│   ├── kubeflow_pipeline.py
│   └── vertex_pipeline.py
├── serving/
│   ├── Dockerfile.serving
│   ├── tf_serving_config/
│   │   └── models.config
│   └── envoy/
│       └── envoy.yaml
├── monitoring/
│   ├── data_validation.py
│   ├── model_analysis.py
│   └── alerts/
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── terraform/
│   ├── main.tf
│   ├── vertex_ai.tf
│   └── gke.tf
├── k8s/
│   ├── tf-serving.yaml
│   └── hpa.yaml
├── pyproject.toml
├── Makefile
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 TFX 파이프라인

```python
# src/pipeline/tfx_pipeline.py
import tensorflow as tf
from tfx import v1 as tfx
from tfx.proto import example_gen_pb2, trainer_pb2
from tfx.dsl.components.common import resolver
from tfx.dsl.experimental import latest_blessed_model_resolver


def create_pipeline(
    pipeline_name: str,
    pipeline_root: str,
    data_path: str,
    module_file: str,
    serving_model_dir: str,
    metadata_path: str,
) -> tfx.dsl.Pipeline:
    """TFX 파이프라인 생성"""

    # 1. 데이터 수집
    example_gen = tfx.components.CsvExampleGen(
        input_base=data_path,
        output_config=example_gen_pb2.Output(
            split_config=example_gen_pb2.SplitConfig(splits=[
                example_gen_pb2.SplitConfig.Split(name="train", hash_buckets=8),
                example_gen_pb2.SplitConfig.Split(name="eval", hash_buckets=2),
            ])
        ),
    )

    # 2. 데이터 통계
    statistics_gen = tfx.components.StatisticsGen(
        examples=example_gen.outputs["examples"]
    )

    # 3. 스키마 추론
    schema_gen = tfx.components.SchemaGen(
        statistics=statistics_gen.outputs["statistics"]
    )

    # 4. 데이터 검증
    example_validator = tfx.components.ExampleValidator(
        statistics=statistics_gen.outputs["statistics"],
        schema=schema_gen.outputs["schema"],
    )

    # 5. 데이터 변환 (Feature Engineering)
    transform = tfx.components.Transform(
        examples=example_gen.outputs["examples"],
        schema=schema_gen.outputs["schema"],
        module_file=module_file,
    )

    # 6. 학습
    trainer = tfx.components.Trainer(
        module_file=module_file,
        examples=transform.outputs["transformed_examples"],
        transform_graph=transform.outputs["transform_graph"],
        schema=schema_gen.outputs["schema"],
        train_args=trainer_pb2.TrainArgs(num_steps=10000),
        eval_args=trainer_pb2.EvalArgs(num_steps=1000),
    )

    # 7. 최신 blessed 모델 가져오기
    model_resolver = resolver.Resolver(
        strategy_class=latest_blessed_model_resolver.LatestBlessedModelResolver,
        model=tfx.dsl.Channel(type=tfx.types.standard_artifacts.Model),
        model_blessing=tfx.dsl.Channel(
            type=tfx.types.standard_artifacts.ModelBlessing
        ),
    )

    # 8. 모델 평가
    evaluator = tfx.components.Evaluator(
        examples=example_gen.outputs["examples"],
        model=trainer.outputs["model"],
        baseline_model=model_resolver.outputs["model"],
        eval_config=tfx.proto.EvalConfig(
            model_specs=[tfx.proto.ModelSpec(label_key="label")],
            slicing_specs=[
                tfx.proto.SlicingSpec(),  # 전체
                tfx.proto.SlicingSpec(feature_keys=["category"]),  # 카테고리별
            ],
            metrics_specs=[
                tfx.proto.MetricsSpec(
                    metrics=[
                        tfx.proto.MetricConfig(class_name="BinaryAccuracy"),
                        tfx.proto.MetricConfig(class_name="AUC"),
                    ],
                    thresholds={
                        "binary_accuracy": tfx.proto.MetricThreshold(
                            value_threshold=tfx.proto.GenericValueThreshold(
                                lower_bound={"value": 0.9}
                            ),
                            change_threshold=tfx.proto.GenericChangeThreshold(
                                direction=tfx.proto.MetricDirection.HIGHER_IS_BETTER,
                                absolute={"value": -0.01},
                            ),
                        ),
                    },
                ),
            ],
        ),
    )

    # 9. 모델 푸시
    pusher = tfx.components.Pusher(
        model=trainer.outputs["model"],
        model_blessing=evaluator.outputs["blessing"],
        push_destination=tfx.proto.PushDestination(
            filesystem=tfx.proto.PushDestination.Filesystem(
                base_directory=serving_model_dir
            )
        ),
    )

    return tfx.dsl.Pipeline(
        pipeline_name=pipeline_name,
        pipeline_root=pipeline_root,
        components=[
            example_gen, statistics_gen, schema_gen, example_validator,
            transform, trainer, model_resolver, evaluator, pusher,
        ],
        metadata_connection_config=tfx.orchestration.metadata.sqlite_metadata_connection_config(
            metadata_path
        ),
    )
```

### 2.2 분산 학습 전략

```python
# src/training/distributed.py
import tensorflow as tf
import json
import os


def get_distribution_strategy(strategy_type: str = "mirrored"):
    """분산 전략 생성"""

    if strategy_type == "mirrored":
        # 단일 노드, 멀티 GPU
        return tf.distribute.MirroredStrategy()

    elif strategy_type == "multi_worker":
        # 멀티 노드
        tf_config = json.loads(os.environ.get("TF_CONFIG", "{}"))
        return tf.distribute.MultiWorkerMirroredStrategy(
            communication_options=tf.distribute.experimental.CommunicationOptions(
                implementation=tf.distribute.experimental.CommunicationImplementation.NCCL
            )
        )

    elif strategy_type == "tpu":
        resolver = tf.distribute.cluster_resolver.TPUClusterResolver()
        tf.config.experimental_connect_to_cluster(resolver)
        tf.tpu.experimental.initialize_tpu_system(resolver)
        return tf.distribute.TPUStrategy(resolver)

    elif strategy_type == "parameter_server":
        cluster_resolver = tf.distribute.cluster_resolver.TFConfigClusterResolver()
        return tf.distribute.ParameterServerStrategy(cluster_resolver)

    else:
        return tf.distribute.get_strategy()  # 기본 (no distribution)


def distributed_train(cfg):
    """분산 학습 실행"""
    strategy = get_distribution_strategy(cfg.training.strategy)

    # 글로벌 배치 사이즈 계산
    global_batch_size = cfg.training.batch_size_per_replica * strategy.num_replicas_in_sync
    print(f"분산 전략: {strategy.__class__.__name__}, "
          f"레플리카 수: {strategy.num_replicas_in_sync}, "
          f"글로벌 배치: {global_batch_size}")

    with strategy.scope():
        model = build_model(cfg.model)
        model.compile(
            optimizer=tf.keras.optimizers.Adam(cfg.training.lr),
            loss="sparse_categorical_crossentropy",
            metrics=["accuracy"],
        )

    # 데이터셋 분산
    train_ds = create_dataset(cfg.data, global_batch_size)
    dist_train_ds = strategy.experimental_distribute_dataset(train_ds)

    model.fit(dist_train_ds, epochs=cfg.training.epochs)
    return model
```

### 2.3 TF Serving 구성

```protobuf
# serving/tf_serving_config/models.config
model_config_list {
  config {
    name: "my_model"
    base_path: "/models/my_model"
    model_platform: "tensorflow"
    model_version_policy {
      specific {
        versions: 1
        versions: 2
      }
    }
    version_labels {
      key: "stable"
      value: 1
    }
    version_labels {
      key: "canary"
      value: 2
    }
  }
}
```

```yaml
# k8s/tf-serving.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tf-serving
spec:
  replicas: 3
  selector:
    matchLabels:
      app: tf-serving
  template:
    spec:
      containers:
      - name: tf-serving
        image: tensorflow/serving:latest-gpu
        args:
        - --model_config_file=/config/models.config
        - --monitoring_config_file=/config/monitoring.config
        - --enable_batching=true
        - --batching_parameters_file=/config/batching.config
        resources:
          limits:
            nvidia.com/gpu: 1
            memory: "16Gi"
        ports:
        - containerPort: 8501  # REST
        - containerPort: 8500  # gRPC
        readinessProbe:
          httpGet:
            path: /v1/models/my_model
            port: 8501
          initialDelaySeconds: 30
```

### 2.4 Vertex AI 파이프라인

```python
# pipeline/vertex_pipeline.py
from google.cloud import aiplatform
from kfp.v2 import dsl, compiler


@dsl.pipeline(name="ml-training-pipeline")
def training_pipeline(
    project_id: str,
    region: str,
    data_uri: str,
    model_display_name: str,
):
    # 데이터 전처리
    preprocess_op = preprocess_component(
        input_data=data_uri,
        output_path=f"gs://{project_id}-ml/processed",
    )

    # 학습
    train_op = train_component(
        training_data=preprocess_op.outputs["output_path"],
        epochs=100,
        batch_size=256,
        learning_rate=1e-3,
    )

    # 평가
    eval_op = evaluate_component(
        model=train_op.outputs["model"],
        test_data=preprocess_op.outputs["test_path"],
    )

    # 조건부 배포
    with dsl.Condition(eval_op.outputs["accuracy"] > 0.95):
        deploy_op = deploy_component(
            model=train_op.outputs["model"],
            model_name=model_display_name,
            endpoint_name=f"{model_display_name}-endpoint",
            machine_type="n1-standard-4",
            accelerator_type="NVIDIA_TESLA_T4",
            accelerator_count=1,
            min_replicas=1,
            max_replicas=5,
        )


def run_pipeline():
    aiplatform.init(project="my-project", location="us-central1")
    compiler.Compiler().compile(
        pipeline_func=training_pipeline,
        package_path="pipeline.json",
    )
    job = aiplatform.PipelineJob(
        display_name="training-pipeline",
        template_path="pipeline.json",
        parameter_values={
            "project_id": "my-project",
            "region": "us-central1",
            "data_uri": "gs://my-bucket/data",
            "model_display_name": "my-model-v2",
        },
    )
    job.run()
```

### 2.5 모델 모니터링

```python
# monitoring/model_analysis.py
import tensorflow_model_analysis as tfma


def analyze_model(eval_result_path: str):
    """모델 성능 분석 (TFMA)"""
    eval_config = tfma.EvalConfig(
        model_specs=[tfma.ModelSpec(label_key="label")],
        slicing_specs=[
            tfma.SlicingSpec(),
            tfma.SlicingSpec(feature_keys=["age_group"]),
            tfma.SlicingSpec(feature_keys=["gender"]),
        ],
        metrics_specs=[
            tfma.MetricsSpec(
                metrics=[
                    tfma.MetricConfig(class_name="AUC"),
                    tfma.MetricConfig(class_name="FairnessIndicators",
                                      config='{"thresholds": [0.5]}'),
                ],
            ),
        ],
    )

    eval_result = tfma.load_eval_result(eval_result_path)
    tfma.view.render_slicing_metrics(eval_result)
    return eval_result
```

```python
# monitoring/data_validation.py
import tensorflow_data_validation as tfdv


def validate_new_data(stats_path: str, schema_path: str, new_data_path: str):
    """새 데이터의 스키마/분포 검증"""
    schema = tfdv.load_schema_text(schema_path)
    reference_stats = tfdv.load_statistics(stats_path)
    new_stats = tfdv.generate_statistics_from_csv(new_data_path)

    # 스키마 이상 감지
    anomalies = tfdv.validate_statistics(new_stats, schema)
    if anomalies.anomaly_info:
        print("스키마 이상 감지:")
        for feature, info in anomalies.anomaly_info.items():
            print(f"  - {feature}: {info.description}")

    # 분포 드리프트 감지
    schema.default_environment.append("TRAINING")
    schema.default_environment.append("SERVING")

    drift_anomalies = tfdv.validate_statistics(
        new_stats, schema, environment="SERVING",
        previous_statistics=reference_stats,
    )

    return anomalies, drift_anomalies
```

## 3. 테스트/검증 전략

### E2E 파이프라인 테스트

```python
# tests/e2e/test_pipeline.py
import pytest


@pytest.mark.e2e
def test_tfx_pipeline_local():
    """TFX 파이프라인 로컬 실행 테스트"""
    from src.pipeline.tfx_pipeline import create_pipeline
    from tfx.orchestration import LocalDagRunner

    pipeline = create_pipeline(
        pipeline_name="test-pipeline",
        pipeline_root="/tmp/test_pipeline",
        data_path="tests/fixtures/sample_data",
        module_file="src/pipeline/components/custom_trainer.py",
        serving_model_dir="/tmp/test_serving",
        metadata_path="/tmp/test_metadata.db",
    )

    LocalDagRunner().run(pipeline)


@pytest.mark.e2e
def test_serving_endpoint():
    """서빙 엔드포인트 테스트"""
    import requests
    import numpy as np

    payload = {
        "instances": np.random.randn(2, 224, 224, 3).tolist()
    }
    response = requests.post(
        "http://localhost:8501/v1/models/my_model:predict",
        json=payload,
    )
    assert response.status_code == 200
    predictions = response.json()["predictions"]
    assert len(predictions) == 2
```

## 4. 성능 최적화

### TF Serving 배칭 설정

```
# serving/tf_serving_config/batching.config
max_batch_size { value: 128 }
batch_timeout_micros { value: 10000 }
max_enqueued_batches { value: 1000000 }
num_batch_threads { value: 8 }
```

### 모델 최적화

```python
# TensorRT 최적화
from tensorflow.python.compiler.tensorrt import trt_convert as trt

converter = trt.TrtGraphConverterV2(
    input_saved_model_dir="saved_model",
    conversion_params=trt.TrtConversionParams(
        precision_mode=trt.TrtPrecisionMode.FP16,
        max_workspace_size_bytes=1 << 30,
    ),
)
converter.convert()
converter.save("saved_model_trt")
```

### TPU 최적화

```python
# TPU 학습 최적화
strategy = tf.distribute.TPUStrategy(resolver)

with strategy.scope():
    model = build_model()
    model.compile(
        optimizer=tf.keras.optimizers.Adam(1e-3),
        loss="sparse_categorical_crossentropy",
        steps_per_execution=100,  # TPU에서 중요: 스텝 배칭
    )
```

## 5. 체크리스트

### 인프라
- [ ] GKE / Vertex AI 환경 프로비저닝
- [ ] GPU/TPU 클러스터 설정
- [ ] 분산 스토리지 (GCS) 구성
- [ ] 네트워크 설정 (VPC, 방화벽)
- [ ] Terraform으로 IaC 관리

### MLOps 파이프라인
- [ ] TFX 파이프라인 구축 및 검증
- [ ] 데이터 검증 (TFDV) 설정
- [ ] 모델 평가 자동화 (TFMA)
- [ ] 모델 레지스트리 운영
- [ ] CI/CD (학습 -> 평가 -> 배포)

### 서빙
- [ ] TF Serving 배포 및 설정
- [ ] 배칭 최적화
- [ ] 오토스케일링 (HPA)
- [ ] 카나리 배포 설정
- [ ] A/B 테스트 인프라

### 모니터링
- [ ] 데이터 드리프트 감지 (TFDV)
- [ ] 모델 성능 모니터링
- [ ] 공정성 지표 추적
- [ ] 알림 설정
- [ ] 자동 재학습 트리거

### 거버넌스
- [ ] 모델 카드 작성
- [ ] 데이터 리니지 추적
- [ ] 감사 로그
- [ ] RBAC 설정
- [ ] 컴플라이언스 검토
