# 모니터링 - Small Scale

> 기본 로깅, 헬스체크, 무료 모니터링 도구 활용

---

## 적용 대상

- 1~3명 팀, 단일 서비스
- 최소 비용으로 가시성 확보
- 무료 또는 저비용 도구 활용

---

## 기본 로깅

### stdout 로깅 (12-Factor App)

```javascript
// Node.js - 기본 콘솔 로깅
const LOG_LEVEL = process.env.LOG_LEVEL || 'info';

const levels = { error: 0, warn: 1, info: 2, debug: 3 };

function log(level, message, meta = {}) {
  if (levels[level] > levels[LOG_LEVEL]) return;

  const entry = {
    timestamp: new Date().toISOString(),
    level,
    message,
    ...meta,
  };

  // stdout으로 JSON 출력 (Docker/K8s가 수집)
  if (level === 'error') {
    console.error(JSON.stringify(entry));
  } else {
    console.log(JSON.stringify(entry));
  }
}

// 사용
log('info', 'Server started', { port: 3000 });
log('error', 'Database connection failed', { error: err.message });
```

```python
# Python - 기본 로깅
import logging
import json
import sys

class JSONFormatter(logging.Formatter):
    def format(self, record):
        log_entry = {
            "timestamp": self.formatTime(record),
            "level": record.levelname.lower(),
            "message": record.getMessage(),
            "module": record.module,
        }
        if record.exc_info:
            log_entry["exception"] = self.formatException(record.exc_info)
        return json.dumps(log_entry, ensure_ascii=False)

# 설정
handler = logging.StreamHandler(sys.stdout)
handler.setFormatter(JSONFormatter())

logger = logging.getLogger("app")
logger.addHandler(handler)
logger.setLevel(logging.INFO)

# 사용
logger.info("Server started", extra={"port": 8000})
logger.error("Database error", exc_info=True)
```

```go
// Go - slog (표준 라이브러리, Go 1.21+)
package main

import (
    "log/slog"
    "os"
)

func main() {
    logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{
        Level: slog.LevelInfo,
    }))
    slog.SetDefault(logger)

    slog.Info("Server started", "port", 8080)
    slog.Error("Database error", "err", err)
}
```

### 파일 로깅 (간단한 로테이션)

```yaml
# docker-compose.yml - 로그 로테이션
services:
  app:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
```

```bash
# logrotate 설정 (/etc/logrotate.d/myapp)
/var/log/myapp/*.log {
    daily
    rotate 14
    compress
    delaycompress
    missingok
    notifempty
    create 0640 app app
    postrotate
        systemctl reload myapp || true
    endscript
}
```

---

## 헬스체크 엔드포인트

### 기본 헬스체크

```javascript
// Express.js
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.APP_VERSION || 'unknown',
  });
});

// 상세 헬스체크 (내부용)
app.get('/health/detail', async (req, res) => {
  const checks = {};
  let healthy = true;

  // DB 체크
  try {
    await db.raw('SELECT 1');
    checks.database = { status: 'ok', latency: '2ms' };
  } catch (err) {
    checks.database = { status: 'error', message: err.message };
    healthy = false;
  }

  // Redis 체크
  try {
    const start = Date.now();
    await redis.ping();
    checks.redis = { status: 'ok', latency: `${Date.now() - start}ms` };
  } catch (err) {
    checks.redis = { status: 'error', message: err.message };
    healthy = false;
  }

  // 디스크 체크
  const diskUsage = getDiskUsage();
  checks.disk = {
    status: diskUsage.percent < 90 ? 'ok' : 'warning',
    usage: `${diskUsage.percent}%`,
  };

  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'healthy' : 'unhealthy',
    checks,
    timestamp: new Date().toISOString(),
  });
});
```

```python
# FastAPI
from fastapi import FastAPI, Response
from datetime import datetime
import time

app = FastAPI()
start_time = time.time()

@app.get("/health")
async def health():
    return {
        "status": "ok",
        "timestamp": datetime.utcnow().isoformat(),
        "uptime": time.time() - start_time,
    }

@app.get("/health/detail")
async def health_detail(response: Response):
    checks = {}
    healthy = True

    # DB 체크
    try:
        await database.execute("SELECT 1")
        checks["database"] = {"status": "ok"}
    except Exception as e:
        checks["database"] = {"status": "error", "message": str(e)}
        healthy = False

    if not healthy:
        response.status_code = 503

    return {
        "status": "healthy" if healthy else "unhealthy",
        "checks": checks,
        "timestamp": datetime.utcnow().isoformat(),
    }
```

---

## 무료 모니터링 도구

### UptimeRobot (무료 50개 모니터)

```
설정 방법:
1. https://uptimerobot.com 가입
2. Add New Monitor → HTTP(s)
3. URL: https://my-app.example.com/health
4. Monitoring Interval: 5분 (무료)
5. Alert Contacts: 이메일, Slack 웹훅
```

### healthchecks.io (Cron 모니터링)

```bash
# cron 작업 모니터링
# 1. healthchecks.io에서 체크 URL 생성
# 2. cron 작업 마지막에 ping

# crontab
0 * * * * /path/to/backup.sh && curl -fsS -m 10 --retry 5 https://hc-ping.com/your-uuid-here

# 실패 시
0 * * * * /path/to/backup.sh && curl -fsS https://hc-ping.com/your-uuid-here || curl -fsS https://hc-ping.com/your-uuid-here/fail
```

