# 공통 보안 가이드

> 모든 도메인(백엔드/프론트엔드/인프라/모델개발/데이터처리)에서 반드시 참조하는 보안 문서.
> 오케스트레이션의 모든 단계에서 이 문서를 기준으로 보안을 검증한다.

---

## 1. 시크릿/크레덴셜 관리

### 절대 금지

```
❌ 코드에 비밀번호, API 키, 토큰을 하드코딩
❌ docker-compose.yml에 평문 비밀번호
❌ terraform.tfvars에 실제 비밀번호 커밋
❌ .env 파일을 git에 커밋
❌ 로그에 토큰, 비밀번호 출력
❌ 에러 메시지에 내부 구조 노출
```

### 올바른 방법

| 환경 | 방법 |
|------|------|
| **로컬 개발** | `.env` 파일 (`.gitignore`에 반드시 등록) |
| **CI/CD** | GitHub Secrets / GitLab CI Variables (마스킹 활성화) |
| **스테이징/프로덕션** | AWS Secrets Manager / GCP Secret Manager / HashiCorp Vault |
| **쿠버네티스** | External Secrets Operator 또는 Sealed Secrets (평문 Secret 금지) |
| **Terraform** | `sensitive = true` 변수 + state 암호화 + remote backend |

### 코드 예시 — 올바른 패턴

```python
# Python — 환경 변수에서 읽기, 기본값 없음 (누락 시 즉시 실패)
import os

SECRET_KEY = os.environ["SECRET_KEY"]  # KeyError로 즉시 실패
DATABASE_URL = os.environ["DATABASE_URL"]

# Pydantic Settings (FastAPI)
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    secret_key: str           # 기본값 없음 = 필수
    database_url: str         # 기본값 없음 = 필수
    debug: bool = False       # 기본값 있음 = 선택

    class Config:
        env_file = ".env"     # 로컬에서만 사용
```

```typescript
// Node.js — zod로 환경 변수 검증 (시작 시 즉시 실패)
import { z } from 'zod';

const envSchema = z.object({
  SECRET_KEY: z.string().min(32, "SECRET_KEY must be at least 32 chars"),
  DATABASE_URL: z.string().url(),
  NODE_ENV: z.enum(["development", "staging", "production"]),
});

export const env = envSchema.parse(process.env);
// 검증 실패 시 앱 시작 자체가 안 됨
```

```go
// Go — 필수 환경 변수 검증
func mustGetEnv(key string) string {
    val := os.Getenv(key)
    if val == "" {
        log.Fatalf("required environment variable %s is not set", key)
    }
    return val
}

var (
    secretKey   = mustGetEnv("SECRET_KEY")
    databaseURL = mustGetEnv("DATABASE_URL")
)
```

---

## 2. 인증/인가 (Authentication & Authorization)

### JWT 보안 체크리스트

```
✅ 알고리즘 명시적 지정 (HS256 또는 RS256, "none" 절대 허용 금지)
✅ 토큰 만료 설정 (access: 15분, refresh: 7일 권장)
✅ 서명 검증 시 알고리즘 화이트리스트 사용
✅ Refresh token rotation (사용 시 즉시 폐기 + 새 토큰 발급)
✅ 토큰 탈취 대비: IP/User-Agent 바인딩 또는 짧은 만료
✅ 로그아웃 시 토큰 블랙리스트 (Redis) 또는 refresh token 삭제
```

### JWT 올바른 구현

```python
# Python — PyJWT 올바른 사용
import jwt
from datetime import datetime, timedelta, timezone

SECRET_KEY = os.environ["SECRET_KEY"]
ALGORITHM = "HS256"  # 명시적 지정

def create_token(user_id: str) -> str:
    payload = {
        "sub": user_id,
        "iat": datetime.now(timezone.utc),
        "exp": datetime.now(timezone.utc) + timedelta(minutes=15),
    }
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def verify_token(token: str) -> dict:
    try:
        return jwt.decode(
            token,
            SECRET_KEY,
            algorithms=[ALGORITHM],  # 리스트로 전달 — 허용 알고리즘 화이트리스트
        )
    except jwt.ExpiredSignatureError:
        raise AuthError("Token expired")
    except jwt.InvalidTokenError:
        raise AuthError("Invalid token")
```

