# dbt 대규모 프로젝트 가이드

## 매칭 조건

- Multi-project (dbt Mesh)
- Custom materializations
- Data mesh 패턴
- 팀 규모 10명+ / 다수 팀
- 데이터 거버넌스, 데이터 카탈로그

## 1. 프로젝트 구조

### Multi-Project 구조 (dbt Mesh)

```
dbt-platform/
├── packages/                     # 공유 패키지
│   └── analytics-utils/
│       ├── dbt_project.yml
│       ├── macros/
│       │   ├── generic_tests/
│       │   │   ├── test_not_negative.sql
│       │   │   ├── test_freshness.sql
│       │   │   └── test_completeness.sql
│       │   ├── materializations/
│       │   │   └── incremental_merge.sql
│       │   └── utils/
│       │       ├── generate_surrogate_key.sql
│       │       ├── date_utils.sql
│       │       └── string_utils.sql
│       └── README.md
│
├── projects/
│   ├── core-data/                # 코어 데이터 프로젝트
│   │   ├── dbt_project.yml
│   │   ├── packages.yml
│   │   ├── models/
│   │   │   ├── staging/
│   │   │   │   ├── erp/
│   │   │   │   ├── crm/
│   │   │   │   └── payments/
│   │   │   ├── intermediate/
│   │   │   └── marts/
│   │   │       ├── core/         # 공개 모델 (다른 프로젝트에서 참조)
│   │   │       │   ├── dim_customers.sql
│   │   │       │   ├── dim_products.sql
│   │   │       │   └── fct_orders.sql
│   │   │       └── internal/     # 내부 전용
│   │   ├── tests/
│   │   └── macros/
│   │
│   ├── finance/                  # 재무 프로젝트
│   │   ├── dbt_project.yml
│   │   ├── packages.yml          # core-data 의존
│   │   ├── models/
│   │   │   ├── staging/
│   │   │   │   └── accounting/
│   │   │   ├── intermediate/
│   │   │   └── marts/
│   │   │       ├── fct_revenue.sql
│   │   │       ├── fct_costs.sql
│   │   │       └── rpt_pnl.sql
│   │   └── tests/
│   │
│   ├── marketing/                # 마케팅 프로젝트
│   │   ├── dbt_project.yml
│   │   ├── packages.yml          # core-data 의존
│   │   ├── models/
│   │   │   ├── staging/
│   │   │   │   ├── google_ads/
│   │   │   │   └── facebook_ads/
│   │   │   └── marts/
│   │   │       ├── fct_ad_performance.sql
│   │   │       └── rpt_roas.sql
│   │   └── tests/
│   │
│   └── data-science/             # 데이터 사이언스 프로젝트
│       ├── dbt_project.yml
│       ├── packages.yml
│       ├── models/
│       │   └── features/         # ML 피처 스토어
│       │       ├── customer_features.sql
│       │       └── product_features.sql
│       └── tests/
│
├── orchestration/
│   ├── dags/
│   │   ├── core_data_dag.py
│   │   ├── finance_dag.py
│   │   └── marketing_dag.py
│   └── dependencies.yml
│
├── governance/
│   ├── data_catalog.yml
│   ├── ownership.yml
│   ├── sla.yml
│   └── policies/
│       ├── pii_masking.yml
│       └── retention.yml
│
├── ci-cd/
│   ├── .github/workflows/
│   │   ├── core-data-ci.yml
│   │   ├── finance-ci.yml
│   │   └── deploy.yml
│   └── scripts/
│       ├── slim_ci.sh
│       └── deploy.sh
│
├── monitoring/
│   ├── dashboards/
│   │   ├── dbt_run_status.json
│   │   └── data_quality.json
│   └── alerts/
│       └── alert_config.yml
│
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 dbt Mesh (Cross-Project References)

```yaml
# projects/core-data/dbt_project.yml
name: core_data
version: "3.0.0"

models:
  core_data:
    marts:
      core:
        +materialized: table
        +access: public            # 다른 프로젝트에서 참조 가능
        +group: core-team
      internal:
        +access: private           # 내부 전용
```

```yaml
# projects/core-data/models/marts/core/_core__models.yml
version: 2

models:
  - name: dim_customers
    access: public                 # 공개 모델
    group: core-team
    description: "고객 디멘션 (통합 마스터)"
    config:
      contract:
        enforced: true             # 스키마 계약 강제
    columns:
      - name: customer_id
        data_type: varchar
        constraints:
          - type: not_null
          - type: primary_key
        data_tests:
          - unique
      - name: customer_name
        data_type: varchar
      - name: customer_segment
        data_type: varchar
        constraints:
          - type: not_null
```

```yaml
# projects/finance/packages.yml
packages:
  - package: dbt-labs/dbt_utils
    version: "1.1.1"
  # cross-project 참조
  - project: core_data
    version: [">=3.0.0", "<4.0.0"]
