# Kubernetes - Small Scale

> 로컬 환경에서 Kubernetes 시작하기: 기본 리소스와 kubectl 사용법

---

## 적용 대상

- 1~3명 팀, Kubernetes 입문
- 로컬 개발/테스트 환경
- 단일 서비스 또는 소수 서비스 배포

---

## 로컬 Kubernetes 환경 비교

| 도구 | 특징 | 리소스 | 추천 대상 |
|------|------|--------|-----------|
| **Minikube** | 가장 성숙한 로컬 K8s | 2+ CPU, 2+ GB RAM | 입문자, 학습용 |
| **kind** | Docker-in-Docker 기반 | 가벼움 | CI/CD, 멀티노드 테스트 |
| **k3s** | 경량 K8s (Rancher) | 512MB RAM | Edge, IoT, 리소스 제한 환경 |
| **Docker Desktop** | 내장 K8s | macOS/Windows | GUI 선호하는 개발자 |

### 설치 및 시작

```bash
# === Minikube ===
# 설치
curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
sudo install minikube-linux-amd64 /usr/local/bin/minikube

# 시작
minikube start --cpus=2 --memory=4096 --driver=docker
minikube dashboard    # 웹 대시보드

# === kind ===
# 설치
go install sigs.k8s.io/kind@latest
# 또는
curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind

# 클러스터 생성
kind create cluster --name my-cluster

# === k3s ===
# 설치 (단일 노드)
curl -sfL https://get.k3s.io | sh -
# kubeconfig
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
```

### kind 멀티노드 설정

```yaml
# kind-config.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
```

```bash
kind create cluster --config kind-config.yaml
```

---

## 프로젝트 구조

```
k8s/
├── namespace.yaml
├── deployment.yaml
├── service.yaml
├── configmap.yaml
├── secret.yaml
└── ingress.yaml
```

---

## 기본 리소스

### Namespace

```yaml
# k8s/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: my-app
  labels:
    app: my-app
    env: development
```

### ConfigMap

```yaml
# k8s/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: my-app
data:
  # 단순 키-값
  NODE_ENV: "production"
  LOG_LEVEL: "info"
  PORT: "3000"

  # 파일 형태
  config.yaml: |
    server:
      port: 3000
      host: 0.0.0.0
    database:
      pool_size: 10
```

### Secret

```yaml
# k8s/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: app-secret
  namespace: my-app
type: Opaque
stringData:              # 평문으로 작성 (자동 base64 인코딩)
  DATABASE_URL: "postgresql://user:password@db:5432/myapp"
  API_KEY: "my-secret-api-key"
```

```bash
# CLI로 시크릿 생성
kubectl create secret generic app-secret \
  --from-literal=DATABASE_URL='postgresql://user:password@db:5432/myapp' \
  --from-file=tls.crt=./cert.pem \
  -n my-app
```

### Deployment

```yaml
# k8s/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
  namespace: my-app
  labels:
    app: my-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: my-app
  template:
    metadata:
      labels:
        app: my-app
    spec:
      containers:
        - name: app
          image: my-app:latest
          ports:
            - containerPort: 3000
              protocol: TCP

          # 환경 변수 (ConfigMap에서)
          envFrom:
            - configMapRef:
                name: app-config
            - secretRef:
                name: app-secret

          # 개별 환경 변수
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name

          # 리소스 제한
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 256Mi

          # 프로브 설정
          readinessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 5
            periodSeconds: 10

          livenessProbe:
            httpGet:
              path: /health
              port: 3000
            initialDelaySeconds: 15
            periodSeconds: 20

          startupProbe:
            httpGet:
              path: /health
              port: 3000
            failureThreshold: 30
            periodSeconds: 10

          # 볼륨 마운트
          volumeMounts:
            - name: config-volume
              mountPath: /app/config
              readOnly: true

      volumes:
        - name: config-volume
          configMap:
            name: app-config
            items:
              - key: config.yaml
                path: config.yaml
```

### Service

```yaml
# k8s/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: my-app
spec:
  type: ClusterIP          # 클러스터 내부 접근
  selector:
    app: my-app
  ports:
    - port: 80              # 서비스 포트
      targetPort: 3000      # 컨테이너 포트
      protocol: TCP
---
# NodePort (외부 접근 - 개발용)
apiVersion: v1
kind: Service
metadata:
  name: my-app-nodeport
  namespace: my-app
spec:
  type: NodePort
  selector:
    app: my-app
  ports:
    - port: 80
      targetPort: 3000
      nodePort: 30080       # 30000-32767 범위
```

### Ingress

```yaml
# k8s/ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: my-app
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
    - host: my-app.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

---

## kubectl 기본 명령어

### 리소스 생성/관리

```bash
# 리소스 적용
kubectl apply -f k8s/                    # 디렉토리 내 모든 YAML
kubectl apply -f k8s/deployment.yaml     # 단일 파일

# 리소스 삭제
kubectl delete -f k8s/deployment.yaml
kubectl delete deployment my-app -n my-app

# 리소스 조회
kubectl get pods -n my-app
kubectl get pods -n my-app -o wide       # 상세 정보 (노드, IP)
kubectl get all -n my-app                # 모든 리소스
kubectl get events -n my-app --sort-by='.lastTimestamp'
```

### 디버깅

```bash
# Pod 상세 정보
kubectl describe pod <pod-name> -n my-app

# 로그 확인
kubectl logs <pod-name> -n my-app
kubectl logs <pod-name> -n my-app -f               # 실시간
kubectl logs <pod-name> -n my-app --previous        # 이전 컨테이너
kubectl logs -l app=my-app -n my-app                # 레이블 기준

# 컨테이너 내부 접속
kubectl exec -it <pod-name> -n my-app -- /bin/sh

# 포트 포워딩 (로컬에서 접근)
kubectl port-forward svc/my-app 3000:80 -n my-app

# DNS 확인
kubectl run -it --rm debug --image=busybox -- nslookup my-app.my-app.svc.cluster.local
```

### 유용한 별칭

```bash
# ~/.bashrc 또는 ~/.zshrc
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kgd='kubectl get deployments'
alias kga='kubectl get all'
alias kl='kubectl logs'
alias klf='kubectl logs -f'
alias ke='kubectl exec -it'
alias kd='kubectl describe'
alias kaf='kubectl apply -f'
alias kdf='kubectl delete -f'

# 네임스페이스 고정
alias kn='kubectl config set-context --current --namespace'
# 사용: kn my-app
```

---

## 전체 배포 흐름

```bash
# 1. 네임스페이스 생성
kubectl apply -f k8s/namespace.yaml

# 2. ConfigMap, Secret 생성
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml

# 3. 애플리케이션 배포
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# 4. 배포 상태 확인
kubectl rollout status deployment/my-app -n my-app

# 5. Pod 확인
kubectl get pods -n my-app

# 6. 로그 확인
kubectl logs -l app=my-app -n my-app

# 7. 접근 테스트
kubectl port-forward svc/my-app 3000:80 -n my-app
curl http://localhost:3000/health
```

---

## 체크리스트

- [ ] 로컬 K8s 환경 설정 (minikube/kind/k3s)
- [ ] Namespace로 리소스 격리
- [ ] Deployment에 리소스 requests/limits 설정
- [ ] readinessProbe, livenessProbe 설정
- [ ] ConfigMap/Secret으로 설정 외부화
- [ ] Secret은 stringData 사용 또는 CLI로 생성
- [ ] Service 타입 적절히 선택 (ClusterIP/NodePort)
- [ ] kubectl 기본 명령어 숙지
