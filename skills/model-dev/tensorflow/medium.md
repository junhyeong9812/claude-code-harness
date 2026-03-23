# TensorFlow 중규모 프로젝트 가이드

## 매칭 조건

- 팀 프로젝트 (3~10명)
- 데이터: 수 GB ~ 수백 GB
- Custom training loop, tf.data 파이프라인
- TensorBoard, 실험 추적 시스템 사용
- CI/CD 파이프라인 존재

## 1. 프로젝트 구조

```
tf-medium/
├── configs/
│   ├── base.yaml
│   ├── model/
│   │   ├── efficientnet.yaml
│   │   └── custom_transformer.yaml
│   ├── data/
│   │   └── image_dataset.yaml
│   └── training/
│       ├── default.yaml
│       └── fine_tune.yaml
├── src/
│   ├── __init__.py
│   ├── data/
│   │   ├── __init__.py
│   │   ├── tfrecord_writer.py    # TFRecord 생성
│   │   ├── tfrecord_reader.py    # TFRecord 읽기
│   │   ├── augmentation.py       # 데이터 증강
│   │   └── datamodule.py         # 데이터 모듈
│   ├── models/
│   │   ├── __init__.py
│   │   ├── base.py               # 베이스 모델
│   │   ├── efficientnet.py
│   │   └── layers.py             # 커스텀 레이어
│   ├── training/
│   │   ├── __init__.py
│   │   ├── trainer.py            # 커스텀 학습 루프
│   │   ├── callbacks.py
│   │   └── losses.py
│   ├── evaluation/
│   │   ├── __init__.py
│   │   └── metrics.py
│   └── utils/
│       ├── __init__.py
│       └── config.py
├── scripts/
│   ├── train.py
│   ├── evaluate.py
│   ├── create_tfrecords.py
│   └── export_model.py
├── tests/
│   ├── unit/
│   └── integration/
├── docker/
│   └── Dockerfile.train
├── .github/workflows/ci.yml
├── pyproject.toml
├── Makefile
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 TFRecord 파이프라인

```python
# src/data/tfrecord_writer.py
import tensorflow as tf
from pathlib import Path


def _bytes_feature(value):
    return tf.train.Feature(bytes_list=tf.train.BytesList(value=[value]))

def _int64_feature(value):
    return tf.train.Feature(int64_list=tf.train.Int64List(value=[value]))


def create_tfrecord(images, labels, output_path: str, shard_size: int = 5000):
    """이미지/라벨을 TFRecord로 변환"""
    output_dir = Path(output_path)
    output_dir.mkdir(parents=True, exist_ok=True)

    num_shards = (len(images) + shard_size - 1) // shard_size

    for shard_idx in range(num_shards):
        shard_path = output_dir / f"data-{shard_idx:05d}-of-{num_shards:05d}.tfrecord"
        start = shard_idx * shard_size
        end = min(start + shard_size, len(images))

        with tf.io.TFRecordWriter(str(shard_path)) as writer:
            for i in range(start, end):
                image_bytes = tf.io.encode_png(images[i]).numpy()
                example = tf.train.Example(features=tf.train.Features(feature={
                    "image": _bytes_feature(image_bytes),
                    "label": _int64_feature(labels[i]),
                }))
                writer.write(example.SerializeToString())

    print(f"TFRecord 생성 완료: {num_shards} 샤드, {len(images)} 샘플")
```

```python
# src/data/tfrecord_reader.py
import tensorflow as tf


def parse_tfrecord(serialized):
    """TFRecord 파싱"""
    features = tf.io.parse_single_example(serialized, {
        "image": tf.io.FixedLenFeature([], tf.string),
        "label": tf.io.FixedLenFeature([], tf.int64),
    })
    image = tf.io.decode_png(features["image"], channels=3)
    image = tf.cast(image, tf.float32) / 255.0
    image = tf.image.resize(image, [224, 224])
    label = features["label"]
    return image, label