```java
// Java/Spring — Spring Security 6 JWT 설정
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    return http
        .csrf(csrf -> csrf.disable())  // SPA는 비활성화, 서버 렌더링은 활성화
        .sessionManagement(session ->
            session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/api/public/**").permitAll()
            .requestMatchers("/api/admin/**").hasRole("ADMIN")
            .anyRequest().authenticated())
        .oauth2ResourceServer(oauth2 ->
            oauth2.jwt(jwt -> jwt.decoder(jwtDecoder())))
        .build();
}

@Bean
public JwtDecoder jwtDecoder() {
    // 알고리즘 명시적 지정
    NimbusJwtDecoder decoder = NimbusJwtDecoder
        .withSecretKey(new SecretKeySpec(secretKey.getBytes(), "HmacSHA256"))
        .macAlgorithm(MacAlgorithm.HS256)
        .build();

    // 추가 검증: issuer, audience
    OAuth2TokenValidator<Jwt> validator = new DelegatingOAuth2TokenValidator<>(
        JwtValidators.createDefault(),
        new JwtClaimValidator<>("iss", iss -> "my-app".equals(iss))
    );
    decoder.setJwtValidator(validator);
    return decoder;
}
```

### 비밀번호 저장

```
❌ 평문 저장
❌ MD5, SHA-1, SHA-256 (단순 해시)
✅ bcrypt (cost factor 12 이상)
✅ Argon2id (메모리 하드, 2025 권장)
✅ scrypt (대안)
```

```python
# Python — passlib + bcrypt
from passlib.context import CryptContext

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

hashed = pwd_context.hash("user_password")          # 해싱
is_valid = pwd_context.verify("user_password", hashed)  # 검증
```

---

## 3. 입력 검증 (Input Validation)

### 원칙

```
✅ 모든 외부 입력은 신뢰하지 않는다
✅ 서버 사이드에서 반드시 검증 (클라이언트 검증은 UX 용도)
✅ 화이트리스트 기반 검증 (허용된 것만 통과)
✅ 타입 + 범위 + 형식 모두 검증
```

### SQL Injection 방지

```python
# ❌ 절대 금지 — 문자열 포맷팅
query = f"SELECT * FROM users WHERE email = '{email}'"

# ✅ ORM 사용
user = await session.execute(select(User).where(User.email == email))

# ✅ 파라미터 바인딩 (raw query 필요 시)
result = await session.execute(
    text("SELECT * FROM users WHERE email = :email"),
    {"email": email}
)
```

```go
// ❌ 절대 금지
query := fmt.Sprintf("SELECT * FROM users WHERE email = '%s'", email)

// ✅ 파라미터 바인딩
row := db.QueryRow("SELECT * FROM users WHERE email = $1", email)

// ✅ sqlc 사용 (컴파일 타임 안전)
user, err := queries.GetUserByEmail(ctx, email)
```

### 이메일 검증 — 올바른 패턴

```python
# ❌ 부족
if "@" in email: ...

# ✅ Pydantic (Python)
from pydantic import BaseModel, EmailStr

class UserCreate(BaseModel):
    email: EmailStr  # RFC 5322 준수 검증
```

```typescript
// ❌ 부족
if (email.includes('@')) { ... }

// ✅ Zod (TypeScript)
import { z } from 'zod';

const schema = z.object({
  email: z.string().email("유효하지 않은 이메일 형식"),
});
```

---

## 4. XSS (Cross-Site Scripting) 방지

### 프론트엔드 공통 규칙

```
❌ innerHTML에 사용자 입력 직접 할당
❌ dangerouslySetInnerHTML 무분별 사용
❌ eval(), new Function() 사용
❌ URL에 javascript: 프로토콜 허용

✅ textContent 사용 (HTML 파싱 없음)
✅ createElement() + textContent 조합
✅ DOMPurify로 HTML 새니타이징 (필요 시)
✅ CSP 헤더 설정
```

### 프레임워크별 올바른 패턴

```jsx
// React — 기본적으로 안전 (자동 이스케이프)
<p>{userInput}</p>  // ✅ 자동 이스케이프

// ❌ 위험 — 반드시 새니타이저 사용
<div dangerouslySetInnerHTML={{ __html: userInput }} />

// ✅ DOMPurify 사용 시
import DOMPurify from 'dompurify';  // npm install dompurify @types/dompurify

<div dangerouslySetInnerHTML={{
  __html: DOMPurify.sanitize(userInput, {
    ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br'],
    ALLOWED_ATTR: ['href', 'target'],
  })
}} />
```

```html
<!-- Vue — 기본적으로 안전 -->
<p>{{ userInput }}</p>  <!-- ✅ 자동 이스케이프 -->

<!-- ❌ 위험 -->
<div v-html="userInput"></div>

<!-- ✅ DOMPurify 사용 시 -->
<div v-html="sanitize(userInput)"></div>
```

