# Hugging Face 대규모 프로젝트 가이드

## 매칭 조건

- 팀 규모 10명 이상 / 다수 팀 협업
- 대규모 모델 (7B+ 파라미터)
- Accelerate, DeepSpeed 분산 학습
- Model Hub 관리, 추론 최적화
- 완전 자동화된 MLOps

## 1. 프로젝트 구조

```
hf-large/
├── configs/
│   ├── base.yaml
│   ├── model/
│   │   ├── llama_7b.yaml
│   │   ├── llama_13b.yaml
│   │   └── mistral_7b.yaml
│   ├── training/
│   │   ├── full_finetune.yaml
│   │   ├── lora.yaml
│   │   ├── deepspeed_zero2.yaml
│   │   └── deepspeed_zero3.yaml
│   ├── data/
│   │   └── instruction.yaml
│   └── serving/
│       ├── vllm.yaml
│       └── tgi.yaml
├── src/
│   ├── __init__.py
│   ├── data/
│   │   ├── __init__.py
│   │   ├── dataset.py
│   │   ├── preprocessing.py
│   │   ├── tokenization.py
│   │   └── streaming.py          # 스트리밍 데이터
│   ├── models/
│   │   ├── __init__.py
│   │   ├── factory.py
│   │   ├── peft_config.py
│   │   └── custom_model.py
│   ├── training/
│   │   ├── __init__.py
│   │   ├── trainer.py
│   │   ├── distributed.py        # Accelerate 래퍼
│   │   ├── callbacks.py
│   │   └── reward_model.py       # RLHF
│   ├── evaluation/
│   │   ├── __init__.py
│   │   ├── benchmarks.py         # 벤치마크 평가
│   │   ├── human_eval.py
│   │   └── safety.py             # 안전성 평가
│   ├── serving/
│   │   ├── __init__.py
│   │   ├── vllm_server.py
│   │   └── optimization.py       # 양자화, pruning
│   └── hub/
│       ├── __init__.py
│       ├── model_card.py          # 모델 카드 생성
│       └── upload.py              # Hub 업로드
├── deepspeed_configs/
│   ├── zero2.json
│   ├── zero3.json
│   └── zero3_offload.json
├── scripts/
│   ├── train.py
│   ├── train_distributed.sh
│   ├── evaluate_benchmarks.py
│   ├── merge_and_push.py
│   └── serve.py
├── pipelines/
│   ├── training/
│   │   ├── Dockerfile
│   │   └── pipeline.py
│   └── serving/
│       ├── Dockerfile.vllm
│       └── Dockerfile.tgi
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/
├── k8s/
│   ├── training-job.yaml
│   ├── serving.yaml
│   └── hpa.yaml
├── .github/workflows/
│   ├── ci.yml
│   ├── train.yml
│   └── deploy.yml
├── pyproject.toml
├── Makefile
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 Accelerate 분산 학습

```python
# src/training/distributed.py
from accelerate import Accelerator, DistributedDataParallelKwargs
from accelerate.utils import set_seed
import torch
from torch.utils.data import DataLoader
from transformers import get_cosine_schedule_with_warmup
import logging

logger = logging.getLogger(__name__)


