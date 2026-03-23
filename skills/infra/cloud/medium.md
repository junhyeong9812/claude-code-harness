# 클라우드 - Medium Scale

> VPC 설계, 로드밸런서, Auto Scaling, IAM, 매니지드 서비스 활용

---

## 적용 대상

- 3~8명 팀, 3~15개 서비스
- 고가용성, 자동 확장 필요
- 네트워크 보안 강화
- 매니지드 서비스로 운영 부담 최소화

---

## VPC 설계

### 표준 VPC 아키텍처

```
┌──────────────────────────────────────────────────────┐
│ VPC: 10.0.0.0/16                                     │
│                                                      │
│ ┌─ AZ-a ───────────────┐  ┌─ AZ-c ────────────────┐ │
│ │                       │  │                        │ │
│ │ Public: 10.0.1.0/24  │  │ Public: 10.0.2.0/24   │ │
│ │ ┌───────┐ ┌───────┐  │  │ ┌───────┐ ┌───────┐   │ │
│ │ │  ALB  │ │  NAT  │  │  │ │  ALB  │ │  NAT  │   │ │
│ │ └───────┘ └───────┘  │  │ └───────┘ └───────┘   │ │
│ │                       │  │                        │ │
│ │ Private: 10.0.11.0/24│  │ Private: 10.0.12.0/24 │ │
│ │ ┌───────┐ ┌───────┐  │  │ ┌───────┐ ┌───────┐   │ │
│ │ │  App  │ │  App  │  │  │ │  App  │ │  App  │   │ │
│ │ └───────┘ └───────┘  │  │ └───────┘ └───────┘   │ │
│ │                       │  │                        │ │
│ │ DB: 10.0.21.0/24     │  │ DB: 10.0.22.0/24      │ │
│ │ ┌───────┐             │  │ ┌───────┐              │ │
│ │ │  RDS  │ (Primary)   │  │ │  RDS  │ (Standby)   │ │
│ │ └───────┘             │  │ └───────┘              │ │
│ └───────────────────────┘  └────────────────────────┘ │
└──────────────────────────────────────────────────────┘
```

### 서브넷 설계 규칙

| 용도 | CIDR 범위 | 설명 |
|------|-----------|------|
| Public | 10.0.1.0/24 ~ 10.0.9.0/24 | ALB, NAT Gateway, Bastion |
| Private (App) | 10.0.11.0/24 ~ 10.0.19.0/24 | 애플리케이션 서버, 컨테이너 |
| Private (DB) | 10.0.21.0/24 ~ 10.0.29.0/24 | RDS, ElastiCache |
| Private (기타) | 10.0.31.0/24 ~ 10.0.39.0/24 | Lambda, 내부 서비스 |

---

## 보안 그룹 설계

```
┌─────────────────────────────────────────┐
│ sg-alb (공개)                            │
│ Inbound:  80/443 from 0.0.0.0/0        │
│ Outbound: all to sg-app                │
├─────────────────────────────────────────┤
│ sg-app (프라이빗)                        │
│ Inbound:  3000 from sg-alb             │
│ Outbound: 5432 to sg-db                │
│ Outbound: 6379 to sg-cache             │
│ Outbound: 443 to 0.0.0.0/0 (외부 API)  │
├─────────────────────────────────────────┤
│ sg-db (프라이빗)                         │
│ Inbound:  5432 from sg-app             │
│ Outbound: none                         │
├─────────────────────────────────────────┤
│ sg-cache (프라이빗)                      │
│ Inbound:  6379 from sg-app             │
│ Outbound: none                         │
└─────────────────────────────────────────┘
```

---

## 로드밸런서

### ALB (Application Load Balancer) - AWS

```hcl
# Terraform 예시
resource "aws_lb" "app" {
  name               = "my-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnet_ids

  enable_deletion_protection = var.environment == "prod"

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.id
    prefix  = "alb"
    enabled = true
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.app.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.app.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# HTTP → HTTPS 리다이렉트
resource "aws_lb_listener" "http_redirect" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_target_group" "app" {
  name        = "my-app-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"    # ECS Fargate용

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 30
    path                = "/health"
    port                = "traffic-port"
    timeout             = 5
  }

  deregistration_delay = 30    # 그레이스풀 셧다운 대기

  stickiness {
    type    = "lb_cookie"
    enabled = false
  }
}
```

---

## Auto Scaling Group

```hcl
resource "aws_autoscaling_group" "app" {
  name                = "my-app-asg"
  desired_capacity    = 2
  min_size            = 2
  max_size            = 10
  vpc_zone_identifier = module.vpc.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 60
    }
  }

  tag {
    key                 = "Name"
    value               = "my-app"
    propagate_at_launch = true
  }
}

# CPU 기반 스케일링
resource "aws_autoscaling_policy" "cpu" {
  name                   = "cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}

# 요청 수 기반 스케일링
resource "aws_autoscaling_policy" "requests" {
  name                   = "request-count-tracking"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.app.arn_suffix}/${aws_lb_target_group.app.arn_suffix}"
    }
    target_value = 1000.0
  }
}
```

---

## IAM 역할 및 정책 설계

### 역할 분리 전략

