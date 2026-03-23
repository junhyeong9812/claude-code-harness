# 클라우드 - Small Scale

> AWS/GCP 기본 서비스, 콘솔/CLI 기본, 비용 관리 기초

---

## 적용 대상

- 1~3명 팀, 단일 서비스
- 클라우드 입문
- 최소 비용으로 서비스 운영

---

## AWS vs GCP 기본 서비스 비교

| 기능 | AWS | GCP |
|------|-----|-----|
| 가상 서버 | EC2 | Compute Engine (GCE) |
| 오브젝트 스토리지 | S3 | Cloud Storage (GCS) |
| 관계형 DB | RDS | Cloud SQL |
| DNS | Route 53 | Cloud DNS |
| 로드밸런서 | ALB/NLB | Cloud Load Balancing |
| 컨테이너 | ECS / EKS | Cloud Run / GKE |
| 서버리스 | Lambda | Cloud Functions |
| CDN | CloudFront | Cloud CDN |
| 시크릿 | Secrets Manager | Secret Manager |
| 모니터링 | CloudWatch | Cloud Monitoring |

---

## AWS 기본 설정

### CLI 설치 및 설정

```bash
# AWS CLI 설치
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# 프로파일 설정
aws configure --profile my-project
# AWS Access Key ID: AKIA...
# AWS Secret Access Key: ...
# Default region name: ap-northeast-2
# Default output format: json

# 프로파일 사용
export AWS_PROFILE=my-project

# 또는 명령어별
aws s3 ls --profile my-project
```

### ~/.aws/config (추천 설정)

```ini
[default]
region = ap-northeast-2
output = json

[profile my-project]
region = ap-northeast-2
output = json

[profile my-project-prod]
region = ap-northeast-2
output = json
# SSO 사용 시
sso_start_url = https://my-org.awsapps.com/start
sso_region = ap-northeast-2
sso_account_id = 123456789012
sso_role_name = AdministratorAccess
```

### 기본 AWS 명령어

```bash
# === EC2 ===
# 인스턴스 목록
aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,Tags[?Key==`Name`].Value|[0]]' --output table

# 인스턴스 시작/중지
aws ec2 start-instances --instance-ids i-0abc123
aws ec2 stop-instances --instance-ids i-0abc123

# === S3 ===
# 버킷 목록
aws s3 ls

# 파일 업로드/다운로드
aws s3 cp local-file.txt s3://my-bucket/
aws s3 cp s3://my-bucket/file.txt ./
aws s3 sync ./build s3://my-bucket/static/

# === RDS ===
# 인스턴스 목록
aws rds describe-db-instances --query 'DBInstances[].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address]' --output table

# === CloudWatch ===
# 로그 그룹 목록
aws logs describe-log-groups --query 'logGroups[].logGroupName'

# 로그 조회
aws logs tail /aws/lambda/my-function --follow
```

---

## GCP 기본 설정

### CLI 설치 및 설정

```bash
# gcloud CLI 설치
curl https://sdk.cloud.google.com | bash
exec -l $SHELL

# 초기화
gcloud init

# 프로젝트 설정
gcloud config set project my-project-id
gcloud config set compute/region asia-northeast3
gcloud config set compute/zone asia-northeast3-a

# 인증
gcloud auth login
gcloud auth application-default login
```

### 기본 GCP 명령어

```bash
# === Compute Engine ===
# 인스턴스 목록
gcloud compute instances list

# 인스턴스 생성
gcloud compute instances create my-app \
  --machine-type=e2-micro \
  --zone=asia-northeast3-a \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size=20GB

# SSH 접속
gcloud compute ssh my-app --zone=asia-northeast3-a

# === Cloud Storage ===
# 버킷 생성
gsutil mb -l asia-northeast3 gs://my-bucket

# 파일 업로드/다운로드
gsutil cp local-file.txt gs://my-bucket/
gsutil cp gs://my-bucket/file.txt ./
gsutil rsync -r ./build gs://my-bucket/static/

# === Cloud SQL ===
# 인스턴스 목록
gcloud sql instances list

# 연결
gcloud sql connect my-db --user=admin
```

---

## EC2/GCE 기본 구성

### EC2 (AWS) 사용자 데이터

```bash
#!/bin/bash
# EC2 User Data - 애플리케이션 서버 초기 설정

set -e

# 시스템 업데이트
yum update -y

# Docker 설치
yum install -y docker
systemctl enable docker
systemctl start docker

# Docker Compose 설치
DOCKER_COMPOSE_VERSION="v2.24.0"
curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-linux-x86_64" \
  -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# 앱 사용자 추가
useradd -m -G docker app

# 앱 배포 디렉토리
mkdir -p /opt/app
chown app:app /opt/app

# ECR 로그인 (cron으로 12시간마다)
echo "0 */12 * * * aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin 123456789.dkr.ecr.ap-northeast-2.amazonaws.com" | crontab -
```

---

