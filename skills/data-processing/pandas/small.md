# Pandas 소규모 프로젝트 가이드

## 매칭 조건

- 일회성 분석 / 스크립트 기반 처리
- 데이터: 수 MB ~ 수 GB (메모리 적재 가능)
- CSV, Excel, JSON 파일 처리
- 노트북 기반 탐색/분석
- 팀 규모: 1~2명

## 1. 프로젝트 구조

```
pandas-small/
├── notebooks/
│   ├── 01_eda.ipynb              # 탐색적 데이터 분석
│   ├── 02_cleaning.ipynb         # 데이터 정제
│   └── 03_analysis.ipynb         # 분석 및 리포트
├── data/
│   ├── raw/                      # 원본 데이터 (읽기 전용)
│   │   ├── sales_2024.csv
│   │   └── customers.xlsx
│   └── processed/                # 처리된 데이터
│       └── cleaned_sales.csv
├── src/
│   ├── __init__.py
│   ├── cleaning.py               # 정제 함수
│   └── analysis.py               # 분석 함수
├── outputs/
│   ├── figures/                  # 시각화 결과
│   └── reports/                  # 분석 리포트
├── requirements.txt
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 데이터 로딩

```python
import pandas as pd
import numpy as np

# CSV 로딩 (기본)
df = pd.read_csv("data/raw/sales_2024.csv")

# CSV 로딩 (옵션 지정)
df = pd.read_csv(
    "data/raw/sales_2024.csv",
    encoding="utf-8",           # 또는 "cp949" (한글 인코딩)
    parse_dates=["order_date"],  # 날짜 컬럼 자동 파싱
    dtype={"product_id": str},   # 타입 지정
    usecols=["order_id", "product_id", "amount", "order_date"],  # 필요한 컬럼만
)

# Excel 로딩
df = pd.read_excel(
    "data/raw/customers.xlsx",
    sheet_name="Sheet1",        # 또는 인덱스 0
    header=0,                    # 헤더 행
    skiprows=1,                  # 건너뛸 행
)

# 여러 파일 합치기
from pathlib import Path

files = Path("data/raw/").glob("sales_*.csv")
df = pd.concat([pd.read_csv(f) for f in files], ignore_index=True)
```

### 2.2 EDA (탐색적 데이터 분석)

```python
def eda_report(df: pd.DataFrame) -> None:
    """기본 EDA 리포트 출력"""
    print("=" * 60)
    print(f"데이터 크기: {df.shape[0]:,} 행 x {df.shape[1]} 열")
    print(f"메모리 사용량: {df.memory_usage(deep=True).sum() / 1e6:.1f} MB")
    print("=" * 60)

    print("\n--- 컬럼 정보 ---")
    print(df.dtypes)

    print("\n--- 결측치 ---")
    missing = df.isnull().sum()
    missing_pct = (missing / len(df) * 100).round(1)
    missing_info = pd.DataFrame({"결측 수": missing, "비율(%)": missing_pct})
    print(missing_info[missing_info["결측 수"] > 0])

    print("\n--- 수치형 컬럼 통계 ---")
    print(df.describe().round(2))

    print("\n--- 범주형 컬럼 유니크 값 ---")
    for col in df.select_dtypes(include=["object", "category"]).columns:
        n_unique = df[col].nunique()
        top_values = df[col].value_counts().head(5)
        print(f"\n{col} (유니크: {n_unique})")
        print(top_values)

    print("\n--- 중복 행 ---")
    dup_count = df.duplicated().sum()
    print(f"중복 행: {dup_count:,} ({dup_count / len(df) * 100:.1f}%)")


eda_report(df)
```

### 2.3 데이터 정제

```python
# src/cleaning.py
import pandas as pd
import numpy as np


def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """데이터프레임 정제 파이프라인"""
    df = df.copy()

    # 1. 컬럼명 정리 (소문자, 공백 -> 밑줄)
    df.columns = (
        df.columns
        .str.strip()
        .str.lower()
        .str.replace(r"\s+", "_", regex=True)
        .str.replace(r"[^\w]", "", regex=True)
    )

    # 2. 중복 제거
    before = len(df)
    df = df.drop_duplicates()
    print(f"중복 제거: {before - len(df):,}건")

    # 3. 결측치 처리
    df = handle_missing(df)

    # 4. 타입 변환
    df = convert_types(df)

    # 5. 이상치 처리
    df = handle_outliers(df, numeric_cols=["amount", "quantity"])

    return df


