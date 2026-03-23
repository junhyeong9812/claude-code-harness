# CI/CD - Medium Scale

> 멀티 환경 파이프라인, 매트릭스 빌드, 캐싱 전략, PR 자동 검증

---

## 적용 대상

- 3~8명 팀, 3~15개 서비스
- dev/staging/prod 멀티 환경 배포
- 체계적인 PR 리뷰 프로세스

---

## 프로젝트 구조

```
.github/
├── workflows/
│   ├── ci.yml                    # PR 검증
│   ├── cd-dev.yml                # dev 자동 배포
│   ├── cd-staging.yml            # staging 자동 배포
│   ├── cd-prod.yml               # prod 수동 승인 배포
│   ├── reusable-build.yml        # 재사용 가능한 빌드
│   └── reusable-deploy.yml       # 재사용 가능한 배포
├── actions/
│   ├── setup-project/
│   │   └── action.yml
│   └── notify/
│       └── action.yml
└── CODEOWNERS
```

---

## 멀티 환경 파이프라인

### 재사용 가능한 빌드 워크플로우

```yaml
# .github/workflows/reusable-build.yml
name: Reusable Build

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      image_tag:
        required: true
        type: string
    outputs:
      image:
        description: "빌드된 이미지 전체 경로"
        value: ${{ jobs.build.outputs.image }}

env:
  REGISTRY: ghcr.io

jobs:
  build:
    runs-on: ubuntu-latest
    outputs:
      image: ${{ steps.meta.outputs.tags }}

    permissions:
      contents: read
      packages: write

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

      - name: Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ github.repository }}
          tags: |
            type=raw,value=${{ inputs.image_tag }}
            type=raw,value=${{ inputs.environment }}-latest

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          build-args: |
            NODE_ENV=${{ inputs.environment == 'prod' && 'production' || 'development' }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### 재사용 가능한 배포 워크플로우

```yaml
# .github/workflows/reusable-deploy.yml
name: Reusable Deploy

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      image_tag:
        required: true
        type: string
      cluster_name:
        required: true
        type: string
    secrets:
      AWS_ROLE_ARN:
        required: true
      SLACK_WEBHOOK_URL:
        required: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}

    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-northeast-2

      - name: Update kubeconfig
        run: |
          aws eks update-kubeconfig --name ${{ inputs.cluster_name }} --region ap-northeast-2

      - name: Deploy with Kustomize
        run: |
          cd k8s/overlays/${{ inputs.environment }}
          kustomize edit set image my-app=ghcr.io/${{ github.repository }}:${{ inputs.image_tag }}
          kubectl apply -k .

      - name: Wait for rollout
        run: |
          kubectl rollout status deployment/my-app -n my-app-${{ inputs.environment }} --timeout=300s

      - name: Smoke test
        run: |
          ENDPOINT=$(kubectl get ingress my-app -n my-app-${{ inputs.environment }} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
          curl -sf "https://${ENDPOINT}/health" || exit 1

      - name: Notify
        if: always()
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "${{ job.status == 'success' && '✅' || '❌' }} [${{ inputs.environment }}] 배포 ${{ job.status }}: ${{ github.repository }}@${{ inputs.image_tag }}"
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

### 환경별 배포 파이프라인

```yaml
# .github/workflows/cd-prod.yml
name: Deploy Production

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      image_tag:
        description: '배포할 이미지 태그'
        required: true

jobs:
  # 1단계: 빌드
  build:
    uses: ./.github/workflows/reusable-build.yml
    with:
      environment: prod
      image_tag: ${{ github.event.inputs.image_tag || github.sha }}
    permissions:
      contents: read
      packages: write

  # 2단계: dev 배포
  deploy-dev:
    needs: build
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: dev
      image_tag: ${{ github.event.inputs.image_tag || github.sha }}
      cluster_name: dev-cluster
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN_DEV }}
      SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

  # 3단계: staging 배포
  deploy-staging:
    needs: deploy-dev
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: staging
      image_tag: ${{ github.event.inputs.image_tag || github.sha }}
      cluster_name: staging-cluster
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN_STAGING }}
      SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}

  # 4단계: prod 배포 (수동 승인 필요)
  deploy-prod:
    needs: deploy-staging
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: production    # GitHub Environment 승인 필요
      image_tag: ${{ github.event.inputs.image_tag || github.sha }}
      cluster_name: prod-cluster
    secrets:
      AWS_ROLE_ARN: ${{ secrets.AWS_ROLE_ARN_PROD }}
      SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK_URL }}
```

---

## 매트릭스 빌드

```yaml
# 멀티 버전, 멀티 OS 테스트
jobs:
  test:
    strategy:
      fail-fast: false    # 하나 실패해도 나머지 계속
      matrix:
        node-version: [18, 20, 22]
        os: [ubuntu-latest, macos-latest]
        exclude:
          - os: macos-latest
            node-version: 18
        include:
          - node-version: 20
            os: ubuntu-latest
            coverage: true    # 커버리지는 한 조합만

    runs-on: ${{ matrix.os }}

    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: 'npm'

      - run: npm ci
      - run: npm test ${{ matrix.coverage && '-- --coverage' || '' }}

      - name: Upload coverage
        if: matrix.coverage
        uses: codecov/codecov-action@v4
```

---

## 캐싱 전략

### 의존성 캐싱

```yaml
# Node.js - 내장 캐싱
- uses: actions/setup-node@v4
  with:
    node-version: 20
    cache: 'npm'

# Python - pip 캐싱
- uses: actions/setup-python@v5
  with:
    python-version: '3.12'
    cache: 'pip'

# Go - 내장 캐싱
- uses: actions/setup-go@v5
  with:
    go-version: '1.22'
    # cache: true (기본 활성화)
```

### 커스텀 캐싱

```yaml
# Gradle 캐싱
- name: Cache Gradle
  uses: actions/cache@v4
  with:
    path: |
      ~/.gradle/caches
      ~/.gradle/wrapper
    key: gradle-${{ runner.os }}-${{ hashFiles('**/*.gradle*', '**/gradle-wrapper.properties') }}
    restore-keys: |
      gradle-${{ runner.os }}-

# Docker 레이어 캐싱 (Buildx)
- uses: docker/build-push-action@v5
  with:
    cache-from: type=gha
    cache-to: type=gha,mode=max

# 빌드 산출물 캐싱
- name: Cache build output
  uses: actions/cache@v4
  with:
    path: dist/
    key: build-${{ hashFiles('src/**', 'package-lock.json') }}
```

### Turborepo 캐싱 (모노레포)

```yaml
- name: Cache Turbo
  uses: actions/cache@v4
  with:
    path: .turbo
    key: turbo-${{ github.sha }}
    restore-keys: turbo-

- name: Build
  run: npx turbo build --cache-dir=.turbo
```

---

## PR 자동 검증

### 종합 PR 체크

```yaml
# .github/workflows/ci.yml
name: PR Check

on:
  pull_request:
    branches: [main, develop]

concurrency:
  group: pr-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  # ===== 코드 품질 =====
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'
      - run: npm ci
      - run: npm run lint
      - run: npm run type-check

  # ===== 테스트 =====
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16-alpine
        env:
          POSTGRES_PASSWORD: test
        ports: ['5432:5432']
        options: --health-cmd pg_isready --health-interval 10s --health-timeout 5s --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'
      - run: npm ci
      - run: npm test -- --coverage
      - name: Coverage comment
        uses: MishaKav/jest-coverage-comment@main
        with:
          coverage-summary-path: coverage/coverage-summary.json

  # ===== 빌드 =====
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'
      - run: npm ci
      - run: npm run build

  # ===== Docker 빌드 검증 =====
  docker-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v5
        with:
          context: .
          push: false
          cache-from: type=gha

  # ===== 보안 스캐닝 =====
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Dependency audit
        run: npm audit --audit-level=high
      - name: Secret scanning
        uses: trufflesecurity/trufflehog@main
        with:
          extra_args: --only-verified

  # ===== PR 사이즈 체크 =====
  pr-size:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Check PR size
        run: |
          CHANGES=$(git diff --stat origin/main...HEAD | tail -1 | awk '{print $4}')
          if [ "${CHANGES:-0}" -gt 500 ]; then
            echo "::warning::PR이 ${CHANGES}줄 변경을 포함합니다. 작은 단위로 분리를 고려하세요."
          fi
```

---

## GitLab CI vs GitHub Actions 비교

| 기능 | GitHub Actions | GitLab CI |
|------|---------------|-----------|
| 설정 파일 | `.github/workflows/*.yml` | `.gitlab-ci.yml` |
| 실행 환경 | Runner (GitHub 호스팅) | Runner (자체 호스팅 가능) |
| 캐싱 | `actions/cache` | `cache:` 키워드 |
| 시크릿 | Repository Secrets | CI/CD Variables |
| 환경 보호 | Environments | Protected Environments |
| 아티팩트 | `actions/upload-artifact` | `artifacts:` 키워드 |
| 매트릭스 | `strategy.matrix` | `parallel:matrix` |
| 재사용 | Reusable workflows | `include:` |

### GitLab CI 동등 설정

```yaml
# .gitlab-ci.yml
stages:
  - lint
  - test
  - build
  - deploy

variables:
  NODE_VERSION: "20"

# 캐시
.node-cache: &node-cache
  cache:
    key:
      files:
        - package-lock.json
    paths:
      - node_modules/
    policy: pull-push

lint:
  stage: lint
  image: node:${NODE_VERSION}-alpine
  <<: *node-cache
  script:
    - npm ci
    - npm run lint
    - npm run type-check
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == "main"

test:
  stage: test
  image: node:${NODE_VERSION}-alpine
  <<: *node-cache
  services:
    - postgres:16-alpine
  variables:
    POSTGRES_PASSWORD: test
    DATABASE_URL: postgresql://postgres:test@postgres:5432/test
  script:
    - npm ci
    - npm test -- --coverage
  coverage: '/All files\s*\|\s*[\d.]+/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage/cobertura-coverage.xml

build:
  stage: build
  image: docker:24
  services:
    - docker:24-dind
  script:
    - docker build -t ${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHORT_SHA} .
    - docker push ${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHORT_SHA}
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

deploy-prod:
  stage: deploy
  image: bitnami/kubectl:latest
  environment:
    name: production
    url: https://app.example.com
  script:
    - kubectl set image deployment/my-app app=${CI_REGISTRY_IMAGE}:${CI_COMMIT_SHORT_SHA}
    - kubectl rollout status deployment/my-app --timeout=300s
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
      when: manual    # 수동 승인
```

---

## CODEOWNERS

```
# .github/CODEOWNERS

# 전체
* @team-lead

# 인프라
.github/workflows/ @devops-team
terraform/ @devops-team
k8s/ @devops-team
Dockerfile @devops-team

# 백엔드
src/api/ @backend-team
src/services/ @backend-team

# 프론트엔드
src/components/ @frontend-team
src/pages/ @frontend-team
```

---

## 체크리스트

- [ ] 멀티 환경 파이프라인 (dev → staging → prod)
- [ ] 재사용 가능한 워크플로우 (workflow_call)
- [ ] 매트릭스 빌드로 멀티 버전 테스트
- [ ] 의존성 캐싱 최적화
- [ ] PR마다 lint + test + build + security 검증
- [ ] 커버리지 리포트 PR 코멘트
- [ ] Environment 보호 규칙 (프로덕션 승인)
- [ ] concurrency 설정으로 중복 방지
- [ ] CODEOWNERS 설정
- [ ] 시크릿 스캐닝 자동화
