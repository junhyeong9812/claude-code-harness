# 모니터링 - Medium Scale

> 구조화된 로깅, APM, 메트릭 수집, 대시보드, 알림

---

## 적용 대상

- 3~8명 팀, 3~15개 서비스
- 체계적인 로깅 및 모니터링 필요
- 장애 원인 분석, 성능 최적화

---

## 프로젝트 구조

```
monitoring/
├── prometheus/
│   ├── prometheus.yml
│   └── rules/
│       ├── app-alerts.yml
│       └── infra-alerts.yml
├── grafana/
│   ├── provisioning/
│   │   ├── dashboards/
│   │   │   ├── dashboard.yml
│   │   │   ├── app-dashboard.json
│   │   │   └── infra-dashboard.json
│   │   └── datasources/
│   │       └── datasource.yml
│   └── grafana.ini
├── alertmanager/
│   └── alertmanager.yml
├── loki/
│   └── loki-config.yml
├── promtail/
│   └── promtail-config.yml
└── docker-compose.monitoring.yml
```

---

## 구조화된 로깅 (JSON)

### 로깅 표준

```json
{
  "timestamp": "2024-03-15T09:30:00.123Z",
  "level": "info",
  "message": "HTTP request completed",
  "service": "user-service",
  "version": "1.2.3",
  "trace_id": "abc123def456",
  "span_id": "789ghi",
  "request": {
    "method": "GET",
    "path": "/api/users/123",
    "status": 200,
    "duration_ms": 45,
    "ip": "10.0.1.50",
    "user_agent": "Mozilla/5.0"
  },
  "user": {
    "id": "user_123"
  }
}
```

### Node.js (Pino)

```javascript
const pino = require('pino');

const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label }),
  },
  timestamp: () => `,"timestamp":"${new Date().toISOString()}"`,
  base: {
    service: process.env.SERVICE_NAME || 'my-app',
    version: process.env.APP_VERSION || '0.0.0',
    env: process.env.NODE_ENV,
  },
  redact: ['req.headers.authorization', 'req.headers.cookie', '*.password'],
});

// Express 미들웨어
const pinoHttp = require('pino-http');

app.use(pinoHttp({
  logger,
  customProps: (req) => ({
    trace_id: req.headers['x-request-id'] || crypto.randomUUID(),
  }),
  serializers: {
    req: (req) => ({
      method: req.method,
      path: req.url,
      ip: req.remoteAddress,
    }),
    res: (res) => ({
      status: res.statusCode,
    }),
  },
}));
```

### Python (structlog)

```python
import structlog
import logging

structlog.configure(
    processors=[
        structlog.contextvars.merge_contextvars,
        structlog.processors.add_log_level,
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.StackInfoRenderer(),
        structlog.processors.format_exc_info,
        structlog.processors.JSONRenderer(),
    ],
    wrapper_class=structlog.make_filtering_bound_logger(logging.INFO),
    context_class=dict,
    logger_factory=structlog.PrintLoggerFactory(),
)

logger = structlog.get_logger(service="user-service")

# 사용
logger.info("request_completed",
    method="GET",
    path="/api/users/123",
    status=200,
    duration_ms=45,
)

# 컨텍스트 바인딩 (요청 스코프)
log = logger.bind(trace_id=request_id, user_id=user.id)
log.info("processing_order", order_id="ORD-123")
```

---

## 로그 수집 (Loki + Promtail)

### Loki 설정

```yaml
# loki/loki-config.yml
auth_enabled: false

server:
  http_listen_port: 3100

common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index:
        prefix: index_
        period: 24h

limits_config:
  retention_period: 30d
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20

compactor:
  working_directory: /loki/compactor
  retention_enabled: true
```

### Promtail 설정 (로그 수집기)

```yaml
# promtail/promtail-config.yml
server:
  http_listen_port: 9080

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  # Docker 컨테이너 로그
  - job_name: docker
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 5s
    relabel_configs:
      - source_labels: ['__meta_docker_container_name']
        target_label: container
        regex: '/(.*)'
      - source_labels: ['__meta_docker_container_label_com_docker_compose_service']
        target_label: service
    pipeline_stages:
      - json:
          expressions:
            level: level
            message: message
            trace_id: trace_id
      - labels:
          level:
          trace_id:

  # 파일 로그
  - job_name: app-logs
    static_configs:
      - targets:
          - localhost
        labels:
          job: app
          __path__: /var/log/myapp/*.log
    pipeline_stages:
      - json:
          expressions:
            level: level
      - labels:
          level:
```

