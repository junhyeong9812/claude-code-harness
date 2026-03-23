# Docker - Large Scale

> 프로덕션 운영, 보안 강화, CI/CD 연동, 대규모 컨테이너 관리

---

## 적용 대상

- 8명 이상 팀, 15개 이상 서비스
- 프로덕션 보안 요구사항 높음
- 이미지 레지스트리 운영, 자동화된 보안 스캐닝
- CI/CD 파이프라인과 완전 통합

---

## 프로젝트 구조

```
project/
├── docker/
│   ├── base/                    # 공통 베이스 이미지
│   │   ├── Dockerfile.node
│   │   ├── Dockerfile.python
│   │   └── Dockerfile.go
│   ├── services/
│   │   ├── api/
│   │   │   ├── Dockerfile
│   │   │   └── entrypoint.sh
│   │   ├── worker/
│   │   │   └── Dockerfile
│   │   ├── scheduler/
│   │   │   └── Dockerfile
│   │   └── nginx/
│   │       ├── Dockerfile
│   │       └── conf.d/
│   └── scripts/
│       ├── build.sh
│       ├── push.sh
│       ├── scan.sh
│       └── cleanup.sh
├── docker-compose.yml
├── docker-compose.prod.yml
├── .hadolint.yaml               # Dockerfile 린트 설정
├── .trivyignore                 # Trivy 무시 목록
└── Makefile
```

---

## 보안 강화 Dockerfile

### Distroless 이미지 사용

```dockerfile
# ===== Build Stage =====
FROM node:20-alpine AS builder

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --only=production && npm cache clean --force
COPY . .
RUN npm run build

# ===== Production Stage (Distroless) =====
FROM gcr.io/distroless/nodejs20-debian12

WORKDIR /app

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

# distroless는 shell이 없으므로 CMD 배열 형식만 가능
CMD ["dist/main.js"]
```

### Alpine 최적화 + Rootless

```dockerfile
# syntax=docker/dockerfile:1.4

FROM python:3.12-alpine AS builder

RUN apk add --no-cache \
    build-base \
    libffi-dev \
    postgresql-dev

WORKDIR /app
COPY requirements.txt .
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install --no-cache-dir --prefix=/install -r requirements.txt

# ===== Production =====
FROM python:3.12-alpine

# 최소 런타임 의존성만
RUN apk add --no-cache \
    libpq \
    tini \
    && rm -rf /var/cache/apk/*

# non-root 사용자
RUN addgroup -g 65532 -S nonroot && \
    adduser -S nonroot -u 65532 -G nonroot -h /app -s /sbin/nologin

WORKDIR /app

COPY --from=builder /install /usr/local
COPY --chown=nonroot:nonroot . .

# 읽기 전용 파일시스템 대비
RUN mkdir -p /app/tmp && chown nonroot:nonroot /app/tmp
VOLUME ["/app/tmp"]

USER 65532:65532

# tini로 PID 1 좀비 프로세스 방지
ENTRYPOINT ["tini", "--"]
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### Go 바이너리 (scratch)

```dockerfile
FROM golang:1.22-alpine AS builder

RUN apk add --no-cache ca-certificates tzdata

WORKDIR /app
COPY go.mod go.sum ./
RUN --mount=type=cache,target=/go/pkg/mod go mod download

COPY . .
RUN --mount=type=cache,target=/root/.cache/go-build \
    CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-w -s -X main.version=${VERSION}" \
    -o /server ./cmd/server

# ===== Scratch (최소 이미지) =====
FROM scratch

# TLS 인증서 및 타임존
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /usr/share/zoneinfo /usr/share/zoneinfo

# non-root UID
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder --chown=65532:65532 /server /server

USER 65532:65532

EXPOSE 8080
ENTRYPOINT ["/server"]
```

---

## 이미지 레지스트리 운영

### 태그 전략

```bash
# 태그 네이밍 컨벤션
REGISTRY=registry.example.com
IMAGE=${REGISTRY}/myapp

# Git SHA 기반 (권장 - 불변성 보장)
docker tag myapp:latest ${IMAGE}:sha-abc1234

# 시맨틱 버전
docker tag myapp:latest ${IMAGE}:v1.2.3

# 환경별 태그
docker tag myapp:latest ${IMAGE}:staging
docker tag myapp:latest ${IMAGE}:production

# 날짜 기반
docker tag myapp:latest ${IMAGE}:20240315-abc1234
```

### 자동 태깅 스크립트

```bash
#!/bin/bash
# docker/scripts/build.sh

set -euo pipefail

REGISTRY="${REGISTRY:-registry.example.com}"
IMAGE_NAME="${1:?Image name required}"
DOCKERFILE="${2:-Dockerfile}"

