# dbt 중규모 프로젝트 가이드

## 매칭 조건

- staging / intermediate / marts 레이어 구분
- 매크로 활용, CI 파이프라인
- 데이터 품질 테스트 체계화
- 팀 규모: 3~10명
- 다수 소스, 다수 모델

## 1. 프로젝트 구조

```
dbt-medium/
├── dbt_project.yml
├── packages.yml                  # 패키지 의존성
├── models/
│   ├── staging/                  # 소스별 스테이징
│   │   ├── erp/
│   │   │   ├── _erp__sources.yml
│   │   │   ├── _erp__models.yml
│   │   │   ├── stg_erp__orders.sql
│   │   │   └── stg_erp__products.sql
│   │   ├── crm/
│   │   │   ├── _crm__sources.yml
│   │   │   ├── _crm__models.yml
│   │   │   ├── stg_crm__customers.sql
│   │   │   └── stg_crm__contacts.sql
│   │   └── web/
│   │       ├── _web__sources.yml
│   │       ├── _web__models.yml
│   │       └── stg_web__events.sql
│   ├── intermediate/            # 중간 변환 레이어
│   │   ├── _int__models.yml
│   │   ├── int_orders_enriched.sql
│   │   ├── int_customer_orders.sql
│   │   └── int_daily_revenue.sql
│   └── marts/                   # 비즈니스 마트
│       ├── core/
│       │   ├── _core__models.yml
│       │   ├── dim_customers.sql
│       │   ├── dim_products.sql
│       │   └── fct_orders.sql
│       ├── finance/
│       │   ├── _finance__models.yml
│       │   ├── fct_revenue.sql
│       │   └── rpt_monthly_revenue.sql
│       └── marketing/
│           ├── _marketing__models.yml
│           ├── dim_campaigns.sql
│           └── fct_campaign_performance.sql
├── seeds/
│   ├── country_codes.csv
│   └── category_mapping.csv
├── snapshots/
│   └── scd_customers.sql
├── macros/
│   ├── generate_schema_name.sql  # 스키마 네이밍 오버라이드
│   ├── utils/
│   │   ├── date_utils.sql
│   │   ├── string_utils.sql
│   │   └── test_utils.sql
│   └── materializations/
├── tests/
│   ├── generic/
│   │   ├── test_not_negative.sql
│   │   └── test_valid_email.sql
│   └── singular/
│       ├── assert_revenue_positive.sql
│       └── assert_no_orphan_orders.sql
├── analyses/
│   └── monthly_kpi.sql
├── .github/
│   └── workflows/
│       ├── ci.yml                # PR 시 테스트
│       └── deploy.yml            # 프로덕션 배포
├── profiles/
│   ├── dev.yml
│   └── prod.yml
├── Makefile
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 프로젝트 설정

```yaml
# dbt_project.yml
name: analytics
version: "2.0.0"
config-version: 2
profile: analytics

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

# 레이어별 설정
models:
  analytics:
    staging:
      +materialized: view
      +schema: staging
      +tags: ["staging"]
    intermediate:
      +materialized: ephemeral
      +tags: ["intermediate"]
    marts:
      +materialized: table
      core:
        +schema: core
      finance:
        +schema: finance
        +tags: ["finance"]
      marketing:
        +schema: marketing
        +tags: ["marketing"]

# 시드 설정
seeds:
  analytics:
    +schema: seeds

# 테스트 설정
tests:
  analytics:
    +severity: warn  # 기본 경고, 중요한 것은 error로 오버라이드

# 변수
vars:
  start_date: "2023-01-01"
  currency: "KRW"
```

```yaml
# packages.yml
packages:
  - package: dbt-labs/dbt_utils
    version: "1.1.1"
  - package: calogica/dbt_expectations
    version: "0.10.1"
  - package: dbt-labs/codegen
    version: "0.12.1"
```

### 2.2 스테이징 레이어 (소스별 정리)

```yaml
# models/staging/erp/_erp__sources.yml
version: 2

sources:
  - name: erp
    description: "ERP 시스템 (주문, 상품)"
    database: "{{ env_var('DBT_DATABASE', 'production') }}"
    schema: erp_raw
    freshness:
      warn_after: { count: 12, period: hour }
      error_after: { count: 24, period: hour }
    loaded_at_field: _etl_loaded_at
    tables:
      - name: orders
        description: "주문 원본 테이블"
        columns:
          - name: id
            data_tests:
              - unique
              - not_null
      - name: products
        description: "상품 원본 테이블"
```

```sql
-- models/staging/erp/stg_erp__orders.sql
-- 스테이징: ERP 주문 데이터 정제

with source as (
    select * from {{ source('erp', 'orders') }}
),

