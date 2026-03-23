# Hugging Face 중규모 프로젝트 가이드

## 매칭 조건

- 팀 프로젝트 (3~10명)
- Custom training loop, PEFT/LoRA 적용
- Datasets 라이브러리 활용
- 체계적 평가 및 실험 관리
- CI/CD 파이프라인 존재

## 1. 프로젝트 구조

```
hf-medium/
├── configs/
│   ├── base.yaml
│   ├── model/
│   │   ├── bert_base.yaml
│   │   ├── llama_7b_lora.yaml
│   │   └── t5_base.yaml
│   ├── data/
│   │   ├── klue_nli.yaml
│   │   └── custom_qa.yaml
│   └── training/
│       ├── full_finetune.yaml
│       ├── lora.yaml
│       └── qlora.yaml
├── src/
│   ├── __init__.py
│   ├── data/
│   │   ├── __init__.py
│   │   ├── dataset.py            # 데이터셋 로딩/전처리
│   │   ├── collator.py           # 커스텀 데이터 콜레이터
│   │   └── preprocessing.py      # 전처리 함수
│   ├── models/
│   │   ├── __init__.py
│   │   ├── model_factory.py      # 모델 생성 팩토리
│   │   └── peft_config.py        # PEFT 설정
│   ├── training/
│   │   ├── __init__.py
│   │   ├── trainer.py            # 커스텀 트레이너
│   │   ├── callbacks.py          # 커스텀 콜백
│   │   └── losses.py             # 커스텀 손실 함수
│   ├── evaluation/
│   │   ├── __init__.py
│   │   ├── metrics.py
│   │   └── error_analysis.py     # 에러 분석
│   └── utils/
│       ├── __init__.py
│       └── logging.py
├── scripts/
│   ├── train.py
│   ├── evaluate.py
│   ├── predict.py
│   └── merge_lora.py             # LoRA 가중치 병합
├── tests/
│   ├── unit/
│   │   ├── test_dataset.py
│   │   └── test_model.py
│   └── integration/
│       └── test_training.py
├── docker/
│   └── Dockerfile.train
├── .github/workflows/ci.yml
├── pyproject.toml
├── Makefile
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 PEFT/LoRA 파인튜닝

```python
# src/models/peft_config.py
from peft import (
    LoraConfig,
    TaskType,
    get_peft_model,
    prepare_model_for_kbit_training,
)
from transformers import AutoModelForCausalLM, BitsAndBytesConfig
import torch


def create_lora_model(model_name: str, cfg):
    """LoRA 모델 생성"""
    model = AutoModelForCausalLM.from_pretrained(
        model_name,
        torch_dtype=torch.bfloat16,
        device_map="auto",
    )

    lora_config = LoraConfig(
        task_type=TaskType.CAUSAL_LM,
        r=cfg.lora.rank,                    # LoRA rank (8, 16, 32, 64)
        lora_alpha=cfg.lora.alpha,           # 보통 rank의 2배
        lora_dropout=cfg.lora.dropout,       # 0.05 ~ 0.1
        target_modules=cfg.lora.target_modules,  # ["q_proj", "v_proj", "k_proj", "o_proj"]
        bias="none",
    )

    model = get_peft_model(model, lora_config)
    model.print_trainable_parameters()  # 학습 가능 파라미터 비율 출력
    return model


def create_qlora_model(model_name: str, cfg):
    """QLoRA 모델 생성 (4bit 양자화 + LoRA)"""
    bnb_config = BitsAndBytesConfig(
        load_in_4bit=True,
        bnb_4bit_quant_type="nf4",
        bnb_4bit_compute_dtype=torch.bfloat16,
        bnb_4bit_use_double_quant=True,
    )

    model = AutoModelForCausalLM.from_pretrained(
        model_name,
        quantization_config=bnb_config,
        device_map="auto",
    )
    model = prepare_model_for_kbit_training(model)

    lora_config = LoraConfig(
        task_type=TaskType.CAUSAL_LM,
        r=cfg.lora.rank,
        lora_alpha=cfg.lora.alpha,
        lora_dropout=cfg.lora.dropout,
        target_modules=cfg.lora.target_modules,
    )

    model = get_peft_model(model, lora_config)
    return model
```

### 2.2 Datasets 라이브러리 활용

```python
# src/data/dataset.py
from datasets import load_dataset, DatasetDict, Dataset, concatenate_datasets
from transformers import AutoTokenizer
from functools import partial


