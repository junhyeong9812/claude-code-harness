# 클라우드 - Large Scale

> 멀티 계정 전략, Landing Zone, 네트워크 아키텍처, 비용 최적화, 컴플라이언스

---

## 적용 대상

- 8명 이상 팀, 여러 팀/조직 협업
- 멀티 계정/프로젝트, 멀티 리전
- 엄격한 보안, 감사, 컴플라이언스 요구
- 대규모 비용 최적화 필요

---

## 멀티 계정 전략 (AWS Organizations)

### 계정 구조

```
Management Account (루트)
│
├── Security OU
│   ├── Security Account
│   │   ├── GuardDuty (위임 관리자)
│   │   ├── SecurityHub
│   │   ├── Detective
│   │   └── Inspector
│   └── Log Archive Account
│       ├── CloudTrail 중앙 로그
│       ├── Config 로그
│       ├── VPC Flow Logs
│       └── ALB Access Logs
│
├── Infrastructure OU
│   ├── Network Account
│   │   ├── Transit Gateway
│   │   ├── Route 53 (DNS)
│   │   ├── Direct Connect / VPN
│   │   └── 공유 VPC (RAM)
│   └── Shared Services Account
│       ├── ECR (컨테이너 레지스트리)
│       ├── CI/CD 도구
│       ├── 모니터링 (Grafana)
│       └── Artifact Repository
│
├── Workloads OU
│   ├── Product A
│   │   ├── Dev Account
│   │   ├── Staging Account
│   │   └── Prod Account
│   └── Product B
│       ├── Dev Account
│       └── Prod Account
│
└── Sandbox OU
    └── Sandbox Account (실험용, 격리)
```

### GCP 폴더 구조

```
Organization
│
├── Folder: Security
│   ├── Project: security-audit
│   └── Project: log-archive
│
├── Folder: Infrastructure
│   ├── Project: shared-vpc-host
│   ├── Project: shared-services
│   └── Project: ci-cd
│
├── Folder: Workloads
│   ├── Folder: Product A
│   │   ├── Project: product-a-dev
│   │   ├── Project: product-a-staging
│   │   └── Project: product-a-prod
│   └── Folder: Product B
│       └── ...
│
└── Folder: Sandbox
    └── Project: sandbox-experiments
```

---

## Landing Zone / Control Tower

### AWS Control Tower 설정

```hcl
# Control Tower은 콘솔에서 설정 권장
# Terraform으로 관리할 추가 가드레일:

# SCP (Service Control Policy) - 프로덕션 보호
resource "aws_organizations_policy" "prod_protection" {
  name    = "prod-protection"
  type    = "SERVICE_CONTROL_POLICY"
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyRegionOutsideAllowed"
        Effect    = "Deny"
        Action    = "*"
        Resource  = "*"
        Condition = {
          StringNotEquals = {
            "aws:RequestedRegion" = [
              "ap-northeast-2",
              "us-east-1"    # 글로벌 서비스용
            ]
          }
        }
      },
      {
        Sid    = "DenyLeaveOrganization"
        Effect = "Deny"
        Action = "organizations:LeaveOrganization"
        Resource = "*"
      },
      {
        Sid    = "DenyDisableCloudTrail"
        Effect = "Deny"
        Action = [
          "cloudtrail:StopLogging",
          "cloudtrail:DeleteTrail"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyDisableGuardDuty"
        Effect = "Deny"
        Action = [
          "guardduty:DisableOrganizationAdminAccount",
          "guardduty:DeleteDetector"
        ]
        Resource = "*"
      }
    ]
  })
}

# SCP를 Prod OU에 연결
resource "aws_organizations_policy_attachment" "prod_protection" {
  policy_id = aws_organizations_policy.prod_protection.id
  target_id = aws_organizations_organizational_unit.prod.id
}
```

### Account Factory (Terraform)