```javascript
// Vanilla JS
// ❌ 위험
element.innerHTML = userInput;

// ✅ 안전
element.textContent = userInput;

// ✅ HTML 필요 시 — createElement 조합
const p = document.createElement('p');
p.textContent = userInput;
container.appendChild(p);
```

### CSP (Content Security Policy) 설정

```
# 프로덕션 권장 CSP — unsafe-inline/unsafe-eval 금지
Content-Security-Policy:
  default-src 'self';
  script-src 'self' 'nonce-{RANDOM}';
  style-src 'self' 'nonce-{RANDOM}';
  img-src 'self' data: https:;
  font-src 'self';
  connect-src 'self' https://api.example.com;
  frame-ancestors 'none';
  base-uri 'self';
  form-action 'self';
```

```
❌ script-src 'unsafe-inline' 'unsafe-eval'  — CSP 무력화
✅ script-src 'nonce-{RANDOM}'               — nonce 기반 허용
```

---

## 5. CSRF (Cross-Site Request Forgery) 방지

### SPA + API 구조

```
✅ SameSite=Strict 또는 Lax 쿠키 속성
✅ Custom header 검증 (X-Requested-With)
✅ CSRF 토큰 (서버 렌더링 폼에서는 필수)
```

### CSRF 토큰 안전한 추출

```typescript
// ❌ 위험 — null 체크 없음
document.cookie.split('; ').find(row => row.startsWith('XSRF-TOKEN=')).split('=')[1];

// ✅ 안전
function getCsrfToken(): string | null {
  const match = document.cookie
    .split('; ')
    .find(row => row.startsWith('XSRF-TOKEN='));
  return match ? decodeURIComponent(match.split('=')[1]) : null;
}

// 사용 시 null 체크 필수
const token = getCsrfToken();
if (!token) {
  throw new Error('CSRF token not found');
}
```

---

## 6. 경쟁 조건 (Race Condition) 방지

### 중복 생성 문제 — Check-then-Act

```python
# ❌ 경쟁 조건 — 두 요청이 동시에 통과 가능
user = await repo.find_by_email(email)
if user:
    raise DuplicateError()
await repo.create(User(email=email))  # 두 번째 요청도 여기 도달

# ✅ DB 유니크 제약 + 예외 처리
try:
    await repo.create(User(email=email))
except IntegrityError:
    raise DuplicateError("이미 존재하는 이메일입니다")
```

```sql
-- DB 레벨 제약이 최종 방어선
ALTER TABLE users ADD CONSTRAINT users_email_unique UNIQUE (email);
```

### 재고 차감 등 동시성 문제

```python
# ❌ 경쟁 조건 — 두 요청이 동시에 같은 재고를 읽음
product = await repo.find(product_id)
if product.stock < quantity:
    raise InsufficientStock()
product.stock -= quantity
await repo.save(product)

# ✅ 비관적 잠금 (Pessimistic Locking)
product = await repo.find_with_lock(product_id)  # SELECT ... FOR UPDATE

# ✅ 낙관적 잠금 (Optimistic Locking)
# JPA: @Version 필드 사용
# SQLAlchemy: version_id_col 사용
```

---

## 7. 의존성 보안

### 체크리스트

```
✅ 정기적 취약점 스캔 (주 1회 이상)
✅ 자동 업데이트 도구 활성화 (Dependabot / Renovate)
✅ Lock 파일 커밋 (package-lock.json, poetry.lock, go.sum)
✅ 최소 의존성 원칙 — 불필요한 패키지 제거
✅ 라이선스 호환성 확인
```

### 도구별 명령어

```bash
# Python
pip-audit                           # 취약점 스캔
safety check                        # Safety DB 기반

# Node.js
npm audit                           # 내장 감사
npm audit fix                       # 자동 수정

# Go
govulncheck ./...                   # 공식 취약점 스캐너

# Java/Kotlin
./gradlew dependencyCheckAnalyze    # OWASP Dependency Check

# Docker
trivy image myapp:latest            # 컨테이너 이미지 스캔
trivy fs .                          # 파일시스템 스캔

# Terraform
tfsec .                             # Terraform 보안 스캔
checkov -d .                        # 다용도 IaC 스캔
```

---

## 8. 로깅 보안

### 절대 로그에 남기면 안 되는 것