class DataManager:
    """데이터셋 관리 클래스"""

    def __init__(self, tokenizer_name: str, max_length: int = 512):
        self.tokenizer = AutoTokenizer.from_pretrained(tokenizer_name)
        if self.tokenizer.pad_token is None:
            self.tokenizer.pad_token = self.tokenizer.eos_token
        self.max_length = max_length

    def load_and_prepare(self, cfg) -> DatasetDict:
        """데이터셋 로드 및 전처리"""
        # 데이터 로드 (다양한 소스 지원)
        if cfg.data.source == "hub":
            dataset = load_dataset(cfg.data.name, cfg.data.subset)
        elif cfg.data.source == "csv":
            dataset = load_dataset("csv", data_files=cfg.data.files)
        elif cfg.data.source == "json":
            dataset = load_dataset("json", data_files=cfg.data.files)

        # 전처리 적용
        dataset = dataset.map(
            partial(self._preprocess, task=cfg.data.task),
            batched=True,
            remove_columns=dataset["train"].column_names,
            num_proc=cfg.data.num_proc,
            desc="전처리 중",
        )

        # 데이터셋 분할 (필요한 경우)
        if "validation" not in dataset:
            split = dataset["train"].train_test_split(test_size=0.1, seed=42)
            dataset = DatasetDict({
                "train": split["train"],
                "validation": split["test"],
            })

        return dataset

    def _preprocess(self, examples, task: str):
        """태스크별 전처리"""
        if task == "classification":
            return self._preprocess_classification(examples)
        elif task == "causal_lm":
            return self._preprocess_causal_lm(examples)
        elif task == "instruction":
            return self._preprocess_instruction(examples)

    def _preprocess_classification(self, examples):
        return self.tokenizer(
            examples["text"],
            truncation=True,
            padding="max_length",
            max_length=self.max_length,
        )

    def _preprocess_causal_lm(self, examples):
        """Causal LM 전처리 (텍스트 연결 + 청킹)"""
        tokenized = self.tokenizer(
            examples["text"],
            truncation=True,
            max_length=self.max_length,
        )
        return tokenized

    def _preprocess_instruction(self, examples):
        """Instruction 형식 전처리"""
        formatted = []
        for instruction, input_text, output in zip(
            examples["instruction"], examples["input"], examples["output"]
        ):
            if input_text:
                prompt = f"### 지시:\n{instruction}\n\n### 입력:\n{input_text}\n\n### 응답:\n{output}"
            else:
                prompt = f"### 지시:\n{instruction}\n\n### 응답:\n{output}"
            formatted.append(prompt)

        tokenized = self.tokenizer(
            formatted,
            truncation=True,
            padding="max_length",
            max_length=self.max_length,
        )
        tokenized["labels"] = tokenized["input_ids"].copy()
        return tokenized
```

### 2.3 커스텀 Trainer

```python
# src/training/trainer.py
from transformers import Trainer, TrainingArguments
import torch
import torch.nn as nn