renamed as (
    select
        -- 키
        cast(id as varchar) as order_id,
        cast(customer_id as varchar) as customer_id,
        cast(product_id as varchar) as product_id,

        -- 측정값
        cast(amount as numeric(12, 2)) as amount,
        cast(quantity as integer) as quantity,
        cast(discount_rate as numeric(5, 4)) as discount_rate,

        -- 차원
        lower(trim(status)) as order_status,
        lower(trim(channel)) as order_channel,

        -- 날짜
        cast(ordered_at as timestamp) as ordered_at,
        cast(shipped_at as timestamp) as shipped_at,
        cast(delivered_at as timestamp) as delivered_at,

        -- 메타
        _etl_loaded_at

    from source
    where id is not null
)

select * from renamed
```

### 2.3 중간 레이어

```sql
-- models/intermediate/int_orders_enriched.sql
-- 주문에 고객/상품 정보 결합

with orders as (
    select * from {{ ref('stg_erp__orders') }}
),

customers as (
    select * from {{ ref('stg_crm__customers') }}
),

products as (
    select * from {{ ref('stg_erp__products') }}
),

enriched as (
    select
        o.order_id,
        o.customer_id,
        o.product_id,
        o.amount,
        o.quantity,
        o.discount_rate,
        o.amount * (1 - o.discount_rate) as net_amount,
        o.amount * o.quantity * (1 - o.discount_rate) as total_net_amount,
        o.order_status,
        o.order_channel,
        o.ordered_at,
        o.shipped_at,
        o.delivered_at,

        -- 고객 정보
        c.customer_name,
        c.customer_segment,
        c.city,
        c.country,

        -- 상품 정보
        p.product_name,
        p.category,
        p.subcategory,
        p.unit_cost,

        -- 마진
        o.amount * (1 - o.discount_rate) - p.unit_cost * o.quantity as gross_margin

    from orders o
    left join customers c on o.customer_id = c.customer_id
    left join products p on o.product_id = p.product_id
)

select * from enriched
```

### 2.4 마트 레이어

```sql
-- models/marts/core/fct_orders.sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    on_schema_change='append_new_columns',
) }}

with enriched_orders as (
    select * from {{ ref('int_orders_enriched') }}
    {% if is_incremental() %}
    where ordered_at > (select max(ordered_at) from {{ this }})
    {% endif %}
),

final as (
    select
        -- 키
        order_id,
        customer_id,
        product_id,

        -- 측정값
        amount,
        quantity,
        net_amount,
        total_net_amount,
        gross_margin,

        -- 차원
        order_status,
        order_channel,
        customer_segment,
        category,
        subcategory,
        city,
        country,

        -- 날짜
        ordered_at,
        shipped_at,
        delivered_at,
        {{ dbt_utils.date_trunc('day', 'ordered_at') }} as order_date,
        {{ dbt_utils.date_trunc('month', 'ordered_at') }} as order_month,

        -- 배송 리드타임
        {{ dbt.datediff('ordered_at', 'shipped_at', 'day') }} as days_to_ship,
        {{ dbt.datediff('ordered_at', 'delivered_at', 'day') }} as days_to_deliver

    from enriched_orders
)

select * from final
```

```sql
-- models/marts/finance/rpt_monthly_revenue.sql
{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('fct_orders') }}
    where order_status != 'cancelled'
),

monthly as (
    select
        order_month,
        category,
        country,
        count(distinct order_id) as order_count,
        count(distinct customer_id) as unique_customers,
        sum(total_net_amount) as total_revenue,
        sum(gross_margin) as total_margin,
        {{ safe_divide('sum(gross_margin)', 'sum(total_net_amount)') }} as margin_rate,
        avg(total_net_amount) as avg_order_value
    from orders
    group by 1, 2, 3
)

select * from monthly
```

### 2.5 고급 매크로

```sql
-- macros/generate_schema_name.sql
-- 환경별 스키마 네이밍 커스터마이징
{% macro generate_schema_name(custom_schema_name, node) %}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name }}
    {%- endif -%}
{% endmacro %}
```

```sql
-- macros/utils/date_utils.sql

{% macro fiscal_quarter(date_column) %}
    case
        when extract(month from {{ date_column }}) between 1 and 3 then 'Q4'
        when extract(month from {{ date_column }}) between 4 and 6 then 'Q1'
        when extract(month from {{ date_column }}) between 7 and 9 then 'Q2'
        when extract(month from {{ date_column }}) between 10 and 12 then 'Q3'
    end
{% endmacro %}

{% macro date_range_filter(column, start_var='start_date', end_var=none) %}
    {{ column }} >= '{{ var(start_var) }}'
    {% if end_var is not none %}
        and {{ column }} <= '{{ var(end_var) }}'
    {% endif %}
{% endmacro %}

{% macro safe_divide(numerator, denominator) %}
    case
        when {{ denominator }} = 0 or {{ denominator }} is null then null
        else cast({{ numerator }} as numeric) / cast({{ denominator }} as numeric)
    end
{% endmacro %}
```

### 2.6 제네릭 테스트

```sql
-- tests/generic/test_not_negative.sql
{% test not_negative(model, column_name) %}

