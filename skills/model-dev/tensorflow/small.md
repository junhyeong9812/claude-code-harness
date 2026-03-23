# TensorFlow 소규모 프로젝트 가이드

## 매칭 조건

- 개인 학습 / PoC / 프로토타이핑
- 데이터: 수 MB ~ 수 GB
- Keras Sequential / Functional API 사용
- 노트북 기반 실험
- 팀 규모: 1~2명

## 1. 프로젝트 구조

```
tf-small/
├── notebooks/
│   ├── 01_eda.ipynb              # 탐색적 데이터 분석
│   ├── 02_baseline.ipynb         # 베이스라인 모델
│   └── 03_experiment.ipynb       # 실험
├── data/
│   ├── raw/
│   └── processed/
├── src/
│   ├── __init__.py
│   ├── model.py                  # 모델 정의
│   ├── dataset.py                # 데이터 파이프라인
│   └── utils.py                  # 유틸리티
├── saved_models/                 # 저장된 모델
├── logs/                         # TensorBoard 로그
├── requirements.txt
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 시드 고정 및 환경 설정

```python
import os
import random
import numpy as np
import tensorflow as tf

def set_seed(seed: int = 42) -> None:
    """재현성을 위한 시드 고정"""
    random.seed(seed)
    np.random.seed(seed)
    tf.random.set_seed(seed)
    os.environ["PYTHONHASHSEED"] = str(seed)
    os.environ["TF_DETERMINISTIC_OPS"] = "1"

set_seed(42)

# GPU 메모리 증가 허용
gpus = tf.config.experimental.list_physical_devices("GPU")
for gpu in gpus:
    tf.config.experimental.set_memory_growth(gpu, True)

print(f"TensorFlow 버전: {tf.__version__}")
print(f"GPU 사용 가능: {len(gpus) > 0}")
```

### 2.2 Sequential API로 빠른 프로토타이핑

```python
from tensorflow import keras
from keras import layers

# Sequential API: 단순한 순차 모델
model = keras.Sequential([
    layers.Input(shape=(28, 28, 1)),
    layers.Conv2D(32, 3, activation="relu", padding="same"),
    layers.BatchNormalization(),
    layers.MaxPooling2D(),
    layers.Conv2D(64, 3, activation="relu", padding="same"),
    layers.BatchNormalization(),
    layers.MaxPooling2D(),
    layers.GlobalAveragePooling2D(),
    layers.Dropout(0.3),
    layers.Dense(128, activation="relu"),
    layers.Dropout(0.3),
    layers.Dense(10, activation="softmax"),
])

model.summary()

model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=1e-3),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
)
```

### 2.3 Functional API로 복잡한 구조

```python
# Functional API: 다중 입력/출력, 잔차 연결 등
inputs = keras.Input(shape=(224, 224, 3))

# 사전학습 백본
backbone = keras.applications.EfficientNetV2B0(
    include_top=False,
    weights="imagenet",
    input_tensor=inputs,
)
backbone.trainable = False  # 파인튜닝 전에 동결

x = layers.GlobalAveragePooling2D()(backbone.output)
x = layers.Dense(256, activation="relu")(x)
x = layers.Dropout(0.3)(x)
outputs = layers.Dense(10, activation="softmax")(x)

model = keras.Model(inputs=inputs, outputs=outputs)

model.compile(
    optimizer=keras.optimizers.Adam(learning_rate=1e-3),
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
)
```

### 2.4 데이터 파이프라인

```python
# src/dataset.py
import tensorflow as tf


def create_dataset(
    x: np.ndarray,
    y: np.ndarray,
    batch_size: int = 32,
    shuffle: bool = True,
    augment: bool = False,
) -> tf.data.Dataset:
    """tf.data 파이프라인 생성"""
    ds = tf.data.Dataset.from_tensor_slices((x, y))

    if shuffle:
        ds = ds.shuffle(buffer_size=len(x))

    ds = ds.batch(batch_size)

    if augment:
        ds = ds.map(augment_fn, num_parallel_calls=tf.data.AUTOTUNE)

    ds = ds.prefetch(tf.data.AUTOTUNE)
    return ds


def augment_fn(image, label):
    """기본 데이터 증강"""
    image = tf.image.random_flip_left_right(image)
    image = tf.image.random_brightness(image, 0.2)
    image = tf.image.random_contrast(image, 0.8, 1.2)
    return image, label


# 사용 예시
(x_train, y_train), (x_test, y_test) = keras.datasets.cifar10.load_data()
x_train = x_train.astype("float32") / 255.0
x_test = x_test.astype("float32") / 255.0

train_ds = create_dataset(x_train, y_train, batch_size=64, augment=True)
test_ds = create_dataset(x_test, y_test, batch_size=64, shuffle=False)
```

### 2.5 학습 실행 및 콜백

```python
callbacks = [
    keras.callbacks.EarlyStopping(
        monitor="val_loss",
        patience=5,
        restore_best_weights=True,
    ),
    keras.callbacks.ReduceLROnPlateau(
        monitor="val_loss",
        factor=0.5,
        patience=3,
    ),
    keras.callbacks.TensorBoard(
        log_dir="logs/experiment_01",
        histogram_freq=1,
    ),
    keras.callbacks.ModelCheckpoint(
        filepath="saved_models/best_model.keras",
        monitor="val_accuracy",
        save_best_only=True,
    ),
]

history = model.fit(
    train_ds,
    validation_data=test_ds,
    epochs=50,
    callbacks=callbacks,
)
```

### 2.6 학습 결과 시각화

```python
import matplotlib.pyplot as plt


