# 모니터링 - Large Scale

> OpenTelemetry, 분산 트레이싱, SLO/SLI, 대규모 로그/메트릭 파이프라인

---

## 적용 대상

- 8명 이상 팀, 15개 이상 서비스
- 마이크로서비스 아키텍처
- SLO 기반 운영, 대규모 데이터 처리
- 비용 효율적 장기 저장 필요

---

## 아키텍처 개요

```
┌─────────────────────────────────────────────────────────────┐
│                      Applications                           │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐             │
│  │Svc A │ │Svc B │ │Svc C │ │Svc D │ │Svc E │             │
│  │ OTel │ │ OTel │ │ OTel │ │ OTel │ │ OTel │             │
│  └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘ └──┬───┘             │
│     │        │        │        │        │                   │
└─────┼────────┼────────┼────────┼────────┼───────────────────┘
      │        │        │        │        │
      ▼        ▼        ▼        ▼        ▼
┌─────────────────────────────────────────────────────────────┐
│              OTel Collector (Gateway)                        │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐                 │
│  │ Traces   │  │ Metrics  │  │  Logs    │                  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘                 │
└───────┼──────────────┼──────────────┼───────────────────────┘
        │              │              │
        ▼              ▼              ▼
   ┌─────────┐   ┌──────────┐  ┌──────────────┐
   │  Tempo   │   │Prometheus│  │    Loki      │
   │ (Traces) │   │ / Mimir  │  │(Elasticsearch)│
   └────┬─────┘   └────┬─────┘  └──────┬───────┘
        │              │               │
        └──────────────┼───────────────┘
                       ▼
                  ┌──────────┐
                  │ Grafana  │
                  │Dashboard │
                  └──────────┘
```

---

## OpenTelemetry (통합 계측)

### OTel SDK 설정

```javascript
// tracing.js - Node.js OpenTelemetry 설정
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-grpc');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-grpc');
const { OTLPLogExporter } = require('@opentelemetry/exporter-logs-otlp-grpc');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const { Resource } = require('@opentelemetry/resources');
const { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION } = require('@opentelemetry/semantic-conventions');

const sdk = new NodeSDK({
  resource: new Resource({
    [ATTR_SERVICE_NAME]: process.env.SERVICE_NAME || 'my-service',
    [ATTR_SERVICE_VERSION]: process.env.APP_VERSION || '0.0.0',
    'deployment.environment': process.env.NODE_ENV || 'development',
    'service.namespace': 'my-app',
  }),

  // Traces
  traceExporter: new OTLPTraceExporter({
    url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4317',
  }),

  // Metrics
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({
      url: process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4317',
    }),
    exportIntervalMillis: 15000,
  }),

  // Auto-instrumentation
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-http': {
        ignoreIncomingPaths: ['/health', '/metrics'],
      },
      '@opentelemetry/instrumentation-express': {},
      '@opentelemetry/instrumentation-pg': {},
      '@opentelemetry/instrumentation-redis': {},
      '@opentelemetry/instrumentation-ioredis': {},
    }),
  ],
});

sdk.start();

// Graceful shutdown
process.on('SIGTERM', () => {
  sdk.shutdown().then(() => process.exit(0));
});
```

```python
# Python OpenTelemetry 설정
from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource, SERVICE_NAME, SERVICE_VERSION
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor
from opentelemetry.instrumentation.redis import RedisInstrumentor
from opentelemetry.instrumentation.httpx import HTTPXClientInstrumentor

import os

resource = Resource.create({
    SERVICE_NAME: os.environ.get("SERVICE_NAME", "my-service"),
    SERVICE_VERSION: os.environ.get("APP_VERSION", "0.0.0"),
    "deployment.environment": os.environ.get("ENV", "development"),
})

# Traces
trace_provider = TracerProvider(resource=resource)
trace_provider.add_span_processor(
    BatchSpanProcessor(OTLPSpanExporter(
        endpoint=os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
    ))
)
trace.set_tracer_provider(trace_provider)

# Metrics
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(
        endpoint=os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "http://otel-collector:4317"),
    ),
    export_interval_millis=15000,
)
meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
metrics.set_meter_provider(meter_provider)

# Auto-instrumentation
FastAPIInstrumentor().instrument()
SQLAlchemyInstrumentor().instrument()
RedisInstrumentor().instrument()
HTTPXClientInstrumentor().instrument()
```