select
    {{ column_name }}
from {{ model }}
where {{ column_name }} < 0

{% endtest %}
```

```sql
-- tests/generic/test_valid_email.sql
{% test valid_email(model, column_name) %}

select
    {{ column_name }}
from {{ model }}
where {{ column_name }} is not null
  and {{ column_name }} not like '%@%.%'

{% endtest %}
```

```yaml
# 제네릭 테스트 적용
# models/staging/crm/_crm__models.yml
version: 2

models:
  - name: stg_crm__customers
    columns:
      - name: email
        data_tests:
          - valid_email
      - name: customer_id
        data_tests:
          - unique
          - not_null
```

### 2.7 dbt_expectations 활용

```yaml
# models/marts/core/_core__models.yml
version: 2

models:
  - name: fct_orders
    data_tests:
      # 행 수 범위 확인
      - dbt_expectations.expect_table_row_count_to_be_between:
          min_value: 1000
          max_value: 10000000

    columns:
      - name: amount
        data_tests:
          # 값 범위 확인
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 100000000
          # 결측치 비율 확인
          - dbt_expectations.expect_column_values_to_not_be_null:
              row_condition: "order_status = 'completed'"

      - name: order_date
        data_tests:
          # 미래 날짜 방지
          - dbt_expectations.expect_column_values_to_be_between:
              max_value: "{{ dbt.dateadd('day', 1, dbt.current_timestamp()) }}"
```

### 2.8 CI/CD 파이프라인

```yaml
# .github/workflows/ci.yml
name: dbt CI

on:
  pull_request:
    branches: [main]

jobs:
  dbt-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.11"

      - name: Install dependencies
        run: |
          pip install dbt-core dbt-postgres
          dbt deps

      - name: dbt build (변경된 모델만)
        run: |
          dbt build --select state:modified+ --state ./prod-manifest/
        env:
          DBT_DATABASE: ${{ secrets.DBT_CI_DATABASE }}
          DBT_USER: ${{ secrets.DBT_CI_USER }}
          DBT_PASSWORD: ${{ secrets.DBT_CI_PASSWORD }}

      - name: dbt source freshness
        run: dbt source freshness
```

### 2.9 Makefile

```makefile
.PHONY: deps run test docs fresh

deps:
	dbt deps

run:
	dbt run

run-staging:
	dbt run --select staging

run-marts:
	dbt run --select marts

test:
	dbt test

docs:
	dbt docs generate && dbt docs serve

fresh:
	dbt source freshness

build:
	dbt build  # run + test

ci:
	dbt build --select state:modified+ --state ./prod-manifest/

full-refresh:
	dbt run --full-refresh --select tag:incremental
```

## 3. 테스트/검증 전략

### 테스트 계층

```
1단계: 소스 테스트 (sources.yml)
  - unique, not_null 기본 제약
  - freshness 체크

2단계: 스테이징 테스트 (schema.yml)
  - 타입 검증, 값 범위, accepted_values

3단계: 마트 테스트
  - 비즈니스 규칙 (singular tests)
  - dbt_expectations로 고급 검증

4단계: CI 테스트
  - 변경된 모델만 빌드+테스트
  - 회귀 테스트
```

### 참조 무결성 테스트

```yaml
columns:
  - name: customer_id
    data_tests:
      - relationships:
          to: ref('dim_customers')
          field: customer_id
          severity: warn  # 또는 error
```

## 4. 성능 최적화

### 인크리멘탈 모델 최적화

```sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
    incremental_strategy='merge',  -- 또는 'delete+insert'
    cluster_by=['order_date'],     -- BigQuery
    partition_by={
        "field": "order_date",
        "data_type": "date",
        "granularity": "month"
    },
) }}
```

### 모델 실행 순서 최적화

```bash
# 특정 태그/경로만 실행
dbt run --select tag:critical
dbt run --select marts.finance

# 업스트림 변경 시 관련 모델만
dbt run --select +dim_customers
```

## 5. 체크리스트

### 구조
- [ ] staging / intermediate / marts 레이어 구분
- [ ] 소스별 디렉토리 분리 (staging)
- [ ] 도메인별 디렉토리 분리 (marts)
- [ ] 네이밍 규칙 통일 (`stg_`, `int_`, `fct_`, `dim_`, `rpt_`)

### 테스트
- [ ] 모든 기본 키에 unique + not_null
- [ ] 외래 키 참조 무결성 (relationships)
- [ ] 값 범위/accepted_values 테스트
- [ ] dbt_expectations 활용
- [ ] CI에서 자동 테스트

### 매크로
- [ ] 반복 패턴 매크로화
- [ ] generate_schema_name 커스터마이징
- [ ] 공용 유틸리티 매크로 라이브러리

### 운영
- [ ] CI/CD 파이프라인 구축
- [ ] 문서 자동 생성 (dbt docs)
- [ ] source freshness 모니터링
- [ ] 인크리멘탈 모델 전환 검토
