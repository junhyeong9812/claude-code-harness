# Terraform - Large Scale

> Terragrunt, 대규모 모듈 라이브러리, 멀티 계정, Policy as Code

---

## 적용 대상

- 8명 이상 팀, 여러 팀/조직 협업
- 멀티 AWS 계정 / GCP 프로젝트
- 수백 개 리소스, 엄격한 거버넌스 요구

---

## 프로젝트 구조 (Terragrunt)

```
infrastructure/
├── terragrunt.hcl                         # 루트 설정
├── _env/                                  # 공통 환경 변수
│   ├── dev.hcl
│   ├── staging.hcl
│   └── prod.hcl
├── modules/                               # 사내 모듈 라이브러리
│   ├── networking/
│   │   ├── vpc/
│   │   ├── transit-gateway/
│   │   └── dns/
│   ├── compute/
│   │   ├── ecs-service/
│   │   ├── eks-cluster/
│   │   └── lambda/
│   ├── database/
│   │   ├── rds/
│   │   ├── dynamodb/
│   │   └── elasticache/
│   ├── security/
│   │   ├── iam-role/
│   │   ├── security-group/
│   │   └── kms/
│   └── monitoring/
│       ├── cloudwatch/
│       └── sns-topic/
├── accounts/
│   ├── management/                        # 관리 계정
│   │   └── ap-northeast-2/
│   │       ├── organizations/
│   │       │   └── terragrunt.hcl
│   │       └── sso/
│   │           └── terragrunt.hcl
│   ├── shared-services/                   # 공유 서비스 계정
│   │   └── ap-northeast-2/
│   │       ├── ecr/
│   │       │   └── terragrunt.hcl
│   │       ├── transit-gateway/
│   │       │   └── terragrunt.hcl
│   │       └── monitoring/
│   │           └── terragrunt.hcl
│   ├── dev/
│   │   └── ap-northeast-2/
│   │       ├── env.hcl
│   │       ├── networking/
│   │       │   └── vpc/
│   │       │       └── terragrunt.hcl
│   │       └── services/
│   │           └── my-app/
│   │               ├── ecs/
│   │               │   └── terragrunt.hcl
│   │               └── rds/
│   │                   └── terragrunt.hcl
│   └── prod/
│       └── ap-northeast-2/
│           ├── env.hcl
│           ├── networking/
│           │   └── vpc/
│           │       └── terragrunt.hcl
│           └── services/
│               └── my-app/
│                   ├── ecs/
│                   │   └── terragrunt.hcl
│                   └── rds/
│                       └── terragrunt.hcl
└── policies/                              # Policy as Code
    ├── opa/
    │   ├── deny_public_s3.rego
    │   ├── require_tags.rego
    │   └── restrict_instance_types.rego
    └── sentinel/
        ├── restrict-ec2-instance-type.sentinel
        └── require-tags.sentinel
```

---

## Terragrunt 설정

### 루트 terragrunt.hcl

```hcl
# infrastructure/terragrunt.hcl

# Remote State 자동 생성
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "my-org-terraform-state-${get_aws_account_id()}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"

    s3_bucket_tags = {
      ManagedBy = "terragrunt"
    }
  }
}

# 공통 프로바이더 생성
generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"

  default_tags {
    tags = {
      ManagedBy   = "terraform"
      Environment = "${local.environment}"
      Team        = "${local.team}"
    }
  }
}
EOF
}

# 공통 변수
locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl", "empty.hcl"), { locals = {} })
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl", "empty.hcl"), { locals = {} })
  env_vars     = read_terragrunt_config(find_in_parent_folders("env.hcl", "empty.hcl"), { locals = {} })

  aws_region   = try(local.region_vars.locals.aws_region, "ap-northeast-2")
  environment  = try(local.env_vars.locals.environment, "dev")
  team         = try(local.account_vars.locals.team, "platform")
}

# Terraform 버전 고정
terraform_version_constraint = ">= 1.5.0"

# 의존성 병렬 실행 설정
terraform {
  extra_arguments "parallelism" {
    commands = get_terraform_commands_that_need_parallelism()
    arguments = ["-parallelism=20"]
  }

  extra_arguments "plan_file" {
    commands  = ["plan"]
    arguments = ["-out=tfplan"]
  }
}
```