## S3/GCS 정적 사이트 호스팅

### S3 정적 사이트

```bash
# 버킷 생성
aws s3 mb s3://my-app-static

# 정적 웹사이트 호스팅 활성화
aws s3 website s3://my-app-static \
  --index-document index.html \
  --error-document error.html

# 퍼블릭 읽기 정책
cat <<EOF > bucket-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::my-app-static/*"
    }
  ]
}
EOF

aws s3api put-bucket-policy --bucket my-app-static --policy file://bucket-policy.json

# 파일 배포
aws s3 sync ./build s3://my-app-static/ \
  --delete \
  --cache-control "public, max-age=31536000" \
  --exclude "index.html" \
  --exclude "*.json"

aws s3 cp ./build/index.html s3://my-app-static/ \
  --cache-control "no-cache, no-store, must-revalidate"
```

---

## RDS / Cloud SQL 기본

### RDS 연결

```bash
# 엔드포인트 확인
aws rds describe-db-instances \
  --db-instance-identifier my-db \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text

# psql로 연결 (VPN/Bastion 필요)
psql -h my-db.abc123.ap-northeast-2.rds.amazonaws.com \
  -U admin -d myapp

# 자동 백업 확인
aws rds describe-db-instances \
  --db-instance-identifier my-db \
  --query 'DBInstances[0].[BackupRetentionPeriod,LatestRestorableTime]'
```

---

## 비용 관리 기초

### AWS 비용 확인

```bash
# 이번 달 비용
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "$(date +%Y-%m-01)" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity MONTHLY \
  --metrics "BlendedCost" \
  --group-by Type=DIMENSION,Key=SERVICE

# 예산 알림 설정 (콘솔 권장)
# AWS Console → Billing → Budgets → Create budget
```

### 비용 절감 팁

| 방법 | 절감율 | 적용 대상 |
|------|--------|-----------|
| **인스턴스 중지** | 100% (중지 시) | 개발/테스트 환경 퇴근 후 중지 |
| **적정 사이징** | 20~50% | 사용량 대비 과도한 스펙 축소 |
| **Spot/Preemptible** | 60~90% | 배치 작업, CI/CD, 개발 환경 |
| **리전 선택** | 10~30% | 서울 vs 버지니아 가격 차이 |
| **Free Tier 활용** | 100% | 12개월 무료, Always Free |

### AWS Free Tier 주요 항목

```
EC2:         t2.micro 또는 t3.micro 750시간/월 (12개월)
S3:          5GB 스토리지, 2만 GET, 2천 PUT (12개월)
RDS:         db.t2.micro 750시간/월, 20GB (12개월)
Lambda:      월 100만 요청, 40만 GB-초 (항상 무료)
DynamoDB:    25GB, 25 WCU/RCU (항상 무료)
CloudWatch:  10개 커스텀 메트릭 (항상 무료)
```

### 비용 알림 스크립트

```bash
#!/bin/bash
# 일일 비용 확인 및 알림

THRESHOLD=10  # USD

TODAY_COST=$(aws ce get-cost-and-usage \
  --time-period Start=$(date +%Y-%m-%d),End=$(date -d "+1 day" +%Y-%m-%d) \
  --granularity DAILY \
  --metrics "BlendedCost" \
  --query 'ResultsByTime[0].Total.BlendedCost.Amount' \
  --output text)

echo "오늘 비용: $${TODAY_COST} USD"

# 임계값 초과 시 알림
if (( $(echo "${TODAY_COST} > ${THRESHOLD}" | bc -l) )); then
  echo "비용 경고: 일일 비용이 $${THRESHOLD} USD를 초과했습니다!"
  # Slack 알림 등 추가
fi
```

---

## 보안 기본

### IAM 최소 권한

```bash
# 루트 계정 사용 금지
# IAM 사용자 생성 후 MFA 활성화

# 정책 예시: S3 특정 버킷만 접근
cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ]
    }
  ]
}
EOF
```

### 보안 체크리스트

```
필수:
├── [ ] 루트 계정 MFA 활성화
├── [ ] IAM 사용자별 개별 계정
├── [ ] 액세스 키 정기 교체 (90일)
├── [ ] S3 퍼블릭 접근 차단 (기본)
├── [ ] 보안 그룹 최소 포트만 오픈
├── [ ] RDS 퍼블릭 접근 비활성화
└── [ ] CloudTrail 활성화 (감사 로그)
```

---

## 체크리스트

- [ ] CLI 설치 및 프로파일 설정
- [ ] IAM 사용자 생성 및 MFA 활성화
- [ ] 보안 그룹 최소 권한 설정
- [ ] S3/GCS 퍼블릭 접근 기본 차단
- [ ] RDS/Cloud SQL 프라이빗 서브넷 배치
- [ ] 자동 백업 활성화
- [ ] 비용 예산 알림 설정
- [ ] 태깅 컨벤션 적용
- [ ] Free Tier 범위 확인
