# PyTorch 중규모 프로젝트 가이드

## 매칭 조건

- 팀 프로젝트 (3~10명)
- 데이터: 수 GB ~ 수백 GB
- 단일 노드 멀티 GPU
- Config-driven 실험 관리
- 실험 추적 (MLflow / W&B) 사용
- CI/CD 파이프라인 존재

## 1. 프로젝트 구조

```
pytorch-medium/
├── configs/
│   ├── config.yaml               # 기본 설정
│   ├── model/
│   │   ├── resnet.yaml
│   │   └── transformer.yaml
│   ├── data/
│   │   ├── imagenet.yaml
│   │   └── custom.yaml
│   ├── training/
│   │   ├── default.yaml
│   │   └── fine_tune.yaml
│   └── experiment/
│       ├── baseline.yaml
│       └── ablation_lr.yaml
├── src/
│   ├── __init__.py
│   ├── data/
│   │   ├── __init__.py
│   │   ├── dataset.py            # Dataset 클래스
│   │   ├── transforms.py         # 데이터 변환
│   │   └── datamodule.py         # 데이터 로딩 통합
│   ├── models/
│   │   ├── __init__.py
│   │   ├── base.py               # 베이스 모델
│   │   ├── resnet.py
│   │   └── transformer.py
│   ├── training/
│   │   ├── __init__.py
│   │   ├── trainer.py            # 학습 루프
│   │   ├── callbacks.py          # 콜백
│   │   └── losses.py             # 손실 함수
│   ├── evaluation/
│   │   ├── __init__.py
│   │   └── metrics.py            # 평가 메트릭
│   └── utils/
│       ├── __init__.py
│       ├── logging.py            # 로깅 유틸
│       └── seed.py               # 시드 고정
├── scripts/
│   ├── train.py                  # 학습 진입점
│   ├── evaluate.py               # 평가 스크립트
│   └── export.py                 # 모델 내보내기
├── tests/
│   ├── unit/
│   │   ├── test_model.py
│   │   ├── test_dataset.py
│   │   └── test_transforms.py
│   └── integration/
│       └── test_training.py
├── docker/
│   ├── Dockerfile.train
│   └── Dockerfile.serve
├── outputs/                      # Hydra 출력 (git 무시)
├── .github/
│   └── workflows/
│       └── ci.yml
├── pyproject.toml
├── Makefile
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 Hydra 기반 설정 관리

```yaml
# configs/config.yaml
defaults:
  - model: resnet
  - data: custom
  - training: default
  - _self_

experiment_name: ${model.name}_${data.name}_lr${training.lr}
seed: 42

hydra:
  run:
    dir: outputs/${now:%Y-%m-%d}/${now:%H-%M-%S}
  sweep:
    dir: outputs/multirun/${now:%Y-%m-%d}/${now:%H-%M-%S}
```

```yaml
# configs/model/resnet.yaml
name: resnet50
pretrained: true
num_classes: 10
dropout: 0.3
```

```yaml
# configs/training/default.yaml
epochs: 50
lr: 1e-3
weight_decay: 1e-4
batch_size: 64
optimizer: adamw
scheduler: cosine
warmup_epochs: 5
grad_clip_norm: 1.0
early_stopping_patience: 10
```

### 2.2 구조화된 Trainer 클래스

```python
# src/training/trainer.py
from dataclasses import dataclass, field
from pathlib import Path
import time
import logging

import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from omegaconf import DictConfig

logger = logging.getLogger(__name__)


@dataclass
class TrainState:
    """학습 상태 관리"""
    epoch: int = 0
    global_step: int = 0
    best_metric: float = float("inf")
    history: dict = field(default_factory=lambda: {"train_loss": [], "val_loss": [], "val_metric": []})