```hcl
# 새 계정 자동 프로비저닝
module "account" {
  source = "./modules/account-factory"

  account_name  = "product-a-prod"
  email         = "aws+product-a-prod@example.com"
  ou_id         = aws_organizations_organizational_unit.workloads.id

  # 기본 설정 자동 적용
  enable_guardduty    = true
  enable_securityhub  = true
  enable_config       = true
  enable_cloudtrail   = true

  # VPC 기본 설정
  vpc_cidr           = "10.10.0.0/16"
  transit_gateway_id = data.aws_ec2_transit_gateway.shared.id

  # SSO 역할 매핑
  sso_groups = {
    admin     = "arn:aws:sso:::permissionSet/ssoins-xxx/ps-admin"
    developer = "arn:aws:sso:::permissionSet/ssoins-xxx/ps-developer"
    readonly  = "arn:aws:sso:::permissionSet/ssoins-xxx/ps-readonly"
  }

  tags = {
    Product     = "product-a"
    Environment = "prod"
    CostCenter  = "ENG-001"
  }
}
```

---

## 네트워크 아키텍처

### Transit Gateway (AWS)

```
┌──────────────────────────────────────────────────────────────┐
│                      Transit Gateway                         │
│                                                              │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐               │
│  │ VPC: Dev  │  │VPC:Staging│  │ VPC: Prod │               │
│  │10.1.0.0/16│  │10.2.0.0/16│  │10.3.0.0/16│               │
│  └─────┬─────┘  └─────┬─────┘  └─────┬─────┘               │
│        │               │               │                     │
│  ┌─────▼─────────────────────────────▼─────┐                │
│  │        Transit Gateway Route Table        │               │
│  │                                           │               │
│  │  10.1.0.0/16 → VPC Dev attachment         │               │
│  │  10.2.0.0/16 → VPC Staging attachment     │               │
│  │  10.3.0.0/16 → VPC Prod attachment        │               │
│  │  10.0.0.0/16 → Shared Services attachment │               │
│  │  0.0.0.0/0   → Inspection VPC (방화벽)     │               │
│  └─────┬─────────────────────────────────────┘               │
│        │                                                     │
│  ┌─────▼──────┐   ┌──────────────┐   ┌──────────────┐      │
│  │VPC: Shared │   │VPC:Inspection│   │  On-premise   │      │
│  │10.0.0.0/16 │   │  (방화벽)     │   │  VPN/DX      │      │
│  └────────────┘   └──────────────┘   └──────────────┘      │
└──────────────────────────────────────────────────────────────┘
```

```hcl
# Transit Gateway
resource "aws_ec2_transit_gateway" "main" {
  description                     = "Central Transit Gateway"
  default_route_table_association = "disable"
  default_route_table_propagation = "disable"
  dns_support                     = "enable"
  vpn_ecmp_support                = "enable"

  tags = {
    Name = "central-tgw"
  }
}

# VPC Attachment
resource "aws_ec2_transit_gateway_vpc_attachment" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  vpc_id             = module.vpc_prod.vpc_id
  subnet_ids         = module.vpc_prod.private_subnet_ids

  transit_gateway_default_route_table_association = false
  transit_gateway_default_route_table_propagation = false

  tags = {
    Name = "prod-vpc-attachment"
  }
}

# Route Table 분리 (Prod는 격리)
resource "aws_ec2_transit_gateway_route_table" "prod" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  tags = { Name = "prod-rt" }
}

resource "aws_ec2_transit_gateway_route_table" "non_prod" {
  transit_gateway_id = aws_ec2_transit_gateway.main.id
  tags = { Name = "non-prod-rt" }
}

# Prod → Shared만 허용, Dev 접근 차단
resource "aws_ec2_transit_gateway_route" "prod_to_shared" {
  destination_cidr_block         = "10.0.0.0/16"
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_vpc_attachment.shared.id
  transit_gateway_route_table_id = aws_ec2_transit_gateway_route_table.prod.id
}
```

### VPC Peering (간단한 경우)

```hcl
# 2개 VPC 간 직접 연결 (소규모에 적합)
resource "aws_vpc_peering_connection" "dev_to_shared" {
  peer_vpc_id = module.vpc_shared.vpc_id
  vpc_id      = module.vpc_dev.vpc_id
  auto_accept = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }
}
```

---

## 비용 최적화