### 환경별 설정

```hcl
# accounts/prod/ap-northeast-2/env.hcl
locals {
  environment  = "prod"
  aws_region   = "ap-northeast-2"
  account_id   = "123456789012"
  vpc_cidr     = "10.1.0.0/16"
}
```

### 서비스 terragrunt.hcl 예시

```hcl
# accounts/prod/ap-northeast-2/services/my-app/ecs/terragrunt.hcl

terraform {
  source = "../../../../../../modules/compute/ecs-service"
}

include "root" {
  path = find_in_parent_folders()
}

# 환경 변수 로드
locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals
}

# 의존성 (VPC, RDS 등)
dependency "vpc" {
  config_path = "../../../networking/vpc"
  mock_outputs = {
    vpc_id             = "vpc-mock"
    private_subnet_ids = ["subnet-mock-1", "subnet-mock-2"]
  }
}

dependency "rds" {
  config_path = "../rds"
  mock_outputs = {
    endpoint = "mock-db.cluster.ap-northeast-2.rds.amazonaws.com"
    db_name  = "myapp"
  }
}

inputs = {
  project_name = "my-app"
  environment  = local.env.environment

  # VPC
  vpc_id     = dependency.vpc.outputs.vpc_id
  subnet_ids = dependency.vpc.outputs.private_subnet_ids

  # ECS
  cpu    = 1024
  memory = 2048
  desired_count = 3

  # 환경 변수
  environment_variables = {
    DATABASE_URL = "postgresql://admin@${dependency.rds.outputs.endpoint}/${dependency.rds.outputs.db_name}"
    NODE_ENV     = local.env.environment
  }
}
```

### Terragrunt 명령어

```bash
# 단일 모듈
cd accounts/prod/ap-northeast-2/services/my-app/ecs
terragrunt plan
terragrunt apply

# 전체 환경 한번에 (의존성 순서 자동 해결)
cd accounts/prod
terragrunt run-all plan
terragrunt run-all apply

# 특정 모듈과 의존성만
terragrunt run-all apply --terragrunt-include-dir "*/services/my-app/*"

# 의존성 그래프 확인
terragrunt graph-dependencies | dot -Tpng > deps.png
```

---

## 대규모 모듈 라이브러리

### 모듈 버전 관리

```hcl
# 사내 모듈 레지스트리 사용
module "vpc" {
  source  = "app.terraform.io/my-org/vpc/aws"
  version = "~> 3.0"

  # ...
}

# Git 태그 기반 버전
module "vpc" {
  source = "git::https://github.com/my-org/terraform-modules.git//networking/vpc?ref=v3.2.1"
}

# Terragrunt에서 버전 고정
terraform {
  source = "git::https://github.com/my-org/terraform-modules.git//networking/vpc?ref=v3.2.1"
}
```

### 모듈 테스트 (Terratest)

```go
// modules/networking/vpc/test/vpc_test.go
package test

import (
    "testing"

    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestVPC(t *testing.T) {
    t.Parallel()

    terraformOptions := &terraform.Options{
        TerraformDir: "../",
        Vars: map[string]interface{}{
            "project_name": "test",
            "environment":  "test",
            "vpc_cidr":     "10.99.0.0/16",
        },
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    vpcID := terraform.Output(t, terraformOptions, "vpc_id")
    assert.NotEmpty(t, vpcID)

    publicSubnetIDs := terraform.OutputList(t, terraformOptions, "public_subnet_ids")
    assert.Equal(t, 2, len(publicSubnetIDs))
}
```