```
IAM 역할 구조:
├── 사람 (IAM Users / SSO)
│   ├── Admin          → AdministratorAccess (긴급 시만)
│   ├── Developer      → 커스텀 정책 (읽기 + 제한된 쓰기)
│   ├── ReadOnly       → ReadOnlyAccess
│   └── CI/CD          → OIDC 기반 (장기 키 금지)
└── 서비스 (IAM Roles)
    ├── ECS Task Role  → 앱이 사용할 AWS 서비스 접근
    ├── EC2 Instance   → 인스턴스 프로파일
    └── Lambda Exec    → 실행 권한
```

### 개발자 정책 예시

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ReadAccess",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ecs:Describe*",
        "ecs:List*",
        "rds:Describe*",
        "s3:Get*",
        "s3:List*",
        "logs:Get*",
        "logs:Describe*",
        "logs:FilterLogEvents",
        "cloudwatch:Get*",
        "cloudwatch:List*"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECSDeployDev",
      "Effect": "Allow",
      "Action": [
        "ecs:UpdateService",
        "ecs:RegisterTaskDefinition"
      ],
      "Resource": "arn:aws:ecs:ap-northeast-2:*:service/dev-cluster/*",
      "Condition": {
        "StringEquals": {
          "aws:ResourceTag/Environment": "dev"
        }
      }
    },
    {
      "Sid": "DenyDangerousActions",
      "Effect": "Deny",
      "Action": [
        "ec2:TerminateInstances",
        "rds:DeleteDBInstance",
        "s3:DeleteBucket",
        "iam:CreateUser",
        "iam:DeleteUser",
        "organizations:*"
      ],
      "Resource": "*"
    }
  ]
}
```

### ECS Task Role

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3Access",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::my-app-uploads/*"
    },
    {
      "Sid": "SQSAccess",
      "Effect": "Allow",
      "Action": [
        "sqs:SendMessage",
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage"
      ],
      "Resource": "arn:aws:sqs:ap-northeast-2:*:my-app-queue"
    },
    {
      "Sid": "SecretsManager",
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:ap-northeast-2:*:secret:my-app/*"
    }
  ]
}
```

---

## 매니지드 서비스 활용

### ECS Fargate (AWS)

```hcl
# ECS 클러스터
resource "aws_ecs_cluster" "main" {
  name = "my-app-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Task Definition
resource "aws_ecs_task_definition" "app" {
  family                   = "my-app"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "app"
      image     = "${aws_ecr_repository.app.repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "NODE_ENV", value = "production" }
      ]

      secrets = [
        {
          name      = "DATABASE_URL"
          valueFrom = aws_secretsmanager_secret.db_url.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/my-app"
          "awslogs-region"        = "ap-northeast-2"
          "awslogs-stream-prefix" = "app"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 60
      }
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "app" {
  name            = "my-app"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = module.vpc.private_subnet_ids
    security_groups = [aws_security_group.app.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "app"
    container_port   = 3000
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
}
```

### Cloud Run (GCP)

```hcl
resource "google_cloud_run_v2_service" "app" {
  name     = "my-app"
  location = "asia-northeast3"

  template {
    scaling {
      min_instance_count = 1
      max_instance_count = 10
    }

    containers {
      image = "asia-northeast3-docker.pkg.dev/${var.project_id}/my-repo/my-app:latest"

      ports {
        container_port = 3000
      }

      env {
        name  = "NODE_ENV"
        value = "production"
      }

      env {
        name = "DATABASE_URL"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.db_url.secret_id
            version = "latest"
          }
        }
      }

      resources {
        limits = {
          cpu    = "1"
          memory = "512Mi"
        }
      }

      startup_probe {
        http_get {
          path = "/health"
          port = 3000
        }
        initial_delay_seconds = 10
        period_seconds        = 3
      }
    }

    service_account = google_service_account.app.email
  }

  traffic {
    type    = "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST"
    percent = 100
  }
}

# 공개 접근 허용
resource "google_cloud_run_v2_service_iam_member" "public" {
  name     = google_cloud_run_v2_service.app.name
  location = google_cloud_run_v2_service.app.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}
```

### Lambda / Cloud Functions

```hcl
# AWS Lambda
resource "aws_lambda_function" "handler" {
  function_name = "my-handler"
  runtime       = "nodejs20.x"
  handler       = "index.handler"
  timeout       = 30
  memory_size   = 256

  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")

  role = aws_iam_role.lambda_exec.arn

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.main.name
    }
  }

  tracing_config {
    mode = "Active"    # X-Ray 추적
  }
}

# API Gateway 트리거
resource "aws_apigatewayv2_api" "main" {
  name          = "my-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id             = aws_apigatewayv2_api.main.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.handler.invoke_arn
  payload_format_version = "2.0"
}
```

---

## 체크리스트

- [ ] VPC 3-tier 서브넷 설계 (Public/Private/DB)
- [ ] 보안 그룹 최소 권한 (서비스 간 참조)
- [ ] ALB + HTTPS + HTTP 리다이렉트
- [ ] Auto Scaling 또는 매니지드 서비스 사용
- [ ] IAM 역할 분리 (사람/서비스/CI)
- [ ] ECS Fargate 또는 Cloud Run 도입 검토
- [ ] Secrets Manager로 시크릿 관리
- [ ] CloudWatch/Cloud Monitoring 로깅 설정
- [ ] 배포 시 Circuit Breaker + 자동 롤백
- [ ] VPC Flow Logs 활성화
