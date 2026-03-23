# dbt 소규모 프로젝트 가이드

## 매칭 조건

- Simple models, 기본 테스트
- 단일 데이터 소스
- 개인/소규모 팀 프로젝트
- dbt 학습/프로토타이핑
- 팀 규모: 1~2명

## 1. 프로젝트 구조

```
dbt-small/
├── dbt_project.yml               # 프로젝트 설정
├── profiles.yml                  # 연결 설정 (로컬)
├── models/
│   ├── sources.yml               # 소스 정의
│   ├── schema.yml                # 모델 문서화/테스트
│   ├── stg_orders.sql            # 스테이징 모델
│   ├── stg_customers.sql
│   ├── fct_orders.sql            # 팩트 모델
│   └── dim_customers.sql         # 디멘션 모델
├── seeds/
│   └── category_mapping.csv      # 정적 매핑 데이터
├── tests/
│   └── assert_positive_amounts.sql  # 커스텀 테스트
├── macros/
│   └── utils.sql                 # 유틸리티 매크로
├── analyses/
│   └── ad_hoc_query.sql          # 임시 분석 쿼리
├── snapshots/
│   └── scd_customers.sql         # SCD Type 2
└── README.md
```

## 2. 핵심 패턴 및 코드 예시

### 2.1 프로젝트 설정

```yaml
# dbt_project.yml
name: my_analytics
version: "1.0.0"
config-version: 2
profile: my_analytics

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

models:
  my_analytics:
    +materialized: view           # 기본은 view
    +schema: analytics
```

```yaml
# profiles.yml (로컬 개발용, ~/.dbt/profiles.yml)
my_analytics:
  target: dev
  outputs:
    dev:
      type: postgres              # 또는 bigquery, snowflake 등
      host: localhost
      port: 5432
      user: "{{ env_var('DBT_USER') }}"
      password: "{{ env_var('DBT_PASSWORD') }}"
      dbname: analytics
      schema: dev_{{ env_var('USER') }}  # 개발자별 스키마
      threads: 4
```

### 2.2 소스 정의

```yaml
# models/sources.yml
version: 2

sources:
  - name: raw
    description: "원본 데이터 소스"
    database: production
    schema: raw_data
    tables:
      - name: orders
        description: "주문 테이블"
        columns:
          - name: order_id
            description: "주문 고유 ID"
            data_tests:
              - unique
              - not_null
          - name: amount
            description: "주문 금액"
          - name: order_date
            description: "주문 일자"

      - name: customers
        description: "고객 테이블"
        columns:
          - name: customer_id
            data_tests:
              - unique
              - not_null
```

### 2.3 스테이징 모델

```sql
-- models/stg_orders.sql
-- 원본 데이터를 정제하여 스테이징
-- materialized: view (기본)

with source as (
    select * from {{ source('raw', 'orders') }}
),

renamed as (
    select
        order_id,
        customer_id,
        product_id,
        cast(amount as numeric(12, 2)) as amount,
        cast(quantity as integer) as quantity,
        cast(order_date as date) as order_date,
        lower(trim(category)) as category,
        lower(trim(status)) as status,
        created_at,
        updated_at
    from source
    where order_id is not null
      and amount >= 0
)

select * from renamed
```

```sql
-- models/stg_customers.sql
with source as (
    select * from {{ source('raw', 'customers') }}
),

renamed as (
    select
        customer_id,
        trim(name) as customer_name,
        lower(trim(email)) as email,
        trim(phone) as phone,
        trim(city) as city,
        trim(country) as country,
        cast(created_at as timestamp) as registered_at
    from source
    where customer_id is not null
)

select * from renamed
```

### 2.4 팩트/디멘션 모델

```sql
-- models/fct_orders.sql
-- 주문 팩트 테이블

{{ config(materialized='table') }}

with orders as (
    select * from {{ ref('stg_orders') }}
),

customers as (
    select * from {{ ref('stg_customers') }}
),

category_mapping as (
    select * from {{ ref('category_mapping') }}  -- seed
),

final as (
    select
        o.order_id,
        o.customer_id,
        o.product_id,
        o.amount,
        o.quantity,
        o.amount * o.quantity as total_amount,
        o.order_date,
        o.category,
        coalesce(cm.category_label, '기타') as category_label,
        o.status,
        c.customer_name,
        c.city,
        c.country,
        -- 날짜 차원
        extract(year from o.order_date) as order_year,
        extract(month from o.order_date) as order_month,
        extract(dow from o.order_date) as day_of_week,
        case
            when extract(dow from o.order_date) in (0, 6) then true
            else false
        end as is_weekend
    from orders o
    left join customers c on o.customer_id = c.customer_id
    left join category_mapping cm on o.category = cm.category_code
)

select * from final
```