---

## 멀티 계정/프로젝트 관리

### AWS Organizations 구조

```
Management Account (루트)
├── Security OU
│   └── Security Account (GuardDuty, SecurityHub)
├── Infrastructure OU
│   ├── Shared Services Account (ECR, Transit Gateway)
│   └── Network Account (DNS, VPN)
├── Workloads OU
│   ├── Dev Account
│   ├── Staging Account
│   └── Prod Account
└── Sandbox OU
    └── Sandbox Account
```

### Cross-account 접근

```hcl
# 다른 계정의 리소스 관리
provider "aws" {
  alias  = "shared"
  region = "ap-northeast-2"

  assume_role {
    role_arn = "arn:aws:iam::${var.shared_account_id}:role/TerraformCrossAccountRole"
  }
}

resource "aws_ecr_repository" "app" {
  provider = aws.shared
  name     = "my-app"
}
```

---

## Policy as Code

### OPA (Open Policy Agent)

```rego
# policies/opa/require_tags.rego
package terraform.policies

import input.plan as tfplan

# 필수 태그 목록
required_tags := {"Project", "Environment", "ManagedBy", "Team"}

# 태그가 없는 리소스 찾기
deny[msg] {
    resource := tfplan.resource_changes[_]
    resource.change.actions[_] == "create"

    tags := object.get(resource.change.after, "tags", {})
    missing := required_tags - {key | tags[key]}
    count(missing) > 0

    msg := sprintf(
        "%s '%s' 에 필수 태그가 없습니다: %v",
        [resource.type, resource.name, missing]
    )
}
```

```rego
# policies/opa/deny_public_s3.rego
package terraform.policies

deny[msg] {
    resource := input.plan.resource_changes[_]
    resource.type == "aws_s3_bucket_acl"
    resource.change.after.acl == "public-read"

    msg := sprintf(
        "S3 버킷 '%s'에 public-read ACL이 설정되어 있습니다. 퍼블릭 접근을 차단하세요.",
        [resource.name]
    )
}
```

```rego
# policies/opa/restrict_instance_types.rego
package terraform.policies

allowed_instance_types := {
    "t3.micro", "t3.small", "t3.medium", "t3.large",
    "m6i.large", "m6i.xlarge", "m6i.2xlarge",
    "r6g.large", "r6g.xlarge",
}

deny[msg] {
    resource := input.plan.resource_changes[_]
    resource.type == "aws_instance"
    resource.change.actions[_] == "create"

    instance_type := resource.change.after.instance_type
    not allowed_instance_types[instance_type]

    msg := sprintf(
        "인스턴스 타입 '%s'은 허용되지 않습니다. 허용 목록: %v",
        [instance_type, allowed_instance_types]
    )
}
```

### CI/CD에서 OPA 검증

```bash
#!/bin/bash
# scripts/policy-check.sh

set -euo pipefail

ENV="${1:?환경을 지정하세요 (dev/staging/prod)}"

cd "environments/${ENV}"

# Plan JSON 생성
terraform plan -out=tfplan
terraform show -json tfplan > plan.json

# OPA 정책 검증
opa eval \
  --input plan.json \
  --data ../../policies/opa/ \
  "data.terraform.policies.deny" \
  --format pretty

VIOLATIONS=$(opa eval \
  --input plan.json \
  --data ../../policies/opa/ \
  "data.terraform.policies.deny" \
  --format json | jq '.result[0].expressions[0].value | length')

if [ "${VIOLATIONS}" -gt 0 ]; then
  echo "정책 위반 ${VIOLATIONS}건 발견. 배포를 중단합니다."
  exit 1
fi

echo "정책 검증 통과."
```

---

## Drift Detection

### 자동 드리프트 감지

