# CI/CD - Large Scale

> 모노레포 CI/CD, 고급 배포 전략, 보안 스캐닝, 릴리스 자동화

---

## 적용 대상

- 8명 이상 팀, 15개 이상 서비스
- 모노레포 또는 대규모 멀티레포
- 카나리/블루그린 배포
- 엄격한 보안 및 컴플라이언스 요구

---

## 프로젝트 구조 (모노레포)

```
monorepo/
├── .github/
│   ├── workflows/
│   │   ├── ci.yml                    # 변경 감지 + 동적 빌드
│   │   ├── cd.yml                    # 환경별 배포
│   │   ├── security-scan.yml         # 보안 스캐닝
│   │   └── release.yml               # 릴리스 자동화
│   └── actions/
│       ├── detect-changes/
│       │   └── action.yml
│       ├── build-service/
│       │   └── action.yml
│       └── deploy-service/
│           └── action.yml
├── packages/
│   ├── shared-lib/                   # 공유 라이브러리
│   ├── api-gateway/                  # 서비스 1
│   ├── user-service/                 # 서비스 2
│   ├── order-service/                # 서비스 3
│   └── notification-service/         # 서비스 4
├── infrastructure/
│   ├── terraform/
│   └── k8s/
├── turbo.json                        # Turborepo 설정
├── pnpm-workspace.yaml
└── package.json
```

---

## 변경 감지 기반 빌드

### 변경 감지 액션

```yaml
# .github/actions/detect-changes/action.yml
name: Detect Changes
description: 변경된 서비스 감지

outputs:
  services:
    description: "변경된 서비스 JSON 배열"
    value: ${{ steps.changes.outputs.services }}
  has_changes:
    description: "변경 여부"
    value: ${{ steps.changes.outputs.has_changes }}

runs:
  using: composite
  steps:
    - name: Get changed files
      id: changed
      uses: tj-actions/changed-files@v44
      with:
        json: true

    - name: Detect service changes
      id: changes
      shell: bash
      run: |
        CHANGED_FILES='${{ steps.changed.outputs.all_changed_files }}'
        SERVICES=()

        # 각 서비스의 변경 여부 확인
        for service in api-gateway user-service order-service notification-service; do
          if echo "${CHANGED_FILES}" | grep -q "packages/${service}/"; then
            SERVICES+=("${service}")
          fi
        done

        # 공유 라이브러리 변경 시 모든 서비스 빌드
        if echo "${CHANGED_FILES}" | grep -q "packages/shared-lib/"; then
          SERVICES=("api-gateway" "user-service" "order-service" "notification-service")
        fi

        # 인프라 변경 감지
        if echo "${CHANGED_FILES}" | grep -q "infrastructure/"; then
          SERVICES+=("infrastructure")
        fi

        # 중복 제거 및 JSON 출력
        UNIQUE_SERVICES=($(echo "${SERVICES[@]}" | tr ' ' '\n' | sort -u))

        if [ ${#UNIQUE_SERVICES[@]} -eq 0 ]; then
          echo "services=[]" >> $GITHUB_OUTPUT
          echo "has_changes=false" >> $GITHUB_OUTPUT
        else
          JSON=$(printf '%s\n' "${UNIQUE_SERVICES[@]}" | jq -R . | jq -s .)
          echo "services=${JSON}" >> $GITHUB_OUTPUT
          echo "has_changes=true" >> $GITHUB_OUTPUT
        fi
```

### 모노레포 CI