def handle_missing(df: pd.DataFrame) -> pd.DataFrame:
    """결측치 처리"""
    df = df.copy()

    # 수치형: 중앙값으로 대체
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    for col in numeric_cols:
        if df[col].isnull().any():
            median_val = df[col].median()
            df[col] = df[col].fillna(median_val)
            print(f"  {col}: 중앙값({median_val})으로 대체")

    # 범주형: 최빈값 또는 'unknown'
    cat_cols = df.select_dtypes(include=["object"]).columns
    for col in cat_cols:
        if df[col].isnull().any():
            df[col] = df[col].fillna("unknown")
            print(f"  {col}: 'unknown'으로 대체")

    return df


def handle_outliers(
    df: pd.DataFrame,
    numeric_cols: list[str],
    method: str = "iqr",
    factor: float = 1.5,
) -> pd.DataFrame:
    """이상치 처리 (IQR 방식)"""
    df = df.copy()

    for col in numeric_cols:
        if col not in df.columns:
            continue

        q1 = df[col].quantile(0.25)
        q3 = df[col].quantile(0.75)
        iqr = q3 - q1
        lower = q1 - factor * iqr
        upper = q3 + factor * iqr

        outliers = (df[col] < lower) | (df[col] > upper)
        n_outliers = outliers.sum()

        if n_outliers > 0:
            df.loc[outliers, col] = df[col].clip(lower=lower, upper=upper)
            print(f"  {col}: {n_outliers:,}건 이상치 클리핑 ({lower:.2f} ~ {upper:.2f})")

    return df


def convert_types(df: pd.DataFrame) -> pd.DataFrame:
    """최적 타입 변환"""
    df = df.copy()

    # 메모리 최적화
    for col in df.select_dtypes(include=["int64"]).columns:
        df[col] = pd.to_numeric(df[col], downcast="integer")

    for col in df.select_dtypes(include=["float64"]).columns:
        df[col] = pd.to_numeric(df[col], downcast="float")

    # 낮은 카디널리티 문자열 -> category
    for col in df.select_dtypes(include=["object"]).columns:
        if df[col].nunique() / len(df) < 0.1:
            df[col] = df[col].astype("category")

    return df
```

### 2.4 데이터 분석

```python
# src/analysis.py
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib
matplotlib.rcParams["font.family"] = "NanumGothic"  # 한글 폰트


def sales_analysis(df: pd.DataFrame) -> dict:
    """매출 분석 예시"""
    results = {}

    # 월별 매출 추이
    monthly = (
        df.set_index("order_date")
        .resample("M")["amount"]
        .agg(["sum", "count", "mean"])
        .rename(columns={"sum": "총매출", "count": "주문수", "mean": "평균단가"})
    )
    results["monthly"] = monthly

    # 카테고리별 매출
    by_category = (
        df.groupby("category")["amount"]
        .agg(["sum", "mean", "count"])
        .sort_values("sum", ascending=False)
    )
    results["by_category"] = by_category

    # 고객별 RFM 분석
    rfm = df.groupby("customer_id").agg(
        recency=("order_date", lambda x: (pd.Timestamp.now() - x.max()).days),
        frequency=("order_id", "nunique"),
        monetary=("amount", "sum"),
    )
    results["rfm"] = rfm

    return results


def plot_monthly_sales(monthly: pd.DataFrame, save_path: str = None):
    """월별 매출 시각화"""
    fig, ax1 = plt.subplots(figsize=(12, 5))

    ax1.bar(monthly.index, monthly["총매출"], alpha=0.7, label="총매출")
    ax1.set_ylabel("총매출")
    ax1.set_xlabel("월")

    ax2 = ax1.twinx()
    ax2.plot(monthly.index, monthly["주문수"], color="red", marker="o", label="주문수")
    ax2.set_ylabel("주문수")

    fig.legend(loc="upper left", bbox_to_anchor=(0.1, 0.95))
    plt.title("월별 매출 추이")
    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=150)
    plt.show()