### Reserved Instances / Savings Plans

```bash
# 현재 사용량 분석
aws ce get-reservation-coverage \
  --time-period Start=2024-01-01,End=2024-03-01 \
  --granularity MONTHLY

# Savings Plans 권장 확인
aws ce get-savings-plans-purchase-recommendation \
  --savings-plans-type COMPUTE_SP \
  --term-in-years ONE_YEAR \
  --payment-option NO_UPFRONT \
  --lookback-period-in-days SIXTY_DAYS
```

### 비용 최적화 체크리스트

| 전략 | 절감율 | 대상 |
|------|--------|------|
| **Savings Plans (Compute)** | 30~40% | 안정적 워크로드 |
| **Reserved Instances** | 40~60% | 고정 인스턴스 (RDS 등) |
| **Spot Instances** | 60~90% | 배치, CI/CD, 내결함성 워크로드 |
| **적정 사이징** | 20~50% | 사용률 낮은 리소스 다운그레이드 |
| **스케줄 기반 중지** | 65% | 개발/테스트 환경 (근무시간만) |
| **스토리지 계층** | 50~80% | S3 Glacier, EBS 스냅샷 |
| **NAT Gateway 최적화** | 가변 | VPC 엔드포인트로 대체 |

### Spot Instance 활용

```hcl
# ECS Capacity Provider (Spot)
resource "aws_ecs_capacity_provider" "spot" {
  name = "spot"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.spot.arn
    managed_termination_protection = "DISABLED"

    managed_scaling {
      status          = "ENABLED"
      target_capacity = 100
    }
  }
}

# Spot Fleet (Mixed Instances)
resource "aws_launch_template" "spot" {
  name_prefix   = "spot-"
  image_id      = data.aws_ami.ecs.id
  instance_type = "t3.medium"

  instance_market_options {
    market_type = "spot"
    spot_options {
      max_price          = "0.05"
      spot_instance_type = "one-time"
    }
  }
}

resource "aws_autoscaling_group" "spot" {
  desired_capacity = 2
  max_size         = 10
  min_size         = 0

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 1    # 최소 1개 On-Demand
      on_demand_percentage_above_base_capacity = 0    # 나머지 전부 Spot
      spot_allocation_strategy                 = "capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.spot.id
        version            = "$Latest"
      }

      override {
        instance_type = "t3.medium"
      }
      override {
        instance_type = "t3.large"
      }
      override {
        instance_type = "m5.large"
      }
      override {
        instance_type = "m6i.large"
      }
    }
  }
}
```

### 비용 리포트 자동화

```hcl
# Cost and Usage Report
resource "aws_cur_report_definition" "main" {
  report_name                = "daily-cost-report"
  time_unit                  = "DAILY"
  format                     = "Parquet"
  compression                = "Parquet"
  s3_bucket                  = aws_s3_bucket.cur_reports.id
  s3_prefix                  = "cur"
  s3_region                  = "ap-northeast-2"
  additional_schema_elements = ["RESOURCES"]
}

# 비용 이상 탐지
resource "aws_ce_anomaly_monitor" "main" {
  name              = "cost-anomaly-monitor"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
}

resource "aws_ce_anomaly_subscription" "main" {
  name      = "cost-anomaly-alert"
  frequency = "IMMEDIATE"

  monitor_arn_list = [aws_ce_anomaly_monitor.main.arn]

  subscriber {
    type    = "EMAIL"
    address = "devops@example.com"
  }

  subscriber {
    type    = "SNS"
    address = aws_sns_topic.cost_alerts.arn
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = ["100"]    # $100 이상 이상 발생 시
    }
  }
}
```

---

## 컴플라이언스 및 감사 로깅

### 중앙 로깅 아키텍처

```
모든 계정의 로그 → Log Archive Account

CloudTrail     → S3 (중앙)   → Athena (쿼리)
VPC Flow Logs  → S3 (중앙)   → Athena (쿼리)
Config         → S3 (중앙)   → Config 규칙
ALB Logs       → S3 (중앙)   → Athena (쿼리)
GuardDuty      → SecurityHub → EventBridge → SNS/Slack
```