def create_tfrecord_dataset(
    file_pattern: str,
    batch_size: int = 32,
    shuffle: bool = True,
    augment_fn=None,
) -> tf.data.Dataset:
    """TFRecord 기반 데이터셋 생성"""
    files = tf.data.Dataset.list_files(file_pattern, shuffle=shuffle)
    ds = files.interleave(
        tf.data.TFRecordDataset,
        num_parallel_calls=tf.data.AUTOTUNE,
        deterministic=not shuffle,
    )

    if shuffle:
        ds = ds.shuffle(buffer_size=10000)

    ds = ds.map(parse_tfrecord, num_parallel_calls=tf.data.AUTOTUNE)

    if augment_fn:
        ds = ds.map(augment_fn, num_parallel_calls=tf.data.AUTOTUNE)

    ds = ds.batch(batch_size).prefetch(tf.data.AUTOTUNE)
    return ds
```

### 2.2 커스텀 학습 루프

```python
# src/training/trainer.py
import tensorflow as tf
from pathlib import Path
import logging
import time

logger = logging.getLogger(__name__)


class CustomTrainer:
    """커스텀 학습 루프 트레이너"""

    def __init__(self, cfg, model, optimizer, loss_fn, metrics):
        self.cfg = cfg
        self.model = model
        self.optimizer = optimizer
        self.loss_fn = loss_fn
        self.metrics = metrics
        self.ckpt_dir = Path("checkpoints")
        self.ckpt_dir.mkdir(parents=True, exist_ok=True)

        # 체크포인트 매니저
        self.checkpoint = tf.train.Checkpoint(
            model=model, optimizer=optimizer
        )
        self.ckpt_manager = tf.train.CheckpointManager(
            self.checkpoint, str(self.ckpt_dir), max_to_keep=3
        )

        # TensorBoard
        self.train_writer = tf.summary.create_file_writer("logs/train")
        self.val_writer = tf.summary.create_file_writer("logs/val")

    @tf.function
    def train_step(self, x, y):
        """단일 학습 스텝 (tf.function으로 컴파일)"""
        with tf.GradientTape() as tape:
            predictions = self.model(x, training=True)
            loss = self.loss_fn(y, predictions)

        gradients = tape.gradient(loss, self.model.trainable_variables)

        # 그래디언트 클리핑
        gradients, _ = tf.clip_by_global_norm(
            gradients, self.cfg.training.grad_clip_norm
        )

        self.optimizer.apply_gradients(
            zip(gradients, self.model.trainable_variables)
        )

        # 메트릭 업데이트
        for metric in self.metrics["train"]:
            metric.update_state(y, predictions)

        return loss

    @tf.function
    def val_step(self, x, y):
        """단일 검증 스텝"""
        predictions = self.model(x, training=False)
        loss = self.loss_fn(y, predictions)

        for metric in self.metrics["val"]:
            metric.update_state(y, predictions)

        return loss

    def fit(self, train_ds, val_ds):
        """전체 학습 실행"""
        best_val_loss = float("inf")
        patience_counter = 0

        for epoch in range(self.cfg.training.epochs):
            start_time = time.time()

            # 학습
            train_losses = []
            for x, y in train_ds:
                loss = self.train_step(x, y)
                train_losses.append(loss.numpy())

            # 검증
            val_losses = []
            for x, y in val_ds:
                loss = self.val_step(x, y)
                val_losses.append(loss.numpy())

            # 에포크 결과
            avg_train_loss = sum(train_losses) / len(train_losses)
            avg_val_loss = sum(val_losses) / len(val_losses)
            epoch_time = time.time() - start_time

            # TensorBoard 로깅
            self._log_metrics(epoch, avg_train_loss, avg_val_loss)

            # 메트릭 출력
            train_metrics_str = self._format_metrics("train")
            val_metrics_str = self._format_metrics("val")

            logger.info(
                f"Epoch {epoch+1}/{self.cfg.training.epochs} ({epoch_time:.1f}s) | "
                f"Train Loss: {avg_train_loss:.4f} {train_metrics_str} | "
                f"Val Loss: {avg_val_loss:.4f} {val_metrics_str}"
            )

            # 메트릭 리셋
            self._reset_metrics()

            # 체크포인트 저장
            if avg_val_loss < best_val_loss:
                best_val_loss = avg_val_loss
                self.ckpt_manager.save()
                patience_counter = 0
            else:
                patience_counter += 1

            # Early stopping
            if patience_counter >= self.cfg.training.early_stopping_patience:
                logger.info(f"Early stopping at epoch {epoch+1}")
                break

        # 최적 체크포인트 복원
        self.checkpoint.restore(self.ckpt_manager.latest_checkpoint)
        logger.info(f"학습 완료. Best val loss: {best_val_loss:.4f}")

    def _log_metrics(self, epoch, train_loss, val_loss):
        with self.train_writer.as_default():
            tf.summary.scalar("loss", train_loss, step=epoch)
            for m in self.metrics["train"]:
                tf.summary.scalar(m.name, m.result(), step=epoch)

        with self.val_writer.as_default():
            tf.summary.scalar("loss", val_loss, step=epoch)
            for m in self.metrics["val"]:
                tf.summary.scalar(m.name, m.result(), step=epoch)

    def _format_metrics(self, split: str) -> str:
        parts = [f"{m.name}: {m.result().numpy():.4f}" for m in self.metrics[split]]
        return " | ".join(parts)

    def _reset_metrics(self):
        for split in self.metrics:
            for m in self.metrics[split]:
                m.reset_state()
