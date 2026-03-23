# Kubernetes - Large Scale

> 멀티 클러스터, 서비스 메시, GitOps, 보안 강화, 옵저버빌리티

---

## 적용 대상

- 8명 이상 팀, 여러 팀/조직 협업
- 15개 이상 서비스, 멀티 클러스터
- 높은 보안, 감사, 컴플라이언스 요구사항
- 자동화된 GitOps 워크플로우

---

## 프로젝트 구조

```
platform/
├── clusters/
│   ├── prod-apne2/              # ap-northeast-2 프로덕션
│   │   ├── flux-system/
│   │   ├── infrastructure/
│   │   │   ├── sources/
│   │   │   ├── controllers/
│   │   │   └── configs/
│   │   └── apps/
│   │       ├── my-app/
│   │       └── my-api/
│   ├── staging/
│   │   └── ...
│   └── dev/
│       └── ...
├── infrastructure/
│   ├── cert-manager/
│   ├── ingress-nginx/
│   ├── monitoring/
│   │   ├── prometheus/
│   │   ├── grafana/
│   │   └── alertmanager/
│   ├── istio/
│   └── policies/
│       ├── network-policies/
│       ├── pod-security/
│       └── opa-gatekeeper/
├── apps/
│   ├── base/
│   │   └── my-app/
│   └── overlays/
│       ├── dev/
│       ├── staging/
│       └── prod/
└── scripts/
    ├── bootstrap.sh
    └── rotate-secrets.sh
```

---

## GitOps (ArgoCD)

### ArgoCD 설치

```bash
# ArgoCD 설치
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# 초기 비밀번호 확인
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# CLI 로그인
argocd login argocd.example.com
```

### Application 정의

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app-prod
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: production
  source:
    repoURL: https://github.com/org/platform.git
    targetRevision: main
    path: apps/overlays/prod/my-app
  destination:
    server: https://kubernetes.default.svc
    namespace: my-app-prod
  syncPolicy:
    automated:
      prune: true             # 삭제된 리소스 정리
      selfHeal: true          # 수동 변경 자동 복원
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

### ApplicationSet (멀티 클러스터)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: my-app
  namespace: argocd