### Better Uptime / Betterstack (무료 플랜)

```
기능:
- 3분 간격 모니터링 (무료)
- 상태 페이지 (status.example.com)
- 인시던트 관리
- 이메일/Slack 알림
```

---

## 간단한 모니터링 스크립트

### 서버 상태 체크

```bash
#!/bin/bash
# monitor.sh - 간단한 서버 모니터링

SLACK_WEBHOOK="${SLACK_WEBHOOK_URL}"
THRESHOLD_CPU=80
THRESHOLD_MEM=80
THRESHOLD_DISK=85

# CPU 사용률
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'.' -f1)

# 메모리 사용률
MEM_USAGE=$(free | awk '/Mem:/ {printf "%d", $3/$2 * 100}')

# 디스크 사용률
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')

# 경고 메시지 생성
ALERTS=""

if [ "$CPU_USAGE" -gt "$THRESHOLD_CPU" ]; then
  ALERTS="${ALERTS}\n- CPU 사용률: ${CPU_USAGE}% (임계값: ${THRESHOLD_CPU}%)"
fi

if [ "$MEM_USAGE" -gt "$THRESHOLD_MEM" ]; then
  ALERTS="${ALERTS}\n- 메모리 사용률: ${MEM_USAGE}% (임계값: ${THRESHOLD_MEM}%)"
fi

if [ "$DISK_USAGE" -gt "$THRESHOLD_DISK" ]; then
  ALERTS="${ALERTS}\n- 디스크 사용률: ${DISK_USAGE}% (임계값: ${THRESHOLD_DISK}%)"
fi

# 알림 전송
if [ -n "$ALERTS" ]; then
  curl -s -X POST "${SLACK_WEBHOOK}" \
    -H 'Content-type: application/json' \
    -d "{\"text\": \"서버 경고 ($(hostname)):\\n${ALERTS}\"}"
fi
```

```bash
# crontab에 등록 (5분마다)
*/5 * * * * /opt/scripts/monitor.sh
```

### 엔드포인트 상태 체크

```bash
#!/bin/bash
# check-endpoints.sh

ENDPOINTS=(
  "https://my-app.example.com/health"
  "https://api.example.com/health"
)

for url in "${ENDPOINTS[@]}"; do
  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${url}")

  if [ "$HTTP_CODE" != "200" ]; then
    echo "ALERT: ${url} returned ${HTTP_CODE}"
    # Slack/이메일 알림
  fi
done
```

---

## Docker 로그 관리

```yaml
# docker-compose.yml
services:
  app:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "{{.Name}}/{{.ID}}"
```

```bash
# 로그 확인
docker compose logs -f app
docker compose logs --since 1h app
docker compose logs --tail 100 app

# 특정 패턴 검색
docker compose logs app 2>&1 | grep -i error

# 로그 내보내기
docker compose logs --no-color app > app.log
```

---

## 에러 트래킹 (무료 옵션)

### Sentry (무료 플랜: 5K 이벤트/월)

```javascript
// Node.js
const Sentry = require("@sentry/node");

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: 0.1,  // 10% 샘플링
});

// Express 미들웨어
app.use(Sentry.Handlers.requestHandler());
app.use(Sentry.Handlers.errorHandler());

// 수동 에러 리포팅
try {
  riskyOperation();
} catch (err) {
  Sentry.captureException(err);
}
```

```python
# Python
import sentry_sdk

sentry_sdk.init(
    dsn=os.environ["SENTRY_DSN"],
    environment=os.environ.get("ENV", "development"),
    traces_sample_rate=0.1,
)

# 자동 에러 캡처 (FastAPI/Django 통합 지원)
```

---

## 상태 페이지

### 간단한 상태 페이지

```html
<!-- status.html (S3/GCS에 정적 호스팅) -->
<!DOCTYPE html>
<html>
<head><title>Service Status</title></head>
<body>
  <h1>서비스 상태</h1>
  <div id="status"></div>
  <script>
    async function checkStatus() {
      const services = [
        { name: 'API', url: 'https://api.example.com/health' },
        { name: 'Web', url: 'https://www.example.com/health' },
      ];

      const results = await Promise.all(
        services.map(async (s) => {
          try {
            const res = await fetch(s.url, { mode: 'cors' });
            return { ...s, status: res.ok ? 'operational' : 'degraded' };
          } catch {
            return { ...s, status: 'down' };
          }
        })
      );

      document.getElementById('status').innerHTML = results
        .map(r => `<p>${r.name}: <strong>${r.status}</strong></p>`)
        .join('');
    }
    checkStatus();
    setInterval(checkStatus, 60000);
  </script>
</body>
</html>
```

---

## 체크리스트

- [ ] stdout으로 JSON 구조화 로깅
- [ ] `/health` 엔드포인트 구현
- [ ] 로그 로테이션 설정
- [ ] UptimeRobot 또는 유사 도구로 외부 모니터링
- [ ] Sentry (무료) 에러 트래킹
- [ ] 서버 리소스 모니터링 스크립트
- [ ] Slack 알림 연동
- [ ] 상태 페이지 제공 (옵션)
- [ ] cron 작업 모니터링 (healthchecks.io)
