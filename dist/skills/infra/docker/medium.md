# Docker - Medium Scale

> 다중 서비스 구성, 환경별 분리, 운영 수준의 Docker 활용

---

## 적용 대상

- 3~8명 팀, 3~15개 서비스
- 환경별(dev/staging/prod) 분리 필요
- 팀 내 일관된 개발 환경 필요

---

## 프로젝트 구조

```
project/
├── docker/
│   ├── app/
│   │   ├── Dockerfile
│   │   └── entrypoint.sh
│   ├── nginx/
│   │   ├── Dockerfile
│   │   ├── nginx.conf
│   │   └── conf.d/
│   │       └── default.conf
│   └── worker/
│       └── Dockerfile
├── docker-compose.yml              # 기본 (공통 설정)
├── docker-compose.override.yml     # 로컬 개발용 (자동 병합)
├── docker-compose.staging.yml      # 스테이징 오버라이드
├── docker-compose.prod.yml         # 프로덕션 오버라이드
├── .env                            # 로컬 환경 변수
├── .env.staging
├── .env.prod
├── Makefile                        # 편의 명령어
└── src/
    └── ...
```

---

## 다중 서비스 Compose

### docker-compose.yml (기본)

```yaml
version: "3.8"

x-common-env: &common-env
  TZ: Asia/Seoul
  LOG_LEVEL: ${LOG_LEVEL:-info}

x-healthcheck-defaults: &healthcheck-defaults
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s

services:
  # ===== Application =====
  app:
    build:
      context: .
      dockerfile: docker/app/Dockerfile
      args:
        - NODE_ENV=${NODE_ENV:-production}
    environment:
      <<: *common-env
      DATABASE_URL: postgresql://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}
      REDIS_URL: redis://redis:6379
      RABBITMQ_URL: amqp://${RABBITMQ_USER}:${RABBITMQ_PASS}@rabbitmq:5672
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
    networks:
      - frontend
      - backend
    restart: unless-stopped

  # ===== Worker =====
  worker:
    build:
      context: .
      dockerfile: docker/worker/Dockerfile
    environment:
      <<: *common-env
      DATABASE_URL: postgresql://${DB_USER}:${DB_PASSWORD}@db:5432/${DB_NAME}
      REDIS_URL: redis://redis:6379
      RABBITMQ_URL: amqp://${RABBITMQ_USER}:${RABBITMQ_PASS}@rabbitmq:5672
    depends_on:
      db:
        condition: service_healthy
      rabbitmq:
        condition: service_healthy
    networks:
      - backend
    restart: unless-stopped
    deploy:
      replicas: 2

  # ===== Reverse Proxy =====
  nginx:
    build:
      context: .
      dockerfile: docker/nginx/Dockerfile
    ports:
      - "${NGINX_PORT:-80}:80"
      - "${NGINX_SSL_PORT:-443}:443"
    depends_on:
      app:
        condition: service_healthy
    networks:
      - frontend
    restart: unless-stopped

  # ===== Database =====
  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
      POSTGRES_DB: ${DB_NAME}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./docker/db/init:/docker-entrypoint-initdb.d
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD-SHELL", "pg_isready -U ${DB_USER} -d ${DB_NAME}"]
    networks:
      - backend
    restart: unless-stopped

  # ===== Cache =====
  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes --maxmemory 256mb --maxmemory-policy allkeys-lru
    volumes:
      - redis_data:/data
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD", "redis-cli", "ping"]
    networks:
      - backend
    restart: unless-stopped

  # ===== Message Queue =====
  rabbitmq:
    image: rabbitmq:3-management-alpine
    environment:
      RABBITMQ_DEFAULT_USER: ${RABBITMQ_USER}
      RABBITMQ_DEFAULT_PASS: ${RABBITMQ_PASS}
    volumes:
      - rabbitmq_data:/var/lib/rabbitmq
    healthcheck:
      <<: *healthcheck-defaults
      test: ["CMD", "rabbitmq-diagnostics", "-q", "ping"]
    networks:
      - backend
    restart: unless-stopped

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true    # 외부 접근 차단

volumes:
  postgres_data:
  redis_data:
  rabbitmq_data:
```

---

## 환경별 Compose 파일 분리

### docker-compose.override.yml (로컬 개발)

```yaml
version: "3.8"

services:
  app:
    build:
      target: builder
    volumes:
      - ./src:/app/src
      - /app/node_modules
    command: npm run dev
    environment:
      NODE_ENV: development
      LOG_LEVEL: debug
    ports:
      - "3000:3000"
      - "9229:9229"    # 디버거 포트

  worker:
    build:
      target: builder
    volumes:
      - ./src:/app/src
    command: npm run dev:worker
    deploy:
      replicas: 1

  db:
    ports:
      - "5432:5432"    # 로컬에서 직접 접근 허용

  redis:
    ports:
      - "6379:6379"

  rabbitmq:
    ports:
      - "5672:5672"
      - "15672:15672"  # 관리 UI

  # 개발 전용 서비스
  mailhog:
    image: mailhog/mailhog
    ports:
      - "1025:1025"
      - "8025:8025"
    networks:
      - backend
```