### Go OpenTelemetry

```go
package main

import (
    "context"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/resource"
    sdktrace "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.24.0"
)

func initTracer(ctx context.Context) (func(), error) {
    exporter, err := otlptracegrpc.New(ctx,
        otlptracegrpc.WithEndpoint("otel-collector:4317"),
        otlptracegrpc.WithInsecure(),
    )
    if err != nil {
        return nil, err
    }

    res := resource.NewWithAttributes(
        semconv.SchemaURL,
        semconv.ServiceName("my-service"),
        semconv.ServiceVersion("1.0.0"),
        semconv.DeploymentEnvironment("production"),
    )

    tp := sdktrace.NewTracerProvider(
        sdktrace.WithBatcher(exporter),
        sdktrace.WithResource(res),
        sdktrace.WithSampler(sdktrace.ParentBased(
            sdktrace.TraceIDRatioBased(0.1), // 10% 샘플링
        )),
    )

    otel.SetTracerProvider(tp)

    return func() { tp.Shutdown(ctx) }, nil
}
```

---

## OTel Collector 설정

```yaml
# otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

  # Prometheus 메트릭 스크레이핑
  prometheus:
    config:
      scrape_configs:
        - job_name: 'kubernetes-pods'
          kubernetes_sd_configs:
            - role: pod
          relabel_configs:
            - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
              action: keep
              regex: true

processors:
  batch:
    send_batch_size: 10000
    timeout: 10s

  memory_limiter:
    check_interval: 5s
    limit_mib: 4096
    spike_limit_mib: 512

  # 불필요한 속성 제거 (비용 최적화)
  attributes/remove:
    actions:
      - key: http.user_agent
        action: delete
      - key: net.sock.peer.addr
        action: delete

  # 샘플링 (트레이스)
  tail_sampling:
    decision_wait: 10s
    policies:
      # 에러는 100% 수집
      - name: errors
        type: status_code
        status_code:
          status_codes: [ERROR]
      # 느린 요청 100% 수집
      - name: slow-requests
        type: latency
        latency:
          threshold_ms: 1000
      # 나머지 10% 샘플링
      - name: default
        type: probabilistic
        probabilistic:
          sampling_percentage: 10

  # 리소스 감지
  resourcedetection:
    detectors: [env, docker, system]

exporters:
  # Traces → Tempo
  otlp/tempo:
    endpoint: tempo:4317
    tls:
      insecure: true

  # Metrics → Prometheus/Mimir
  prometheusremotewrite:
    endpoint: http://mimir:9009/api/v1/push
    tls:
      insecure: true

  # Logs → Loki
  loki:
    endpoint: http://loki:3100/loki/api/v1/push
    default_labels_enabled:
      exporter: false
      job: true

  # 디버그 (개발용)
  debug:
    verbosity: basic

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch, tail_sampling]
      exporters: [otlp/tempo]

    metrics:
      receivers: [otlp, prometheus]
      processors: [memory_limiter, batch, attributes/remove]
      exporters: [prometheusremotewrite]

    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [loki]

  telemetry:
    logs:
      level: info
    metrics:
      address: 0.0.0.0:8888
```

---

## 분산 트레이싱

### 트레이스 전파 (W3C Trace Context)

```
서비스 A → 서비스 B → 서비스 C → DB

traceparent: 00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01
             │  │                                │                 │
             │  │ trace-id                       │ span-id         │ sampled
             │  (전체 요청 추적)                   (현재 구간)       (수집 여부)
             version
```

### 커스텀 스팬 생성