---

## 메트릭 수집 (Prometheus)

### Prometheus 설정

```yaml
# prometheus/prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

scrape_configs:
  # Prometheus 자체 메트릭
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # 애플리케이션 메트릭
  - job_name: 'app'
    metrics_path: /metrics
    static_configs:
      - targets:
          - 'app:3000'
          - 'worker:3000'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '(.+):\d+'

  # Node Exporter (서버 메트릭)
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  # PostgreSQL Exporter
  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  # Redis Exporter
  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']

  # Docker 서비스 디스커버리
  - job_name: 'docker'
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        refresh_interval: 15s
    relabel_configs:
      - source_labels: ['__meta_docker_container_label_prometheus_scrape']
        regex: 'true'
        action: keep
      - source_labels: ['__meta_docker_container_label_prometheus_port']
        target_label: __address__
        regex: '(.+)'
        replacement: '${1}'
```

### 애플리케이션 메트릭 노출

```javascript
// Node.js (prom-client)
const client = require('prom-client');

// 기본 메트릭 (CPU, 메모리, 이벤트 루프 등)
client.collectDefaultMetrics();

// HTTP 요청 메트릭
const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
});

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status'],
});

// 비즈니스 메트릭
const ordersCreated = new client.Counter({
  name: 'orders_created_total',
  help: 'Total number of orders created',
  labelNames: ['payment_method'],
});

const activeUsers = new client.Gauge({
  name: 'active_users',
  help: 'Number of active users',
});

// Express 미들웨어
app.use((req, res, next) => {
  const end = httpRequestDuration.startTimer();
  res.on('finish', () => {
    const route = req.route?.path || req.path;
    const labels = { method: req.method, route, status: res.statusCode };
    end(labels);
    httpRequestsTotal.inc(labels);
  });
  next();
});

// /metrics 엔드포인트
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', client.register.contentType);
  res.end(await client.register.metrics());
});
```

```python
# Python (prometheus_client)
from prometheus_client import Counter, Histogram, Gauge, generate_latest
from fastapi import FastAPI, Request, Response
import time

app = FastAPI()

REQUEST_DURATION = Histogram(
    'http_request_duration_seconds',
    'Duration of HTTP requests',
    ['method', 'endpoint', 'status'],
    buckets=[0.01, 0.05, 0.1, 0.5, 1, 2, 5],
)

REQUEST_COUNT = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status'],
)

@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = time.time() - start

    labels = {
        'method': request.method,
        'endpoint': request.url.path,
        'status': response.status_code,
    }
    REQUEST_DURATION.labels(**labels).observe(duration)
    REQUEST_COUNT.labels(**labels).inc()

    return response

@app.get("/metrics")
async def metrics():
    return Response(content=generate_latest(), media_type="text/plain")
```

---

## 알림 규칙

### Prometheus Alerting Rules

```yaml
# prometheus/rules/app-alerts.yml
groups:
  - name: application
    rules:
      # 높은 에러율
      - alert: HighErrorRate
        expr: |
          sum(rate(http_requests_total{status=~"5.."}[5m]))
          /
          sum(rate(http_requests_total[5m]))
          > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "높은 에러율 ({{ $value | humanizePercentage }})"
          description: "5xx 에러율이 5%를 초과했습니다."

      # 느린 응답
      - alert: HighLatency
        expr: |
          histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))
          > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "높은 P95 레이턴시 ({{ $value }}s)"

      # 서비스 다운
      - alert: ServiceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "{{ $labels.job }} 서비스 다운"

  - name: infrastructure
    rules:
      # 높은 CPU
      - alert: HighCPU
        expr: |
          100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
          > 80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "높은 CPU 사용률 ({{ $value }}%)"

      # 높은 메모리
      - alert: HighMemory
        expr: |
          (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
          > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "높은 메모리 사용률 ({{ $value }}%)"

      # 디스크 부족
      - alert: DiskSpaceLow
        expr: |
          (1 - (node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"} / node_filesystem_size_bytes)) * 100
          > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "디스크 사용률 높음 ({{ $value }}%)"

      # DB 연결 부족
      - alert: PostgresConnectionsHigh
        expr: |
          pg_stat_activity_count / pg_settings_max_connections
          > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "PostgreSQL 연결 수 높음 ({{ $value | humanizePercentage }})"
```