class Trainer:
    """구조화된 학습 루프"""

    def __init__(
        self,
        cfg: DictConfig,
        model: nn.Module,
        train_loader: DataLoader,
        val_loader: DataLoader,
        optimizer: torch.optim.Optimizer,
        scheduler: torch.optim.lr_scheduler._LRScheduler,
        criterion: nn.Module,
        callbacks: list | None = None,
    ):
        self.cfg = cfg
        self.model = model
        self.train_loader = train_loader
        self.val_loader = val_loader
        self.optimizer = optimizer
        self.scheduler = scheduler
        self.criterion = criterion
        self.callbacks = callbacks or []
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model.to(self.device)
        self.state = TrainState()
        self.scaler = torch.amp.GradScaler("cuda") if self.device.type == "cuda" else None

    def fit(self) -> TrainState:
        """전체 학습 실행"""
        logger.info(f"학습 시작 - {self.cfg.training.epochs} 에포크, 디바이스: {self.device}")

        for epoch in range(self.cfg.training.epochs):
            self.state.epoch = epoch

            # 학습
            train_loss = self._train_one_epoch()
            self.state.history["train_loss"].append(train_loss)

            # 검증
            val_loss, val_metric = self._validate()
            self.state.history["val_loss"].append(val_loss)
            self.state.history["val_metric"].append(val_metric)

            # 스케줄러 업데이트
            self.scheduler.step()

            # 로깅
            lr = self.optimizer.param_groups[0]["lr"]
            logger.info(
                f"Epoch {epoch+1}/{self.cfg.training.epochs} | "
                f"Train Loss: {train_loss:.4f} | Val Loss: {val_loss:.4f} | "
                f"Val Metric: {val_metric:.4f} | LR: {lr:.2e}"
            )

            # 콜백 실행
            for cb in self.callbacks:
                cb.on_epoch_end(self.state, val_loss, val_metric)

            # 최적 모델 저장
            if val_loss < self.state.best_metric:
                self.state.best_metric = val_loss
                self._save_checkpoint("best.pt")

            # Early stopping 확인
            if self._check_early_stopping():
                logger.info(f"Early stopping at epoch {epoch+1}")
                break

        self._save_checkpoint("last.pt")
        return self.state

    def _train_one_epoch(self) -> float:
        """한 에포크 학습"""
        self.model.train()
        total_loss = 0.0
        num_batches = 0

        for batch in self.train_loader:
            loss = self._train_step(batch)
            total_loss += loss
            num_batches += 1
            self.state.global_step += 1

        return total_loss / num_batches

    def _train_step(self, batch: tuple) -> float:
        """단일 스텝 학습"""
        inputs, targets = batch
        inputs = inputs.to(self.device)
        targets = targets.to(self.device)

        self.optimizer.zero_grad()

        if self.scaler is not None:
            with torch.amp.autocast("cuda"):
                outputs = self.model(inputs)
                loss = self.criterion(outputs, targets)
            self.scaler.scale(loss).backward()
            self.scaler.unscale_(self.optimizer)
            nn.utils.clip_grad_norm_(
                self.model.parameters(), self.cfg.training.grad_clip_norm
            )
            self.scaler.step(self.optimizer)
            self.scaler.update()
        else:
            outputs = self.model(inputs)
            loss = self.criterion(outputs, targets)
            loss.backward()
            nn.utils.clip_grad_norm_(
                self.model.parameters(), self.cfg.training.grad_clip_norm
            )
            self.optimizer.step()

        return loss.item()

    @torch.no_grad()
    def _validate(self) -> tuple[float, float]:
        """검증"""
        self.model.eval()
        total_loss = 0.0
        correct = 0
        total = 0

        for inputs, targets in self.val_loader:
            inputs = inputs.to(self.device)
            targets = targets.to(self.device)
            outputs = self.model(inputs)
            loss = self.criterion(outputs, targets)
            total_loss += loss.item()
            preds = outputs.argmax(dim=1)
            correct += (preds == targets).sum().item()
            total += targets.size(0)

        avg_loss = total_loss / len(self.val_loader)
        accuracy = correct / total
        return avg_loss, accuracy

    def _check_early_stopping(self) -> bool:
        """Early stopping 확인"""
        patience = self.cfg.training.early_stopping_patience
        if len(self.state.history["val_loss"]) < patience:
            return False
        recent = self.state.history["val_loss"][-patience:]
        return all(recent[i] >= recent[i - 1] for i in range(1, len(recent)))

    def _save_checkpoint(self, filename: str) -> None:
        """체크포인트 저장"""
        path = Path("checkpoints") / filename
        path.parent.mkdir(parents=True, exist_ok=True)
        torch.save({
            "epoch": self.state.epoch,
            "global_step": self.state.global_step,
            "model_state_dict": self.model.state_dict(),
            "optimizer_state_dict": self.optimizer.state_dict(),
            "scheduler_state_dict": self.scheduler.state_dict(),
            "best_metric": self.state.best_metric,
            "config": dict(self.cfg),
        }, path)
        logger.info(f"체크포인트 저장: {path}")