```

### 2.3 커스텀 레이어 및 모델

```python
# src/models/layers.py
import tensorflow as tf
from keras import layers


class SqueezeExcitation(layers.Layer):
    """Squeeze-and-Excitation 블록"""

    def __init__(self, filters, ratio=16, **kwargs):
        super().__init__(**kwargs)
        self.filters = filters
        self.ratio = ratio
        self.gap = layers.GlobalAveragePooling2D()
        self.dense1 = layers.Dense(filters // ratio, activation="relu")
        self.dense2 = layers.Dense(filters, activation="sigmoid")

    def call(self, inputs):
        se = self.gap(inputs)
        se = self.dense1(se)
        se = self.dense2(se)
        se = tf.reshape(se, [-1, 1, 1, self.filters])
        return inputs * se


class ResidualBlock(layers.Layer):
    """잔차 블록"""

    def __init__(self, filters, strides=1, **kwargs):
        super().__init__(**kwargs)
        self.conv1 = layers.Conv2D(filters, 3, strides=strides, padding="same")
        self.bn1 = layers.BatchNormalization()
        self.conv2 = layers.Conv2D(filters, 3, padding="same")
        self.bn2 = layers.BatchNormalization()
        self.se = SqueezeExcitation(filters)

        self.shortcut = (
            tf.keras.Sequential([
                layers.Conv2D(filters, 1, strides=strides),
                layers.BatchNormalization(),
            ]) if strides != 1 else layers.Lambda(lambda x: x)
        )

    def call(self, inputs, training=False):
        x = tf.nn.relu(self.bn1(self.conv1(inputs), training=training))
        x = self.bn2(self.conv2(x), training=training)
        x = self.se(x)
        return tf.nn.relu(x + self.shortcut(inputs))
```

### 2.4 데이터 증강 파이프라인

```python
# src/data/augmentation.py
import tensorflow as tf


class TrainAugmentation:
    """학습용 데이터 증강 파이프라인"""

    def __init__(self, image_size: int = 224):
        self.image_size = image_size
        self.augment = tf.keras.Sequential([
            layers.RandomFlip("horizontal"),
            layers.RandomRotation(0.1),
            layers.RandomZoom(0.1),
            layers.RandomContrast(0.1),
        ])

    def __call__(self, image, label):
        image = tf.image.resize(image, [self.image_size, self.image_size])
        image = self.augment(image)
        return image, label


class CutMix:
    """CutMix 데이터 증강"""

    def __init__(self, alpha: float = 1.0):
        self.alpha = alpha

    def __call__(self, images, labels):
        batch_size = tf.shape(images)[0]
        lam = tf.random.uniform([], 0, 1)

        # 랜덤 bounding box
        h, w = tf.shape(images)[1], tf.shape(images)[2]
        cut_h = tf.cast(tf.cast(h, tf.float32) * tf.sqrt(1 - lam), tf.int32)
        cut_w = tf.cast(tf.cast(w, tf.float32) * tf.sqrt(1 - lam), tf.int32)

        indices = tf.random.shuffle(tf.range(batch_size))
        shuffled_images = tf.gather(images, indices)
        shuffled_labels = tf.gather(labels, indices)

        # 간단한 구현 (실제로는 bbox 마스크 적용)
        mixed_images = lam * images + (1 - lam) * shuffled_images
        mixed_labels = lam * tf.cast(labels, tf.float32) + (1 - lam) * tf.cast(shuffled_labels, tf.float32)

        return mixed_images, mixed_labels
```

### 2.5 모델 export

```python
# scripts/export_model.py
import tensorflow as tf


def export_saved_model(model, export_path: str):
    """SavedModel 포맷으로 내보내기"""
    model.save(export_path)
    print(f"SavedModel 저장: {export_path}")

    # 서명 확인
    loaded = tf.saved_model.load(export_path)
    print(f"서명: {list(loaded.signatures.keys())}")


def export_tflite(model, export_path: str, quantize: bool = False):
    """TFLite로 변환"""
    converter = tf.lite.TFLiteConverter.from_keras_model(model)

    if quantize:
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]

    tflite_model = converter.convert()

    with open(export_path, "wb") as f:
        f.write(tflite_model)

    size_mb = len(tflite_model) / (1024 * 1024)
    print(f"TFLite 저장: {export_path} ({size_mb:.1f} MB)")