```
❌ 비밀번호 (평문이든 해시든)
❌ JWT 토큰
❌ API 키
❌ 신용카드 번호
❌ 주민등록번호
❌ 개인 식별 정보 (이메일, 전화번호는 마스킹)
```

### 안전한 로깅 패턴

```python
import structlog

logger = structlog.get_logger()

# ❌
logger.info("login", password=password, token=token)

# ✅ 민감 정보 마스킹
def mask_email(email: str) -> str:
    local, domain = email.split("@")
    return f"{local[:2]}***@{domain}"

logger.info("login", email=mask_email(email), user_id=user_id)
```

---

## 9. API 보안

### 필수 HTTP 헤더

```python
# FastAPI 예시
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://myapp.com"],  # ❌ "*" 금지
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Authorization", "Content-Type"],
    allow_credentials=True,
)
```

### Rate Limiting

```python
# FastAPI + slowapi
from slowapi import Limiter
from slowapi.util import get_remote_address

limiter = Limiter(key_func=get_remote_address)

@app.post("/api/login")
@limiter.limit("5/minute")  # 로그인은 반드시 제한
async def login(request: Request):
    ...
```

### 에러 응답 — 내부 정보 노출 금지

```python
# ❌ 내부 정보 노출
{
  "error": "psycopg2.errors.UniqueViolation: duplicate key value violates unique constraint \"users_email_key\""
}

# ✅ 사용자 친화적 메시지만
{
  "error": {
    "code": "DUPLICATE_EMAIL",
    "message": "이미 사용 중인 이메일입니다."
  }
}
# 내부 에러는 서버 로그에만 기록
```

---

## 10. 인프라 보안

### Docker

```dockerfile
# ✅ non-root 사용자
RUN addgroup --system app && adduser --system --ingroup app app
USER app

# ✅ 최소 이미지
FROM gcr.io/distroless/python3-debian12

# ✅ .dockerignore 필수 항목
.env
.git
node_modules
__pycache__
*.secret
```

### Kubernetes

```yaml
# ✅ Pod Security Context
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
  capabilities:
    drop: ["ALL"]
```

### Terraform

```hcl
# ✅ 민감 변수 표시
variable "db_password" {
  type      = string
  sensitive = true  # plan/apply 출력에서 마스킹
}

# ✅ state 암호화 (S3 backend)
backend "s3" {
  bucket         = "myapp-terraform-state"
  key            = "state/terraform.tfstate"
  region         = "ap-northeast-2"
  encrypt        = true
  dynamodb_table = "terraform-lock"
}
```

---

## 11. 데이터 보안

### 개인정보 처리

```
✅ 저장 시 암호화 (AES-256 at rest)
✅ 전송 시 암호화 (TLS 1.3)
✅ 최소 수집 원칙 (필요한 것만)
✅ 보관 기간 설정 및 자동 삭제
✅ 접근 로그 기록 (감사 추적)
```

### 데이터 마스킹 (로그, 테스트)

```python
# 프로덕션 데이터를 테스트에 사용할 때 마스킹
def mask_pii(data: dict) -> dict:
    masked = data.copy()
    if "email" in masked:
        local, domain = masked["email"].split("@")
        masked["email"] = f"{local[:2]}***@{domain}"
    if "phone" in masked:
        masked["phone"] = masked["phone"][:3] + "****" + masked["phone"][-4:]
    if "name" in masked:
        masked["name"] = masked["name"][0] + "**"
    return masked
```

---

## 12. Insecure Design 방지 (OWASP A04)

### 위협 모델링 기본

설계 단계에서 보안을 고려하지 않으면, 구현 후 아무리 패치해도 근본적 취약점이 남는다.

### 계획 단계에서 반드시 확인

```
- [ ] 민감 데이터는 어디에 저장되고, 누가 접근하는가?
- [ ] 인증/인가가 우회될 수 있는 경로가 있는가?
- [ ] 비즈니스 로직에 악용 가능한 허점이 있는가? (무한 쿠폰, 음수 결제 등)
- [ ] 실패 시 안전한 방향으로 동작하는가? (Fail Secure)
- [ ] 외부 입력이 내부 로직에 영향을 미치는 경로를 전부 파악했는가?
```

### 보안 설계 원칙

| 원칙 | 설명 | 예시 |
|------|------|------|
| **최소 권한** | 필요한 권한만 부여 | DB 계정에 DROP 권한 제거 |
| **심층 방어** | 단일 방어선에 의존하지 않음 | 클라이언트 + 서버 + DB 레벨 검증 |
| **Fail Secure** | 실패 시 접근 거부 | 인증 서버 장애 시 요청 차단 |
| **공격 표면 최소화** | 불필요한 기능/엔드포인트 제거 | 관리자 API는 내부망 전용 |
| **기본값은 안전하게** | 옵트인 방식 | 새 엔드포인트는 기본 인증 필요 |