```javascript
const { trace, SpanStatusCode } = require('@opentelemetry/api');

const tracer = trace.getTracer('order-service');

async function processOrder(orderId) {
  // 커스텀 스팬
  return tracer.startActiveSpan('process-order', async (span) => {
    try {
      span.setAttribute('order.id', orderId);

      // 하위 스팬: 재고 확인
      const inventory = await tracer.startActiveSpan('check-inventory', async (inventorySpan) => {
        const result = await inventoryService.check(orderId);
        inventorySpan.setAttribute('inventory.available', result.available);
        inventorySpan.end();
        return result;
      });

      // 하위 스팬: 결제 처리
      const payment = await tracer.startActiveSpan('process-payment', async (paymentSpan) => {
        const result = await paymentService.charge(orderId);
        paymentSpan.setAttribute('payment.method', result.method);
        paymentSpan.setAttribute('payment.amount', result.amount);
        paymentSpan.end();
        return result;
      });

      span.setStatus({ code: SpanStatusCode.OK });
      return { inventory, payment };
    } catch (error) {
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error.message,
      });
      span.recordException(error);
      throw error;
    } finally {
      span.end();
    }
  });
}
```

### Tempo (트레이스 백엔드)

```yaml
# tempo-config.yaml
server:
  http_listen_port: 3200

distributor:
  receivers:
    otlp:
      protocols:
        grpc:
          endpoint: 0.0.0.0:4317

storage:
  trace:
    backend: s3
    s3:
      bucket: tempo-traces
      endpoint: s3.ap-northeast-2.amazonaws.com
      region: ap-northeast-2
    wal:
      path: /var/tempo/wal
    block:
      bloom_filter_false_positive: 0.05
      v2_index_downsample_bytes: 1000
      v2_encoding: zstd

compactor:
  compaction:
    block_retention: 720h    # 30일

metrics_generator:
  registry:
    external_labels:
      source: tempo
  storage:
    path: /var/tempo/generator/wal
    remote_write:
      - url: http://mimir:9009/api/v1/push
  traces_storage:
    path: /var/tempo/generator/traces
```

---

## SLO/SLI 기반 모니터링

### SLI 정의

```yaml
# SLI (Service Level Indicator) 정의
SLIs:
  availability:
    description: "성공적인 요청 비율"
    good_events: 'http_requests_total{status!~"5.."}'
    total_events: 'http_requests_total'

  latency:
    description: "300ms 이내 응답 비율"
    good_events: 'http_request_duration_seconds_bucket{le="0.3"}'
    total_events: 'http_request_duration_seconds_count'

  throughput:
    description: "초당 처리 요청 수"
    metric: 'rate(http_requests_total[5m])'
```

### SLO 기반 Prometheus 규칙

