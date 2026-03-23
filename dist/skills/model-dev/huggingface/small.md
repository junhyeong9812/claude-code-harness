# Hugging Face 소규모 프로젝트 가이드

## 매칭 조건

- 개인 학습 / PoC / 프로토타이핑
- 사전학습 모델 활용 (Quick fine-tuning)
- Trainer API 기반 간단한 파인튜닝
- 노트북 기반 실험
- 팀 규모: 1~2명

## 1. 프로젝트 구조

```
hf-small/
├── notebooks/
│   ├── 01_explore_models.ipynb   # 모델 탐색 및 추론 테스트
│   ├── 02_fine_tune.ipynb        # 파인튜닝
│   └── 03_evaluation.ipynb       # 평가
├── data/
│   ├── raw/
│   └── processed/
├── src/
│   ├── __init__.py
│   ├── dataset.py                # 데이터 전처리
│   └── utils.py
├── outputs/
│   ├── models/                   # 파인튜닝된 모델
│   └── results/                  # 평가 결과
├── requirements.txt
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 사전학습 모델 빠른 추론

```python
from transformers import pipeline

# 텍스트 분류
classifier = pipeline("text-classification", model="klue/bert-base")
result = classifier("이 영화 정말 재미있었어요!")
print(result)  # [{'label': 'POSITIVE', 'score': 0.98}]

# 질의응답
qa = pipeline("question-answering", model="deepset/roberta-base-squad2")
result = qa(
    question="PyTorch는 어떤 프레임워크인가요?",
    context="PyTorch는 Facebook에서 개발한 딥러닝 프레임워크입니다."
)
print(result)

# 텍스트 생성
generator = pipeline("text-generation", model="skt/ko-gpt-trinity-1.2B-v0.5")
result = generator("인공지능의 미래는", max_length=100, num_return_sequences=1)
print(result[0]["generated_text"])

# 제로샷 분류
zero_shot = pipeline("zero-shot-classification", model="facebook/bart-large-mnli")
result = zero_shot(
    "오늘 주식 시장이 크게 올랐습니다.",
    candidate_labels=["경제", "스포츠", "정치", "기술"],
)
print(result)
```

### 2.2 텍스트 분류 파인튜닝

```python
from transformers import (
    AutoTokenizer,
    AutoModelForSequenceClassification,
    TrainingArguments,
    Trainer,
)
from datasets import load_dataset
import numpy as np
from sklearn.metrics import accuracy_score, f1_score

# 데이터 로드
dataset = load_dataset("klue", "nli")
# 또는 로컬 CSV
# dataset = load_dataset("csv", data_files={"train": "data/train.csv", "test": "data/test.csv"})

# 토크나이저 및 모델
model_name = "klue/bert-base"
tokenizer = AutoTokenizer.from_pretrained(model_name)
model = AutoModelForSequenceClassification.from_pretrained(
    model_name, num_labels=3
)

# 토크나이징
def tokenize_fn(examples):
    return tokenizer(
        examples["premise"],
        examples["hypothesis"],
        truncation=True,
        padding="max_length",
        max_length=128,
    )

tokenized_ds = dataset.map(tokenize_fn, batched=True, remove_columns=dataset["train"].column_names - {"label"})

# 메트릭
def compute_metrics(eval_pred):
    predictions, labels = eval_pred
    preds = np.argmax(predictions, axis=1)
    return {
        "accuracy": accuracy_score(labels, preds),
        "f1_macro": f1_score(labels, preds, average="macro"),
    }

# 학습 설정
training_args = TrainingArguments(
    output_dir="outputs/models/klue-nli",
    num_train_epochs=3,
    per_device_train_batch_size=16,
    per_device_eval_batch_size=32,
    learning_rate=2e-5,
    weight_decay=0.01,
    warmup_ratio=0.1,
    eval_strategy="epoch",
    save_strategy="epoch",
    load_best_model_at_end=True,
    metric_for_best_model="f1_macro",
    logging_steps=100,
    fp16=True,
    seed=42,
    report_to="none",  # 또는 "wandb", "mlflow"
)

# Trainer 생성 및 학습
trainer = Trainer(
    model=model,
    args=training_args,
    train_dataset=tokenized_ds["train"],
    eval_dataset=tokenized_ds["validation"],
    compute_metrics=compute_metrics,
    tokenizer=tokenizer,
)

trainer.train()
```

### 2.3 토큰 분류 (NER) 파인튜닝

```python
from transformers import AutoModelForTokenClassification, DataCollatorForTokenClassification

# NER 데이터셋
dataset = load_dataset("klue", "ner")

label_list = dataset["train"].features["ner_tags"].feature.names
id2label = {i: l for i, l in enumerate(label_list)}
label2id = {l: i for i, l in enumerate(label_list)}

model = AutoModelForTokenClassification.from_pretrained(
    "klue/bert-base",
    num_labels=len(label_list),
    id2label=id2label,
    label2id=label2id,
)

# 토크나이징 (서브워드 정렬 처리)
def tokenize_and_align_labels(examples):
    tokenized = tokenizer(
        examples["tokens"],
        truncation=True,
        is_split_into_words=True,
        padding="max_length",
        max_length=128,
    )

    labels = []
    for i, label in enumerate(examples["ner_tags"]):
        word_ids = tokenized.word_ids(batch_index=i)
        label_ids = []
        prev_word_id = None
        for word_id in word_ids:
            if word_id is None:
                label_ids.append(-100)
            elif word_id != prev_word_id:
                label_ids.append(label[word_id])
            else:
                label_ids.append(-100)  # 서브워드는 무시
            prev_word_id = word_id
        labels.append(label_ids)

    tokenized["labels"] = labels
    return tokenized

