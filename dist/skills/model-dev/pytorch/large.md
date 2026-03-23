# PyTorch 대규모 프로젝트 가이드

## 매칭 조건

- 팀 규모 10명 이상 / 다수 팀 협업
- 데이터: 수백 GB ~ TB 이상
- 멀티 노드 분산 학습 (DDP / FSDP)
- 완전 자동화된 MLOps 파이프라인
- 모델 레지스트리, A/B 테스트, 모니터링

## 1. 프로젝트 구조

```
pytorch-large/
├── configs/
│   ├── base.yaml
│   ├── model/
│   │   ├── llm_7b.yaml
│   │   ├── llm_13b.yaml
│   │   └── vision_large.yaml
│   ├── training/
│   │   ├── distributed.yaml
│   │   ├── fsdp.yaml
│   │   └── deepspeed.yaml
│   ├── data/
│   │   └── large_dataset.yaml
│   └── deploy/
│       ├── serving.yaml
│       └── ab_test.yaml
├── src/
│   ├── __init__.py
│   ├── data/
│   │   ├── __init__.py
│   │   ├── dataset.py
│   │   ├── streaming.py          # 스트리밍 데이터 로더
│   │   ├── tokenizer.py
│   │   └── preprocessing/
│   │       ├── __init__.py
│   │       └── pipeline.py
│   ├── models/
│   │   ├── __init__.py
│   │   ├── base.py
│   │   ├── llm.py
│   │   └── layers/
│   │       ├── __init__.py
│   │       ├── attention.py
│   │       └── feedforward.py
│   ├── training/
│   │   ├── __init__.py
│   │   ├── trainer.py
│   │   ├── distributed.py        # DDP/FSDP 래퍼
│   │   ├── callbacks.py
│   │   ├── optimizers.py
│   │   └── schedulers.py
│   ├── evaluation/
│   │   ├── __init__.py
│   │   ├── metrics.py
│   │   └── benchmarks.py
│   ├── serving/
│   │   ├── __init__.py
│   │   ├── model_server.py
│   │   ├── preprocessing.py
│   │   └── postprocessing.py
│   └── utils/
│       ├── __init__.py
│       ├── logging.py
│       ├── distributed.py
│       └── profiling.py
├── pipelines/
│   ├── training/
│   │   ├── Dockerfile
│   │   ├── pipeline.py           # Kubeflow/Vertex AI 파이프라인
│   │   └── components/
│   │       ├── preprocess.py
│   │       ├── train.py
│   │       └── evaluate.py
│   ├── serving/
│   │   ├── Dockerfile
│   │   └── triton_config/
│   │       └── config.pbtxt
│   └── monitoring/
│       ├── data_drift.py
│       └── model_drift.py
├── scripts/
│   ├── train_distributed.sh
│   ├── benchmark.py
│   └── model_registry.py
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
│       └── test_serving.py
├── k8s/
│   ├── training-job.yaml
│   ├── serving-deployment.yaml
│   └── hpa.yaml
├── terraform/
│   ├── main.tf
│   └── gpu_cluster.tf
├── .github/
│   └── workflows/
│       ├── ci.yml
│       ├── training.yml
│       └── deploy.yml
├── pyproject.toml
├── Makefile
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 분산 학습 (DDP)

```python
# src/training/distributed.py
import os
import torch
import torch.distributed as dist
from torch.nn.parallel import DistributedDataParallel as DDP
from torch.utils.data.distributed import DistributedSampler
import logging

logger = logging.getLogger(__name__)


def setup_distributed() -> tuple[int, int]:
    """분산 학습 환경 초기화"""
    dist.init_process_group(backend="nccl")
    local_rank = int(os.environ["LOCAL_RANK"])
    world_size = dist.get_world_size()
    torch.cuda.set_device(local_rank)
    logger.info(f"Rank {local_rank}/{world_size} 초기화 완료")
    return local_rank, world_size


def cleanup_distributed() -> None:
    dist.destroy_process_group()


def is_main_process() -> bool:
    return not dist.is_initialized() or dist.get_rank() == 0