```yaml
# prometheus/rules/slo.yml
groups:
  - name: slo-rules
    rules:
      # === Availability SLO: 99.9% ===

      # 5분 에러율
      - record: slo:http_error_rate:5m
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum(rate(http_requests_total[5m]))

      # 30일 에러 버짓 소비율
      - record: slo:error_budget_remaining:30d
        expr: |
          1 - (
            sum(increase(http_requests_total{status=~"5.."}[30d]))
            /
            sum(increase(http_requests_total[30d]))
          ) / 0.001

      # 1시간 버닝 레이트 (빠른 소진 감지)
      - record: slo:error_budget_burn_rate:1h
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[1h]))
          /
          sum(rate(http_requests_total[1h]))
          / 0.001

      # === Latency SLO: 99% < 300ms ===

      - record: slo:latency_good_rate:5m
        expr: |
          sum(rate(http_request_duration_seconds_bucket{le="0.3"}[5m]))
          /
          sum(rate(http_request_duration_seconds_count[5m]))

  - name: slo-alerts
    rules:
      # 빠른 에러 버짓 소진 (1시간에 2% 소진)
      - alert: SLOErrorBudgetFastBurn
        expr: slo:error_budget_burn_rate:1h > 14.4
        for: 2m
        labels:
          severity: critical
          slo: availability
        annotations:
          summary: "에러 버짓 빠른 소진 감지"
          description: "현재 버닝 레이트: {{ $value }}x. 이 속도로 에러 버짓이 빠르게 소진됩니다."

      # 느린 에러 버짓 소진 (6시간에 5% 소진)
      - alert: SLOErrorBudgetSlowBurn
        expr: |
          slo:error_budget_burn_rate:1h > 6
          and
          sum(rate(http_requests_total{status=~"5.."}[6h]))
          /
          sum(rate(http_requests_total[6h]))
          / 0.001 > 6
        for: 15m
        labels:
          severity: warning
          slo: availability
        annotations:
          summary: "에러 버짓 느린 소진 감지"

      # 에러 버짓 부족
      - alert: SLOErrorBudgetExhausted
        expr: slo:error_budget_remaining:30d < 0
        for: 5m
        labels:
          severity: critical
          slo: availability
        annotations:
          summary: "30일 에러 버짓 소진됨"
          description: "잔여 에러 버짓: {{ $value | humanizePercentage }}"

      # 레이턴시 SLO 위반
      - alert: SLOLatencyBreach
        expr: slo:latency_good_rate:5m < 0.99
        for: 5m
        labels:
          severity: warning
          slo: latency
        annotations:
          summary: "레이턴시 SLO 위반 (300ms 이내 {{ $value | humanizePercentage }})"
```

---

## 대규모 로그 파이프라인

### Kafka 기반 로그 파이프라인

```
┌──────────────┐    ┌──────────────┐    ┌──────────────────┐
│ Applications │───▶│    Kafka     │───▶│  Elasticsearch   │
│ (Filebeat/   │    │  (Buffer)    │    │  (검색/분석)      │
│  Fluent Bit) │    │              │    └──────────────────┘
└──────────────┘    │  Topics:     │    ┌──────────────────┐
                    │  - app-logs  │───▶│    S3/GCS        │
                    │  - audit-logs│    │  (장기 저장)      │
                    │  - metrics   │    └──────────────────┘
                    └──────────────┘
```

### Fluent Bit 설정

```ini
# fluent-bit.conf
[SERVICE]
    Flush         5
    Log_Level     info
    Daemon        off
    Parsers_File  parsers.conf
    HTTP_Server   On
    HTTP_Listen   0.0.0.0
    HTTP_Port     2020

[INPUT]
    Name          tail
    Path          /var/log/containers/*.log
    Parser        docker
    Tag           kube.*
    Mem_Buf_Limit 5MB
    Skip_Long_Lines On

[FILTER]
    Name          kubernetes
    Match         kube.*
    Kube_URL      https://kubernetes.default.svc:443
    Merge_Log     On
    K8S-Logging.Parser On
    K8S-Logging.Exclude On

[FILTER]
    Name          modify
    Match         *
    Add           cluster production
    Add           region ap-northeast-2

# 감사 로그 → 별도 토픽
[OUTPUT]
    Name          kafka
    Match         kube.*.audit*
    Brokers       kafka-1:9092,kafka-2:9092,kafka-3:9092
    Topics        audit-logs
    Format        json
    Timestamp_Key @timestamp

# 애플리케이션 로그 → Loki
[OUTPUT]
    Name          loki
    Match         kube.*
    Host          loki-gateway
    Port          3100
    Labels        job=fluent-bit, cluster=production
    Label_Keys    $kubernetes['namespace_name'],$kubernetes['pod_name']
    Auto_Kubernetes_Labels On

# 에러 로그 → Elasticsearch (상세 분석)
[OUTPUT]
    Name          es
    Match         kube.*error*
    Host          elasticsearch
    Port          9200
    Index         error-logs
    Type          _doc
    Suppress_Type_Name On
```

---

## 비용 효율적 메트릭 저장

### Thanos (Prometheus 장기 저장)