tokenized_ds = dataset.map(tokenize_and_align_labels, batched=True)

data_collator = DataCollatorForTokenClassification(tokenizer)

trainer = Trainer(
    model=model,
    args=TrainingArguments(
        output_dir="outputs/models/klue-ner",
        num_train_epochs=5,
        per_device_train_batch_size=16,
        learning_rate=3e-5,
        eval_strategy="epoch",
        save_strategy="epoch",
        load_best_model_at_end=True,
        fp16=True,
    ),
    train_dataset=tokenized_ds["train"],
    eval_dataset=tokenized_ds["validation"],
    data_collator=data_collator,
    tokenizer=tokenizer,
)

trainer.train()
```

### 2.4 모델 저장 및 추론

```python
# 모델 저장
trainer.save_model("outputs/models/final")
tokenizer.save_pretrained("outputs/models/final")

# 로드 및 추론
from transformers import pipeline

classifier = pipeline(
    "text-classification",
    model="outputs/models/final",
    tokenizer="outputs/models/final",
)

results = classifier([
    "이 제품 정말 좋아요!",
    "배송이 너무 늦었어요.",
])
for r in results:
    print(f"라벨: {r['label']}, 확률: {r['score']:.4f}")
```

### 2.5 Hub에 업로드

```python
# Hugging Face Hub에 모델 공유
from huggingface_hub import login

login()  # 토큰 입력

trainer.push_to_hub(
    "my-username/klue-nli-bert",
    commit_message="KLUE NLI fine-tuned BERT",
)

# 또는 직접 업로드
model.push_to_hub("my-username/klue-nli-bert")
tokenizer.push_to_hub("my-username/klue-nli-bert")
```

## 3. 테스트/검증 전략

### 모델 기본 검증

```python
def test_model_inference():
    """모델 추론 기본 테스트"""
    tokenizer = AutoTokenizer.from_pretrained("outputs/models/final")
    model = AutoModelForSequenceClassification.from_pretrained("outputs/models/final")

    inputs = tokenizer("테스트 문장입니다.", return_tensors="pt")
    outputs = model(**inputs)

    assert outputs.logits.shape[1] == 3  # num_labels
    print(f"추론 테스트 통과. Logits shape: {outputs.logits.shape}")


def test_tokenizer():
    """토크나이저 검증"""
    tokenizer = AutoTokenizer.from_pretrained("outputs/models/final")

    text = "안녕하세요, 반갑습니다."
    tokens = tokenizer(text, return_tensors="pt")

    assert "input_ids" in tokens
    assert "attention_mask" in tokens
    assert tokens["input_ids"].shape[0] == 1

    decoded = tokenizer.decode(tokens["input_ids"][0], skip_special_tokens=True)
    print(f"원본: {text}")
    print(f"디코딩: {decoded}")
```

### 데이터 검증

```python
def validate_dataset(dataset):
    """데이터셋 기본 검증"""
    print(f"학습 세트 크기: {len(dataset['train'])}")
    print(f"검증 세트 크기: {len(dataset['validation'])}")
    print(f"컬럼: {dataset['train'].column_names}")
    print(f"피처 타입: {dataset['train'].features}")

    # 라벨 분포 확인
    from collections import Counter
    label_dist = Counter(dataset["train"]["label"])
    print(f"라벨 분포: {dict(label_dist)}")

    # 텍스트 길이 분포
    lengths = [len(t.split()) for t in dataset["train"]["text"]]
    print(f"텍스트 길이 - 평균: {np.mean(lengths):.0f}, "
          f"최대: {max(lengths)}, 최소: {min(lengths)}")
```

## 4. 성능 최적화

### 학습 속도 최적화

```python
training_args = TrainingArguments(
    ...
    fp16=True,                    # Mixed precision
    dataloader_num_workers=4,     # 멀티 워커 데이터 로딩
    group_by_length=True,         # 유사 길이 샘플 그룹핑 (패딩 최소화)
    dataloader_pin_memory=True,   # GPU 메모리 핀닝
    gradient_accumulation_steps=4, # 실효 배치 사이즈 확대
)
```

### 추론 최적화

```python
# ONNX로 변환하여 추론 최적화
from optimum.onnxruntime import ORTModelForSequenceClassification

ort_model = ORTModelForSequenceClassification.from_pretrained(
    "outputs/models/final",
    export=True,
)
ort_model.save_pretrained("outputs/models/onnx")

# ONNX 모델로 추론
classifier = pipeline(
    "text-classification",
    model=ort_model,
    tokenizer=tokenizer,
)
```

## 5. 체크리스트

### 프로젝트 시작 시
- [ ] 태스크에 적합한 사전학습 모델 선택
- [ ] 데이터셋 EDA 및 품질 확인
- [ ] 라벨 체계 및 분포 확인
- [ ] GPU 환경 확인 (`transformers` 버전 호환성)

### 파인튜닝 시
- [ ] 토크나이저 max_length 적절히 설정
- [ ] 학습률 (2e-5 ~ 5e-5 범위 탐색)
- [ ] Warmup ratio 설정 (0.06 ~ 0.1)
- [ ] Evaluation 전략 설정
- [ ] FP16 활성화

### 평가 시
- [ ] 적절한 메트릭 선정 (accuracy, F1, EM 등)
- [ ] 에러 분석 수행
- [ ] 라벨별 성능 확인
- [ ] 추론 속도 벤치마크

### 공유/배포
- [ ] 모델 카드 작성
- [ ] Hub 업로드 (선택)
- [ ] `requirements.txt` 최신화
- [ ] 노트북 재현성 확인