```hcl
# Organization-wide CloudTrail
resource "aws_cloudtrail" "org" {
  name                       = "org-trail"
  s3_bucket_name             = aws_s3_bucket.cloudtrail.id
  is_organization_trail      = true
  is_multi_region_trail      = true
  enable_log_file_validation = true

  cloud_watch_logs_group_arn = "${aws_cloudwatch_log_group.cloudtrail.arn}:*"
  cloud_watch_logs_role_arn  = aws_iam_role.cloudtrail_cw.arn

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    data_resource {
      type   = "AWS::S3::Object"
      values = ["arn:aws:s3"]
    }
  }

  insight_selector {
    insight_type = "ApiCallRateInsight"
  }
  insight_selector {
    insight_type = "ApiErrorRateInsight"
  }
}
```

### AWS Config 규칙

```hcl
# 필수 Config 규칙
resource "aws_config_config_rule" "encrypted_volumes" {
  name = "encrypted-volumes"
  source {
    owner             = "AWS"
    source_identifier = "ENCRYPTED_VOLUMES"
  }
}

resource "aws_config_config_rule" "s3_bucket_public_read" {
  name = "s3-bucket-public-read-prohibited"
  source {
    owner             = "AWS"
    source_identifier = "S3_BUCKET_PUBLIC_READ_PROHIBITED"
  }
}

resource "aws_config_config_rule" "rds_multi_az" {
  name = "rds-multi-az-support"
  source {
    owner             = "AWS"
    source_identifier = "RDS_MULTI_AZ_SUPPORT"
  }
}

resource "aws_config_config_rule" "required_tags" {
  name = "required-tags"
  source {
    owner             = "AWS"
    source_identifier = "REQUIRED_TAGS"
  }
  input_parameters = jsonencode({
    tag1Key = "Environment"
    tag2Key = "Project"
    tag3Key = "ManagedBy"
    tag4Key = "Team"
  })
}

# 자동 치료 (비준수 리소스 자동 수정)
resource "aws_config_remediation_configuration" "encrypt_s3" {
  config_rule_name = aws_config_config_rule.s3_bucket_public_read.name
  target_type      = "SSM_DOCUMENT"
  target_id        = "AWS-DisableS3BucketPublicReadWrite"

  parameter {
    name           = "BucketName"
    resource_value = "RESOURCE_ID"
  }

  automatic                  = true
  maximum_automatic_attempts = 3
  retry_attempt_seconds      = 60
}
```

---

## 태깅 전략

```hcl
# 필수 태그
locals {
  required_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Team        = var.team
    CostCenter  = var.cost_center
    Owner       = var.owner_email
  }
}

# AWS default_tags (모든 리소스에 자동 적용)
provider "aws" {
  default_tags {
    tags = local.required_tags
  }
}
```

### 태깅 컨벤션

| 태그 키 | 값 예시 | 용도 |
|---------|--------|------|
| `Project` | my-app | 비용 분배 |
| `Environment` | dev/staging/prod | 환경 구분 |
| `Team` | backend/platform | 담당 팀 |
| `ManagedBy` | terraform/manual | 관리 방식 |
| `CostCenter` | ENG-001 | 비용 센터 |
| `Owner` | team@example.com | 담당자 |
| `DataClassification` | public/internal/confidential | 데이터 등급 |

---

## 체크리스트

- [ ] 멀티 계정 구조 설계 (OU, SCP)
- [ ] Landing Zone 또는 Control Tower 설정
- [ ] Transit Gateway 또는 VPC Peering 네트워크
- [ ] SCP로 프로덕션 보호 정책 적용
- [ ] 중앙 로깅 (CloudTrail, VPC Flow Logs, Config)
- [ ] GuardDuty + SecurityHub 활성화
- [ ] Savings Plans / Reserved Instances 적용
- [ ] Spot Instance 활용 (비프로덕션)
- [ ] 비용 이상 탐지 알림 설정
- [ ] Config 규칙 + 자동 치료
- [ ] 태깅 전략 수립 및 강제화
- [ ] Account Factory 자동화
