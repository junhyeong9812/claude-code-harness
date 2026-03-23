# Kubernetes - Medium Scale

> Namespace 전략, RBAC, Helm, HPA, Kustomize를 활용한 중규모 클러스터 운영

---

## 적용 대상

- 3~8명 팀, 3~15개 서비스
- 환경별 클러스터 또는 Namespace 분리
- 자동 스케일링, 권한 관리 필요

---

## 프로젝트 구조

### Kustomize 기반

```
k8s/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── configmap.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   └── pvc.yaml
├── overlays/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   ├── patch-deployment.yaml
│   │   └── configmap.yaml
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   ├── patch-deployment.yaml
│   │   └── configmap.yaml
│   └── prod/
│       ├── kustomization.yaml
│       ├── patch-deployment.yaml
│       ├── patch-hpa.yaml
│       └── configmap.yaml
└── components/
    ├── monitoring/
    │   ├── kustomization.yaml
    │   └── service-monitor.yaml
    └── network-policy/
        ├── kustomization.yaml
        └── network-policy.yaml
```

### Helm 기반

```
helm/
├── my-app/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-dev.yaml
│   ├── values-staging.yaml
│   ├── values-prod.yaml
│   └── templates/
│       ├── _helpers.tpl
│       ├── deployment.yaml
│       ├── service.yaml
│       ├── configmap.yaml
│       ├── secret.yaml
│       ├── ingress.yaml
│       ├── hpa.yaml
│       ├── pvc.yaml
│       ├── serviceaccount.yaml
│       ├── rbac.yaml
│       └── NOTES.txt
└── charts/               # 의존성 차트
```

---

## Namespace 전략

```yaml
# 환경별 Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: my-app-prod
  labels:
    app: my-app
    env: production
    team: backend
  annotations:
    description: "프로덕션 환경"
---
# 리소스 쿼터
apiVersion: v1
kind: ResourceQuota
metadata:
  name: resource-quota
  namespace: my-app-prod
spec:
  hard:
    requests.cpu: "8"
    requests.memory: 16Gi
    limits.cpu: "16"
    limits.memory: 32Gi
    pods: "50"
    services: "20"
    persistentvolumeclaims: "10"
---
# LimitRange (기본 리소스 제한)
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: my-app-prod
spec:
  limits:
    - default:           # 기본 limits
        cpu: 500m
        memory: 256Mi
      defaultRequest:    # 기본 requests
        cpu: 100m
        memory: 128Mi
      max:               # 최대 허용
        cpu: "2"
        memory: 2Gi
      min:               # 최소 허용
        cpu: 50m
        memory: 64Mi
      type: Container
```

---

## RBAC (역할 기반 접근 제어)

### 개발자 역할

```yaml
# 개발자용 Role (Namespace 범위)
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer
  namespace: my-app-dev
rules:
  - apiGroups: [""]
    resources: ["pods", "pods/log", "pods/exec", "services", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: [""]
    resources: ["pods/portforward"]
    verbs: ["create"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: developer-binding
  namespace: my-app-dev
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: developer
subjects:
  - kind: User
    name: developer@example.com
    apiGroup: rbac.authorization.k8s.io
  - kind: Group
    name: developers
    apiGroup: rbac.authorization.k8s.io
```

### 운영자 역할

```yaml
# 운영자용 ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: operator
rules:
  - apiGroups: ["", "apps", "batch", "networking.k8s.io"]
    resources: ["*"]
    verbs: ["get", "list", "watch", "create", "update", "patch"]
  - apiGroups: [""]
    resources: ["secrets"]
    verbs: ["get", "list"]    # 시크릿은 읽기만
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: operator-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: operator
subjects:
  - kind: Group
    name: operators
    apiGroup: rbac.authorization.k8s.io
```

### 서비스 계정

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-app
  namespace: my-app-prod
  annotations:
    # AWS IRSA
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/my-app-role
    # GCP Workload Identity
    iam.gke.io/gcp-service-account: my-app@project.iam.gserviceaccount.com
```

---

## Ingress 설정

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: my-app-prod
  annotations:
    # NGINX Ingress Controller
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/proxy-body-size: "10m"
    nginx.ingress.kubernetes.io/rate-limit: "100"
    nginx.ingress.kubernetes.io/rate-limit-window: "1m"
    # TLS (cert-manager)
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: nginx
  tls:
    - hosts:
        - api.example.com
      secretName: api-tls
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /api/v1
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
          - path: /api/v2
            pathType: Prefix
            backend:
              service:
                name: my-app-v2
                port:
                  number: 80
```

---

## PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: app-data
  namespace: my-app-prod
spec:
  accessModes:
    - ReadWriteOnce          # 단일 노드 읽기/쓰기
  storageClassName: gp3      # AWS EBS gp3
  resources:
    requests:
      storage: 20Gi
---
# StatefulSet에서 사용
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: my-db
  namespace: my-app-prod
spec:
  serviceName: my-db
  replicas: 3
  selector:
    matchLabels:
      app: my-db
  template:
    metadata:
      labels:
        app: my-db
    spec:
      containers:
        - name: db
          image: postgres:16-alpine
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        storageClassName: gp3
        resources:
          requests:
            storage: 50Gi
```

---

## HPA (Horizontal Pod Autoscaler)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: my-app
  namespace: my-app-prod
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: my-app
  minReplicas: 2
  maxReplicas: 10
  metrics:
    # CPU 사용률 기반
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    # 메모리 사용률 기반
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
    # 커스텀 메트릭 (예: RPS)
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: 1000
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300    # 5분 안정화
      policies:
        - type: Percent
          value: 10
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
        - type: Percent
          value: 50
          periodSeconds: 60
        - type: Pods
          value: 4
          periodSeconds: 60
      selectPolicy: Max
```