class DistributedTrainer:
    """Accelerate 기반 분산 학습 트레이너"""

    def __init__(self, cfg, model, tokenizer, train_dataset, eval_dataset):
        self.cfg = cfg

        # Accelerator 초기화
        ddp_kwargs = DistributedDataParallelKwargs(find_unused_parameters=False)
        self.accelerator = Accelerator(
            mixed_precision=cfg.training.mixed_precision,  # "bf16", "fp16"
            gradient_accumulation_steps=cfg.training.gradient_accumulation_steps,
            kwargs_handlers=[ddp_kwargs],
            log_with="wandb",
        )

        self.accelerator.init_trackers(
            project_name=cfg.project_name,
            config=dict(cfg),
        )

        set_seed(cfg.seed)

        # 데이터 로더
        train_loader = DataLoader(
            train_dataset,
            batch_size=cfg.training.batch_size_per_device,
            shuffle=True,
            collate_fn=self._collate_fn,
            num_workers=cfg.data.num_workers,
            pin_memory=True,
        )
        eval_loader = DataLoader(
            eval_dataset,
            batch_size=cfg.training.batch_size_per_device * 2,
            collate_fn=self._collate_fn,
        )

        # 옵티마이저
        optimizer = torch.optim.AdamW(
            model.parameters(),
            lr=cfg.training.lr,
            weight_decay=cfg.training.weight_decay,
        )

        # 스케줄러
        num_training_steps = (
            len(train_loader) * cfg.training.epochs
            // cfg.training.gradient_accumulation_steps
        )
        scheduler = get_cosine_schedule_with_warmup(
            optimizer,
            num_warmup_steps=int(num_training_steps * cfg.training.warmup_ratio),
            num_training_steps=num_training_steps,
        )

        # Accelerate로 래핑
        (
            self.model,
            self.optimizer,
            self.train_loader,
            self.eval_loader,
            self.scheduler,
        ) = self.accelerator.prepare(
            model, optimizer, train_loader, eval_loader, scheduler
        )

        self.tokenizer = tokenizer

    def fit(self):
        """전체 학습 실행"""
        global_step = 0
        best_eval_loss = float("inf")

        for epoch in range(self.cfg.training.epochs):
            self.model.train()
            epoch_loss = 0.0

            for step, batch in enumerate(self.train_loader):
                with self.accelerator.accumulate(self.model):
                    outputs = self.model(**batch)
                    loss = outputs.loss
                    self.accelerator.backward(loss)

                    # 그래디언트 클리핑
                    if self.accelerator.sync_gradients:
                        self.accelerator.clip_grad_norm_(
                            self.model.parameters(),
                            self.cfg.training.max_grad_norm,
                        )

                    self.optimizer.step()
                    self.scheduler.step()
                    self.optimizer.zero_grad()

                epoch_loss += loss.detach().float().item()

                if self.accelerator.sync_gradients:
                    global_step += 1

                    if global_step % self.cfg.training.logging_steps == 0:
                        self.accelerator.log({
                            "train/loss": loss.detach().float().item(),
                            "train/lr": self.scheduler.get_last_lr()[0],
                            "train/epoch": epoch,
                        }, step=global_step)

                    if global_step % self.cfg.training.eval_steps == 0:
                        eval_loss = self._evaluate()
                        self.accelerator.log(
                            {"eval/loss": eval_loss}, step=global_step
                        )

                        if eval_loss < best_eval_loss:
                            best_eval_loss = eval_loss
                            self._save_checkpoint("best")

            logger.info(
                f"Epoch {epoch+1}/{self.cfg.training.epochs} | "
                f"Avg Loss: {epoch_loss / len(self.train_loader):.4f}"
            )

        self._save_checkpoint("final")
        self.accelerator.end_training()

    @torch.no_grad()
    def _evaluate(self) -> float:
        self.model.eval()
        total_loss = 0.0
        for batch in self.eval_loader:
            outputs = self.model(**batch)
            loss = outputs.loss
            total_loss += self.accelerator.gather(loss).mean().item()
        self.model.train()
        return total_loss / len(self.eval_loader)

    def _save_checkpoint(self, tag: str):
        self.accelerator.wait_for_everyone()
        unwrapped = self.accelerator.unwrap_model(self.model)
        unwrapped.save_pretrained(
            f"{self.cfg.output_dir}/{tag}",
            save_function=self.accelerator.save,
        )
        if self.accelerator.is_main_process:
            self.tokenizer.save_pretrained(f"{self.cfg.output_dir}/{tag}")

    def _collate_fn(self, examples):
        return self.tokenizer.pad(
            examples, padding=True, return_tensors="pt"
        )