```yaml
# .github/workflows/ci.yml
name: Monorepo CI

on:
  pull_request:
    branches: [main]

concurrency:
  group: ci-${{ github.event.pull_request.number }}
  cancel-in-progress: true

jobs:
  detect:
    runs-on: ubuntu-latest
    outputs:
      services: ${{ steps.detect.outputs.services }}
      has_changes: ${{ steps.detect.outputs.has_changes }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - id: detect
        uses: ./.github/actions/detect-changes

  lint-and-test:
    needs: detect
    if: needs.detect.outputs.has_changes == 'true'
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        service: ${{ fromJson(needs.detect.outputs.services) }}
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v3
        with:
          version: 9

      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'pnpm'

      - run: pnpm install --frozen-lockfile

      - name: Lint
        run: pnpm --filter ${{ matrix.service }} lint

      - name: Test
        run: pnpm --filter ${{ matrix.service }} test

      - name: Build
        run: pnpm --filter ${{ matrix.service }} build

  docker-build:
    needs: detect
    if: needs.detect.outputs.has_changes == 'true'
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        service: ${{ fromJson(needs.detect.outputs.services) }}
        exclude:
          - service: infrastructure
          - service: shared-lib
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - uses: docker/build-push-action@v5
        with:
          context: .
          file: packages/${{ matrix.service }}/Dockerfile
          push: false
          cache-from: type=gha,scope=${{ matrix.service }}
          cache-to: type=gha,scope=${{ matrix.service }},mode=max
```

### Turborepo 활용

```json
// turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": [".env"],
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**"],
      "cache": true
    },
    "lint": {
      "cache": true
    },
    "test": {
      "dependsOn": ["build"],
      "cache": false
    },
    "deploy": {
      "dependsOn": ["build", "test", "lint"],
      "cache": false
    }
  }
}
```

```yaml
# Turborepo + Remote Cache
- name: Build affected
  env:
    TURBO_TOKEN: ${{ secrets.TURBO_TOKEN }}
    TURBO_TEAM: ${{ secrets.TURBO_TEAM }}
  run: |
    pnpm turbo build --filter=...[origin/main] --cache-dir=.turbo
```

---

## 카나리 / 블루그린 배포

### 카나리 배포 (Kubernetes + Istio)