# 메타데이터
GIT_SHA=$(git rev-parse --short HEAD)
GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
VERSION=$(git describe --tags --always --dirty 2>/dev/null || echo "dev")

FULL_IMAGE="${REGISTRY}/${IMAGE_NAME}"

echo "Building ${FULL_IMAGE}..."

docker build \
  --build-arg BUILD_DATE="${BUILD_DATE}" \
  --build-arg VERSION="${VERSION}" \
  --build-arg GIT_SHA="${GIT_SHA}" \
  --label "org.opencontainers.image.created=${BUILD_DATE}" \
  --label "org.opencontainers.image.version=${VERSION}" \
  --label "org.opencontainers.image.revision=${GIT_SHA}" \
  --label "org.opencontainers.image.source=$(git remote get-url origin)" \
  -t "${FULL_IMAGE}:${GIT_SHA}" \
  -t "${FULL_IMAGE}:${GIT_BRANCH}" \
  -t "${FULL_IMAGE}:latest" \
  -f "${DOCKERFILE}" .

echo "Built: ${FULL_IMAGE}:${GIT_SHA}"
```

---

## 보안 스캐닝 (Trivy)

### 로컬 스캐닝

```bash
# 이미지 취약점 스캐닝
trivy image myapp:latest

# 심각도 필터링
trivy image --severity HIGH,CRITICAL myapp:latest

# JSON 출력 (CI/CD용)
trivy image --format json --output report.json myapp:latest

# Dockerfile 스캐닝
trivy config ./docker/services/api/Dockerfile

# docker-compose.yml 스캐닝
trivy config ./docker-compose.yml

# SBOM 생성
trivy image --format spdx-json --output sbom.json myapp:latest
```

### CI/CD 통합 스캐닝 스크립트

```bash
#!/bin/bash
# docker/scripts/scan.sh

set -euo pipefail

IMAGE="${1:?Image name required}"
SEVERITY="${SEVERITY:-HIGH,CRITICAL}"
EXIT_CODE="${EXIT_CODE:-1}"  # 취약점 발견 시 종료 코드

echo "=== Scanning ${IMAGE} ==="

# 이미지 취약점 스캐닝
trivy image \
  --severity "${SEVERITY}" \
  --exit-code "${EXIT_CODE}" \
  --no-progress \
  --format table \
  "${IMAGE}"

SCAN_RESULT=$?

# JSON 리포트 생성
trivy image \
  --format json \
  --output "scan-report-$(date +%Y%m%d).json" \
  "${IMAGE}"

if [ ${SCAN_RESULT} -ne 0 ]; then
  echo "CRITICAL/HIGH 취약점 발견! 빌드 실패."
  exit 1
fi

echo "스캔 통과: ${IMAGE}"
```

### .trivyignore

```
# 허용된 취약점 (사유 기록)
# CVE-2023-XXXXX: 해당 기능 미사용, 다음 업데이트에서 해결
CVE-2023-XXXXX

# CVE-2024-YYYYY: 내부 네트워크에서만 접근 가능
CVE-2024-YYYYY
```

### Hadolint (Dockerfile 린트)

```yaml
# .hadolint.yaml
ignored:
  - DL3008   # apt pin versions
  - DL3018   # apk pin versions

trustedRegistries:
  - docker.io
  - gcr.io
  - registry.example.com

override:
  warning:
    - DL3059  # multiple consecutive RUN
```

```bash
# 린트 실행
hadolint docker/services/api/Dockerfile
hadolint --config .hadolint.yaml docker/**/**/Dockerfile
```

---

## Docker Swarm 프로덕션

### docker-compose.prod.yml (Swarm 모드)

```yaml
version: "3.8"

services:
  app:
    image: ${REGISTRY}/myapp:${TAG}
    deploy:
      mode: replicated
      replicas: 3
      placement:
        constraints:
          - node.role == worker
          - node.labels.zone == ap-northeast-2a
        preferences:
          - spread: node.labels.zone
      update_config:
        parallelism: 1
        delay: 30s
        failure_action: rollback
        monitor: 60s
        max_failure_ratio: 0.3
        order: start-first
      rollback_config:
        parallelism: 1
        delay: 10s
        order: stop-first
      resources:
        limits:
          cpus: "2.0"
          memory: 1G
        reservations:
          cpus: "0.5"
          memory: 256M
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
        window: 120s
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 30s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "5"
        tag: "{{.Name}}/{{.ID}}"
    secrets:
      - db_password
      - api_key
    configs:
      - source: app_config
        target: /app/config.yaml

  nginx:
    image: ${REGISTRY}/nginx:${TAG}
    ports:
      - target: 80
        published: 80
        protocol: tcp
        mode: ingress
      - target: 443
        published: 443
        protocol: tcp
        mode: ingress
    deploy:
      mode: global       # 모든 노드에 배포
      placement:
        constraints:
          - node.role == worker
      resources:
        limits:
          cpus: "0.5"
          memory: 128M