```yaml
# Thanos Sidecar (Prometheus Pod에 추가)
# prometheus와 동일 Pod에서 실행
containers:
  - name: thanos-sidecar
    image: quay.io/thanos/thanos:v0.34.0
    args:
      - sidecar
      - --tsdb.path=/prometheus
      - --prometheus.url=http://localhost:9090
      - --objstore.config-file=/etc/thanos/bucket.yaml
    volumeMounts:
      - name: prometheus-data
        mountPath: /prometheus
      - name: thanos-config
        mountPath: /etc/thanos
```

```yaml
# bucket.yaml (S3)
type: S3
config:
  bucket: thanos-metrics
  endpoint: s3.ap-northeast-2.amazonaws.com
  region: ap-northeast-2
  access_key: ""    # IRSA/IAM Role 사용
  secret_key: ""
```

### Mimir (Grafana Mimir)

```yaml
# mimir-config.yaml
multitenancy_enabled: false

blocks_storage:
  backend: s3
  s3:
    bucket_name: mimir-blocks
    endpoint: s3.ap-northeast-2.amazonaws.com
    region: ap-northeast-2
  tsdb:
    dir: /data/tsdb
  bucket_store:
    sync_dir: /data/tsdb-sync

compactor:
  data_dir: /data/compactor
  sharding_ring:
    kvstore:
      store: memberlist

limits:
  max_global_series_per_user: 5000000
  ingestion_rate: 200000
  compactor_blocks_retention_period: 365d    # 1년 보관

ruler_storage:
  backend: s3
  s3:
    bucket_name: mimir-ruler
    endpoint: s3.ap-northeast-2.amazonaws.com
    region: ap-northeast-2
```

### 비용 최적화 전략

| 전략 | 설명 | 절감 효과 |
|------|------|----------|
| **다운샘플링** | 오래된 데이터 해상도 낮춤 (5m → 1h) | 90%+ 스토리지 |
| **보관 정책** | Hot(7일)/Warm(30일)/Cold(1년) | 70%+ 스토리지 |
| **메트릭 필터링** | 불필요한 메트릭/레이블 제거 | 30~50% |
| **카디널리티 관리** | 높은 카디널리티 레이블 제한 | 성능 + 비용 |
| **S3/GCS 저장** | 오브젝트 스토리지 장기 저장 | 80%+ vs EBS |
| **샘플링** | 트레이스 10% 수집 | 90% 트레이스 비용 |

```yaml
# Prometheus 보관 정책
prometheus:
  prometheusSpec:
    retention: 7d              # 로컬 7일만
    retentionSize: 20GB
    # Thanos/Mimir로 장기 데이터 전송
```

---

## Grafana 대시보드 표준

### 골든 시그널 대시보드

```
4가지 골든 시그널:
├── Latency      → P50, P95, P99 응답 시간
├── Traffic      → 초당 요청 수 (RPS)
├── Errors       → 에러율 (%)
└── Saturation   → CPU, 메모리, 연결 수 포화도
```

### RED 메서드 (마이크로서비스)

```
├── Rate         → 초당 요청 수
├── Errors       → 에러율
└── Duration     → 요청 처리 시간
```

### USE 메서드 (인프라)

```
├── Utilization  → 리소스 사용률
├── Saturation   → 대기열 길이, 지연
└── Errors       → 에러 수
```

---

## 체크리스트

- [ ] OpenTelemetry SDK 통합 (traces + metrics + logs)
- [ ] OTel Collector 게이트웨이 배포
- [ ] Tail sampling 정책 설정 (비용 최적화)
- [ ] 분산 트레이싱 (Tempo/Jaeger)
- [ ] SLO/SLI 정의 및 에러 버짓 알림
- [ ] Kafka/메시지 큐 기반 로그 버퍼링
- [ ] 장기 메트릭 저장 (Thanos/Mimir)
- [ ] 로그 보관 정책 (Hot/Warm/Cold)
- [ ] 골든 시그널 대시보드 구축
- [ ] 메트릭 카디널리티 관리
- [ ] 불필요한 메트릭/레이블 필터링
- [ ] 비용 모니터링 (옵저버빌리티 비용 자체도 추적)
