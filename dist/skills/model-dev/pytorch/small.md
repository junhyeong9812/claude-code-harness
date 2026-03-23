# PyTorch 소규모 프로젝트 가이드

## 매칭 조건

- 개인 학습 / PoC / 프로토타이핑
- 데이터: 수 MB ~ 수 GB
- 단일 GPU 또는 CPU
- 노트북 기반 실험
- 팀 규모: 1~2명

## 1. 프로젝트 구조

```
pytorch-small/
├── notebooks/
│   ├── 01_eda.ipynb              # 탐색적 데이터 분석
│   ├── 02_baseline.ipynb         # 베이스라인 모델
│   └── 03_experiment.ipynb       # 실험
├── data/
│   ├── raw/                      # 원본 데이터
│   └── processed/                # 전처리 데이터
├── src/
│   ├── __init__.py
│   ├── model.py                  # 모델 정의
│   ├── dataset.py                # 데이터셋 정의
│   └── utils.py                  # 유틸리티
├── outputs/
│   ├── models/                   # 저장된 모델
│   └── figures/                  # 시각화 결과
├── requirements.txt
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 시드 고정

```python
import random
import numpy as np
import torch


def set_seed(seed: int = 42) -> None:
    """재현성을 위한 시드 고정"""
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)
    torch.backends.cudnn.deterministic = True
    torch.backends.cudnn.benchmark = False


set_seed(42)
```

### 2.2 간단한 데이터셋 정의

```python
import torch
from torch.utils.data import Dataset, DataLoader
import pandas as pd


class TabularDataset(Dataset):
    """CSV 기반 간단한 데이터셋"""

    def __init__(self, csv_path: str, target_col: str):
        df = pd.read_csv(csv_path)
        self.features = torch.FloatTensor(
            df.drop(columns=[target_col]).values
        )
        self.targets = torch.FloatTensor(df[target_col].values)

    def __len__(self) -> int:
        return len(self.targets)

    def __getitem__(self, idx: int) -> tuple[torch.Tensor, torch.Tensor]:
        return self.features[idx], self.targets[idx]


# 사용 예시
train_ds = TabularDataset("data/processed/train.csv", target_col="label")
train_loader = DataLoader(train_ds, batch_size=32, shuffle=True)
```

### 2.3 간단한 모델 정의

```python
import torch.nn as nn