secrets:
  db_password:
    external: true
  api_key:
    external: true

configs:
  app_config:
    file: ./config/app.yaml
```

### Swarm 운영 명령어

```bash
# 스택 배포
docker stack deploy -c docker-compose.yml -c docker-compose.prod.yml myapp

# 서비스 확인
docker service ls
docker service ps myapp_app

# 스케일링
docker service scale myapp_app=5

# 롤링 업데이트
docker service update --image ${REGISTRY}/myapp:v1.2.4 myapp_app

# 롤백
docker service rollback myapp_app

# 로그 확인
docker service logs -f myapp_app

# 시크릿 관리
echo "my-secret-password" | docker secret create db_password -
docker secret ls
```

---

## CI/CD 파이프라인 연동

### GitHub Actions 예시

```yaml
name: Docker Build & Deploy

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hadolint/hadolint-action@v3.1.0
        with:
          dockerfile: docker/services/api/Dockerfile

  build-and-scan:
    needs: lint
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      security-events: write
    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=sha
            type=ref,event=branch
            type=semver,pattern={{version}}

      - name: Build
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/services/api/Dockerfile
          push: false
          load: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Trivy Scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:sha-${{ github.sha }}
          format: 'sarif'
          output: 'trivy-results.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'

      - name: Push
        if: github.event_name == 'push'
        uses: docker/build-push-action@v5
        with:
          context: .
          file: docker/services/api/Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

## 이미지 정리 및 운영

### 자동 정리 스크립트

```bash
#!/bin/bash
# docker/scripts/cleanup.sh

set -euo pipefail

echo "=== Docker Cleanup ==="

# 30일 이상 된 사용하지 않는 이미지 삭제
docker image prune -a --filter "until=720h" -f

# 중지된 컨테이너 삭제
docker container prune -f

# 사용하지 않는 네트워크 삭제
docker network prune -f

# 사용하지 않는 빌드 캐시 정리 (50GB 이상 시)
CACHE_SIZE=$(docker system df --format '{{.BuildCache}}' | grep -oP '\d+\.?\d*' | head -1)
if (( $(echo "${CACHE_SIZE:-0} > 50" | bc -l) )); then
  echo "빌드 캐시 ${CACHE_SIZE}GB -> 정리"
  docker builder prune --keep-storage 20GB -f
fi

docker system df
echo "=== Cleanup Complete ==="
```

### 레지스트리 이미지 정리

```bash
# 최근 N개 태그만 유지 (GitHub Container Registry)
# gh CLI 사용
gh api \
  -H "Accept: application/vnd.github+json" \
  /user/packages/container/myapp/versions \
  --paginate \
  | jq -r '.[10:] | .[].id' \
  | xargs -I {} gh api --method DELETE \
    /user/packages/container/myapp/versions/{}
```

---

## 보안 모범 사례 요약

| 항목 | 설명 |
|------|------|
| **Rootless** | `USER nonroot` 또는 UID 65532 사용 |
| **읽기 전용 FS** | `--read-only` 플래그 + tmpfs 마운트 |
| **최소 이미지** | distroless, scratch, alpine 사용 |
| **CVE 스캐닝** | Trivy로 빌드/배포 시 자동 스캐닝 |
| **SBOM** | 소프트웨어 구성 목록 생성 및 관리 |
| **시크릿** | Docker secrets 사용, 빌드 시 `--secret` 마운트 |
| **서명** | Docker Content Trust / Cosign으로 이미지 서명 |
| **네트워크** | 최소한의 포트 노출, internal 네트워크 |
| **린트** | Hadolint로 Dockerfile 품질 관리 |
| **레이블** | OCI 표준 레이블로 추적성 확보 |

---

## 체크리스트

- [ ] Distroless 또는 Alpine 기반 최소 이미지 사용
- [ ] Non-root 사용자로 실행 (UID 65532 권장)
- [ ] Trivy 보안 스캐닝 CI/CD 파이프라인에 통합
- [ ] Hadolint로 Dockerfile 린트 자동화
- [ ] 이미지 태그 전략 수립 (Git SHA 기반 권장)
- [ ] 레지스트리 이미지 정리 자동화
- [ ] Docker secrets 또는 시크릿 매니저 사용
- [ ] OCI 표준 레이블 적용
- [ ] SBOM 생성 및 관리
- [ ] 롤링 업데이트 / 롤백 설정 완료
- [ ] 리소스 제한 (CPU/메모리) 설정
- [ ] 로그 드라이버 및 로테이션 설정
