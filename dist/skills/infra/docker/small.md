# Docker - Small Scale

> 단일 서비스 컨테이너화 및 로컬 개발 환경 구성

---

## 적용 대상

- 1~3명 팀, 단일 서비스
- MVP, 사이드 프로젝트, 내부 툴
- 빠르게 컨테이너화하여 어디서든 동일한 환경 실행

---

## 프로젝트 구조

```
my-app/
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
├── .env                  # 로컬 환경 변수 (git에 커밋하지 않음)
├── .env.example          # 환경 변수 템플릿
├── src/
│   └── ...
└── README.md
```

---

## Dockerfile 기본

### Multi-stage Build (Node.js 예시)

```dockerfile
# ===== Build Stage =====
FROM node:20-alpine AS builder

WORKDIR /app

# 의존성 먼저 복사 → 캐시 활용
COPY package.json package-lock.json ./
RUN npm ci --only=production

COPY . .
RUN npm run build

# ===== Production Stage =====
FROM node:20-alpine AS production

WORKDIR /app

# 보안: non-root 사용자
RUN addgroup -g 1001 -S appgroup && \
    adduser -S appuser -u 1001 -G appgroup

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

USER appuser

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:3000/health || exit 1

CMD ["node", "dist/main.js"]
```

### Multi-stage Build (Python 예시)

```dockerfile
# ===== Build Stage =====
FROM python:3.12-slim AS builder

WORKDIR /app

RUN pip install --no-cache-dir poetry
COPY pyproject.toml poetry.lock ./
RUN poetry export -f requirements.txt -o requirements.txt --without-hashes
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

COPY . .

# ===== Production Stage =====
FROM python:3.12-slim AS production

WORKDIR /app

RUN useradd --create-home --shell /bin/bash appuser

COPY --from=builder /install /usr/local
COPY --from=builder /app .

USER appuser

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8000/health')" || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Multi-stage Build (Go 예시)

```dockerfile
# ===== Build Stage =====
FROM golang:1.22-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o /app/server ./cmd/server

# ===== Production Stage =====
FROM scratch

COPY --from=builder /app/server /server
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

EXPOSE 8080

ENTRYPOINT ["/server"]
```

---

## .dockerignore

```
# 버전 관리
.git
.gitignore

# 의존성 (컨테이너 내에서 설치)
node_modules
__pycache__
*.pyc
.venv
vendor/

# 빌드 산출물
dist
build
*.egg-info

# IDE / 에디터
.vscode
.idea
*.swp
*.swo

# 환경 파일
.env
.env.local
.env.*.local

# Docker 자체
Dockerfile
docker-compose*.yml
.dockerignore

# 문서 / 테스트
README.md
docs/
tests/
coverage/
```

---

## docker-compose.yml 기본

```yaml
version: "3.8"

services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
      target: production
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=development
      - DATABASE_URL=postgresql://user:password@db:5432/myapp
    env_file:
      - .env
    depends_on:
      db:
        condition: service_healthy
    restart: unless-stopped

  db:
    image: postgres:16-alpine
    ports:
      - "5432:5432"
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: password
      POSTGRES_DB: myapp
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U user -d myapp"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
```

---

## 이미지 최적화 팁

### 1. 레이어 캐시 극대화

```dockerfile
# 나쁜 예: 소스 변경 시 의존성도 다시 설치
COPY . .
RUN npm install

# 좋은 예: 의존성 파일만 먼저 복사
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
```

### 2. 경량 베이스 이미지 사용

| 이미지 | 크기 (대략) | 용도 |
|--------|------------|------|
| `node:20` | ~1GB | 개발/디버깅 |
| `node:20-slim` | ~200MB | 일반 프로덕션 |
| `node:20-alpine` | ~130MB | 경량 프로덕션 |
| `python:3.12` | ~1GB | 개발/디버깅 |
| `python:3.12-slim` | ~150MB | 일반 프로덕션 |
| `golang:1.22-alpine` + `scratch` | ~10MB | Go 바이너리 |

### 3. 불필요한 파일 제거

```dockerfile
# apt 캐시 정리
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# pip 캐시 비활성화
RUN pip install --no-cache-dir -r requirements.txt
```

### 4. 이미지 크기 확인

```bash
# 이미지 크기 확인
docker images my-app

# 레이어별 크기 분석
docker history my-app:latest

# dive 도구로 상세 분석
dive my-app:latest
```

---

## 로컬 개발 환경 구성

### 개발용 docker-compose.override.yml

```yaml
# docker-compose.override.yml (자동으로 docker-compose.yml과 병합됨)
version: "3.8"

services:
  app:
    build:
      target: builder    # 개발 스테이지 사용
    volumes:
      - .:/app           # 소스 마운트 (핫 리로드)
      - /app/node_modules # node_modules는 마운트 제외
    command: npm run dev
    environment:
      - NODE_ENV=development
      - DEBUG=app:*
```

### 자주 쓰는 명령어

```bash
# 빌드 및 실행
docker compose up --build

# 백그라운드 실행
docker compose up -d

# 로그 확인
docker compose logs -f app

# 컨테이너 내부 접속
docker compose exec app sh

# 전체 정리
docker compose down -v    # 볼륨까지 삭제
docker system prune -f    # 사용하지 않는 리소스 정리

# 이미지 재빌드 (캐시 무시)
docker compose build --no-cache
```

---

## .env 관리

### .env.example (커밋 대상)

```bash
# Database
DATABASE_URL=postgresql://user:password@db:5432/myapp

# App
PORT=3000
NODE_ENV=development
LOG_LEVEL=debug

# External Services
REDIS_URL=redis://redis:6379
```

### .gitignore에 추가

```
.env
.env.local
.env.*.local
```

---

## 체크리스트

- [ ] Multi-stage build 적용
- [ ] .dockerignore 작성
- [ ] non-root 사용자로 실행
- [ ] HEALTHCHECK 설정
- [ ] 의존성 파일 먼저 복사 (캐시 최적화)
- [ ] .env.example 작성 및 .env는 .gitignore 처리
- [ ] docker-compose로 로컬 DB 등 의존성 통합
- [ ] 불필요한 패키지/파일 이미지에서 제외