### docker-compose.staging.yml

```yaml
version: "3.8"

services:
  app:
    image: ${REGISTRY}/my-app:${IMAGE_TAG:-latest}
    environment:
      NODE_ENV: staging
      LOG_LEVEL: info
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
        reservations:
          cpus: "0.5"
          memory: 256M

  worker:
    image: ${REGISTRY}/my-worker:${IMAGE_TAG:-latest}
    deploy:
      replicas: 2
      resources:
        limits:
          cpus: "0.5"
          memory: 256M

  nginx:
    image: ${REGISTRY}/my-nginx:${IMAGE_TAG:-latest}
    deploy:
      resources:
        limits:
          cpus: "0.5"
          memory: 128M
```

### docker-compose.prod.yml

```yaml
version: "3.8"

services:
  app:
    image: ${REGISTRY}/my-app:${IMAGE_TAG}
    environment:
      NODE_ENV: production
      LOG_LEVEL: warn
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: "2.0"
          memory: 1G
        reservations:
          cpus: "1.0"
          memory: 512M
      update_config:
        parallelism: 1
        delay: 30s
        order: start-first
      rollback_config:
        parallelism: 1
        delay: 10s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  worker:
    image: ${REGISTRY}/my-worker:${IMAGE_TAG}
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: "1.0"
          memory: 512M

  db:
    # 프로덕션에서는 외부 관리형 DB 사용 권장
    # 여기서는 제외하고 DATABASE_URL을 외부 RDS 등으로 지정
    profiles:
      - never    # 프로덕션에서 실행하지 않음
```

---

## 실행 명령어

### Makefile

```makefile
.PHONY: dev staging prod build push clean

# === 로컬 개발 ===
dev:
	docker compose up --build

dev-d:
	docker compose up --build -d

dev-logs:
	docker compose logs -f

dev-down:
	docker compose down

dev-clean:
	docker compose down -v --remove-orphans

# === 스테이징 ===
staging:
	docker compose -f docker-compose.yml -f docker-compose.staging.yml \
		--env-file .env.staging up -d

staging-down:
	docker compose -f docker-compose.yml -f docker-compose.staging.yml \
		--env-file .env.staging down

# === 프로덕션 ===
prod:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml \
		--env-file .env.prod up -d

prod-down:
	docker compose -f docker-compose.yml -f docker-compose.prod.yml \
		--env-file .env.prod down

# === 빌드 & 푸시 ===
build:
	docker compose build --parallel

push:
	docker compose push

# === 유틸 ===
shell:
	docker compose exec app sh

db-shell:
	docker compose exec db psql -U $${DB_USER} -d $${DB_NAME}

clean:
	docker system prune -af
	docker volume prune -f
```

---

## 네트워크 분리

```
┌─────────────────────────────────────────────┐
│                 frontend 네트워크             │
│                                             │
│   ┌─────────┐     ┌─────────┐              │
│   │  nginx   │────▶│   app   │              │
│   └─────────┘     └────┬────┘              │
│       ▲                 │                    │
│   외부 접근             │                    │
└─────────────────────────┼────────────────────┘
                          │
┌─────────────────────────┼────────────────────┐
│                 backend 네트워크 (internal)    │
│                         │                    │
│   ┌─────────┐     ┌────▼────┐  ┌──────────┐│
│   │  worker  │────▶│   db    │  │  redis   ││
│   └────┬────┘     └─────────┘  └──────────┘│
│        │                                     │
│        ▼                                     │
│   ┌──────────┐                              │
│   │ rabbitmq │                              │
│   └──────────┘                              │
└─────────────────────────────────────────────┘
```

- **frontend**: 외부 트래픽을 받는 서비스 (nginx, app)
- **backend (internal)**: 내부 통신만 허용 (db, redis, rabbitmq)
- `internal: true` 설정으로 backend 네트워크는 외부에서 접근 불가

---

## Health Check 패턴

### 애플리케이션 헬스체크

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
  interval: 30s      # 체크 주기
  timeout: 10s       # 타임아웃
  retries: 3         # 실패 허용 횟수
  start_period: 40s  # 시작 유예 기간