```yaml
# .github/workflows/canary-deploy.yml
name: Canary Deploy

on:
  workflow_dispatch:
    inputs:
      service:
        description: '배포할 서비스'
        required: true
        type: choice
        options: [api-gateway, user-service, order-service]
      image_tag:
        description: '이미지 태그'
        required: true

jobs:
  canary:
    runs-on: ubuntu-latest
    environment: production-canary
    steps:
      - uses: actions/checkout@v4

      - name: Configure kubectl
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-northeast-2

      - name: Update kubeconfig
        run: aws eks update-kubeconfig --name prod-cluster

      # 1단계: 카나리 Deployment 생성 (10%)
      - name: Deploy canary
        run: |
          cat <<EOF | kubectl apply -f -
          apiVersion: apps/v1
          kind: Deployment
          metadata:
            name: ${{ inputs.service }}-canary
            namespace: production
            labels:
              app: ${{ inputs.service }}
              version: canary
          spec:
            replicas: 1
            selector:
              matchLabels:
                app: ${{ inputs.service }}
                version: canary
            template:
              metadata:
                labels:
                  app: ${{ inputs.service }}
                  version: canary
              spec:
                containers:
                  - name: app
                    image: ghcr.io/${{ github.repository }}/${{ inputs.service }}:${{ inputs.image_tag }}
          EOF

      # 2단계: Istio VirtualService 업데이트 (10% 트래픽)
      - name: Route 10% traffic to canary
        run: |
          cat <<EOF | kubectl apply -f -
          apiVersion: networking.istio.io/v1beta1
          kind: VirtualService
          metadata:
            name: ${{ inputs.service }}
            namespace: production
          spec:
            hosts:
              - ${{ inputs.service }}
            http:
              - route:
                  - destination:
                      host: ${{ inputs.service }}
                      subset: stable
                    weight: 90
                  - destination:
                      host: ${{ inputs.service }}
                      subset: canary
                    weight: 10
          EOF

      # 3단계: 모니터링 (5분)
      - name: Monitor canary
        run: |
          echo "카나리 배포 모니터링 중 (5분)..."
          sleep 300

          # 에러율 체크 (Prometheus)
          ERROR_RATE=$(curl -s "http://prometheus:9090/api/v1/query" \
            --data-urlencode "query=sum(rate(http_requests_total{app=\"${{ inputs.service }}\",version=\"canary\",status=~\"5..\"}[5m])) / sum(rate(http_requests_total{app=\"${{ inputs.service }}\",version=\"canary\"}[5m]))" \
            | jq -r '.data.result[0].value[1] // "0"')

          echo "카나리 에러율: ${ERROR_RATE}"

          if (( $(echo "${ERROR_RATE} > 0.05" | bc -l) )); then
            echo "에러율 5% 초과. 롤백합니다."
            exit 1
          fi

      # 4단계: 점진적 트래픽 증가
      - name: Promote to 50%
        run: |
          # 50% 트래픽으로 증가
          kubectl patch virtualservice ${{ inputs.service }} -n production \
            --type=json -p='[
              {"op":"replace","path":"/spec/http/0/route/0/weight","value":50},
              {"op":"replace","path":"/spec/http/0/route/1/weight","value":50}
            ]'
          sleep 180

      # 5단계: 전체 전환
      - name: Full promotion
        run: |
          # Stable deployment 업데이트
          kubectl set image deployment/${{ inputs.service }} \
            app=ghcr.io/${{ github.repository }}/${{ inputs.service }}:${{ inputs.image_tag }} \
            -n production

          kubectl rollout status deployment/${{ inputs.service }} -n production --timeout=300s

          # 카나리 정리
          kubectl delete deployment ${{ inputs.service }}-canary -n production
          kubectl patch virtualservice ${{ inputs.service }} -n production \
            --type=json -p='[
              {"op":"replace","path":"/spec/http/0/route/0/weight","value":100},
              {"op":"remove","path":"/spec/http/0/route/1"}
            ]'

  rollback:
    needs: canary
    if: failure()
    runs-on: ubuntu-latest
    steps:
      - name: Rollback canary
        run: |
          kubectl delete deployment ${{ inputs.service }}-canary -n production --ignore-not-found
          kubectl patch virtualservice ${{ inputs.service }} -n production \
            --type=json -p='[
              {"op":"replace","path":"/spec/http/0/route/0/weight","value":100}
            ]'
          echo "카나리 롤백 완료"
```

### 블루그린 배포

```yaml
  blue-green:
    runs-on: ubuntu-latest
    steps:
      # 현재 활성 슬롯 확인
      - name: Check active slot
        id: active
        run: |
          ACTIVE=$(kubectl get svc ${{ inputs.service }} -n production \
            -o jsonpath='{.spec.selector.slot}')
          echo "active=${ACTIVE}" >> $GITHUB_OUTPUT
          echo "inactive=$([ ${ACTIVE} = 'blue' ] && echo 'green' || echo 'blue')" >> $GITHUB_OUTPUT

      # 비활성 슬롯에 배포
      - name: Deploy to inactive slot
        run: |
          kubectl set image deployment/${{ inputs.service }}-${{ steps.active.outputs.inactive }} \
            app=ghcr.io/${{ github.repository }}/${{ inputs.service }}:${{ inputs.image_tag }} \
            -n production
          kubectl rollout status deployment/${{ inputs.service }}-${{ steps.active.outputs.inactive }} \
            -n production --timeout=300s

      # 스모크 테스트
      - name: Smoke test inactive slot
        run: |
          INACTIVE_SVC="${{ inputs.service }}-${{ steps.active.outputs.inactive }}"
          kubectl port-forward svc/${INACTIVE_SVC} 8080:80 -n production &
          sleep 5
          curl -sf http://localhost:8080/health
          kill %1

      # 트래픽 전환
      - name: Switch traffic
        run: |
          kubectl patch svc ${{ inputs.service }} -n production \
            -p '{"spec":{"selector":{"slot":"${{ steps.active.outputs.inactive }}"}}}'
```

---

## 보안 스캐닝 파이프라인