```

## 3. 테스트/검증 전략

### 단위 테스트

```python
# tests/unit/test_layers.py
import pytest
import tensorflow as tf
from src.models.layers import SqueezeExcitation, ResidualBlock


def test_se_block():
    se = SqueezeExcitation(64)
    x = tf.random.normal((2, 32, 32, 64))
    output = se(x)
    assert output.shape == (2, 32, 32, 64)


def test_residual_block():
    block = ResidualBlock(64, strides=2)
    x = tf.random.normal((2, 32, 32, 32))
    output = block(x, training=True)
    assert output.shape == (2, 16, 16, 64)


def test_residual_block_gradient():
    block = ResidualBlock(64)
    x = tf.random.normal((2, 32, 32, 64))
    with tf.GradientTape() as tape:
        tape.watch(x)
        output = block(x, training=True)
        loss = tf.reduce_sum(output)
    grads = tape.gradient(loss, x)
    assert grads is not None
    assert not tf.reduce_any(tf.math.is_nan(grads))
```

### 통합 테스트

```python
# tests/integration/test_trainer.py
def test_custom_trainer_runs(tmp_path, dummy_config):
    model = build_model(dummy_config.model)
    optimizer = tf.keras.optimizers.Adam(1e-3)
    loss_fn = tf.keras.losses.SparseCategoricalCrossentropy()
    metrics = {
        "train": [tf.keras.metrics.SparseCategoricalAccuracy()],
        "val": [tf.keras.metrics.SparseCategoricalAccuracy()],
    }

    trainer = CustomTrainer(dummy_config, model, optimizer, loss_fn, metrics)
    trainer.fit(dummy_train_ds, dummy_val_ds)

    assert Path("checkpoints").exists()
```

## 4. 성능 최적화

### tf.data 고급 최적화

```python
# 멀티 워커 데이터 로딩 + 캐시
options = tf.data.Options()
options.threading.private_threadpool_size = 8
options.threading.max_intra_op_parallelism = 1

ds = ds.with_options(options)

# 스냅샷으로 전처리 결과 캐시
ds = ds.snapshot("/tmp/tf_snapshot")
```

### tf.function 최적화

```python
# input_signature로 리트레이싱 방지
@tf.function(input_signature=[
    tf.TensorSpec(shape=[None, 224, 224, 3], dtype=tf.float32),
    tf.TensorSpec(shape=[None], dtype=tf.int64),
])
def train_step(self, x, y):
    ...
```

### 프로파일링

```python
# TensorBoard 프로파일러
tf.profiler.experimental.start("logs/profiler")
# ... 학습 스텝 실행
tf.profiler.experimental.stop()
```

## 5. 체크리스트

### 프로젝트 셋업
- [ ] TFRecord 파이프라인 구축
- [ ] Hydra / YAML 설정 구조 구성
- [ ] Docker 환경 구성
- [ ] CI/CD 설정
- [ ] TensorBoard / MLflow 연동

### 코드 품질
- [ ] 커스텀 레이어 단위 테스트
- [ ] tf.function 적용 및 리트레이싱 확인
- [ ] 그래디언트 클리핑 설정
- [ ] Mixed precision 적용 검토

### 학습 관리
- [ ] 체크포인트 저장/복원 검증
- [ ] Early stopping 설정
- [ ] 데이터 증강 전략 수립
- [ ] 하이퍼파라미터 sweep 자동화

### 배포 준비
- [ ] SavedModel 포맷 export
- [ ] TFLite 변환 (모바일/에지)
- [ ] 추론 벤치마크
- [ ] API 서빙 코드 작성