```

### 2.2 DeepSpeed 설정

```json
// deepspeed_configs/zero3.json
{
  "bf16": {
    "enabled": true
  },
  "zero_optimization": {
    "stage": 3,
    "offload_optimizer": {
      "device": "none"
    },
    "offload_param": {
      "device": "none"
    },
    "overlap_comm": true,
    "contiguous_gradients": true,
    "sub_group_size": 1e9,
    "reduce_bucket_size": "auto",
    "stage3_prefetch_bucket_size": "auto",
    "stage3_param_persistence_threshold": "auto",
    "stage3_max_live_parameters": 1e9,
    "stage3_max_reuse_distance": 1e9,
    "stage3_gather_16bit_weights_on_model_save": true
  },
  "gradient_accumulation_steps": "auto",
  "gradient_clipping": "auto",
  "steps_per_print": 100,
  "train_batch_size": "auto",
  "train_micro_batch_size_per_gpu": "auto",
  "wall_clock_breakdown": false
}
```

```json
// deepspeed_configs/zero3_offload.json
{
  "bf16": { "enabled": true },
  "zero_optimization": {
    "stage": 3,
    "offload_optimizer": {
      "device": "cpu",
      "pin_memory": true
    },
    "offload_param": {
      "device": "cpu",
      "pin_memory": true
    },
    "overlap_comm": true,
    "contiguous_gradients": true,
    "reduce_bucket_size": "auto",
    "stage3_prefetch_bucket_size": "auto",
    "stage3_param_persistence_threshold": "auto",
    "stage3_gather_16bit_weights_on_model_save": true
  },
  "gradient_accumulation_steps": "auto",
  "gradient_clipping": "auto",
  "train_batch_size": "auto",
  "train_micro_batch_size_per_gpu": "auto"
}
```

### 2.3 분산 학습 실행 스크립트

```bash
#!/bin/bash
# scripts/train_distributed.sh

# Accelerate (자동 설정)
accelerate launch \
    --num_processes 8 \
    --mixed_precision bf16 \
    scripts/train.py \
    training=lora \
    model=llama_7b

# DeepSpeed ZeRO-3
accelerate launch \
    --use_deepspeed \
    --deepspeed_config_file deepspeed_configs/zero3.json \
    --num_processes 8 \
    scripts/train.py \
    training=deepspeed_zero3 \
    model=llama_13b

# 멀티 노드 (SLURM)
# srun accelerate launch \
#     --num_processes $((SLURM_NNODES * 8)) \
#     --num_machines $SLURM_NNODES \
#     --machine_rank $SLURM_NODEID \
#     --main_process_ip $MASTER_ADDR \
#     --main_process_port $MASTER_PORT \
#     scripts/train.py
```

### 2.4 추론 최적화 및 서빙

```python
# src/serving/optimization.py
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
import torch


def quantize_gptq(model_path: str, output_path: str):
    """GPTQ 양자화"""
    from auto_gptq import AutoGPTQForCausalLM, BaseQuantizeConfig

    quantize_config = BaseQuantizeConfig(
        bits=4,
        group_size=128,
        desc_act=True,
    )

    model = AutoGPTQForCausalLM.from_pretrained(
        model_path, quantize_config=quantize_config
    )

    # 캘리브레이션 데이터로 양자화
    tokenizer = AutoTokenizer.from_pretrained(model_path)
    calibration_data = [
        tokenizer(text, return_tensors="pt")
        for text in load_calibration_texts()
    ]
    model.quantize(calibration_data)
    model.save_quantized(output_path)


def quantize_awq(model_path: str, output_path: str):
    """AWQ 양자화"""
    from awq import AutoAWQForCausalLM

    model = AutoAWQForCausalLM.from_pretrained(model_path)
    tokenizer = AutoTokenizer.from_pretrained(model_path)

    model.quantize(
        tokenizer,
        quant_config={"zero_point": True, "q_group_size": 128, "w_bit": 4},
    )
    model.save_quantized(output_path)
    tokenizer.save_pretrained(output_path)
```

```python
# src/serving/vllm_server.py
from vllm import LLM, SamplingParams
from vllm.entrypoints.openai.api_server import run_server