class DistributedTrainer:
    """DDP 기반 분산 학습 트레이너"""

    def __init__(self, cfg, model, train_dataset, val_dataset):
        self.cfg = cfg
        self.local_rank, self.world_size = setup_distributed()
        self.device = torch.device(f"cuda:{self.local_rank}")

        # 모델을 DDP로 래핑
        model = model.to(self.device)
        self.model = DDP(
            model,
            device_ids=[self.local_rank],
            find_unused_parameters=False,
        )

        # 분산 샘플러
        self.train_sampler = DistributedSampler(
            train_dataset, num_replicas=self.world_size, rank=self.local_rank
        )
        self.val_sampler = DistributedSampler(
            val_dataset, num_replicas=self.world_size, rank=self.local_rank
        )

        self.train_loader = torch.utils.data.DataLoader(
            train_dataset,
            batch_size=cfg.training.batch_size_per_gpu,
            sampler=self.train_sampler,
            num_workers=cfg.data.num_workers,
            pin_memory=True,
        )
        self.val_loader = torch.utils.data.DataLoader(
            val_dataset,
            batch_size=cfg.training.batch_size_per_gpu,
            sampler=self.val_sampler,
            num_workers=cfg.data.num_workers,
            pin_memory=True,
        )

    def fit(self):
        for epoch in range(self.cfg.training.epochs):
            self.train_sampler.set_epoch(epoch)  # 셔플 보장
            self._train_one_epoch(epoch)
            self._validate(epoch)

            if is_main_process():
                self._save_checkpoint(epoch)

        cleanup_distributed()
```

### 2.2 FSDP (Fully Sharded Data Parallel)

```python
# src/training/fsdp_trainer.py
import torch
from torch.distributed.fsdp import (
    FullyShardedDataParallel as FSDP,
    MixedPrecision,
    ShardingStrategy,
    CPUOffload,
)
from torch.distributed.fsdp.wrap import (
    size_based_auto_wrap_policy,
    transformer_auto_wrap_policy,
)
import functools


def create_fsdp_model(model, cfg):
    """FSDP로 모델 래핑"""

    # Transformer 블록 기반 래핑 정책
    auto_wrap_policy = functools.partial(
        transformer_auto_wrap_policy,
        transformer_layer_cls={
            torch.nn.TransformerEncoderLayer,
            torch.nn.TransformerDecoderLayer,
        },
    )

    # Mixed Precision 설정
    mp_policy = MixedPrecision(
        param_dtype=torch.bfloat16,
        reduce_dtype=torch.bfloat16,
        buffer_dtype=torch.bfloat16,
    )

    # FSDP 래핑
    fsdp_model = FSDP(
        model,
        auto_wrap_policy=auto_wrap_policy,
        mixed_precision=mp_policy,
        sharding_strategy=ShardingStrategy.FULL_SHARD,
        cpu_offload=CPUOffload(offload_params=cfg.training.cpu_offload),
        device_id=torch.cuda.current_device(),
        limit_all_gathers=True,
    )

    return fsdp_model


def save_fsdp_checkpoint(model, optimizer, path):
    """FSDP 체크포인트 저장"""
    from torch.distributed.fsdp import (
        FullStateDictConfig,
        StateDictType,
    )

    full_state_cfg = FullStateDictConfig(offload_to_cpu=True, rank0_only=True)

    with FSDP.state_dict_type(model, StateDictType.FULL_STATE_DICT, full_state_cfg):
        state_dict = model.state_dict()
        if dist.get_rank() == 0:
            torch.save({"model": state_dict}, path)
```

### 2.3 모델 레지스트리

```python
# scripts/model_registry.py
import mlflow
from mlflow.tracking import MlflowClient


class ModelRegistry:
    """MLflow 모델 레지스트리 관리"""

    def __init__(self, tracking_uri: str):
        mlflow.set_tracking_uri(tracking_uri)
        self.client = MlflowClient()

    def register_model(
        self,
        run_id: str,
        model_name: str,
        artifact_path: str = "model",
        tags: dict | None = None,
    ) -> str:
        """모델 등록"""
        model_uri = f"runs:/{run_id}/{artifact_path}"
        result = mlflow.register_model(model_uri, model_name)

        if tags:
            for key, value in tags.items():
                self.client.set_model_version_tag(
                    model_name, result.version, key, value
                )

        return result.version

    def promote_model(
        self, model_name: str, version: str, stage: str
    ) -> None:
        """모델 스테이지 승격 (Staging -> Production)"""
        self.client.transition_model_version_stage(
            name=model_name,
            version=version,
            stage=stage,
            archive_existing_versions=True,
        )

    def get_production_model(self, model_name: str):
        """프로덕션 모델 로드"""
        model_uri = f"models:/{model_name}/Production"
        return mlflow.pytorch.load_model(model_uri)
```

### 2.4 분산 학습 실행 스크립트

```bash
#!/bin/bash
# scripts/train_distributed.sh

# 단일 노드, 멀티 GPU
torchrun \
    --nproc_per_node=8 \
    --nnodes=1 \
    scripts/train.py \
    training=distributed \
    model=llm_7b

