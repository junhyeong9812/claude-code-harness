# 데이터 처리 스킬

> 데이터 정제/전처리/ETL 관련 작업 시 자동 활성화되는 가이드

---

## 매칭 조건

| 조건 | 감지 대상 |
|------|----------|
| **키워드** | "데이터", "정제", "전처리", "ETL", "파이프라인", "클렌징", "변환" |
| **의도** | 데이터 수집, 정제, 변환, 적재, 품질 검증 |
| **파일 경로** | `data/`, `etl/`, `pipelines/`, `scripts/`, `notebooks/` |
| **파일 내용** | `import pandas`, `from pyspark`, `dbt_project.yml` |

---

## 지원 기술 스택

| 스택 | 규모별 가이드 |
|------|-------------|
| Pandas | `pandas/small.md` · `pandas/medium.md` · `pandas/large.md` |
| PySpark | `pyspark/small.md` · `pyspark/medium.md` · `pyspark/large.md` |
| dbt | `dbt/small.md` · `dbt/medium.md` · `dbt/large.md` |

---

## 규모별 분류 기준

| 기준 | Small | Medium | Large |
|------|-------|--------|-------|
| **데이터 크기** | 수 MB ~ 수 GB | 수 GB ~ 수백 GB | 수백 GB ~ PB |
| **처리 빈도** | 일회성 / 비정기 | 일별/주별 정기 배치 | 실시간 / 대규모 배치 |
| **팀 규모** | 1~2명 | 3~10명 | 10명+ / 다수 팀 |
| **인프라** | 로컬 / 노트북 | 서버 / 소규모 클러스터 | 대규모 클러스터 / 클라우드 |
| **복잡도** | 단순 변환/집계 | 다단계 파이프라인 | 데이터 플랫폼 수준 |

### 규모 판단 키워드

- **Small**: 스크립트, 노트북, 일회성, 분석, 탐색, CSV, Excel
- **Medium**: ETL, 파이프라인, 스케줄링, 데이터 품질, validation, cron
- **Large**: 데이터 플랫폼, 스트리밍, 데이터 메시, 거버넌스, Delta Lake, Airflow

---

## 도구 선택 가이드

```
데이터 크기가 메모리에 적재 가능한가?
├── Yes → Pandas (또는 Polars)
└── No
    ├── SQL 기반 변환이 주인가?
    │   ├── Yes → dbt
    │   └── No → PySpark
    └── 실시간 처리가 필요한가?
        ├── Yes → PySpark Structured Streaming / Flink
        └── No → PySpark Batch
```

---

## 공통 체크 항목

### 리서치 단계
- [ ] 원본 데이터 구조 파악 (스키마, 타입, 크기)
- [ ] 데이터 품질 현황 (결측치, 이상치, 중복)
- [ ] 기존 파이프라인 구조 확인
- [ ] 데이터 소스 / 싱크 확인
- [ ] 처리 규모 파악 (메모리 내 가능 vs 분산 필요)

### 구현 단계
- [ ] 멱등성 보장 (재실행 시 동일 결과)
- [ ] 데이터 검증 단계 포함
- [ ] 원본 데이터 보존 (비파괴 처리)
- [ ] 처리 로그 및 통계 기록
- [ ] 대용량 대비 청크/배치 처리

### 셀프체크
- [ ] 결측치 처리 전략이 명확한가?
- [ ] 데이터 타입 변환이 올바른가?
- [ ] 중복 제거 기준이 적절한가?
- [ ] 처리 전후 데이터 건수가 예상과 맞는가?
- [ ] 메모리 사용량은 적절한가?

### 공통 데이터 검증 패턴

```python
from dataclasses import dataclass
from typing import Any


@dataclass
class ValidationResult:
    is_valid: bool
    check_name: str
    details: dict[str, Any] | None = None
    error_message: str | None = None


def check_not_null(df, column: str) -> ValidationResult:
    null_count = df[column].isnull().sum()
    return ValidationResult(
        is_valid=null_count == 0,
        check_name=f"not_null_{column}",
        details={"null_count": int(null_count), "total_rows": len(df)},
        error_message=f"{column}에 {null_count}개의 null 값 발견" if null_count > 0 else None,
    )


def check_unique(df, column: str) -> ValidationResult:
    dup_count = df[column].duplicated().sum()
    return ValidationResult(
        is_valid=dup_count == 0,
        check_name=f"unique_{column}",
        details={"duplicate_count": int(dup_count)},
        error_message=f"{column}에 {dup_count}개의 중복 값 발견" if dup_count > 0 else None,
    )
```

### 공통 프로젝트 구조

```
data-project/
├── configs/              # 환경별 설정
├── src/
│   ├── extractors/      # 데이터 추출
│   ├── transformers/    # 데이터 변환
│   ├── loaders/         # 데이터 적재
│   ├── validators/      # 데이터 검증
│   └── utils/           # 유틸리티
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── notebooks/           # 탐색용 노트북
├── dags/                # 오케스트레이션
├── Dockerfile
├── pyproject.toml
└── README.md
```