def create_vllm_engine(cfg):
    """vLLM 추론 엔진 생성"""
    llm = LLM(
        model=cfg.serving.model_path,
        dtype=cfg.serving.dtype,                # "bfloat16"
        tensor_parallel_size=cfg.serving.tp_size,  # GPU 수
        max_model_len=cfg.serving.max_model_len,
        gpu_memory_utilization=cfg.serving.gpu_memory_utilization,  # 0.9
        quantization=cfg.serving.quantization,  # "awq", "gptq", None
    )
    return llm


def batch_inference(llm, prompts: list[str], cfg) -> list[str]:
    """배치 추론"""
    sampling_params = SamplingParams(
        temperature=cfg.generation.temperature,
        top_p=cfg.generation.top_p,
        max_tokens=cfg.generation.max_tokens,
        repetition_penalty=cfg.generation.repetition_penalty,
    )

    outputs = llm.generate(prompts, sampling_params)
    return [output.outputs[0].text for output in outputs]
```

### 2.5 Model Hub 관리

```python
# src/hub/model_card.py
from huggingface_hub import ModelCard, ModelCardData


def create_model_card(cfg, eval_results: dict) -> str:
    """모델 카드 자동 생성"""
    card_data = ModelCardData(
        language="ko",
        license="apache-2.0",
        model_name=cfg.model.display_name,
        base_model=cfg.model.base_model,
        datasets=[cfg.data.name],
        metrics=[
            {"type": "accuracy", "value": eval_results["accuracy"]},
        ],
        tags=["text-generation", "korean", "fine-tuned"],
    )

    card = ModelCard.from_template(
        card_data,
        model_id=cfg.hub.model_id,
        model_description=cfg.model.description,
        training_details=f"""
## 학습 설정
- Base Model: {cfg.model.base_model}
- Method: {cfg.training.method} (rank={cfg.lora.rank})
- Epochs: {cfg.training.epochs}
- Learning Rate: {cfg.training.lr}
- Batch Size: {cfg.training.batch_size} x {cfg.training.gradient_accumulation_steps}
- Mixed Precision: {cfg.training.mixed_precision}
        """,
        eval_results=f"""
## 평가 결과
| 메트릭 | 값 |
|--------|-----|
| Accuracy | {eval_results.get('accuracy', 'N/A')} |
| F1 | {eval_results.get('f1', 'N/A')} |
| Perplexity | {eval_results.get('perplexity', 'N/A')} |
        """,
    )

    return str(card)
```

```python
# src/hub/upload.py
from huggingface_hub import HfApi, create_repo


def upload_model_to_hub(
    model_path: str,
    repo_id: str,
    model_card: str,
    private: bool = True,
):
    """모델을 Hugging Face Hub에 업로드"""
    api = HfApi()

    # 리포 생성
    create_repo(repo_id, private=private, exist_ok=True)

    # 모델 카드 저장
    with open(f"{model_path}/README.md", "w") as f:
        f.write(model_card)

    # 업로드
    api.upload_folder(
        folder_path=model_path,
        repo_id=repo_id,
        commit_message="Upload fine-tuned model",
    )
    print(f"업로드 완료: https://huggingface.co/{repo_id}")
```

### 2.6 벤치마크 평가

```python
# src/evaluation/benchmarks.py
from lm_eval import simple_evaluate
from lm_eval.models.huggingface import HFLM


def run_benchmarks(model_path: str, tasks: list[str]) -> dict:
    """lm-evaluation-harness로 벤치마크 평가"""
    model = HFLM(
        pretrained=model_path,
        dtype="bfloat16",
        batch_size="auto",
    )

    results = simple_evaluate(
        model=model,
        tasks=tasks,        # ["hellaswag", "arc_challenge", "mmlu", ...]
        num_fewshot=5,
        batch_size="auto",
    )

    # 결과 정리
    summary = {}
    for task, metrics in results["results"].items():
        summary[task] = {
            k: v for k, v in metrics.items()
            if isinstance(v, (int, float))
        }

    return summary