class CustomTrainer(Trainer):
    """커스텀 트레이너 (손실 함수, 메트릭 커스터마이징)"""

    def __init__(self, *args, label_weights=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.label_weights = label_weights

    def compute_loss(self, model, inputs, return_outputs=False, **kwargs):
        """커스텀 손실 함수"""
        labels = inputs.pop("labels")
        outputs = model(**inputs)
        logits = outputs.logits

        if self.label_weights is not None:
            weight = torch.tensor(
                self.label_weights, dtype=torch.float32, device=logits.device
            )
            loss_fn = nn.CrossEntropyLoss(weight=weight)
        else:
            loss_fn = nn.CrossEntropyLoss()

        loss = loss_fn(logits.view(-1, logits.shape[-1]), labels.view(-1))
        return (loss, outputs) if return_outputs else loss


class SFTTrainerWithLogging(Trainer):
    """SFT 트레이너 + 추가 로깅"""

    def log(self, logs: dict):
        """학습 로그에 추가 정보 포함"""
        if "loss" in logs:
            logs["perplexity"] = torch.exp(torch.tensor(logs["loss"])).item()

        # 학습률 로깅
        if self.state.global_step > 0:
            logs["learning_rate"] = self.optimizer.param_groups[0]["lr"]

        super().log(logs)
```

### 2.4 평가 및 에러 분석

```python
# src/evaluation/error_analysis.py
import pandas as pd
import numpy as np
from transformers import pipeline
from sklearn.metrics import classification_report, confusion_matrix
import seaborn as sns
import matplotlib.pyplot as plt


class ErrorAnalyzer:
    """모델 에러 분석 도구"""

    def __init__(self, model_path: str, tokenizer_path: str):
        self.pipe = pipeline(
            "text-classification",
            model=model_path,
            tokenizer=tokenizer_path,
            device=0,
        )

    def analyze(self, texts: list[str], true_labels: list[str]) -> pd.DataFrame:
        """에러 분석 실행"""
        predictions = self.pipe(texts, batch_size=32)
        pred_labels = [p["label"] for p in predictions]
        pred_scores = [p["score"] for p in predictions]

        df = pd.DataFrame({
            "text": texts,
            "true_label": true_labels,
            "pred_label": pred_labels,
            "confidence": pred_scores,
            "correct": [t == p for t, p in zip(true_labels, pred_labels)],
        })

        # 에러 케이스만 추출
        errors = df[~df["correct"]].sort_values("confidence", ascending=False)
        print(f"전체: {len(df)}, 정답: {df['correct'].sum()}, "
              f"오류: {len(errors)} ({len(errors)/len(df)*100:.1f}%)")

        # 분류 리포트
        print("\n=== Classification Report ===")
        print(classification_report(true_labels, pred_labels))

        return df

    def plot_confusion_matrix(self, df: pd.DataFrame, labels: list[str]):
        """혼동 행렬 시각화"""
        cm = confusion_matrix(df["true_label"], df["pred_label"], labels=labels)
        plt.figure(figsize=(8, 6))
        sns.heatmap(cm, annot=True, fmt="d", xticklabels=labels, yticklabels=labels)
        plt.xlabel("예측")
        plt.ylabel("실제")
        plt.title("혼동 행렬")
        plt.tight_layout()
        plt.savefig("outputs/results/confusion_matrix.png", dpi=150)

    def analyze_by_length(self, df: pd.DataFrame):
        """텍스트 길이별 성능 분석"""
        df["text_length"] = df["text"].str.len()
        bins = [0, 50, 100, 200, 500, float("inf")]
        labels = ["~50", "50~100", "100~200", "200~500", "500+"]
        df["length_group"] = pd.cut(df["text_length"], bins=bins, labels=labels)

        grouped = df.groupby("length_group")["correct"].agg(["mean", "count"])
        print("\n=== 텍스트 길이별 정확도 ===")
        print(grouped)
        return grouped
```

### 2.5 LoRA 가중치 병합

```python
# scripts/merge_lora.py
from peft import PeftModel
from transformers import AutoModelForCausalLM, AutoTokenizer
import torch


def merge_lora_weights(
    base_model_name: str,
    lora_adapter_path: str,
    output_path: str,
):
    """LoRA 어댑터를 기본 모델에 병합"""
    print(f"기본 모델 로드: {base_model_name}")
    base_model = AutoModelForCausalLM.from_pretrained(
        base_model_name,
        torch_dtype=torch.bfloat16,
        device_map="cpu",
    )

    print(f"LoRA 어댑터 로드: {lora_adapter_path}")
    model = PeftModel.from_pretrained(base_model, lora_adapter_path)

    print("가중치 병합 중...")
    merged_model = model.merge_and_unload()

    print(f"병합된 모델 저장: {output_path}")
    merged_model.save_pretrained(output_path)

    tokenizer = AutoTokenizer.from_pretrained(lora_adapter_path)
    tokenizer.save_pretrained(output_path)
    print("완료!")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--base_model", required=True)
    parser.add_argument("--lora_path", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    merge_lora_weights(args.base_model, args.lora_path, args.output)
```

### 2.6 학습 진입점

```python
# scripts/train.py
import hydra
from omegaconf import DictConfig
from transformers import TrainingArguments, EarlyStoppingCallback
import wandb

from src.data.dataset import DataManager
from src.models.peft_config import create_lora_model, create_qlora_model
from src.training.trainer import CustomTrainer


@hydra.main(config_path="../configs", config_name="base", version_base=None)
def main(cfg: DictConfig):
    # 실험 추적
    wandb.init(project=cfg.project_name, config=dict(cfg))

    # 데이터
    dm = DataManager(cfg.model.name, max_length=cfg.data.max_length)
    dataset = dm.load_and_prepare(cfg)

    # 모델
    if cfg.training.method == "lora":
        model = create_lora_model(cfg.model.name, cfg)
    elif cfg.training.method == "qlora":
        model = create_qlora_model(cfg.model.name, cfg)
    else:
        from transformers import AutoModelForCausalLM
        model = AutoModelForCausalLM.from_pretrained(cfg.model.name)

    # 학습 설정
    training_args = TrainingArguments(
        output_dir=cfg.output_dir,
        num_train_epochs=cfg.training.epochs,
        per_device_train_batch_size=cfg.training.batch_size,
        gradient_accumulation_steps=cfg.training.gradient_accumulation_steps,
        learning_rate=cfg.training.lr,
        warmup_ratio=cfg.training.warmup_ratio,
        weight_decay=cfg.training.weight_decay,
        fp16=cfg.training.fp16,
        bf16=cfg.training.bf16,
        eval_strategy="steps",
        eval_steps=cfg.training.eval_steps,
        save_steps=cfg.training.save_steps,
        logging_steps=cfg.training.logging_steps,
        load_best_model_at_end=True,
        report_to="wandb",
    )

    trainer = CustomTrainer(
        model=model,
        args=training_args,
        train_dataset=dataset["train"],
        eval_dataset=dataset["validation"],
        tokenizer=dm.tokenizer,
        callbacks=[EarlyStoppingCallback(early_stopping_patience=3)],
    )

    trainer.train()
    trainer.save_model(f"{cfg.output_dir}/final")
    wandb.finish()


if __name__ == "__main__":
    main()
```

## 3. 테스트/검증 전략

### 단위 테스트

```python
# tests/unit/test_dataset.py
import pytest
from src.data.dataset import DataManager


@pytest.fixture
def data_manager():
    return DataManager("klue/bert-base", max_length=128)


def test_classification_preprocessing(data_manager):
    examples = {"text": ["테스트 문장", "또 다른 문장"], "label": [0, 1]}
    result = data_manager._preprocess_classification(examples)
    assert "input_ids" in result
    assert len(result["input_ids"]) == 2
    assert len(result["input_ids"][0]) == 128  # max_length


def test_instruction_preprocessing(data_manager):
    examples = {
        "instruction": ["요약해주세요"],
        "input": ["긴 텍스트..."],
        "output": ["요약 결과"],
    }
    result = data_manager._preprocess_instruction(examples)
    assert "labels" in result
```

### LoRA 모델 테스트

```python
# tests/unit/test_model.py
def test_lora_trainable_params():
    """LoRA 적용 후 학습 가능 파라미터 비율 확인"""
    from peft import LoraConfig, get_peft_model
    from transformers import AutoModelForSequenceClassification

    model = AutoModelForSequenceClassification.from_pretrained(
        "bert-base-uncased", num_labels=2
    )
    total_before = sum(p.numel() for p in model.parameters())

    config = LoraConfig(r=8, lora_alpha=16, target_modules=["query", "value"])
    peft_model = get_peft_model(model, config)

    trainable = sum(p.numel() for p in peft_model.parameters() if p.requires_grad)
    ratio = trainable / total_before * 100
    assert ratio < 5, f"학습 가능 파라미터 비율이 너무 높음: {ratio:.2f}%"
    print(f"학습 가능 파라미터: {trainable:,} ({ratio:.2f}%)")
```

## 4. 성능 최적화

### 메모리 최적화

```python
# 그래디언트 체크포인팅
model.gradient_checkpointing_enable()

# Flash Attention 2 사용
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    attn_implementation="flash_attention_2",
    torch_dtype=torch.bfloat16,
)

# 8bit 옵티마이저
from bitsandbytes.optim import AdamW8bit
optimizer = AdamW8bit(model.parameters(), lr=2e-5)
```

### 데이터 로딩 최적화

```python
# 스트리밍 모드로 대규모 데이터셋 처리
dataset = load_dataset("huge_dataset", streaming=True)
dataset = dataset.shuffle(seed=42, buffer_size=10000)

# Arrow 캐시 활용
dataset = load_dataset("my_data", cache_dir="/fast-ssd/cache")
```

### 추론 최적화

```python
# vLLM으로 빠른 추론
from vllm import LLM, SamplingParams

llm = LLM(model="outputs/models/merged", dtype="bfloat16")
params = SamplingParams(temperature=0.7, max_tokens=256)
outputs = llm.generate(["질문입니다."], params)
```

## 5. 체크리스트

### 프로젝트 셋업
- [ ] PEFT/LoRA vs Full fine-tuning 결정
- [ ] 모델 크기 및 GPU 메모리 확인
- [ ] Hydra 설정 구조 구성
- [ ] W&B / MLflow 연동
- [ ] CI/CD 설정

### 학습
- [ ] LoRA rank, alpha, target_modules 설정
- [ ] 그래디언트 체크포인팅 활성화
- [ ] BF16/FP16 설정
- [ ] 적절한 배치 사이즈 + gradient accumulation
- [ ] 학습률 스케줄러 설정

### 평가
- [ ] 태스크별 적절한 메트릭 설정
- [ ] 에러 분석 수행
- [ ] 길이/카테고리별 세분화 평가
- [ ] 기존 모델 대비 비교 평가

### 모델 관리
- [ ] LoRA 가중치 병합 테스트
- [ ] Hub 업로드 (모델 카드 포함)
- [ ] 추론 최적화 (ONNX / vLLM)
- [ ] 버전 관리 전략 수립