# 멀티 노드 (SLURM 환경)
# srun torchrun \
#     --nproc_per_node=8 \
#     --nnodes=$SLURM_NNODES \
#     --node_rank=$SLURM_NODEID \
#     --master_addr=$MASTER_ADDR \
#     --master_port=$MASTER_PORT \
#     scripts/train.py training=distributed model=llm_13b
```

### 2.5 Kubernetes 학습 잡

```yaml
# k8s/training-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: distributed-training
spec:
  parallelism: 4  # 4 노드
  completions: 4
  template:
    spec:
      containers:
      - name: trainer
        image: registry.example.com/model-train:latest
        resources:
          limits:
            nvidia.com/gpu: 8
            memory: "256Gi"
            cpu: "64"
        env:
        - name: NCCL_DEBUG
          value: "INFO"
        - name: MASTER_ADDR
          value: "distributed-training-0"
        - name: MASTER_PORT
          value: "29500"
        volumeMounts:
        - name: data
          mountPath: /data
        - name: checkpoints
          mountPath: /checkpoints
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: training-data-pvc
      - name: checkpoints
        persistentVolumeClaim:
          claimName: checkpoints-pvc
      restartPolicy: OnFailure
```

### 2.6 모델 서빙 (Triton)

```python
# src/serving/model_server.py
import torch
import numpy as np
from pathlib import Path


class ModelExporter:
    """모델을 서빙 포맷으로 내보내기"""

    @staticmethod
    def to_torchscript(model, example_input, output_path: str):
        """TorchScript로 변환"""
        model.eval()
        traced = torch.jit.trace(model, example_input)
        traced.save(output_path)

    @staticmethod
    def to_onnx(model, example_input, output_path: str):
        """ONNX로 변환"""
        model.eval()
        torch.onnx.export(
            model,
            example_input,
            output_path,
            input_names=["input"],
            output_names=["output"],
            dynamic_axes={
                "input": {0: "batch_size"},
                "output": {0: "batch_size"},
            },
            opset_version=17,
        )
```

```
# pipelines/serving/triton_config/config.pbtxt
name: "my_model"
platform: "onnxruntime_onnx"
max_batch_size: 64
input [
  {
    name: "input"
    data_type: TYPE_FP32
    dims: [ 3, 224, 224 ]
  }
]
output [
  {
    name: "output"
    data_type: TYPE_FP32
    dims: [ 1000 ]
  }
]
instance_group [
  {
    count: 2
    kind: KIND_GPU
  }
]
dynamic_batching {
  preferred_batch_size: [ 16, 32 ]
  max_queue_delay_microseconds: 100
}
```

### 2.7 A/B 테스트 및 모니터링

```python
# pipelines/monitoring/model_drift.py
from dataclasses import dataclass
import numpy as np
from scipy import stats


@dataclass
class DriftReport:
    feature_name: str
    drift_detected: bool
    p_value: float
    test_statistic: float


def detect_drift_ks(
    reference: np.ndarray,
    current: np.ndarray,
    threshold: float = 0.05,
) -> DriftReport:
    """Kolmogorov-Smirnov 검정으로 데이터 드리프트 감지"""
    stat, p_value = stats.ks_2samp(reference, current)
    return DriftReport(
        feature_name="",
        drift_detected=p_value < threshold,
        p_value=p_value,
        test_statistic=stat,
    )


def monitor_prediction_distribution(
    baseline_preds: np.ndarray,
    current_preds: np.ndarray,
    threshold: float = 0.1,
) -> dict:
    """예측 분포 변화 모니터링"""
    baseline_dist = np.bincount(baseline_preds) / len(baseline_preds)
    current_dist = np.bincount(current_preds) / len(current_preds)

    # Jensen-Shannon Divergence
    from scipy.spatial.distance import jensenshannon
    jsd = jensenshannon(baseline_dist, current_dist)

    return {
        "jsd": float(jsd),
        "drift_detected": jsd > threshold,
        "baseline_dist": baseline_dist.tolist(),
        "current_dist": current_dist.tolist(),
    }
```

## 3. 테스트/검증 전략

### E2E 서빙 테스트

```python
# tests/e2e/test_serving.py
import pytest
import requests
import numpy as np


@pytest.fixture
def triton_client():
    import tritonclient.http as httpclient
    return httpclient.InferenceServerClient(url="localhost:8000")