```

```sql
-- projects/finance/models/marts/fct_revenue.sql
-- 다른 프로젝트의 공개 모델 참조
with orders as (
    select * from {{ ref('core_data', 'fct_orders') }}  -- cross-project ref
),

accounting as (
    select * from {{ ref('stg_accounting__transactions') }}
),

revenue as (
    select
        o.order_date,
        o.category,
        o.country,
        sum(o.total_net_amount) as gross_revenue,
        sum(a.refund_amount) as total_refunds,
        sum(o.total_net_amount) - sum(coalesce(a.refund_amount, 0)) as net_revenue
    from orders o
    left join accounting a on o.order_id = a.order_id
    where o.order_status = 'completed'
    group by 1, 2, 3
)

select * from revenue
```

### 2.2 Custom Materialization

```sql
-- packages/analytics-utils/macros/materializations/incremental_merge.sql
{% materialization incremental_merge, adapter='bigquery' %}
    {# 커스텀 인크리멘탈 - merge 전략 최적화 #}

    {%- set target_relation = this -%}
    {%- set existing_relation = load_relation(this) -%}
    {%- set tmp_relation = make_temp_relation(this) -%}

    {% if existing_relation is none %}
        {# 첫 실행: 테이블 생성 #}
        {% set build_sql %}
            create table {{ target_relation }} as (
                {{ sql }}
            )
        {% endset %}
    {% else %}
        {# 인크리멘탈: 임시 테이블 + MERGE #}
        {% set build_sql %}
            create temp table {{ tmp_relation }} as (
                {{ sql }}
            );

            merge into {{ target_relation }} as target
            using {{ tmp_relation }} as source
            on {{ config.get('unique_key') | join(' and ') }}
            when matched then
                update set {{ get_merge_update_columns(config) }}
            when not matched then
                insert ({{ get_merge_insert_columns(config) }})
                values ({{ get_merge_insert_values(config) }})
            ;

            drop table {{ tmp_relation }};
        {% endset %}
    {% endif %}

    {% call statement('main') %}
        {{ build_sql }}
    {% endcall %}

    {{ return({'relations': [target_relation]}) }}
{% endmaterialization %}
```

### 2.3 데이터 메시 패턴

```yaml
# governance/ownership.yml
# 도메인별 데이터 소유권 정의
domains:
  - name: core
    owner: data-platform-team
    slack_channel: "#data-core"
    projects:
      - core-data
    sla:
      freshness: 4h
      quality_score: 0.99

  - name: finance
    owner: finance-analytics-team
    slack_channel: "#finance-data"
    projects:
      - finance
    sla:
      freshness: 12h
      quality_score: 0.995

  - name: marketing
    owner: marketing-analytics-team
    slack_channel: "#marketing-data"
    projects:
      - marketing
    sla:
      freshness: 6h
      quality_score: 0.98
```

```yaml
# governance/data_catalog.yml
# 데이터 카탈로그 메타데이터
catalog:
  - model: core_data.dim_customers
    domain: core
    classification: PII            # 개인정보 포함
    retention: 7years
    consumers:
      - finance
      - marketing
      - data-science
    pii_columns:
      - customer_name
      - email
      - phone
    masking_policy: hash           # PII 마스킹 정책

  - model: core_data.fct_orders
    domain: core
    classification: business_sensitive
    retention: 5years
    consumers:
      - finance
      - marketing
```

### 2.4 PII 마스킹 매크로

```sql
-- packages/analytics-utils/macros/utils/pii_masking.sql

{% macro mask_pii(column_name, masking_type='hash') %}
    {% if target.name == 'prod' %}
        {# 프로덕션: 원본 유지 #}
        {{ column_name }}
    {% elif masking_type == 'hash' %}
        {# 비프로덕션: 해시 마스킹 #}
        md5(cast({{ column_name }} as varchar))
    {% elif masking_type == 'redact' %}
        '***REDACTED***'
    {% elif masking_type == 'partial' %}
        concat(left({{ column_name }}, 2), '****')
    {% else %}
        {{ column_name }}
    {% endif %}
{% endmacro %}
```

```sql
-- 사용 예시
select
    customer_id,
    {{ mask_pii('customer_name', 'partial') }} as customer_name,
    {{ mask_pii('email', 'hash') }} as email,
    {{ mask_pii('phone', 'redact') }} as phone,
    customer_segment,
    city,
    country
from {{ ref('stg_crm__customers') }}
```

### 2.5 ML 피처 스토어 패턴

```sql
-- projects/data-science/models/features/customer_features.sql
{{ config(
    materialized='incremental',
    unique_key='customer_id',
    tags=['feature-store', 'ml'],
    meta={
        'owner': 'ml-team',
        'update_frequency': 'daily',
        'feature_group': 'customer',
    }
) }}

with orders as (
    select * from {{ ref('core_data', 'fct_orders') }}
    {% if is_incremental() %}
    where order_date > (select max(feature_date) from {{ this }})
    {% endif %}
),

customer_features as (
    select
        customer_id,
        current_date as feature_date,

        -- 구매 빈도 피처
        count(*) as total_orders_lifetime,
        count(case when order_date >= current_date - interval '30 days' then 1 end) as orders_last_30d,
        count(case when order_date >= current_date - interval '90 days' then 1 end) as orders_last_90d,

        -- 금액 피처
        sum(total_net_amount) as total_revenue_lifetime,
        avg(total_net_amount) as avg_order_value,
        max(total_net_amount) as max_order_value,
        sum(case when order_date >= current_date - interval '30 days'
            then total_net_amount else 0 end) as revenue_last_30d,

        -- 시간 피처
        min(order_date) as first_order_date,
        max(order_date) as last_order_date,
        current_date - max(order_date) as days_since_last_order,
        max(order_date) - min(order_date) as customer_tenure_days,

        -- 다양성 피처
        count(distinct category) as unique_categories,
        count(distinct order_channel) as unique_channels,

        -- 추세 피처
        {{ safe_divide(
            "sum(case when order_date >= current_date - interval '30 days' then total_net_amount else 0 end)",
            "nullif(sum(case when order_date between current_date - interval '60 days' and current_date - interval '30 days' then total_net_amount else 0 end), 0)"
        ) }} as revenue_trend_30d

    from orders
    group by customer_id
)

select * from customer_features
```

### 2.6 고급 테스트 스위트

```yaml
# projects/core-data/tests/data_quality_suite.yml
version: 2

models:
  - name: fct_orders
    data_tests:
      # 행 수 이상 감지 (전일 대비)
      - dbt_expectations.expect_table_row_count_to_equal_other_table_times_factor:
          compare_model: ref("fct_orders")
          compare_condition: "order_date = current_date - interval '1 day'"
          condition: "order_date = current_date"
          factor: 0.8  # 전일 대비 80% 이상

      # 컬럼 분포 안정성
      - dbt_expectations.expect_column_stdev_to_be_between:
          column_name: amount
          min_value: 10
          max_value: 10000

    columns:
      - name: order_id
        data_tests:
          - unique:
              severity: error
          - not_null:
              severity: error

      - name: total_net_amount
        data_tests:
          - not_negative:
              severity: error
          - dbt_expectations.expect_column_mean_to_be_between:
              min_value: 100
              max_value: 100000
```

### 2.7 오케스트레이션 (Airflow)

```python
# orchestration/dags/core_data_dag.py
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.sensors.external_task import ExternalTaskSensor


default_args = {
    "owner": "data-platform-team",
    "retries": 2,
    "retry_delay": timedelta(minutes=10),
}

with DAG(
    dag_id="dbt_core_data",
    default_args=default_args,
    schedule_interval="0 3 * * *",
    start_date=datetime(2024, 1, 1),
    catchup=False,
    tags=["dbt", "core"],
) as dag:

    source_freshness = BashOperator(
        task_id="source_freshness",
        bash_command="cd /projects/core-data && dbt source freshness --target prod",
    )

    staging = BashOperator(
        task_id="build_staging",
        bash_command="cd /projects/core-data && dbt build --select staging --target prod",
    )

    intermediate = BashOperator(
        task_id="build_intermediate",
        bash_command="cd /projects/core-data && dbt build --select intermediate --target prod",
    )

    marts = BashOperator(
        task_id="build_marts",
        bash_command="cd /projects/core-data && dbt build --select marts --target prod",
    )

    # 다운스트림 프로젝트 트리거
    notify_downstream = BashOperator(
        task_id="notify_downstream",
        bash_command="echo 'Core data build complete. Triggering downstream...'",
    )

    source_freshness >> staging >> intermediate >> marts >> notify_downstream
```

### 2.8 모니터링 및 알림

```python
# monitoring/dbt_run_monitor.py
"""dbt 실행 결과 모니터링"""
import json
from pathlib import Path


def parse_run_results(results_path: str) -> dict:
    """run_results.json 파싱"""
    with open(results_path) as f:
        data = json.load(f)

    summary = {
        "total": len(data["results"]),
        "success": sum(1 for r in data["results"] if r["status"] == "success"),
        "error": sum(1 for r in data["results"] if r["status"] == "error"),
        "skipped": sum(1 for r in data["results"] if r["status"] == "skipped"),
        "warn": sum(1 for r in data["results"] if r["status"] == "warn"),
        "total_time": sum(r["execution_time"] for r in data["results"]),
        "slowest_models": sorted(
            [{"name": r["unique_id"], "time": r["execution_time"]}
             for r in data["results"]],
            key=lambda x: x["time"],
            reverse=True,
        )[:10],
    }

    errors = [
        {"model": r["unique_id"], "message": r.get("message", "")}
        for r in data["results"]
        if r["status"] == "error"
    ]

    return {"summary": summary, "errors": errors}


def send_slack_alert(results: dict, webhook_url: str):
    """Slack 알림 전송"""
    import requests

    s = results["summary"]
    status = "SUCCESS" if s["error"] == 0 else "FAILURE"

    blocks = [
        {
            "type": "header",
            "text": {"type": "plain_text", "text": f"dbt Run: {status}"}
        },
        {
            "type": "section",
            "text": {
                "type": "mrkdwn",
                "text": (
                    f"*모델*: {s['success']}/{s['total']} 성공\n"
                    f"*에러*: {s['error']}\n"
                    f"*소요 시간*: {s['total_time']:.0f}초"
                ),
            },
        },
    ]

    if results["errors"]:
        error_text = "\n".join(
            f"- `{e['model']}`: {e['message'][:100]}"
            for e in results["errors"]
        )
        blocks.append({
            "type": "section",
            "text": {"type": "mrkdwn", "text": f"*에러 상세:*\n{error_text}"},
        })

    requests.post(webhook_url, json={"blocks": blocks})
```

## 3. 테스트/검증 전략

### Slim CI (변경분만 테스트)

```bash
#!/bin/bash
# ci-cd/scripts/slim_ci.sh

# 프로덕션 manifest 다운로드
aws s3 cp s3://dbt-artifacts/prod/manifest.json ./prod-manifest/manifest.json

# 변경된 모델 + 다운스트림만 빌드 및 테스트
dbt build \
    --select state:modified+ \
    --state ./prod-manifest/ \
    --target ci \
    --fail-fast

# 결과 업로드
aws s3 cp target/run_results.json s3://dbt-artifacts/ci/${GITHUB_SHA}/
```

### 데이터 계약 테스트

```yaml
# 스키마 계약 (dbt v1.5+)
models:
  - name: dim_customers
    config:
      contract:
        enforced: true     # 컬럼 추가/삭제/타입 변경 시 실패
    columns:
      - name: customer_id
        data_type: varchar(50)
        constraints:
          - type: not_null
          - type: primary_key
```

## 4. 성능 최적화

### 인크리멘탈 고급 전략

```sql
-- 파티션 기반 인크리멘탈 (BigQuery)
{{ config(
    materialized='incremental',
    unique_key='order_id',
    partition_by={
        "field": "order_date",
        "data_type": "date",
        "granularity": "day",
    },
    cluster_by=["customer_id", "category"],
    incremental_strategy='merge',
    incremental_predicates=[
        "DBT_INTERNAL_DEST.order_date >= date_sub(current_date(), interval 3 day)"
    ],
) }}
```

### 모델 실행 병렬화

```bash
# 스레드 수 최적화
dbt run --threads 16

# 태그별 병렬 실행
dbt run --select tag:priority_1 &
dbt run --select tag:priority_2 &
wait
```

### 쿼리 최적화

```sql
-- 서브쿼리 대신 CTE 사용 (가독성 + 일부 엔진 최적화)
-- 조기 필터링 (staging에서 불필요 행 제거)
-- 적절한 materialization (ephemeral -> view -> table -> incremental)
```

## 5. 체크리스트

### 아키텍처
- [ ] Multi-project 구조 설계 (dbt Mesh)
- [ ] 도메인별 프로젝트 분리
- [ ] 공유 패키지 구성 (매크로, 테스트)
- [ ] Cross-project reference 설정
- [ ] 데이터 계약 (model contracts) 정의

### 거버넌스
- [ ] 데이터 소유권 정의 (group, access)
- [ ] PII 마스킹 정책 구현
- [ ] 데이터 카탈로그 연동
- [ ] 데이터 보존 정책 적용
- [ ] 감사 로그 설정

### CI/CD
- [ ] Slim CI 구축 (state:modified)
- [ ] 프로젝트별 CI 파이프라인
- [ ] manifest 아티팩트 관리
- [ ] 프로덕션 배포 자동화
- [ ] 롤백 전략

### 모니터링
- [ ] dbt 실행 결과 추적
- [ ] 데이터 품질 대시보드
- [ ] SLA 모니터링
- [ ] 알림 설정 (Slack / PagerDuty)
- [ ] 느린 모델 추적 및 최적화

### 확장성
- [ ] 피처 스토어 패턴 구현
- [ ] 커스텀 materialization 개발
- [ ] 메타데이터 자동 수집
- [ ] 셀프서비스 분석 환경 구축
