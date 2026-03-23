# Terraform - Medium Scale

> 모듈화, 환경 분리, Remote State, CI/CD 통합

---

## 적용 대상

- 3~8명 팀, 복수 프로젝트/환경
- 코드 재사용성, 환경별 일관성 필요
- CI/CD에서 자동 plan/apply

---

## 프로젝트 구조 (디렉토리 분리 방식)

```
terraform/
├── modules/                          # 재사용 가능한 모듈
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── compute/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── database/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── security/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── backend.tf
│   │   └── terraform.tfvars
│   ├── staging/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── backend.tf
│   │   └── terraform.tfvars
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── backend.tf
│       └── terraform.tfvars
└── global/                           # 환경 공통 리소스
    ├── iam/
    ├── dns/
    └── state-backend/
        ├── main.tf                   # S3 + DynamoDB 생성
        └── outputs.tf
```

---

## Remote State 설정

### State Backend 생성 (최초 1회)

```hcl
# global/state-backend/main.tf
provider "aws" {
  region = "ap-northeast-2"
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "my-org-terraform-state"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-lock"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
```

### 환경별 Backend 설정

```hcl
# environments/prod/backend.tf
terraform {
  backend "s3" {
    bucket         = "my-org-terraform-state"
    key            = "prod/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
```

### GCS Backend (GCP)

```hcl
terraform {
  backend "gcs" {
    bucket = "my-org-terraform-state"
    prefix = "prod"
  }
}
```

---

## 모듈 작성

### networking 모듈

```hcl
# modules/networking/variables.tf
variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_count" {
  type    = number
  default = 2
}

variable "private_subnet_count" {
  type    = number
  default = 2
}

variable "enable_nat_gateway" {
  type    = bool
  default = false
}

variable "single_nat_gateway" {
  description = "비용 절감을 위해 단일 NAT 게이트웨이 사용"
  type        = bool
  default     = true
}
```

```hcl
# modules/networking/main.tf
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${local.name_prefix}-vpc"
  }
}

resource "aws_subnet" "public" {
  count             = var.public_subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${count.index + 1}"
    Type = "public"
  }
}

resource "aws_subnet" "private" {
  count             = var.private_subnet_count
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${local.name_prefix}-private-${count.index + 1}"
    Type = "private"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "${local.name_prefix}-igw" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count          = var.public_subnet_count
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway (옵션)
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.private_subnet_count) : 0
  domain = "vpc"
  tags   = { Name = "${local.name_prefix}-nat-eip-${count.index + 1}" }
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : var.private_subnet_count) : 0
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id
  tags          = { Name = "${local.name_prefix}-nat-${count.index + 1}" }
}

resource "aws_route_table" "private" {
  count  = var.enable_nat_gateway ? var.private_subnet_count : 0
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main[var.single_nat_gateway ? 0 : count.index].id
  }

  tags = { Name = "${local.name_prefix}-private-rt-${count.index + 1}" }
}

resource "aws_route_table_association" "private" {
  count          = var.enable_nat_gateway ? var.private_subnet_count : 0
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}
```

```hcl
# modules/networking/outputs.tf
output "vpc_id" {
  value = aws_vpc.main.id
}

output "vpc_cidr" {
  value = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  value = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}
```

### database 모듈

```hcl
# modules/database/main.tf
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}"
  subnet_ids = var.subnet_ids
}

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}"

  engine               = var.engine
  engine_version       = var.engine_version
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage

  db_name  = var.db_name
  username = var.username
  password = var.password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = var.security_group_ids

  multi_az                = var.multi_az
  backup_retention_period = var.backup_retention_period
  backup_window           = "03:00-04:00"
  maintenance_window      = "Mon:04:00-Mon:05:00"

  storage_encrypted       = true
  skip_final_snapshot     = var.environment != "prod"
  deletion_protection     = var.environment == "prod"
  copy_tags_to_snapshot   = true

  performance_insights_enabled = var.environment == "prod"

  tags = {
    Name        = "${var.project_name}-${var.environment}"
    Environment = var.environment
  }
}
```

---

## 환경별 구성

### environments/prod/main.tf

```hcl
locals {
  project_name = "my-app"
  environment  = "prod"
  aws_region   = "ap-northeast-2"
}

provider "aws" {
  region = local.aws_region

  default_tags {
    tags = {
      Project     = local.project_name
      Environment = local.environment
      ManagedBy   = "terraform"
    }
  }
}

# ===== 네트워킹 =====
module "networking" {
  source = "../../modules/networking"

  project_name       = local.project_name
  environment        = local.environment
  vpc_cidr           = "10.0.0.0/16"
  enable_nat_gateway = true
  single_nat_gateway = false    # 프로덕션은 AZ별 NAT
}

# ===== 보안 =====
module "security" {
  source = "../../modules/security"

  project_name = local.project_name
  environment  = local.environment
  vpc_id       = module.networking.vpc_id
  vpc_cidr     = module.networking.vpc_cidr
}

# ===== 데이터베이스 =====
module "database" {
  source = "../../modules/database"

  project_name       = local.project_name
  environment        = local.environment
  engine             = "postgres"
  engine_version     = "16.1"
  instance_class     = "db.r6g.large"
  allocated_storage  = 100
  max_allocated_storage = 500
  multi_az           = true
  backup_retention_period = 30

  subnet_ids         = module.networking.private_subnet_ids
  security_group_ids = [module.security.db_security_group_id]

  db_name  = "myapp"
  username = "admin"
  password = var.db_password
}

# ===== 다른 State 참조 =====
data "terraform_remote_state" "global" {
  backend = "s3"
  config = {
    bucket = "my-org-terraform-state"
    key    = "global/terraform.tfstate"
    region = "ap-northeast-2"
  }
}
```