def test_model_inference(triton_client):
    """Triton 서빙 추론 테스트"""
    input_data = np.random.randn(1, 3, 224, 224).astype(np.float32)

    inputs = [tritonclient.InferInput("input", input_data.shape, "FP32")]
    inputs[0].set_data_from_numpy(input_data)
    outputs = [tritonclient.InferRequestedOutput("output")]

    result = triton_client.infer("my_model", inputs, outputs=outputs)
    output = result.as_numpy("output")

    assert output.shape == (1, 1000)
    assert np.allclose(output.sum(axis=1), 1.0, atol=0.01)  # softmax 합계


def test_latency(triton_client):
    """레이턴시 요구사항 확인"""
    import time
    input_data = np.random.randn(1, 3, 224, 224).astype(np.float32)
    inputs = [tritonclient.InferInput("input", input_data.shape, "FP32")]
    inputs[0].set_data_from_numpy(input_data)

    latencies = []
    for _ in range(100):
        start = time.time()
        triton_client.infer("my_model", inputs)
        latencies.append(time.time() - start)

    p50 = np.percentile(latencies, 50) * 1000
    p99 = np.percentile(latencies, 99) * 1000
    assert p99 < 100, f"P99 레이턴시 초과: {p99:.1f}ms"
```

### 분산 학습 테스트

```python
# tests/integration/test_distributed.py
import subprocess
import pytest


@pytest.mark.slow
def test_ddp_training_2gpu():
    """2 GPU DDP 학습이 정상 동작하는지 확인"""
    result = subprocess.run(
        [
            "torchrun", "--nproc_per_node=2",
            "scripts/train.py",
            "training=distributed",
            "training.epochs=2",
            "training.batch_size_per_gpu=4",
            "data=test_small",
        ],
        capture_output=True, text=True, timeout=300,
    )
    assert result.returncode == 0, f"학습 실패:\n{result.stderr}"
```

## 4. 성능 최적화

### 통신 최적화

```python
# NCCL 환경 변수 최적화
import os
os.environ["NCCL_IB_DISABLE"] = "0"         # InfiniBand 활성화
os.environ["NCCL_NET_GDR_LEVEL"] = "5"      # GPU Direct RDMA
os.environ["NCCL_P2P_LEVEL"] = "NVL"        # NVLink P2P
```

### 데이터 로딩 최적화

```python
from torch.utils.data import IterableDataset
import webdataset as wds


def create_webdataset(url_pattern: str, batch_size: int):
    """WebDataset으로 대규모 데이터 스트리밍"""
    dataset = (
        wds.WebDataset(url_pattern)
        .shuffle(1000)
        .decode("pil")
        .to_tuple("input.pth", "target.pth")
        .batched(batch_size)
    )
    return dataset
```

### 메모리 최적화

```python
# 그래디언트 체크포인팅
from torch.utils.checkpoint import checkpoint_sequential

class LargeModel(nn.Module):
    def __init__(self):
        super().__init__()
        self.layers = nn.ModuleList([Block() for _ in range(48)])

    def forward(self, x):
        # 메모리 절약을 위해 체크포인팅 적용
        return checkpoint_sequential(self.layers, segments=8, input=x)
```

## 5. 체크리스트

### 인프라
- [ ] GPU 클러스터 프로비저닝 (K8s + GPU operator)
- [ ] 분산 파일 시스템 구성 (NFS / Lustre / S3)
- [ ] NCCL 통신 최적화 (InfiniBand, NVLink)
- [ ] 모니터링 시스템 (Prometheus + Grafana)

### 학습 파이프라인
- [ ] DDP / FSDP 설정 및 검증
- [ ] 체크포인트 저장/복원 (분산 환경)
- [ ] 그래디언트 체크포인팅 적용
- [ ] Mixed precision (BF16/FP16) 적용
- [ ] 데이터 스트리밍 파이프라인 구축

### MLOps
- [ ] 모델 레지스트리 운영 (MLflow / Vertex AI)
- [ ] CI/CD 파이프라인 (학습 -> 평가 -> 등록 -> 배포)
- [ ] A/B 테스트 인프라 구축
- [ ] 데이터/모델 드리프트 모니터링
- [ ] 롤백 전략 수립

### 서빙
- [ ] 모델 최적화 (ONNX, TensorRT, quantization)
- [ ] 서빙 인프라 (Triton / TorchServe / vLLM)
- [ ] 오토스케일링 설정 (HPA / VPA)
- [ ] 레이턴시 / 처리량 벤치마크
- [ ] 카나리 배포 전략

### 거버넌스
- [ ] 모델 카드 작성
- [ ] 편향/공정성 평가 보고서
- [ ] 데이터 리니지 추적
- [ ] 접근 제어 (RBAC)
- [ ] 감사 로그 설정