spec:
  generators:
    - matrix:
        generators:
          - git:
              repoURL: https://github.com/org/platform.git
              revision: main
              directories:
                - path: apps/overlays/*
          - clusters:
              selector:
                matchLabels:
                  env: production
  template:
    metadata:
      name: '{{path.basename}}-{{name}}'
    spec:
      project: production
      source:
        repoURL: https://github.com/org/platform.git
        targetRevision: main
        path: '{{path}}'
      destination:
        server: '{{server}}'
        namespace: my-app
```

### GitOps (Flux)

```yaml
# flux-system/gotk-sync.yaml
apiVersion: source.toolkit.fluxcd.io/v1
kind: GitRepository
metadata:
  name: platform
  namespace: flux-system
spec:
  interval: 1m
  url: https://github.com/org/platform.git
  ref:
    branch: main
  secretRef:
    name: flux-ssh
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: infrastructure
  namespace: flux-system
spec:
  interval: 10m
  sourceRef:
    kind: GitRepository
    name: platform
  path: ./infrastructure
  prune: true
  wait: true
---
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  name: apps
  namespace: flux-system
spec:
  interval: 5m
  dependsOn:
    - name: infrastructure
  sourceRef:
    kind: GitRepository
    name: platform
  path: ./apps/overlays/prod
  prune: true
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: my-app
      namespace: my-app-prod
```

---

## 서비스 메시 (Istio)

### 설치

```bash
# istioctl 설치
curl -L https://istio.io/downloadIstio | sh -

# 프로필 기반 설치
istioctl install --set profile=production

# Namespace에 사이드카 주입 활성화
kubectl label namespace my-app-prod istio-injection=enabled
```

### VirtualService (트래픽 라우팅)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: my-app
  namespace: my-app-prod
spec:
  hosts:
    - my-app
  http:
    # 카나리 배포: 10% 트래픽을 v2로
    - match:
        - headers:
            x-canary:
              exact: "true"
      route:
        - destination:
            host: my-app
            subset: v2
    - route:
        - destination:
            host: my-app
            subset: v1
          weight: 90
        - destination:
            host: my-app
            subset: v2
          weight: 10
      retries:
        attempts: 3
        perTryTimeout: 2s
      timeout: 10s
---
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-app
  namespace: my-app-prod
spec:
  host: my-app
  trafficPolicy:
    connectionPool:
      http:
        h2UpgradePolicy: DEFAULT
        maxRequestsPerConnection: 100
      tcp:
        maxConnections: 100
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
  subsets:
    - name: v1
      labels:
        version: v1
    - name: v2
      labels:
        version: v2
```

### Circuit Breaker

```yaml
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: my-app-circuit-breaker
spec:
  host: my-app
  trafficPolicy:
    connectionPool:
      tcp:
        maxConnections: 100
      http:
        h2UpgradePolicy: DEFAULT
        maxRequestsPerConnection: 10
        maxRetries: 3
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 10s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
```

---

## Pod Security Standards

### Pod Security Admission (PSA)

```yaml
# Namespace에 보안 정책 적용
apiVersion: v1
kind: Namespace
metadata:
  name: my-app-prod
  labels:
    # enforce: 위반 시 거부
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    # audit: 감사 로그 기록
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/audit-version: latest
    # warn: 경고 표시
    pod-security.kubernetes.io/warn: restricted
    pod-security.kubernetes.io/warn-version: latest
```

### restricted 정책 준수 Pod 예시

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65532
        runAsGroup: 65532
        fsGroup: 65532
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: app
          image: registry.example.com/my-app:v1.0.0
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop:
                - ALL
          volumeMounts:
            - name: tmp
              mountPath: /tmp
      volumes:
        - name: tmp
          emptyDir: {}
```

---

## Network Policy

```yaml
# 기본: 모든 트래픽 차단
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
  namespace: my-app-prod
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
---
# 앱 → DB 허용
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: app-to-db
  namespace: my-app-prod
spec:
  podSelector:
    matchLabels:
      app: my-db
  policyTypes:
    - Ingress
  ingress:
    - from:
        - podSelector:
            matchLabels:
              app: my-app
      ports:
        - protocol: TCP
          port: 5432
---
# DNS 허용 (CoreDNS)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: my-app-prod
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
---
# Ingress → 앱 허용
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ingress-to-app
  namespace: my-app-prod
spec:
  podSelector:
    matchLabels:
      app: my-app
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ingress-nginx
      ports:
        - protocol: TCP
          port: 3000
```

---

## 모니터링 스택 (Prometheus + Grafana)

### kube-prometheus-stack 설치

```bash
# Helm 레포지토리 추가
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 설치
helm install monitoring prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f monitoring-values.yaml
```

### monitoring-values.yaml

```yaml
prometheus:
  prometheusSpec:
    retention: 30d
    retentionSize: 50GB
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: gp3
          resources:
            requests:
              storage: 100Gi
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false

grafana:
  adminPassword: "${GRAFANA_ADMIN_PASSWORD}"
  persistence:
    enabled: true
    size: 10Gi
  dashboardProviders:
    dashboardproviders.yaml:
      apiVersion: 1
      providers:
        - name: default
          folder: ''
          type: file
          options:
            path: /var/lib/grafana/dashboards/default

alertmanager:
  config:
    global:
      slack_api_url: "${SLACK_WEBHOOK_URL}"
    route:
      receiver: slack
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 4h
      routes:
        - match:
            severity: critical
          receiver: slack-critical
    receivers:
      - name: slack
        slack_configs:
          - channel: '#alerts'
            title: '{{ .GroupLabels.alertname }}'
            text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
      - name: slack-critical
        slack_configs:
          - channel: '#alerts-critical'
            title: 'CRITICAL: {{ .GroupLabels.alertname }}'
```

### ServiceMonitor

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  namespace: my-app-prod
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: http
      path: /metrics
      interval: 30s
```

### PrometheusRule (알림 규칙)

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: my-app-alerts
  namespace: my-app-prod
spec:
  groups:
    - name: my-app
      rules:
        - alert: HighErrorRate
          expr: |
            sum(rate(http_requests_total{job="my-app",status=~"5.."}[5m]))
            /
            sum(rate(http_requests_total{job="my-app"}[5m]))
            > 0.05
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "높은 에러율 감지"
            description: "{{ $labels.instance }} 에서 5분간 에러율이 {{ $value | humanizePercentage }} 입니다."

        - alert: HighLatency
          expr: |
            histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket{job="my-app"}[5m])) by (le))
            > 1
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "높은 응답 시간"
            description: "P99 응답 시간이 {{ $value }}초 입니다."

        - alert: PodCrashLooping
          expr: |
            increase(kube_pod_container_status_restarts_total{namespace="my-app-prod"}[1h]) > 3
          for: 5m
          labels:
            severity: warning
          annotations:
            summary: "Pod 반복 재시작"
            description: "{{ $labels.pod }} 가 1시간 내 {{ $value }}회 재시작되었습니다."
```

---

## 비용 최적화

### Spot/Preemptible 노드 활용

```yaml
# Spot 노드에 배포 (비용 70%+ 절감)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: worker
spec:
  template:
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
              - matchExpressions:
                  - key: node.kubernetes.io/lifecycle
                    operator: In
                    values:
                      - spot
      tolerations:
        - key: "spot"
          operator: "Equal"
          value: "true"
          effect: "NoSchedule"
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: worker
```

### VPA (Vertical Pod Autoscaler)

```yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: my-app-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  updatePolicy:
    updateMode: "Off"       # 권장 값만 표시 (Auto로 변경 시 자동 적용)
  resourcePolicy:
    containerPolicies:
      - containerName: app
        minAllowed:
          cpu: 50m
          memory: 64Mi
        maxAllowed:
          cpu: "2"
          memory: 2Gi
```

```bash
# VPA 권장 값 확인
kubectl describe vpa my-app-vpa -n my-app-prod
```

### 노드 관리

```bash
# 노드 drain (유지보수)
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# 노드 cordon (스케줄링 비활성화)
kubectl cordon <node-name>

# 노드 uncordon
kubectl uncordon <node-name>

# 노드별 리소스 사용량
kubectl top nodes
kubectl top pods -n my-app-prod --sort-by=memory
```

---

## 멀티 클러스터 운영

```
┌─────────────────────────────────────────────────┐
│                  관리 클러스터                     │
│  ┌───────────┐  ┌───────────┐  ┌──────────────┐│
│  │  ArgoCD   │  │ Prometheus│  │ OPA Gateway  ││
│  └─────┬─────┘  └─────┬─────┘  └──────┬───────┘│
└────────┼───────────────┼───────────────┼────────┘
         │               │               │
    ┌────▼────┐    ┌─────▼────┐    ┌─────▼────┐
    │Prod 클러│    │Staging   │    │Dev 클러스│
    │스터     │    │클러스터   │    │터        │
    │(3 nodes)│    │(2 nodes) │    │(1 node)  │
    └─────────┘    └──────────┘    └──────────┘
```

---

## 체크리스트

- [ ] GitOps 도구 (ArgoCD/Flux) 도입
- [ ] Pod Security Standards (restricted) 적용
- [ ] Network Policy로 트래픽 격리
- [ ] 서비스 메시 도입 여부 평가 (Istio/Linkerd)
- [ ] Prometheus + Grafana 모니터링 스택 구축
- [ ] 알림 규칙 (PrometheusRule) 설정
- [ ] ServiceMonitor로 메트릭 수집
- [ ] Spot/Preemptible 노드 활용
- [ ] VPA로 리소스 최적화
- [ ] topologySpreadConstraints로 AZ 분산
- [ ] 멀티 클러스터 관리 전략 수립
- [ ] OPA/Gatekeeper로 정책 관리