---

## 변수 관리 패턴

### 변수 타입 활용

```hcl
# 복합 변수
variable "app_config" {
  type = object({
    instance_type = string
    min_size      = number
    max_size      = number
    desired_size  = number
  })
  default = {
    instance_type = "t3.medium"
    min_size      = 1
    max_size      = 3
    desired_size  = 2
  }
}

# 맵 변수
variable "instance_types" {
  type = map(string)
  default = {
    dev     = "t3.micro"
    staging = "t3.small"
    prod    = "t3.medium"
  }
}

# 사용
resource "aws_instance" "app" {
  instance_type = var.instance_types[var.environment]
}

# 검증 규칙
variable "environment" {
  type = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment는 dev, staging, prod 중 하나여야 합니다."
  }
}
```

### Data Sources

```hcl
# 최신 AMI 조회
data "aws_ami" "app" {
  most_recent = true
  owners      = ["self"]

  filter {
    name   = "name"
    values = ["my-app-*"]
  }
  filter {
    name   = "state"
    values = ["available"]
  }
}

# 현재 AWS 계정 정보
data "aws_caller_identity" "current" {}

# SSM 파라미터에서 시크릿 조회
data "aws_ssm_parameter" "db_password" {
  name = "/${var.environment}/db/password"
}

# 사용
resource "aws_db_instance" "main" {
  password = data.aws_ssm_parameter.db_password.value
}
```

---

## CI/CD 통합

### GitHub Actions

```yaml
name: Terraform

on:
  push:
    branches: [main]
    paths: ['terraform/**']
  pull_request:
    branches: [main]
    paths: ['terraform/**']

env:
  TF_VERSION: "1.7.0"
  AWS_REGION: "ap-northeast-2"

permissions:
  id-token: write    # OIDC
  contents: read
  pull-requests: write

jobs:
  plan:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/terraform-ci
          aws-region: ${{ env.AWS_REGION }}

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform init

      - name: Terraform Format Check
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform fmt -check -recursive

      - name: Terraform Validate
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform validate

      - name: Terraform Plan
        id: plan
        working-directory: terraform/environments/${{ matrix.environment }}
        run: |
          terraform plan -no-color -out=tfplan 2>&1 | tee plan.txt
        continue-on-error: true

      - name: Comment PR with Plan
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('terraform/environments/${{ matrix.environment }}/plan.txt', 'utf8');
            const truncated = plan.length > 60000 ? plan.substring(0, 60000) + '\n...(truncated)' : plan;
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: `### Terraform Plan - ${{ matrix.environment }}\n\`\`\`\n${truncated}\n\`\`\``
            });

  apply:
    needs: plan
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: production    # GitHub Environment 보호 규칙
    strategy:
      matrix:
        environment: [dev, staging, prod]
      max-parallel: 1          # 순차 적용
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::${{ secrets.AWS_ACCOUNT_ID }}:role/terraform-ci
          aws-region: ${{ env.AWS_REGION }}

      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: ${{ env.TF_VERSION }}

      - name: Terraform Init
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform init

      - name: Terraform Apply
        working-directory: terraform/environments/${{ matrix.environment }}
        run: terraform apply -auto-approve
```

---

## Workspace 방식 (대안)

```hcl
# 단일 코드로 여러 환경 관리
terraform {
  backend "s3" {
    bucket         = "my-org-terraform-state"
    key            = "app/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-lock"
  }
}

locals {
  env_config = {
    dev = {
      instance_type = "t3.micro"
      min_size      = 1
      max_size      = 2
    }
    staging = {
      instance_type = "t3.small"
      min_size      = 1
      max_size      = 3
    }
    prod = {
      instance_type = "t3.medium"
      min_size      = 2
      max_size      = 10
    }
  }

  config = local.env_config[terraform.workspace]
}
```

```bash
# Workspace 생성 및 전환
terraform workspace new staging
terraform workspace select prod
terraform workspace list
```

> 참고: 디렉토리 분리 방식이 환경별 차이가 클 때 더 유연하며, Workspace는 환경간 구성이 유사할 때 적합

---

## 체크리스트

- [ ] Remote State (S3/GCS) + State Locking 설정
- [ ] 모듈화하여 코드 재사용
- [ ] 환경별 분리 (디렉토리 또는 Workspace)
- [ ] CI/CD에서 plan은 PR, apply는 merge 후
- [ ] OIDC로 CI/CD 인증 (장기 키 사용 금지)
- [ ] `terraform plan` 결과 PR 코멘트로 공유
- [ ] 변수 검증 규칙 (validation) 적용
- [ ] `data` source로 동적 값 조회
- [ ] State 파일 암호화 활성화
- [ ] 프로덕션은 `max-parallel: 1`로 순차 적용