class SimpleClassifier(nn.Module):
    """간단한 분류 모델"""

    def __init__(self, input_dim: int, hidden_dim: int, output_dim: int):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(input_dim, hidden_dim),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(hidden_dim, hidden_dim // 2),
            nn.ReLU(),
            nn.Dropout(0.3),
            nn.Linear(hidden_dim // 2, output_dim),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        return self.net(x)


# CNN 예시
class SimpleCNN(nn.Module):
    """간단한 이미지 분류 CNN"""

    def __init__(self, num_classes: int = 10):
        super().__init__()
        self.features = nn.Sequential(
            nn.Conv2d(3, 32, kernel_size=3, padding=1),
            nn.BatchNorm2d(32),
            nn.ReLU(),
            nn.MaxPool2d(2),
            nn.Conv2d(32, 64, kernel_size=3, padding=1),
            nn.BatchNorm2d(64),
            nn.ReLU(),
            nn.MaxPool2d(2),
        )
        self.classifier = nn.Sequential(
            nn.AdaptiveAvgPool2d(1),
            nn.Flatten(),
            nn.Linear(64, num_classes),
        )

    def forward(self, x: torch.Tensor) -> torch.Tensor:
        x = self.features(x)
        return self.classifier(x)
```

### 2.4 기본 학습 루프

```python
def train_one_epoch(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
    optimizer: torch.optim.Optimizer,
    device: torch.device,
) -> float:
    """한 에포크 학습"""
    model.train()
    total_loss = 0.0

    for batch_x, batch_y in loader:
        batch_x, batch_y = batch_x.to(device), batch_y.to(device)

        optimizer.zero_grad()
        output = model(batch_x)
        loss = criterion(output, batch_y)
        loss.backward()
        optimizer.step()

        total_loss += loss.item() * batch_x.size(0)

    return total_loss / len(loader.dataset)


@torch.no_grad()
def evaluate(
    model: nn.Module,
    loader: DataLoader,
    criterion: nn.Module,
    device: torch.device,
) -> tuple[float, float]:
    """평가 (loss, accuracy 반환)"""
    model.eval()
    total_loss = 0.0
    correct = 0

    for batch_x, batch_y in loader:
        batch_x, batch_y = batch_x.to(device), batch_y.to(device)
        output = model(batch_x)
        loss = criterion(output, batch_y)
        total_loss += loss.item() * batch_x.size(0)
        preds = output.argmax(dim=1)
        correct += (preds == batch_y).sum().item()

    avg_loss = total_loss / len(loader.dataset)
    accuracy = correct / len(loader.dataset)
    return avg_loss, accuracy
```

### 2.5 전체 학습 실행

```python
# 하이퍼파라미터
EPOCHS = 20
LR = 1e-3
BATCH_SIZE = 32

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

model = SimpleClassifier(input_dim=20, hidden_dim=64, output_dim=3).to(device)
criterion = nn.CrossEntropyLoss()
optimizer = torch.optim.Adam(model.parameters(), lr=LR)
scheduler = torch.optim.lr_scheduler.ReduceLROnPlateau(
    optimizer, mode="min", patience=3, factor=0.5
)

best_val_loss = float("inf")

for epoch in range(EPOCHS):
    train_loss = train_one_epoch(model, train_loader, criterion, optimizer, device)
    val_loss, val_acc = evaluate(model, val_loader, criterion, device)
    scheduler.step(val_loss)

    print(f"Epoch {epoch+1}/{EPOCHS} | "
          f"Train Loss: {train_loss:.4f} | "
          f"Val Loss: {val_loss:.4f} | "
          f"Val Acc: {val_acc:.4f}")

    # 최적 모델 저장
    if val_loss < best_val_loss:
        best_val_loss = val_loss
        torch.save({
            "epoch": epoch,
            "model_state_dict": model.state_dict(),
            "optimizer_state_dict": optimizer.state_dict(),
            "val_loss": val_loss,
            "val_acc": val_acc,
        }, "outputs/models/best_model.pt")
        print(f"  -> 최적 모델 저장 (val_loss: {val_loss:.4f})")
```

### 2.6 모델 로딩 및 추론

```python
# 모델 로딩
checkpoint = torch.load("outputs/models/best_model.pt", map_location=device)
model.load_state_dict(checkpoint["model_state_dict"])
print(f"로딩 완료 - Epoch: {checkpoint['epoch']}, Val Acc: {checkpoint['val_acc']:.4f}")

# 추론
model.eval()
with torch.no_grad():
    sample = torch.randn(1, 20).to(device)
    prediction = model(sample)
    predicted_class = prediction.argmax(dim=1).item()
    print(f"예측 클래스: {predicted_class}")
```

## 3. 테스트/검증 전략

### 간단한 스모크 테스트

```python
def test_model_forward():
    """모델 forward pass 확인"""
    model = SimpleClassifier(input_dim=20, hidden_dim=64, output_dim=3)
    x = torch.randn(4, 20)
    output = model(x)
    assert output.shape == (4, 3), f"출력 shape 불일치: {output.shape}"
    print("Forward pass 테스트 통과")


def test_model_overfit_single_batch():
    """단일 배치 오버피팅 테스트 (모델이 학습 가능한지 확인)"""
    model = SimpleClassifier(input_dim=20, hidden_dim=64, output_dim=3)
    optimizer = torch.optim.Adam(model.parameters(), lr=1e-2)
    criterion = nn.CrossEntropyLoss()

    # 단일 배치 생성
    x = torch.randn(8, 20)
    y = torch.randint(0, 3, (8,))

    # 100번 반복하여 오버피팅 시도
    model.train()
    for _ in range(100):
        optimizer.zero_grad()
        loss = criterion(model(x), y)
        loss.backward()
        optimizer.step()

    final_loss = criterion(model(x), y).item()
    assert final_loss < 0.1, f"오버피팅 실패: loss={final_loss:.4f}"
    print(f"오버피팅 테스트 통과 (loss: {final_loss:.4f})")


test_model_forward()
test_model_overfit_single_batch()
```

### 데이터 검증

```python
def validate_dataset(dataset: Dataset) -> None:
    """데이터셋 기본 검증"""
    assert len(dataset) > 0, "빈 데이터셋"

    x, y = dataset[0]
    assert not torch.isnan(x).any(), "NaN 값 존재"
    assert not torch.isinf(x).any(), "Inf 값 존재"

    print(f"데이터셋 크기: {len(dataset)}")
    print(f"피처 shape: {x.shape}")
    print(f"타겟 shape: {y.shape}")
```

## 4. 성능 최적화

### 데이터 로딩 최적화

```python
train_loader = DataLoader(
    train_ds,
    batch_size=32,
    shuffle=True,
    num_workers=4,          # CPU 코어에 맞게 조정
    pin_memory=True,        # GPU 사용 시
    persistent_workers=True, # 워커 재사용
)
```

### Mixed Precision (간단 적용)

```python
from torch.amp import autocast, GradScaler

scaler = GradScaler("cuda")

for batch_x, batch_y in train_loader:
    batch_x, batch_y = batch_x.to(device), batch_y.to(device)
    optimizer.zero_grad()

    with autocast("cuda"):
        output = model(batch_x)
        loss = criterion(output, batch_y)

    scaler.scale(loss).backward()
    scaler.step(optimizer)
    scaler.update()
```

### GPU 메모리 팁

```python
# 불필요한 그래디언트 계산 방지
with torch.no_grad():
    predictions = model(test_input)

# GPU 메모리 확인
if torch.cuda.is_available():
    print(f"할당됨: {torch.cuda.memory_allocated() / 1e9:.2f} GB")
    print(f"캐시됨: {torch.cuda.memory_reserved() / 1e9:.2f} GB")

# 메모리 부족 시 그래디언트 누적
accumulation_steps = 4
for i, (batch_x, batch_y) in enumerate(train_loader):
    output = model(batch_x.to(device))
    loss = criterion(output, batch_y.to(device)) / accumulation_steps
    loss.backward()

    if (i + 1) % accumulation_steps == 0:
        optimizer.step()
        optimizer.zero_grad()
```

## 5. 체크리스트

### 프로젝트 시작 시
- [ ] Python 가상환경 생성 및 의존성 설치
- [ ] 랜덤 시드 고정 (`set_seed(42)`)
- [ ] GPU 사용 가능 여부 확인
- [ ] 데이터 EDA 수행

### 모델 개발 시
- [ ] 단일 배치 오버피팅 테스트
- [ ] Forward pass shape 확인
- [ ] 학습 곡선 시각화 (loss, accuracy)
- [ ] 학습률 스케줄러 적용

### 모델 저장 시
- [ ] 모델 state_dict + optimizer state_dict 함께 저장
- [ ] epoch, loss 등 메타 정보 포함
- [ ] 저장된 모델 재로딩 테스트

### 제출/공유 전
- [ ] `requirements.txt` 최신화
- [ ] 노트북 재실행하여 결과 재현 확인
- [ ] 불필요한 출력/디버그 코드 제거
- [ ] README에 실행 방법 기록
