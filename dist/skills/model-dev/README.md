# 모델 개발 스킬

> ML/DL 모델 개발 관련 작업 시 자동 활성화되는 가이드

---

## 매칭 조건

| 조건 | 감지 대상 |
|------|----------|
| **키워드** | "모델", "학습", "훈련", "추론", "파인튜닝", "전처리", "피처" |
| **의도** | 모델 구현, 학습 파이프라인 구축, 추론 서빙, 실험 관리 |
| **파일 경로** | `models/`, `training/`, `experiments/`, `notebooks/` |
| **파일 내용** | `import torch`, `import tensorflow`, `from transformers` |

---

## 지원 기술 스택

| 스택 | 규모별 가이드 |
|------|-------------|
| PyTorch | `pytorch/small.md` · `pytorch/medium.md` · `pytorch/large.md` |
| TensorFlow | `tensorflow/small.md` · `tensorflow/medium.md` · `tensorflow/large.md` |
| HuggingFace | `huggingface/small.md` · `huggingface/medium.md` · `huggingface/large.md` |

---

## 규모별 분류 기준

| 기준 | Small | Medium | Large |
|------|-------|--------|-------|
| **팀 규모** | 1~2명 | 3~10명 | 10명+ / 다수 팀 |
| **데이터** | 수 MB ~ 수 GB | 수 GB ~ 수백 GB | 수백 GB ~ TB+ |
| **학습 시간** | 수 분 ~ 수 시간 | 수 시간 ~ 수 일 | 수 일 ~ 수 주 |
| **GPU** | 단일 GPU / CPU | 단일 노드 멀티 GPU | 멀티 노드 분산 |
| **배포** | 없거나 간단한 API | 스테이징/프로덕션 존재 | 완전 자동화 MLOps |
| **실험 관리** | 수동 / 노트북 | MLflow / W&B | 자동화된 파이프라인 |

### 규모 판단 키워드

- **Small**: 노트북, 프로토타입, 실험, 학습용, PoC, 데모, 개인
- **Medium**: 팀 프로젝트, 설정 관리, CI/CD, 실험 추적, Hydra, MLflow
- **Large**: 분산 학습, DDP, FSDP, MLOps, A/B 테스트, 모델 레지스트리, Kubeflow, Vertex AI

---

## 공통 체크 항목

### 리서치 단계
- [ ] 기존 모델 아키텍처 파악
- [ ] 데이터셋 구조 및 전처리 파이프라인 확인
- [ ] 학습 설정 (하이퍼파라미터, 옵티마이저) 확인
- [ ] 실험 추적 방식 확인 (MLflow / W&B 등)
- [ ] GPU/리소스 환경 확인

### 구현 단계
- [ ] 재현 가능성 확보 (시드 고정, 환경 기록)
- [ ] 메모리 효율 고려 (배치 사이즈, gradient accumulation)
- [ ] 체크포인트 저장/로드 구현
- [ ] 로깅 (loss, metrics, 하이퍼파라미터)
- [ ] 실험 설정 파일 분리 (config)

### 셀프체크
- [ ] 데이터 누수(leakage)는 없는가?
- [ ] train/val/test 분리가 올바른가?
- [ ] 메모리 사용량은 적절한가?
- [ ] 실험 재현이 가능한 상태인가?
- [ ] 모델 저장 형식이 서빙에 적합한가?

### 공통 시드 고정 코드

```python
import os
import random
import numpy as np


def set_seed(seed: int = 42) -> None:
    """모든 랜덤 시드를 고정합니다."""
    random.seed(seed)
    os.environ["PYTHONHASHSEED"] = str(seed)
    np.random.seed(seed)

    try:
        import torch
        torch.manual_seed(seed)
        torch.cuda.manual_seed_all(seed)
        torch.backends.cudnn.deterministic = True
        torch.backends.cudnn.benchmark = False
    except ImportError:
        pass

    try:
        import tensorflow as tf
        tf.random.set_seed(seed)
    except ImportError:
        pass
```

### 공통 프로젝트 구조

```
project-root/
├── configs/              # 하이퍼파라미터, 실험 설정
├── data/
│   ├── raw/             # 원본 데이터 (읽기 전용)
│   ├── processed/       # 전처리된 데이터
│   └── external/        # 외부 데이터
├── src/
│   ├── data/            # 데이터 로딩/전처리
│   ├── models/          # 모델 정의
│   ├── training/        # 학습 로직
│   └── evaluation/      # 평가 로직
├── notebooks/           # 탐색/분석용 노트북
├── tests/               # 테스트 코드
├── outputs/             # 학습 결과 (모델, 로그)
├── Dockerfile
├── pyproject.toml
└── README.md
```
