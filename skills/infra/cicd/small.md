# CI/CD - Small Scale

> GitHub Actions 기본 워크플로우, 빌드-테스트-배포 파이프라인

---

## 적용 대상

- 1~3명 팀, 단일 서비스
- GitHub 기반 프로젝트
- 빠르게 자동화된 빌드/테스트/배포 구축

---

## 프로젝트 구조

```
.github/
├── workflows/
│   ├── ci.yml                # 빌드 + 테스트 (PR마다)
│   ├── cd.yml                # 배포 (main 푸시)
│   └── release.yml           # 릴리스 (태그 푸시)
├── actions/                  # 커스텀 액션 (옵션)
│   └── setup-project/
│       └── action.yml
└── CODEOWNERS                # 코드 리뷰 담당자
```

---

## 기본 CI 워크플로우

### Node.js 프로젝트

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]

# 동일 브랜치 중복 실행 방지
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint-and-test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npm run lint

      - name: Type check
        run: npm run type-check

      - name: Test
        run: npm test -- --coverage

      - name: Upload coverage
        if: github.event_name == 'pull_request'
        uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage/

  build:
    needs: lint-and-test
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'

      - run: npm ci
      - run: npm run build

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: build
          path: dist/
          retention-days: 7
```

### Python 프로젝트

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
          POSTGRES_DB: testdb
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.12'
          cache: 'pip'

      - name: Install dependencies
        run: |
          pip install -r requirements.txt
          pip install -r requirements-dev.txt

      - name: Lint (ruff)
        run: ruff check .

      - name: Format check
        run: ruff format --check .

      - name: Type check (mypy)
        run: mypy src/

      - name: Test
        env:
          DATABASE_URL: postgresql://test:test@localhost:5432/testdb
        run: pytest --cov=src --cov-report=xml

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          file: coverage.xml
```

### Go 프로젝트

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-go@v5
        with:
          go-version: '1.22'

      - name: Lint (golangci-lint)
        uses: golangci/golangci-lint-action@v4
        with:
          version: latest

      - name: Test
        run: go test -race -coverprofile=coverage.out ./...

      - name: Build
        run: go build -o bin/server ./cmd/server
```

---

## 기본 CD 워크플로우

### Docker 빌드 + 배포

```yaml
# .github/workflows/cd.yml
name: CD

on:
  push:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    outputs:
      image_tag: ${{ steps.meta.outputs.version }}

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GHCR
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
            type=sha,prefix=

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Deploy to server
        uses: appleboy/ssh-action@v1
        with:
          host: ${{ secrets.DEPLOY_HOST }}
          username: ${{ secrets.DEPLOY_USER }}
          key: ${{ secrets.DEPLOY_SSH_KEY }}
          script: |
            docker pull ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ needs.build-and-push.outputs.image_tag }}
            docker compose -f /app/docker-compose.yml up -d
            docker image prune -f
```

---

## 시크릿 관리

### GitHub Secrets 설정

```
Repository Settings → Secrets and variables → Actions

필수 시크릿:
├── DEPLOY_HOST          # 배포 서버 IP/도메인
├── DEPLOY_USER          # SSH 사용자
├── DEPLOY_SSH_KEY       # SSH 개인 키
├── DATABASE_URL         # DB 연결 문자열 (테스트용)
└── SLACK_WEBHOOK_URL    # 알림용 (옵션)
```

### 시크릿 사용 규칙

```yaml
# 시크릿을 환경 변수로
env:
  DATABASE_URL: ${{ secrets.DATABASE_URL }}

# 조건부 시크릿 (옵션)
- name: Notify Slack
  if: ${{ secrets.SLACK_WEBHOOK_URL != '' }}
  uses: slackapi/slack-github-action@v1
  with:
    payload: '{"text": "배포 완료: ${{ github.sha }}"}'
  env:
    SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### GitHub Environments

```yaml
# Environment 보호 규칙 설정
# Repository Settings → Environments → production
# - Required reviewers: 1명 이상
# - Wait timer: 5분 (옵션)
# - Deployment branches: main만 허용

deploy:
  runs-on: ubuntu-latest
  environment: production    # 승인 후 실행
  steps:
    - name: Deploy
      run: echo "Deploying..."
```

---

## 릴리스 워크플로우

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: |
          npm ci
          npm run build

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          generate_release_notes: true
          files: |
            dist/*
```

```bash
# 릴리스 생성
git tag v1.0.0
git push origin v1.0.0
```

---

## 알림 설정

```yaml
  # 워크플로우 마지막에 알림
  notify:
    needs: [build, deploy]
    if: always()
    runs-on: ubuntu-latest
    steps:
      - name: Notify on success
        if: needs.deploy.result == 'success'
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "✅ 배포 성공: ${{ github.repository }}@${{ github.sha }}",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*배포 성공*\n• 레포: `${{ github.repository }}`\n• 커밋: `${{ github.sha }}`\n• 작성자: ${{ github.actor }}"
                  }
                }
              ]
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

      - name: Notify on failure
        if: needs.deploy.result == 'failure'
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "❌ 배포 실패: ${{ github.repository }}@${{ github.sha }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## 유용한 패턴

### 경로 필터

```yaml
on:
  push:
    branches: [main]
    paths:
      - 'src/**'
      - 'package.json'
      - 'Dockerfile'
    paths-ignore:
      - '**.md'
      - 'docs/**'
```

### 재사용 가능한 설정 액션

```yaml
# .github/actions/setup-project/action.yml
name: Setup Project
description: 프로젝트 환경 설정

runs:
  using: composite
  steps:
    - uses: actions/setup-node@v4
      with:
        node-version: 20
        cache: 'npm'
    - run: npm ci
      shell: bash
```

```yaml
# 워크플로우에서 사용
steps:
  - uses: actions/checkout@v4
  - uses: ./.github/actions/setup-project
  - run: npm test
```

---

## 체크리스트

- [ ] CI: PR마다 lint + test + build 실행
- [ ] CD: main 푸시 시 자동 배포
- [ ] 시크릿은 GitHub Secrets에 저장
- [ ] Environment 보호 규칙 설정 (프로덕션)
- [ ] `concurrency` 설정으로 중복 실행 방지
- [ ] 캐싱 설정 (npm/pip/go cache)
- [ ] 빌드 아티팩트 업로드
- [ ] 배포 결과 알림 (Slack 등)
- [ ] `paths` 필터로 불필요한 실행 방지