```

### 2.5 결과 저장

```python
# CSV 저장
df.to_csv("data/processed/cleaned_sales.csv", index=False, encoding="utf-8-sig")

# Excel 저장 (여러 시트)
with pd.ExcelWriter("outputs/reports/analysis.xlsx", engine="openpyxl") as writer:
    monthly.to_excel(writer, sheet_name="월별매출")
    by_category.to_excel(writer, sheet_name="카테고리별")
    rfm.to_excel(writer, sheet_name="RFM분석")

# Parquet (분석 재사용 시 추천)
df.to_parquet("data/processed/cleaned_sales.parquet")
```

## 3. 테스트/검증 전략

### 데이터 검증

```python
def validate_cleaned_data(df: pd.DataFrame) -> None:
    """정제된 데이터 검증"""
    # 결측치 없음 확인
    assert df.isnull().sum().sum() == 0, "결측치 존재"

    # 중복 없음 확인
    assert df.duplicated().sum() == 0, "중복 행 존재"

    # 필수 컬럼 존재
    required = ["order_id", "customer_id", "amount", "order_date"]
    missing_cols = set(required) - set(df.columns)
    assert not missing_cols, f"누락 컬럼: {missing_cols}"

    # 값 범위 확인
    assert (df["amount"] >= 0).all(), "음수 금액 존재"
    assert df["order_date"].min() >= pd.Timestamp("2020-01-01"), "비정상 날짜"

    # 건수 확인
    print(f"검증 통과: {len(df):,}건")


validate_cleaned_data(df)
```

### 전후 비교

```python
def compare_before_after(original: pd.DataFrame, cleaned: pd.DataFrame):
    """정제 전후 비교"""
    print(f"행 수: {len(original):,} -> {len(cleaned):,} "
          f"(차이: {len(original) - len(cleaned):,})")
    print(f"열 수: {original.shape[1]} -> {cleaned.shape[1]}")
    print(f"메모리: {original.memory_usage(deep=True).sum()/1e6:.1f} MB -> "
          f"{cleaned.memory_usage(deep=True).sum()/1e6:.1f} MB")

    for col in cleaned.select_dtypes(include=[np.number]).columns:
        if col in original.columns:
            print(f"  {col}: mean {original[col].mean():.2f} -> {cleaned[col].mean():.2f}")
```

## 4. 성능 최적화

### 메모리 절약

```python
# 타입 최적화로 메모리 절약
def optimize_dtypes(df: pd.DataFrame) -> pd.DataFrame:
    for col in df.select_dtypes(include=["int"]).columns:
        df[col] = pd.to_numeric(df[col], downcast="integer")
    for col in df.select_dtypes(include=["float"]).columns:
        df[col] = pd.to_numeric(df[col], downcast="float")
    for col in df.select_dtypes(include=["object"]).columns:
        if df[col].nunique() / len(df) < 0.5:
            df[col] = df[col].astype("category")
    return df
```

### 처리 속도

```python
# vectorized 연산 사용 (apply 대신)
# 나쁜 예
df["category"] = df["amount"].apply(lambda x: "high" if x > 1000 else "low")

# 좋은 예
df["category"] = np.where(df["amount"] > 1000, "high", "low")

# 여러 조건
conditions = [
    df["amount"] > 10000,
    df["amount"] > 1000,
]
choices = ["high", "medium"]
df["category"] = np.select(conditions, choices, default="low")
```

## 5. 체크리스트

### 시작 시
- [ ] 원본 데이터 백업 (raw/ 디렉토리)
- [ ] 인코딩 확인 (UTF-8 / CP949)
- [ ] EDA 수행 (shape, dtypes, 결측치, 분포)
- [ ] 메모리 사용량 확인

### 정제 시
- [ ] 컬럼명 정리
- [ ] 결측치 처리 전략 결정 및 적용
- [ ] 중복 제거
- [ ] 타입 변환
- [ ] 이상치 처리

### 완료 시
- [ ] 정제 전후 데이터 비교
- [ ] 검증 함수 실행
- [ ] 결과 저장 (CSV/Parquet)
- [ ] 노트북 재실행하여 재현 확인