```

### 의존성 기반 헬스체크 (애플리케이션 코드)

```javascript
// /health 엔드포인트
app.get('/health', async (req, res) => {
  const checks = {
    db: 'unknown',
    redis: 'unknown',
  };

  try {
    await db.raw('SELECT 1');
    checks.db = 'healthy';
  } catch (e) {
    checks.db = 'unhealthy';
  }

  try {
    await redis.ping();
    checks.redis = 'healthy';
  } catch (e) {
    checks.redis = 'unhealthy';
  }

  const allHealthy = Object.values(checks).every(s => s === 'healthy');
  res.status(allHealthy ? 200 : 503).json({
    status: allHealthy ? 'healthy' : 'degraded',
    checks,
    timestamp: new Date().toISOString(),
  });
});
```

---

## 빌드 캐시 최적화

### BuildKit 활용

```yaml
# docker-compose.yml
services:
  app:
    build:
      context: .
      dockerfile: docker/app/Dockerfile
      cache_from:
        - ${REGISTRY}/my-app:cache
      args:
        BUILDKIT_INLINE_CACHE: 1
```

```bash
# BuildKit 활성화
export DOCKER_BUILDKIT=1
export COMPOSE_DOCKER_CLI_BUILD=1

# 원격 캐시 활용 빌드
docker build \
  --cache-from ${REGISTRY}/my-app:cache \
  --build-arg BUILDKIT_INLINE_CACHE=1 \
  -t ${REGISTRY}/my-app:${TAG} \
  -f docker/app/Dockerfile .

# 캐시용 이미지 푸시
docker push ${REGISTRY}/my-app:cache
```

### Dockerfile 캐시 마운트

```dockerfile
# syntax=docker/dockerfile:1.4

# pip 캐시 마운트
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# npm 캐시 마운트
RUN --mount=type=cache,target=/root/.npm \
    npm ci

# Go 모듈 캐시 마운트
RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    go build -o /app/server ./cmd/server
```

---

## 시크릿 관리

### Docker Secrets (Compose)

```yaml
version: "3.8"

services:
  app:
    secrets:
      - db_password
      - api_key
    environment:
      DB_PASSWORD_FILE: /run/secrets/db_password
      API_KEY_FILE: /run/secrets/api_key

secrets:
  db_password:
    file: ./secrets/db_password.txt     # 로컬 파일
  api_key:
    environment: API_KEY                 # 환경 변수에서
```

### 애플리케이션에서 시크릿 읽기

```javascript
const fs = require('fs');

function getSecret(name) {
  // Docker secret 파일 우선
  const secretFile = `/run/secrets/${name}`;
  if (fs.existsSync(secretFile)) {
    return fs.readFileSync(secretFile, 'utf8').trim();
  }
  // 환경 변수 폴백
  const envFile = process.env[`${name.toUpperCase()}_FILE`];
  if (envFile && fs.existsSync(envFile)) {
    return fs.readFileSync(envFile, 'utf8').trim();
  }
  return process.env[name.toUpperCase()];
}

const dbPassword = getSecret('db_password');
```

---

## 볼륨 관리

```yaml
volumes:
  # Named volume - Docker가 관리
  postgres_data:
    driver: local

  # Bind mount - 호스트 경로 직접 지정
  app_uploads:
    driver: local
    driver_opts:
      type: none
      device: /data/uploads
      o: bind

  # tmpfs - 메모리에만 저장 (시크릿 등)
  app_tmp:
    driver: local
    driver_opts:
      type: tmpfs
      device: tmpfs
```

### 볼륨 백업

```bash
# PostgreSQL 볼륨 백업
docker compose exec db pg_dump -U user myapp | gzip > backup_$(date +%Y%m%d).sql.gz

# 볼륨 직접 백업
docker run --rm \
  -v postgres_data:/source:ro \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/postgres_$(date +%Y%m%d).tar.gz -C /source .
```

---

## entrypoint.sh 패턴

```bash
#!/bin/sh
set -e

echo "=== Starting application ==="

# DB 마이그레이션 (프로덕션)
if [ "$RUN_MIGRATIONS" = "true" ]; then
  echo "Running database migrations..."
  npm run migrate
fi

# 시드 데이터 (개발)
if [ "$NODE_ENV" = "development" ] && [ "$RUN_SEED" = "true" ]; then
  echo "Seeding database..."
  npm run seed
fi

# 전달된 명령어 실행
exec "$@"
```

```dockerfile
COPY docker/app/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["node", "dist/main.js"]
```

---

## 체크리스트

- [ ] 네트워크 분리 (frontend/backend)
- [ ] 환경별 compose 파일 분리
- [ ] 모든 서비스에 health check 설정
- [ ] 시크릿은 Docker secrets 또는 환경 변수로 관리
- [ ] 볼륨 백업 절차 수립
- [ ] BuildKit 캐시 최적화 적용
- [ ] 리소스 제한 (CPU/메모리) 설정
- [ ] 로그 드라이버 및 로테이션 설정
- [ ] entrypoint.sh로 초기화 로직 분리
- [ ] Makefile로 반복 명령어 자동화