```yaml
# .github/workflows/drift-detection.yaml
name: Terraform Drift Detection

on:
  schedule:
    - cron: '0 9 * * 1-5'    # 평일 오전 9시
  workflow_dispatch:

jobs:
  drift-check:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, staging, prod]
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ap-northeast-2

      - uses: hashicorp/setup-terraform@v3

      - name: Terraform Init
        working-directory: environments/${{ matrix.environment }}
        run: terraform init

      - name: Drift Detection
        id: drift
        working-directory: environments/${{ matrix.environment }}
        run: |
          terraform plan -detailed-exitcode -no-color 2>&1 | tee drift.txt
          echo "exit_code=$?" >> $GITHUB_OUTPUT
        continue-on-error: true

      - name: Notify Slack on Drift
        if: steps.drift.outputs.exit_code == '2'
        uses: slackapi/slack-github-action@v1
        with:
          payload: |
            {
              "text": "Terraform 드리프트 감지: ${{ matrix.environment }} 환경에서 인프라 변경이 감지되었습니다."
            }
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}
```

---

## Import 전략

### 기존 리소스 가져오기

```bash
# Terraform 1.5+ import 블록 (선언적)
```

```hcl
# import.tf
import {
  to = aws_instance.legacy_server
  id = "i-0abc123def456789"
}

import {
  to = aws_vpc.existing
  id = "vpc-0abc123"
}

import {
  to = aws_s3_bucket.data
  id = "my-existing-bucket"
}
```

```bash
# 리소스 코드 자동 생성
terraform plan -generate-config-out=generated.tf

# 검토 후 정리
terraform plan    # 변경 사항 없는지 확인
```

### 대규모 Import 워크플로우

```bash
# 1. 기존 리소스 목록 작성
aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId' --output text

# 2. import 블록 생성
for id in $(aws ec2 describe-instances --query 'Reservations[].Instances[].InstanceId' --output text); do
  echo "import {"
  echo "  to = aws_instance.imported_${id//-/_}"
  echo "  id = \"${id}\""
  echo "}"
done > imports.tf

# 3. 코드 생성 및 검토
terraform plan -generate-config-out=generated_resources.tf

# 4. 정리 및 모듈화
# generated_resources.tf를 모듈 구조에 맞게 재구성

# 5. 검증
terraform plan    # No changes 확인
```

---

## 비용 추정 (Infracost)

```bash
# 설치
brew install infracost

# API 키 설정
infracost auth login

# 비용 추정
infracost breakdown --path=environments/prod

# CI/CD PR 코멘트
infracost diff --path=environments/prod --format json --out-file=/tmp/infracost.json
infracost comment github --path=/tmp/infracost.json \
  --repo=my-org/infrastructure \
  --pull-request=$PR_NUMBER \
  --github-token=$GITHUB_TOKEN
```

### GitHub Actions 통합

```yaml
- name: Infracost
  uses: infracost/actions/setup@v3
  with:
    api-key: ${{ secrets.INFRACOST_API_KEY }}

- name: Generate cost diff
  run: |
    infracost diff \
      --path=environments/prod \
      --format=json \
      --out-file=/tmp/infracost.json

- name: Post comment
  uses: infracost/actions/comment@v1
  with:
    path: /tmp/infracost.json
    behavior: update
```

---

## 체크리스트

- [ ] Terragrunt로 DRY 원칙 적용
- [ ] 모듈 버전 관리 (Git 태그 또는 레지스트리)
- [ ] 모듈 테스트 (Terratest) 자동화
- [ ] 멀티 계정 구조 및 Cross-account IAM 설정
- [ ] OPA/Sentinel Policy as Code 적용
- [ ] 드리프트 감지 자동화 (스케줄)
- [ ] Import 전략 수립 (기존 리소스)
- [ ] Infracost로 비용 추정 CI/CD 통합
- [ ] `terragrunt run-all` 의존성 그래프 검증
- [ ] State 파일 정기 백업
- [ ] 보안 그룹 및 IAM 정책 최소 권한 검증