def plot_history(history):
    """학습 히스토리 시각화"""
    fig, axes = plt.subplots(1, 2, figsize=(12, 4))

    # Loss
    axes[0].plot(history.history["loss"], label="Train")
    axes[0].plot(history.history["val_loss"], label="Validation")
    axes[0].set_title("Loss")
    axes[0].set_xlabel("Epoch")
    axes[0].legend()

    # Accuracy
    axes[1].plot(history.history["accuracy"], label="Train")
    axes[1].plot(history.history["val_accuracy"], label="Validation")
    axes[1].set_title("Accuracy")
    axes[1].set_xlabel("Epoch")
    axes[1].legend()

    plt.tight_layout()
    plt.savefig("outputs/figures/training_history.png", dpi=150)
    plt.show()


plot_history(history)
```

### 2.7 모델 저장 및 로드

```python
# Keras 네이티브 포맷 저장
model.save("saved_models/my_model.keras")

# 로드
loaded_model = keras.models.load_model("saved_models/my_model.keras")

# SavedModel 포맷 (서빙용)
model.export("saved_models/serving_model")

# 추론
predictions = loaded_model.predict(test_ds)
predicted_classes = np.argmax(predictions, axis=1)
```

### 2.8 파인튜닝 패턴

```python
# 1단계: 백본 동결하고 분류기만 학습
backbone.trainable = False
model.compile(optimizer=keras.optimizers.Adam(1e-3), ...)
model.fit(train_ds, epochs=10, ...)

# 2단계: 백본 상위 레이어 해동하고 낮은 학습률로 파인튜닝
backbone.trainable = True
for layer in backbone.layers[:-20]:
    layer.trainable = False

model.compile(optimizer=keras.optimizers.Adam(1e-5), ...)
model.fit(train_ds, epochs=20, ...)
```

## 3. 테스트/검증 전략

### 모델 기본 검증

```python
def test_model_output_shape():
    """모델 출력 shape 검증"""
    model = build_model(num_classes=10)
    dummy_input = tf.random.normal((4, 224, 224, 3))
    output = model(dummy_input, training=False)
    assert output.shape == (4, 10), f"출력 shape 불일치: {output.shape}"
    print("출력 shape 테스트 통과")


def test_model_trainable():
    """모델이 학습 가능한지 확인 (단일 배치 오버피팅)"""
    model = build_model(num_classes=3)
    model.compile(
        optimizer=keras.optimizers.Adam(1e-2),
        loss="sparse_categorical_crossentropy",
    )

    x = tf.random.normal((8, 224, 224, 3))
    y = tf.constant([0, 1, 2, 0, 1, 2, 0, 1])

    initial_loss = model.evaluate(x, y, verbose=0)
    model.fit(x, y, epochs=50, verbose=0)
    final_loss = model.evaluate(x, y, verbose=0)

    assert final_loss < initial_loss * 0.1, "오버피팅 실패"
    print(f"오버피팅 테스트 통과 (loss: {initial_loss:.4f} -> {final_loss:.4f})")
```

### 데이터 파이프라인 검증

```python
def test_dataset_pipeline():
    """데이터셋 파이프라인 검증"""
    ds = create_dataset(x_train[:100], y_train[:100], batch_size=16)

    for batch_x, batch_y in ds.take(1):
        assert batch_x.shape[0] <= 16
        assert batch_x.dtype == tf.float32
        assert tf.reduce_min(batch_x) >= 0.0
        assert tf.reduce_max(batch_x) <= 1.0
        print(f"배치 shape: {batch_x.shape}, 라벨 shape: {batch_y.shape}")
    print("데이터 파이프라인 테스트 통과")
```

## 4. 성능 최적화

### tf.data 최적화

```python
# 최적화된 데이터 파이프라인
ds = (
    tf.data.Dataset.from_tensor_slices((x, y))
    .cache()                                      # 메모리 캐싱
    .shuffle(buffer_size=10000)
    .batch(batch_size)
    .map(preprocess_fn, num_parallel_calls=tf.data.AUTOTUNE)
    .prefetch(tf.data.AUTOTUNE)                   # 자동 프리페칭
)
```

### Mixed Precision

```python
# 간단하게 mixed precision 적용
keras.mixed_precision.set_global_policy("mixed_float16")
# 모델 정의 후 마지막 Dense에 float32 명시
outputs = layers.Dense(10, activation="softmax", dtype="float32")(x)
```

### XLA 컴파일

```python
# XLA JIT 컴파일로 속도 향상
model.compile(
    optimizer="adam",
    loss="sparse_categorical_crossentropy",
    metrics=["accuracy"],
    jit_compile=True,  # XLA 활성화
)
```

## 5. 체크리스트

### 프로젝트 시작 시
- [ ] TensorFlow / GPU 환경 확인
- [ ] 시드 고정 (`set_seed(42)`)
- [ ] 데이터 EDA 수행
- [ ] 사전학습 모델 활용 가능성 확인

### 모델 개발 시
- [ ] Sequential vs Functional API 선택
- [ ] 단일 배치 오버피팅 테스트
- [ ] 콜백 설정 (EarlyStopping, ModelCheckpoint, TensorBoard)
- [ ] 학습 곡선 시각화

### 저장 및 공유
- [ ] `.keras` 포맷으로 모델 저장
- [ ] `requirements.txt` 최신화
- [ ] 노트북 재실행하여 재현 확인
- [ ] TensorBoard 로그 확인