```yaml
# .github/workflows/security-scan.yml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 3 * * 1'    # 매주 월요일 새벽 3시

permissions:
  contents: read
  security-events: write

jobs:
  # ===== SAST (정적 분석) =====
  sast:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: CodeQL Analysis
        uses: github/codeql-action/init@v3
        with:
          languages: javascript, typescript

      - name: Autobuild
        uses: github/codeql-action/autobuild@v3

      - name: Perform Analysis
        uses: github/codeql-action/analyze@v3

      - name: Semgrep
        uses: returntocorp/semgrep-action@v1
        with:
          config: >-
            p/javascript
            p/typescript
            p/security-audit
            p/owasp-top-ten

  # ===== SCA (의존성 취약점) =====
  sca:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Dependency Review
        if: github.event_name == 'pull_request'
        uses: actions/dependency-review-action@v4
        with:
          fail-on-severity: high

      - name: Snyk
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

  # ===== 컨테이너 스캐닝 =====
  container-scan:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        service: [api-gateway, user-service, order-service]
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t ${{ matrix.service }}:scan -f packages/${{ matrix.service }}/Dockerfile .

      - name: Trivy scan
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ matrix.service }}:scan
          format: 'sarif'
          output: 'trivy-${{ matrix.service }}.sarif'
          severity: 'CRITICAL,HIGH'

      - name: Upload results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: trivy-${{ matrix.service }}.sarif

  # ===== 시크릿 스캐닝 =====
  secret-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: TruffleHog
        uses: trufflesecurity/trufflehog@main
        with:
          extra_args: --only-verified --since-commit=${{ github.event.before || 'HEAD~1' }}

      - name: Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}

  # ===== DAST (동적 분석) =====
  dast:
    if: github.event_name == 'schedule'
    runs-on: ubuntu-latest
    steps:
      - name: OWASP ZAP Baseline Scan
        uses: zaproxy/action-baseline@v0.12.0
        with:
          target: 'https://staging-api.example.com'
          rules_file_name: '.zap/rules.tsv'
```

---

## 아티팩트 관리 및 릴리스 자동화

### 자동 릴리스 (semantic-release)

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    branches: [main]

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      packages: write
      issues: write
      pull-requests: write

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          persist-credentials: false

      - uses: actions/setup-node@v4
        with:
          node-version: 20

      - name: Semantic Release
        uses: cycjimmy/semantic-release-action@v4
        with:
          extra_plugins: |
            @semantic-release/changelog
            @semantic-release/git
            conventional-changelog-conventionalcommits
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### .releaserc.json

```json
{
  "branches": ["main"],
  "plugins": [
    ["@semantic-release/commit-analyzer", {
      "preset": "conventionalcommits",
      "releaseRules": [
        { "type": "feat", "release": "minor" },
        { "type": "fix", "release": "patch" },
        { "type": "perf", "release": "patch" },
        { "breaking": true, "release": "major" }
      ]
    }],
    ["@semantic-release/release-notes-generator", {
      "preset": "conventionalcommits"
    }],
    "@semantic-release/changelog",
    ["@semantic-release/git", {
      "assets": ["CHANGELOG.md", "package.json"],
      "message": "chore(release): ${nextRelease.version}"
    }],
    "@semantic-release/github"
  ]
}
```

---

## 체크리스트

- [ ] 변경 감지 기반 빌드 (모노레포)
- [ ] Turborepo/Nx로 빌드 캐싱 최적화
- [ ] 카나리 또는 블루그린 배포 전략 구현
- [ ] SAST (CodeQL/Semgrep) CI 통합
- [ ] SCA (의존성 취약점) 스캐닝
- [ ] 컨테이너 이미지 스캐닝 (Trivy)
- [ ] 시크릿 스캐닝 (TruffleHog/Gitleaks)
- [ ] DAST 정기 스캐닝 (ZAP)
- [ ] semantic-release로 릴리스 자동화
- [ ] 모니터링 기반 자동 롤백
- [ ] 아티팩트 보관 정책 수립