```

### 2.3 실험 추적 (MLflow / W&B)

```python
# src/utils/experiment.py
import mlflow
import wandb
from omegaconf import DictConfig, OmegaConf


class ExperimentTracker:
    """실험 추적 래퍼"""

    def __init__(self, cfg: DictConfig, backend: str = "mlflow"):
        self.backend = backend
        self.cfg = cfg

        if backend == "mlflow":
            mlflow.set_experiment(cfg.experiment_name)
            self.run = mlflow.start_run()
            mlflow.log_params(OmegaConf.to_container(cfg, resolve=True))
        elif backend == "wandb":
            self.run = wandb.init(
                project=cfg.experiment_name,
                config=OmegaConf.to_container(cfg, resolve=True),
            )

    def log_metrics(self, metrics: dict, step: int) -> None:
        if self.backend == "mlflow":
            mlflow.log_metrics(metrics, step=step)
        elif self.backend == "wandb":
            wandb.log(metrics, step=step)

    def log_artifact(self, path: str) -> None:
        if self.backend == "mlflow":
            mlflow.log_artifact(path)
        elif self.backend == "wandb":
            wandb.save(path)

    def finish(self) -> None:
        if self.backend == "mlflow":
            mlflow.end_run()
        elif self.backend == "wandb":
            wandb.finish()
```

### 2.4 콜백 패턴

```python
# src/training/callbacks.py
from abc import ABC, abstractmethod
from pathlib import Path


class Callback(ABC):
    @abstractmethod
    def on_epoch_end(self, state, val_loss: float, val_metric: float) -> None:
        ...


class MetricLoggerCallback(Callback):
    """실험 추적 시스템에 메트릭 기록"""

    def __init__(self, tracker):
        self.tracker = tracker

    def on_epoch_end(self, state, val_loss, val_metric):
        self.tracker.log_metrics({
            "train_loss": state.history["train_loss"][-1],
            "val_loss": val_loss,
            "val_metric": val_metric,
        }, step=state.epoch)


class ModelCheckpointCallback(Callback):
    """주기적으로 체크포인트 저장"""

    def __init__(self, save_every: int = 5, save_dir: str = "checkpoints"):
        self.save_every = save_every
        self.save_dir = Path(save_dir)
        self.save_dir.mkdir(parents=True, exist_ok=True)

    def on_epoch_end(self, state, val_loss, val_metric):
        if (state.epoch + 1) % self.save_every == 0:
            # Trainer에서 저장 로직 호출
            pass
```

### 2.5 학습 진입점

```python
# scripts/train.py
import hydra
from omegaconf import DictConfig
import logging

from src.data.datamodule import DataModule
from src.models import build_model
from src.training.trainer import Trainer
from src.training.callbacks import MetricLoggerCallback
from src.utils.experiment import ExperimentTracker
from src.utils.seed import set_seed

logger = logging.getLogger(__name__)


@hydra.main(config_path="../configs", config_name="config", version_base=None)
def main(cfg: DictConfig) -> None:
    set_seed(cfg.seed)
    logger.info(f"실험: {cfg.experiment_name}")

    # 데이터
    dm = DataModule(cfg.data)
    train_loader, val_loader = dm.get_loaders(cfg.training.batch_size)

    # 모델
    model = build_model(cfg.model)
    logger.info(f"모델 파라미터 수: {sum(p.numel() for p in model.parameters()):,}")

    # 옵티마이저 & 스케줄러
    optimizer = torch.optim.AdamW(
        model.parameters(), lr=cfg.training.lr, weight_decay=cfg.training.weight_decay
    )
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
        optimizer, T_max=cfg.training.epochs
    )
    criterion = torch.nn.CrossEntropyLoss()

    # 실험 추적
    tracker = ExperimentTracker(cfg, backend="mlflow")

    # 학습
    trainer = Trainer(
        cfg=cfg,
        model=model,
        train_loader=train_loader,
        val_loader=val_loader,
        optimizer=optimizer,
        scheduler=scheduler,
        criterion=criterion,
        callbacks=[MetricLoggerCallback(tracker)],
    )

    state = trainer.fit()
    tracker.finish()
    logger.info(f"학습 완료 - Best metric: {state.best_metric:.4f}")


if __name__ == "__main__":
    main()
```

### 2.6 Makefile

```makefile
# Makefile
.PHONY: train test lint format

train:
	python scripts/train.py

