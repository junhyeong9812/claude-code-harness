# 인프라 스킬

> 인프라 관련 작업 시 자동 활성화되는 가이드

---

## 매칭 조건

| 조건 | 감지 대상 |
|------|----------|
| **키워드** | "인프라", "배포", "CI/CD", "도커", "쿠버네티스", "클라우드", "서버 설정", "테라폼", "모니터링" |
| **의도** | 배포 설정, 인프라 구성, 모니터링 설정, 파이프라인 구축, 컨테이너화, IaC |
| **파일 경로** | `infra/`, `deploy/`, `terraform/`, `k8s/`, `.github/workflows/`, `docker-compose.yml` |
| **파일 내용** | `Dockerfile`, `docker-compose`, `resource "aws_`, `apiVersion:`, `provider "`, `helm` |

---

## 규모별 분류

### Small (소규모)

- **팀 규모**: 1~3명
- **서비스 수**: 1~3개
- **특징**: 빠른 셋업, 단일 환경, 수동 운영 허용
- **핵심 원칙**: 최소한의 도구로 동작하는 인프라. 복잡성 최소화
- **적합한 경우**: MVP, 사이드 프로젝트, PoC, 내부 툴

### Medium (중규모)

- **팀 규모**: 3~8명
- **서비스 수**: 3~15개
- **특징**: 환경 분리(dev/staging/prod), 자동화된 배포, IaC 도입
- **핵심 원칙**: 재현 가능한 인프라. 코드로 관리되는 환경 설정
- **적합한 경우**: 성장하는 스타트업, B2B SaaS, 사내 핵심 시스템

### Large (대규모)

- **팀 규모**: 8명 이상, 여러 팀/조직 협업
- **서비스 수**: 15개 이상
- **특징**: 멀티 클러스터/계정, GitOps, Policy as Code, 옵저버빌리티
- **핵심 원칙**: 자동화 우선. 보안 내재화. 비용 최적화. 감사 가능성
- **적합한 경우**: 대규모 서비스, 핀테크, 엔터프라이즈, 멀티 리전

---

## 공통 체크 항목

모든 규모에서 반드시 확인할 사항:

| 항목 | 설명 |
|------|------|
| **시크릿 관리** | 하드코딩 금지, 환경 변수 또는 시크릿 매니저 사용 |
| **환경 분리** | dev/staging/prod 설정 분리 |
| **롤백 전략** | 배포 실패 시 롤백 절차 명확화 |
| **태깅/네이밍** | 리소스 태깅 및 네이밍 컨벤션 준수 |
| **비용 관리** | 비용 영향 사전 검토, 불필요 리소스 정리 |
| **보안** | 최소 권한 원칙, 네트워크 격리, 암호화 |
| **백업** | 데이터 백업 및 복구 절차 |
| **로깅/모니터링** | 최소한의 가시성 확보 |

### 리서치 단계
- [ ] 현재 인프라 구성 파악
- [ ] 환경 분리 확인 (dev / staging / prod)
- [ ] 시크릿 관리 방식 확인
- [ ] 기존 CI/CD 파이프라인 확인
- [ ] 네트워크 / 보안그룹 구성 확인

### 구현 단계
- [ ] 시크릿/크레덴셜 하드코딩 금지
- [ ] 환경별 설정 분리
- [ ] 롤백 가능한 배포 전략
- [ ] 리소스 태깅 / 네이밍 컨벤션 준수
- [ ] 비용 영향 검토

### 셀프체크
- [ ] 민감 정보가 코드에 노출되지 않는가?
- [ ] 프로덕션에 영향 없이 적용 가능한가?
- [ ] 롤백 절차가 명확한가?
- [ ] 비용이 예상 범위 내인가?

---

## 영역별 가이드

| 영역 | Small | Medium | Large |
|------|-------|--------|-------|
| **Docker / Compose** | [small](docker/small.md) | [medium](docker/medium.md) | [large](docker/large.md) |
| **Kubernetes** | [small](kubernetes/small.md) | [medium](kubernetes/medium.md) | [large](kubernetes/large.md) |
| **Terraform / IaC** | [small](terraform/small.md) | [medium](terraform/medium.md) | [large](terraform/large.md) |
| **CI/CD** | [small](cicd/small.md) | [medium](cicd/medium.md) | [large](cicd/large.md) |
| **클라우드 (AWS/GCP)** | [small](cloud/small.md) | [medium](cloud/medium.md) | [large](cloud/large.md) |
| **모니터링 / 로깅** | [small](monitoring/small.md) | [medium](monitoring/medium.md) | [large](monitoring/large.md) |