```sql
-- models/dim_customers.sql
-- 고객 디멘션 테이블

{{ config(materialized='table') }}

with customers as (
    select * from {{ ref('stg_customers') }}
),

orders as (
    select * from {{ ref('stg_orders') }}
),

customer_stats as (
    select
        customer_id,
        count(*) as total_orders,
        sum(amount) as total_spent,
        avg(amount) as avg_order_amount,
        min(order_date) as first_order_date,
        max(order_date) as last_order_date
    from orders
    group by customer_id
),

final as (
    select
        c.customer_id,
        c.customer_name,
        c.email,
        c.city,
        c.country,
        c.registered_at,
        coalesce(cs.total_orders, 0) as total_orders,
        coalesce(cs.total_spent, 0) as total_spent,
        coalesce(cs.avg_order_amount, 0) as avg_order_amount,
        cs.first_order_date,
        cs.last_order_date,
        case
            when cs.total_spent >= 100000 then 'VIP'
            when cs.total_spent >= 50000 then 'Gold'
            when cs.total_spent >= 10000 then 'Silver'
            else 'Bronze'
        end as customer_tier
    from customers c
    left join customer_stats cs on c.customer_id = cs.customer_id
)

select * from final
```

### 2.5 테스트 및 문서화

```yaml
# models/schema.yml
version: 2

models:
  - name: stg_orders
    description: "정제된 주문 스테이징 테이블"
    columns:
      - name: order_id
        description: "주문 고유 ID"
        data_tests:
          - unique
          - not_null
      - name: amount
        description: "주문 금액 (양수)"
        data_tests:
          - not_null

  - name: fct_orders
    description: "주문 팩트 테이블"
    columns:
      - name: order_id
        data_tests:
          - unique
          - not_null
      - name: total_amount
        data_tests:
          - not_null
      - name: category
        data_tests:
          - accepted_values:
              values: ["electronics", "clothing", "food", "others"]

  - name: dim_customers
    description: "고객 디멘션 테이블"
    columns:
      - name: customer_id
        data_tests:
          - unique
          - not_null
      - name: customer_tier
        data_tests:
          - accepted_values:
              values: ["VIP", "Gold", "Silver", "Bronze"]
```

### 2.6 커스텀 테스트

```sql
-- tests/assert_positive_amounts.sql
-- 주문 금액이 모두 양수인지 확인

select
    order_id,
    amount
from {{ ref('fct_orders') }}
where amount < 0
```

### 2.7 유틸리티 매크로

```sql
-- macros/utils.sql

{% macro cents_to_dollars(column_name) %}
    cast({{ column_name }} / 100.0 as numeric(12, 2))
{% endmacro %}

{% macro safe_divide(numerator, denominator) %}
    case
        when {{ denominator }} = 0 then null
        else {{ numerator }} / {{ denominator }}
    end
{% endmacro %}

{% macro date_spine(start_date, end_date) %}
    -- 날짜 스파인 생성
    select
        generate_series(
            '{{ start_date }}'::date,
            '{{ end_date }}'::date,
            '1 day'::interval
        )::date as date_day
{% endmacro %}
```

### 2.8 스냅샷 (SCD Type 2)

```sql
-- snapshots/scd_customers.sql
{% snapshot scd_customers %}

{{
    config(
        target_schema='snapshots',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at',
    )
}}

select * from {{ source('raw', 'customers') }}

{% endsnapshot %}
```

### 2.9 기본 명령어

```bash
# 모델 실행
dbt run                           # 전체 실행
dbt run --select stg_orders       # 특정 모델
dbt run --select +fct_orders      # 업스트림 포함
dbt run --select fct_orders+      # 다운스트림 포함

# 테스트
dbt test                          # 전체 테스트
dbt test --select stg_orders      # 특정 모델 테스트

# 문서 생성 및 서빙
dbt docs generate
dbt docs serve

# Seed (정적 데이터)
dbt seed

# 스냅샷
dbt snapshot
```

## 3. 테스트/검증 전략

### 기본 테스트 (schema.yml)

```yaml
# 모든 모델에 최소한 적용할 테스트
- unique / not_null: 기본 키에 필수
- accepted_values: 열거형 컬럼
- relationships: 외래 키 참조 무결성
```

### 데이터 신선도 검증

```yaml
sources:
  - name: raw
    freshness:
      warn_after: { count: 12, period: hour }
      error_after: { count: 24, period: hour }
    loaded_at_field: _loaded_at
    tables:
      - name: orders
```

```bash
# 신선도 검사
dbt source freshness
```

## 4. 성능 최적화

### Materialization 선택

```
view      → 작은 모델, 자주 변경되는 데이터
table     → 자주 쿼리되는 모델, 무거운 변환
ephemeral → 중간 CTE (실체화하지 않음)
```

### 인크리멘탈 모델 (대규모 테이블)

```sql
-- models/fct_orders.sql
{{ config(
    materialized='incremental',
    unique_key='order_id',
) }}

select * from {{ ref('stg_orders') }}

{% if is_incremental() %}
where order_date > (select max(order_date) from {{ this }})
{% endif %}
```

## 5. 체크리스트

### 프로젝트 시작 시
- [ ] dbt 프로젝트 초기화 (`dbt init`)
- [ ] 프로파일 설정 및 연결 테스트 (`dbt debug`)
- [ ] 소스 정의 (`sources.yml`)
- [ ] 시드 데이터 로드 (`dbt seed`)

### 모델 개발 시
- [ ] ref() / source() 매크로 사용
- [ ] CTE 기반 구조 (with 절)
- [ ] 적절한 materialization 선택
- [ ] 스키마 테스트 작성

### 완료 시
- [ ] `dbt run` 성공
- [ ] `dbt test` 전체 통과
- [ ] `dbt docs generate` 문서 확인
- [ ] `dbt source freshness` 확인