train-sweep:
	python scripts/train.py --multirun training.lr=1e-3,1e-4,1e-5 model=resnet,transformer

test:
	pytest tests/ -v --cov=src

lint:
	ruff check src/ scripts/ tests/

format:
	ruff format src/ scripts/ tests/

docker-build:
	docker build -f docker/Dockerfile.train -t model-train .

docker-train:
	docker run --gpus all -v $(PWD)/data:/app/data model-train
```

## 3. 테스트/검증 전략

### 단위 테스트

```python
# tests/unit/test_model.py
import pytest
import torch
from src.models.resnet import ResNetModel


@pytest.fixture
def model():
    return ResNetModel(num_classes=10, pretrained=False)


def test_forward_shape(model):
    x = torch.randn(2, 3, 224, 224)
    output = model(x)
    assert output.shape == (2, 10)


def test_backward(model):
    x = torch.randn(2, 3, 224, 224)
    output = model(x)
    loss = output.sum()
    loss.backward()
    for name, param in model.named_parameters():
        if param.requires_grad:
            assert param.grad is not None, f"{name}에 그래디언트 없음"


@pytest.mark.parametrize("batch_size", [1, 4, 16])
def test_different_batch_sizes(model, batch_size):
    x = torch.randn(batch_size, 3, 224, 224)
    output = model(x)
    assert output.shape == (batch_size, 10)
```

### 통합 테스트

```python
# tests/integration/test_training.py
import pytest
import torch
from src.training.trainer import Trainer


def test_training_loop_runs(tmp_path, dummy_config, dummy_model, dummy_loaders):
    """학습 루프가 정상 동작하는지 확인"""
    trainer = Trainer(
        cfg=dummy_config,
        model=dummy_model,
        train_loader=dummy_loaders[0],
        val_loader=dummy_loaders[1],
        optimizer=torch.optim.Adam(dummy_model.parameters()),
        scheduler=torch.optim.lr_scheduler.StepLR(
            torch.optim.Adam(dummy_model.parameters()), step_size=1
        ),
        criterion=torch.nn.CrossEntropyLoss(),
    )
    state = trainer.fit()
    assert state.epoch >= 0
    assert len(state.history["train_loss"]) > 0
```

## 4. 성능 최적화

### 멀티 GPU (DataParallel)

```python
if torch.cuda.device_count() > 1:
    model = nn.DataParallel(model)
    logger.info(f"DataParallel: {torch.cuda.device_count()} GPUs")
```

### 프로파일링

```python
from torch.profiler import profile, record_function, ProfilerActivity

with profile(
    activities=[ProfilerActivity.CPU, ProfilerActivity.CUDA],
    schedule=torch.profiler.schedule(wait=1, warmup=1, active=3),
    on_trace_ready=torch.profiler.tensorboard_trace_handler("./profiler_logs"),
    record_shapes=True,
    profile_memory=True,
) as prof:
    for step, (x, y) in enumerate(train_loader):
        if step >= 5:
            break
        with record_function("forward"):
            output = model(x.to(device))
        with record_function("loss"):
            loss = criterion(output, y.to(device))
        with record_function("backward"):
            loss.backward()
            optimizer.step()
            optimizer.zero_grad()
        prof.step()
```

### 컴파일 최적화 (PyTorch 2.0+)

```python
model = torch.compile(model, mode="reduce-overhead")
```

## 5. 체크리스트

### 프로젝트 셋업
- [ ] Hydra 설정 구조 구성
- [ ] Docker 환경 구성
- [ ] CI/CD 파이프라인 설정
- [ ] 실험 추적 시스템 연동 (MLflow / W&B)
- [ ] Makefile 작성

### 코드 품질
- [ ] 타입 힌트 전체 적용
- [ ] 단위 테스트 커버리지 80% 이상
- [ ] ruff / black 포매터 설정
- [ ] pre-commit 훅 설정
- [ ] 코드 리뷰 프로세스 정의

### 학습 관리
- [ ] 하이퍼파라미터 sweep 자동화
- [ ] 체크포인트 저장/복원 검증
- [ ] Early stopping 설정
- [ ] 그래디언트 클리핑 적용
- [ ] Mixed precision 적용 검토

### 모델 배포 준비
- [ ] 모델 export (ONNX / TorchScript)
- [ ] 추론 벤치마크 수행
- [ ] 입력 검증 로직 구현
- [ ] API 서빙 코드 작성