def run_korean_benchmarks(model_path: str) -> dict:
    """한국어 벤치마크 평가"""
    return run_benchmarks(model_path, tasks=[
        "kobest_boolq",
        "kobest_copa",
        "kobest_hellaswag",
        "kobest_sentineg",
        "kobest_wic",
    ])
```

## 3. 테스트/검증 전략

### 분산 학습 테스트

```python
# tests/integration/test_distributed.py
import subprocess
import pytest


@pytest.mark.gpu
@pytest.mark.slow
def test_accelerate_training_2gpu():
    result = subprocess.run(
        [
            "accelerate", "launch",
            "--num_processes=2",
            "--mixed_precision=bf16",
            "scripts/train.py",
            "training.epochs=1",
            "training.batch_size_per_device=2",
            "data=test_small",
        ],
        capture_output=True, text=True, timeout=600,
    )
    assert result.returncode == 0, f"학습 실패:\n{result.stderr}"
```

### 서빙 테스트

```python
# tests/e2e/test_serving.py
def test_vllm_generation():
    from vllm import LLM, SamplingParams

    llm = LLM(model="outputs/models/final", dtype="bfloat16")
    params = SamplingParams(max_tokens=100, temperature=0.7)

    outputs = llm.generate(["한국의 수도는"], params)
    text = outputs[0].outputs[0].text
    assert len(text) > 0
    assert "서울" in text
```

## 4. 성능 최적화

### 학습 처리량 최적화

```python
# Flash Attention 2
model = AutoModelForCausalLM.from_pretrained(
    model_name,
    attn_implementation="flash_attention_2",
    torch_dtype=torch.bfloat16,
)

# 그래디언트 체크포인팅 + LoRA
model.gradient_checkpointing_enable(
    gradient_checkpointing_kwargs={"use_reentrant": False}
)

# Packing (짧은 시퀀스를 하나로 합쳐 패딩 최소화)
from trl import SFTTrainer, DataCollatorForCompletionOnlyLM

trainer = SFTTrainer(
    model=model,
    args=training_args,
    train_dataset=dataset,
    packing=True,
    max_seq_length=2048,
)
```

### 서빙 최적화

```python
# vLLM PagedAttention으로 높은 처리량
# Continuous batching으로 latency 최적화
# Speculative decoding으로 생성 속도 향상

# TGI (Text Generation Inference) 사용
# docker run --gpus all \
#     -v /models:/models \
#     ghcr.io/huggingface/text-generation-inference:latest \
#     --model-id /models/my-model \
#     --quantize awq \
#     --max-batch-prefill-tokens 4096 \
#     --max-total-tokens 8192
```

## 5. 체크리스트

### 인프라
- [ ] GPU 클러스터 프로비저닝 (A100/H100)
- [ ] 고속 스토리지 (NVMe SSD)
- [ ] 네트워크 대역폭 확인 (InfiniBand)
- [ ] 모니터링 시스템 설정

### 학습
- [ ] Accelerate / DeepSpeed 설정 최적화
- [ ] Flash Attention 2 활성화
- [ ] 그래디언트 체크포인팅 적용
- [ ] 적절한 ZeRO 스테이지 선택 (2 vs 3)
- [ ] CPU offloading 필요 여부 확인
- [ ] 체크포인트 저장/복원 검증

### 모델 관리
- [ ] Model Hub 리포지토리 구성
- [ ] 모델 카드 자동 생성
- [ ] 버전 관리 전략
- [ ] LoRA 어댑터 관리 체계

### 서빙
- [ ] 양자화 (AWQ / GPTQ) 적용
- [ ] vLLM / TGI 배포
- [ ] 처리량 / 레이턴시 벤치마크
- [ ] 오토스케일링 설정

### 평가 및 안전
- [ ] 벤치마크 평가 (lm-evaluation-harness)
- [ ] 한국어 벤치마크 (KoBEST 등)
- [ ] 안전성 평가 (유해 콘텐츠, 편향)
- [ ] 레드팀 테스트