---

## 13. SSRF (Server-Side Request Forgery) 방지 (OWASP A10)

### 위험

서버가 사용자 입력에 따라 외부 URL을 요청하면, 내부 네트워크에 접근할 수 있다.

```python
# ❌ 위험 — 사용자가 내부 IP를 지정 가능
@app.post("/fetch")
async def fetch_url(url: str):
    response = requests.get(url)  # url = "http://169.254.169.254/latest/meta-data/"
    return response.text
```

### 방지 패턴

```python
import ipaddress
from urllib.parse import urlparse

# 허용 도메인 화이트리스트
ALLOWED_HOSTS = {"api.example.com", "cdn.example.com"}

# 차단 IP 대역 (내부 네트워크)
BLOCKED_RANGES = [
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("127.0.0.0/8"),
    ipaddress.ip_network("169.254.0.0/16"),  # AWS 메타데이터
    ipaddress.ip_network("fd00::/8"),         # IPv6 사설
]

def validate_url(url: str) -> bool:
    """외부 URL 요청 전 반드시 검증"""
    parsed = urlparse(url)

    # 1. 스킴 검증
    if parsed.scheme not in ("http", "https"):
        return False

    # 2. 호스트 화이트리스트 (가장 안전)
    if ALLOWED_HOSTS and parsed.hostname not in ALLOWED_HOSTS:
        return False

    # 3. 내부 IP 차단 (화이트리스트 없을 때)
    try:
        import socket
        resolved_ip = socket.getaddrinfo(parsed.hostname, None)[0][4][0]
        ip = ipaddress.ip_address(resolved_ip)
        for blocked in BLOCKED_RANGES:
            if ip in blocked:
                return False
    except (socket.gaierror, ValueError):
        return False

    return True


# ✅ 안전한 패턴
@app.post("/fetch")
async def fetch_url(url: str):
    if not validate_url(url):
        raise HTTPException(400, "허용되지 않는 URL입니다")
    response = requests.get(url, timeout=5)
    return response.text
```

```go
// Go — SSRF 방지
func isAllowedURL(rawURL string) bool {
    u, err := url.Parse(rawURL)
    if err != nil {
        return false
    }
    if u.Scheme != "http" && u.Scheme != "https" {
        return false
    }
    ips, err := net.LookupIP(u.Hostname())
    if err != nil {
        return false
    }
    for _, ip := range ips {
        if ip.IsLoopback() || ip.IsPrivate() || ip.IsLinkLocalUnicast() {
            return false
        }
    }
    return true
}
```

### 인프라 레벨 방지

```
✅ AWS: IMDSv2 강제 (토큰 기반 메타데이터 접근)
✅ 네트워크: 애플리케이션 서버의 아웃바운드를 필요한 대상만 허용
✅ 프록시: 외부 요청은 전용 프록시를 통해서만 (URL 필터링 적용)
```

---

## 14. 보안 검증 체크리스트 — 오케스트레이션 단계별

### 리서치 단계

```
- [ ] 기존 인증/인가 방식 파악
- [ ] 시크릿 관리 방식 파악
- [ ] 알려진 보안 취약점 확인 (CVE)
- [ ] 의존성 보안 상태 확인
```

### 계획 단계

```
- [ ] 새로운 보안 위험 요소 식별
- [ ] 인증/인가 변경이 필요한지 확인
- [ ] 입력 검증 전략 수립
- [ ] 민감 데이터 흐름 파악
```

### 구현 단계

```
- [ ] SQL injection 방지 (파라미터 바인딩)
- [ ] XSS 방지 (출력 이스케이프)
- [ ] CSRF 방지 (토큰 또는 SameSite)
- [ ] 경쟁 조건 방지 (DB 제약 + 잠금)
- [ ] 시크릿 하드코딩 없음
- [ ] 에러 메시지에 내부 정보 없음
- [ ] 로그에 민감 정보 없음
```

### 피드백 단계

```
- [ ] 의존성 취약점 스캔 실행
- [ ] 보안 헤더 확인 (CORS, CSP, HSTS)
- [ ] Rate limiting 적용 확인
- [ ] 인증이 필요한 엔드포인트 전수 확인
- [ ] 최소 권한 원칙 준수 확인
```