---

## Helm 차트

### Chart.yaml

```yaml
apiVersion: v2
name: my-app
description: My Application Helm Chart
type: application
version: 0.1.0
appVersion: "1.0.0"
dependencies:
  - name: postgresql
    version: "13.x.x"
    repository: https://charts.bitnami.com/bitnami
    condition: postgresql.enabled
  - name: redis
    version: "18.x.x"
    repository: https://charts.bitnami.com/bitnami
    condition: redis.enabled
```

### values.yaml

```yaml
replicaCount: 2

image:
  repository: registry.example.com/my-app
  tag: "latest"
  pullPolicy: IfNotPresent

imagePullSecrets:
  - name: registry-secret

serviceAccount:
  create: true
  name: ""
  annotations: {}

service:
  type: ClusterIP
  port: 80
  targetPort: 3000

ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
  hosts:
    - host: api.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: api-tls
      hosts:
        - api.example.com

resources:
  limits:
    cpu: 500m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

env:
  NODE_ENV: production
  LOG_LEVEL: info

secretEnv: {}

postgresql:
  enabled: true
  auth:
    database: myapp

redis:
  enabled: true
```

### templates/deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "my-app.fullname" . }}
  labels:
    {{- include "my-app.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "my-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      labels:
        {{- include "my-app.selectorLabels" . | nindent 8 }}
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
    spec:
      serviceAccountName: {{ include "my-app.serviceAccountName" . }}
      containers:
        - name: {{ .Chart.Name }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - containerPort: {{ .Values.service.targetPort }}
          env:
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
            {{- range $key, $value := .Values.secretEnv }}
            - name: {{ $key }}
              valueFrom:
                secretKeyRef:
                  name: {{ include "my-app.fullname" $ }}-secret
                  key: {{ $key }}
            {{- end }}
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          readinessProbe:
            httpGet:
              path: /health
              port: {{ .Values.service.targetPort }}
            initialDelaySeconds: 5
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /health
              port: {{ .Values.service.targetPort }}
            initialDelaySeconds: 15
            periodSeconds: 20
```

### Helm 명령어

```bash
# 의존성 설치
helm dependency update helm/my-app

# 드라이런 (미리보기)
helm template my-app helm/my-app -f helm/my-app/values-prod.yaml

# 설치
helm install my-app helm/my-app \
  -n my-app-prod \
  -f helm/my-app/values-prod.yaml

# 업그레이드
helm upgrade my-app helm/my-app \
  -n my-app-prod \
  -f helm/my-app/values-prod.yaml

# 롤백
helm rollback my-app 1 -n my-app-prod

# 히스토리
helm history my-app -n my-app-prod

# 삭제
helm uninstall my-app -n my-app-prod
```

---

## Kustomize

### base/kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  - configmap.yaml
  - hpa.yaml
  - ingress.yaml

commonLabels:
  app: my-app
  managed-by: kustomize
```

### overlays/prod/kustomization.yaml

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: my-app-prod

resources:
  - ../../base

namePrefix: prod-

commonLabels:
  env: production

# 이미지 태그 변경
images:
  - name: my-app
    newName: registry.example.com/my-app
    newTag: v1.2.3

# ConfigMap 생성
configMapGenerator:
  - name: app-config
    literals:
      - NODE_ENV=production
      - LOG_LEVEL=warn

# 패치
patches:
  - path: patch-deployment.yaml
  - path: patch-hpa.yaml

components:
  - ../../components/monitoring
  - ../../components/network-policy
```

### overlays/prod/patch-deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
  template:
    spec:
      containers:
        - name: app
          resources:
            requests:
              cpu: 500m
              memory: 512Mi
            limits:
              cpu: "2"
              memory: 1Gi
```

### Kustomize 명령어

```bash
# 미리보기
kubectl kustomize k8s/overlays/prod

# 적용
kubectl apply -k k8s/overlays/prod

# 삭제
kubectl delete -k k8s/overlays/prod
```

---

## 환경별 클러스터 분리 전략

```
┌─────────────────────────────────────────────────────┐
│                    접근 방식 비교                      │
├─────────────────┬───────────────┬───────────────────┤
│                 │ Namespace 분리 │ 클러스터 분리       │
├─────────────────┼───────────────┼───────────────────┤
│ 비용            │ 낮음           │ 높음               │
│ 격리 수준       │ 논리적         │ 물리적              │
│ 운영 복잡도     │ 낮음           │ 높음               │
│ 보안            │ 보통           │ 높음               │
│ 추천 대상       │ dev/staging   │ prod              │
└─────────────────┴───────────────┴───────────────────┘

권장: dev/staging은 Namespace 분리, prod는 별도 클러스터
```

### kubeconfig 컨텍스트 관리

```bash
# 컨텍스트 목록
kubectl config get-contexts

# 컨텍스트 전환
kubectl config use-context prod-cluster

# kubectx 도구 사용 (편의)
kubectx prod-cluster
kubens my-app-prod
```

---

## 체크리스트

- [ ] Namespace별 ResourceQuota, LimitRange 설정
- [ ] RBAC으로 역할별 권한 최소화
- [ ] Ingress TLS 설정 (cert-manager)
- [ ] HPA로 자동 스케일링 설정
- [ ] Helm 또는 Kustomize로 환경별 설정 관리
- [ ] PVC 스토리지 클래스 적절히 선택
- [ ] ServiceAccount로 Pod 권한 관리
- [ ] 환경별 클러스터/Namespace 분리 전략 수립
- [ ] kubeconfig 컨텍스트 정리