### Alertmanager 설정

```yaml
# alertmanager/alertmanager.yml
global:
  resolve_timeout: 5m
  slack_api_url: 'https://hooks.slack.com/services/xxx/yyy/zzz'

route:
  receiver: 'slack-default'
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h

  routes:
    # Critical → 즉시 알림 + PagerDuty
    - match:
        severity: critical
      receiver: 'slack-critical'
      repeat_interval: 1h
      continue: true

    - match:
        severity: critical
      receiver: 'pagerduty'
      repeat_interval: 1h

    # Warning → 일반 채널
    - match:
        severity: warning
      receiver: 'slack-default'
      repeat_interval: 4h

receivers:
  - name: 'slack-default'
    slack_configs:
      - channel: '#alerts'
        title: '{{ .GroupLabels.alertname }}'
        text: >-
          {{ range .Alerts }}
          *{{ .Labels.severity | toUpper }}*: {{ .Annotations.summary }}
          {{ .Annotations.description }}
          {{ end }}
        send_resolved: true

  - name: 'slack-critical'
    slack_configs:
      - channel: '#alerts-critical'
        title: 'CRITICAL: {{ .GroupLabels.alertname }}'
        color: '{{ if eq .Status "firing" }}danger{{ else }}good{{ end }}'
        text: >-
          {{ range .Alerts }}
          {{ .Annotations.summary }}
          {{ .Annotations.description }}
          {{ end }}

  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: '<pagerduty-integration-key>'
        severity: '{{ .CommonLabels.severity }}'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname']
```

---

## Grafana 대시보드

### 데이터소스 프로비저닝

```yaml
# grafana/provisioning/datasources/datasource.yml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    jsonData:
      derivedFields:
        - datasourceUid: tempo
          matcherRegex: "trace_id=(\\w+)"
          name: TraceID
          url: "$${__value.raw}"
```

### 모니터링 스택 docker-compose

```yaml
# docker-compose.monitoring.yml
version: "3.8"

services:
  prometheus:
    image: prom/prometheus:v2.50.0
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    ports:
      - "9090:9090"
    restart: unless-stopped

  grafana:
    image: grafana/grafana:10.3.0
    volumes:
      - ./grafana/provisioning:/etc/grafana/provisioning
      - grafana_data:/var/lib/grafana
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD}
      GF_USERS_ALLOW_SIGN_UP: "false"
    ports:
      - "3001:3000"
    restart: unless-stopped

  alertmanager:
    image: prom/alertmanager:v0.27.0
    volumes:
      - ./alertmanager:/etc/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
    ports:
      - "9093:9093"
    restart: unless-stopped

  loki:
    image: grafana/loki:2.9.4
    volumes:
      - ./loki:/etc/loki
      - loki_data:/loki
    command: -config.file=/etc/loki/loki-config.yml
    ports:
      - "3100:3100"
    restart: unless-stopped

  promtail:
    image: grafana/promtail:2.9.4
    volumes:
      - ./promtail:/etc/promtail
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /var/log:/var/log:ro
    command: -config.file=/etc/promtail/promtail-config.yml
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:v1.7.0
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
    restart: unless-stopped

  postgres-exporter:
    image: quay.io/prometheuscommunity/postgres-exporter
    environment:
      DATA_SOURCE_NAME: "postgresql://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}?sslmode=disable"
    restart: unless-stopped

volumes:
  prometheus_data:
  grafana_data:
  loki_data:
```

---

## APM (Application Performance Monitoring)

### Sentry (에러 + 성능)

```javascript
const Sentry = require("@sentry/node");
const { nodeProfilingIntegration } = require("@sentry/profiling-node");

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  release: process.env.APP_VERSION,
  integrations: [nodeProfilingIntegration()],
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  profilesSampleRate: 0.1,
});
```

---

## 체크리스트

- [ ] JSON 구조화 로깅 (timestamp, level, trace_id)
- [ ] Prometheus + Grafana 메트릭 수집/시각화
- [ ] Loki + Promtail 로그 수집
- [ ] 앱 메트릭 노출 (/metrics)
- [ ] 알림 규칙 설정 (에러율, 레이턴시, 리소스)
- [ ] Alertmanager → Slack/PagerDuty 알림
- [ ] 심각도별 알림 경로 분리
- [ ] Node Exporter (서버 메트릭)
- [ ] DB Exporter (PostgreSQL/Redis)
- [ ] Sentry 에러 트래킹 연동
