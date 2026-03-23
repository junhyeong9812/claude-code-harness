# Terraform - Small Scale

> 단일 파일 구성으로 기본 인프라 프로비저닝하기

---

## 적용 대상

- 1~3명 팀, 단일 프로젝트
- 기본 클라우드 리소스 (VPC, EC2/GCE, RDS)
- Terraform 입문, IaC 시작

---

## 프로젝트 구조

```
terraform/
├── main.tf              # 리소스 정의
├── variables.tf         # 변수 선언
├── outputs.tf           # 출력 값
├── providers.tf         # 프로바이더 설정
├── terraform.tfvars     # 변수 값 (git에 커밋하지 않음)
├── terraform.tfvars.example
├── .gitignore
└── .terraform.lock.hcl  # 의존성 잠금 (커밋 대상)
```

---

## 기본 파일 구성

### providers.tf

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # 로컬 state (소규모 시작)
  # 팀 작업 시 remote backend로 전환 권장
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
```

### variables.tf

```hcl
variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "프로젝트 이름"
  type        = string
  default     = "my-app"
}

variable "environment" {
  description = "환경 (dev/staging/prod)"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR 블록"
  type        = string
  default     = "10.0.0.0/16"
}

variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "db_password" {
  description = "데이터베이스 마스터 비밀번호"
  type        = string
  sensitive   = true
}
```

### main.tf

```hcl
# ===== VPC =====
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

# 퍼블릭 서브넷
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-${var.environment}-public-${count.index + 1}"
    Type = "public"
  }
}

# 프라이빗 서브넷
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.project_name}-${var.environment}-private-${count.index + 1}"
    Type = "private"
  }
}

# 인터넷 게이트웨이
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# 라우트 테이블 (퍼블릭)
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 가용 영역 조회
data "aws_availability_zones" "available" {
  state = "available"
}

# ===== 보안 그룹 =====
resource "aws_security_group" "app" {
  name_prefix = "${var.project_name}-${var.environment}-app-"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-app-sg"
  }
}

resource "aws_security_group" "db" {
  name_prefix = "${var.project_name}-${var.environment}-db-"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "PostgreSQL from app"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-db-sg"
  }
}

# ===== EC2 인스턴스 =====
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.app.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker
    systemctl enable docker
    systemctl start docker
  EOF

  tags = {
    Name = "${var.project_name}-${var.environment}-app"
  }
}

# ===== RDS =====
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-${var.environment}-db"

  engine               = "postgres"
  engine_version       = "16.1"
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  max_allocated_storage = 100    # 자동 확장

  db_name  = replace(var.project_name, "-", "_")
  username = "admin"
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]

  backup_retention_period = 7
  skip_final_snapshot     = var.environment != "prod"
  deletion_protection     = var.environment == "prod"
  storage_encrypted       = true

  tags = {
    Name = "${var.project_name}-${var.environment}-db"
  }
}
```

### outputs.tf

```hcl
output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "퍼블릭 서브넷 ID 목록"
  value       = aws_subnet.public[*].id
}

output "app_public_ip" {
  description = "애플리케이션 서버 공인 IP"
  value       = aws_instance.app.public_ip
}

output "db_endpoint" {
  description = "RDS 엔드포인트"
  value       = aws_db_instance.main.endpoint
}

output "db_name" {
  description = "데이터베이스 이름"
  value       = aws_db_instance.main.db_name
}
```

### terraform.tfvars.example

```hcl
aws_region    = "ap-northeast-2"
project_name  = "my-app"
environment   = "dev"
instance_type = "t3.micro"
db_password   = "CHANGE_ME_use_strong_password"
```

### .gitignore

```
# Terraform
.terraform/
*.tfstate
*.tfstate.backup
*.tfstate.*.backup
*.tfvars
!*.tfvars.example
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc
```

---

## terraform 워크플로우

### 기본 명령어

```bash
# 1. 초기화 (프로바이더 다운로드)
terraform init

# 2. 포맷팅 확인
terraform fmt -check -recursive

# 3. 유효성 검사
terraform validate

# 4. 계획 확인 (무엇이 변경되는지 미리 확인)
terraform plan -var-file="terraform.tfvars"

# 5. 적용
terraform apply -var-file="terraform.tfvars"

# 6. 상태 확인
terraform show
terraform state list

# 7. 삭제 (주의!)
terraform destroy -var-file="terraform.tfvars"
```

### 유용한 명령어

```bash
# 특정 리소스만 적용
terraform apply -target=aws_instance.app

# 출력 값 확인
terraform output
terraform output db_endpoint

# 상태 확인
terraform state show aws_instance.app

# 리소스 이름 변경 (state 이동)
terraform state mv aws_instance.app aws_instance.web

# plan 파일 저장 후 적용
terraform plan -out=tfplan
terraform apply tfplan
```

---

## State 파일 관리 기본

### 로컬 State (기본)

```
terraform/
├── terraform.tfstate          # 현재 상태
├── terraform.tfstate.backup   # 이전 상태
└── ...
```

> 주의: `terraform.tfstate`에는 민감 정보(비밀번호, 키)가 포함될 수 있으므로 절대 Git에 커밋하지 않음

### Remote Backend로 전환 (팀 작업 시)

```hcl
# providers.tf에 추가
terraform {
  backend "s3" {
    bucket         = "my-app-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
```

```bash
# backend 변경 시 재초기화
terraform init -migrate-state
```

---

## GCP 예시 (참고)

```hcl
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
}

# VPC
resource "google_compute_network" "main" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "public" {
  name          = "${var.project_name}-public"
  ip_cidr_range = "10.0.1.0/24"
  network       = google_compute_network.main.id
  region        = var.gcp_region
}

# GCE Instance
resource "google_compute_instance" "app" {
  name         = "${var.project_name}-app"
  machine_type = "e2-micro"
  zone         = "${var.gcp_region}-a"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-12"
      size  = 20
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.public.id
    access_config {}
  }
}

# Cloud SQL
resource "google_sql_database_instance" "main" {
  name             = "${var.project_name}-db"
  database_version = "POSTGRES_16"
  region           = var.gcp_region

  settings {
    tier = "db-f1-micro"

    backup_configuration {
      enabled = true
    }
  }

  deletion_protection = var.environment == "prod"
}
```

---

## 체크리스트

- [ ] `.gitignore`에 `.terraform/`, `*.tfstate`, `*.tfvars` 추가
- [ ] `terraform.tfvars.example` 작성 및 공유
- [ ] `sensitive = true`로 민감 변수 표시
- [ ] `terraform plan` 후 확인하고 `apply`
- [ ] 리소스에 일관된 태깅 적용
- [ ] `.terraform.lock.hcl` 커밋 (의존성 고정)
- [ ] State 파일 보안 관리
- [ ] 프로덕션 리소스에 `deletion_protection` 설정
