# 학습 기록 (Learned) — 예시

> 작성일: 2026-03-25
> 관련 계획서: docs/plans/2026-03-25/사용자인증구현/plan.md
> 작업 요약: JWT 기반 사용자 인증/인가 API 구현 (Spring Boot 3 + Java 21)

---

## 1. 사용된 라이브러리

| 라이브러리 | 버전 | 용도 | 왜 선택했는가 |
|-----------|------|------|-------------|
| spring-boot-starter-security | 3.3.0 | 인증/인가 프레임워크 | Spring 생태계 표준, 프로젝트 기존 의존성 |
| jjwt-api | 0.12.5 | JWT 생성/검증 | Spring Security 공식 문서 권장, 타입 안전한 API |
| spring-boot-starter-validation | 3.3.0 | 요청 DTO 검증 | `@Valid` + Record DTO 조합으로 간결한 검증 |

---

## 2. 핵심 함수 / 메서드

### jjwt (io.jsonwebtoken)

| 함수/메서드 | 시그니처 | 역할 | 사용 위치 |
|------------|---------|------|----------|
| `Jwts.builder()` | `JwtBuilder builder()` | JWT 빌더 생성 | `JwtProvider.java:25` |
| `.subject(String)` | `JwtBuilder subject(String sub)` | 토큰의 sub 클레임 설정 | `JwtProvider.java:27` |
| `.signWith(Key)` | `JwtBuilder signWith(Key key)` | HMAC-SHA 서명 | `JwtProvider.java:30` |
| `.compact()` | `String compact()` | 최종 JWT 문자열 생성 | `JwtProvider.java:32` |
| `Jwts.parser()` | `JwtParserBuilder parser()` | JWT 파서 빌더 생성 | `JwtProvider.java:40` |
| `.verifyWith(Key)` | `JwtParserBuilder verifyWith(SecretKey key)` | 서명 검증 키 설정 | `JwtProvider.java:41` |
| `.parseSignedClaims(String)` | `Jws<Claims> parseSignedClaims(String jwt)` | 토큰 파싱 + 서명 검증 | `JwtProvider.java:43` |

**사용 예시:**
```java
// JwtProvider.java — 토큰 생성
public String createToken(Long userId, String role) {
    return Jwts.builder()
        .subject(String.valueOf(userId))       // sub 클레임에 사용자 ID 설정
        .claim("role", role)                    // 커스텀 클레임으로 역할 추가
        .issuedAt(Date.from(Instant.now()))     // 발급 시간 (iat)
        .expiration(Date.from(                  // 만료 시간 (exp) — 15분
            Instant.now().plus(Duration.ofMinutes(15))))
        .signWith(secretKey)                    // HMAC-SHA256 서명
        .compact();                             // 최종 JWT 문자열로 직렬화
}

// JwtProvider.java — 토큰 검증
public Claims parseToken(String token) {
    return Jwts.parser()
        .verifyWith(secretKey)                  // 서명 검증할 키 설정
        .build()                                // 불변 파서 인스턴스 생성
        .parseSignedClaims(token)               // 토큰 파싱 + 서명 검증 (실패 시 JwtException)
        .getPayload();                          // Claims 객체 반환 (sub, role, exp 등)
}
```
- 출처: `src/main/java/com/example/auth/JwtProvider.java:25-48`

**코드 설명:**
- `Jwts.builder()` — jjwt 라이브러리의 정적 팩토리. 빌더 패턴으로 JWT의 각 구성요소를 설정한다.
- `.subject(String)` — JWT 표준 클레임 "sub"을 설정. 여기서는 사용자 ID를 문자열로 변환하여 저장.
- `.claim("role", role)` — 표준 클레임 외 커스텀 클레임 추가. Spring Security의 `hasRole()`에서 사용됨.
- `.signWith(secretKey)` — `SecretKey` 타입을 받으며, 키 길이에 따라 알고리즘 자동 결정 (256bit → HS256).
- `.compact()` — Header.Payload.Signature 형태의 JWT 문자열을 반환. 이 시점에 Base64URL 인코딩 + 서명 수행.
- `.verifyWith(secretKey)` — 파서에 검증용 키를 등록. 서명이 일치하지 않으면 `SignatureException` 발생.
- `.parseSignedClaims(token)` — 토큰 문자열을 파싱하고 서명/만료를 검증. 만료 시 `ExpiredJwtException`.

### Spring Security

| 함수/메서드 | 시그니처 | 역할 | 사용 위치 |
|------------|---------|------|----------|
| `SecurityFilterChain` | `@Bean SecurityFilterChain filterChain(HttpSecurity)` | 보안 필터 체인 설정 | `SecurityConfig.java:20` |
| `.addFilterBefore()` | `HttpSecurity addFilterBefore(Filter, Class)` | 커스텀 필터 삽입 위치 지정 | `SecurityConfig.java:35` |
| `OncePerRequestFilter` | `abstract class` | 요청당 1회 실행 필터 | `JwtAuthFilter.java:15` |

**사용 예시:**
```java
// SecurityConfig.java — 필터 체인 설정
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    return http
        .csrf(csrf -> csrf.disable())           // SPA + JWT이므로 CSRF 비활성화
        .sessionManagement(session ->
            session.sessionCreationPolicy(       // 서버 세션 사용 안 함
                SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/api/v1/auth/**")  // 인증 API는 누구나 접근 가능
                .permitAll()
            .requestMatchers("/api/v1/admin/**") // 관리자 API는 ADMIN 역할 필요
                .hasRole("ADMIN")
            .anyRequest().authenticated())       // 나머지는 인증 필요
        .addFilterBefore(jwtAuthFilter,          // JWT 필터를 인증 필터 앞에 삽입
            UsernamePasswordAuthenticationFilter.class)
        .build();
}
```
- 출처: `src/main/java/com/example/config/SecurityConfig.java:20-38`

**코드 설명:**
- `.csrf(csrf -> csrf.disable())` — Lambda DSL 방식. SPA에서는 Authorization 헤더로 인증하므로 CSRF 토큰 불필요.
- `SessionCreationPolicy.STATELESS` — 서버에 HttpSession을 생성하지 않음. 모든 요청은 JWT로 독립 인증.
- `.requestMatchers()` — Ant 패턴으로 URL 매칭. Spring Security 6에서 `antMatchers()` → `requestMatchers()`로 변경됨.
- `.addFilterBefore(filter, beforeClass)` — `UsernamePasswordAuthenticationFilter` 전에 JWT 필터를 삽입하여, 폼 로그인 대신 JWT로 인증 처리.

---

## 3. 어노테이션 / 데코레이터

| 어노테이션/데코레이터 | 소속 | 역할 | 적용 대상 |
|--------------------|------|------|----------|
| `@RestController` | Spring MVC | JSON 응답 컨트롤러 | `AuthController` |
| `@Valid` | Jakarta Validation | 요청 DTO 검증 트리거 | 컨트롤러 메서드 파라미터 |
| `@NotBlank` | Jakarta Validation | null/빈문자열 거부 | Record DTO 필드 |
| `@Email` | Jakarta Validation | 이메일 형식 검증 | `LoginRequest.email` |
| `@Component` | Spring | 빈 등록 | `JwtProvider`, `JwtAuthFilter` |

**동작 원리:**
- `@Valid`: Spring의 `MethodValidationInterceptor`가 바인딩 시 검증 수행. 실패하면 `MethodArgumentNotValidException` 발생 → `@ControllerAdvice`에서 422 응답.
- `@NotBlank`: `javax.validation`이 아닌 `jakarta.validation` (Spring Boot 3에서 javax → jakarta 전환됨). null, 빈 문자열, 공백만 있는 문자열 모두 거부.
- `OncePerRequestFilter`: 서블릿 필터가 포워딩/리다이렉트 시 중복 실행되는 것을 방지. `shouldNotFilter()`를 오버라이드하면 특정 경로 제외 가능.

---

## 4. 수정 전/후 코드 비교

### 파일: `src/main/java/com/example/config/SecurityConfig.java`

**수정 전:**
```java
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    return http
        .csrf(csrf -> csrf.disable())
        .authorizeHttpRequests(auth -> auth
            .anyRequest().permitAll())  // 모든 요청 허용 (인증 없음)
        .build();
}
```

**수정 후:**
```java
@Bean
public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
    return http
        .csrf(csrf -> csrf.disable())
        .sessionManagement(session ->
            session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers("/api/v1/auth/**").permitAll()
            .requestMatchers("/api/v1/admin/**").hasRole("ADMIN")
            .anyRequest().authenticated())
        .addFilterBefore(jwtAuthFilter, UsernamePasswordAuthenticationFilter.class)
        .build();
}
```

**변경 이유:** 기존에는 인증 없이 모든 요청을 허용했으나, JWT 기반 인증/인가를 적용하여 엔드포인트별 접근 제어 추가.

**변경된 함수/메서드 설명:**
| 함수/메서드 | 변경 내용 | 이유 |
|------------|----------|------|
| `sessionManagement()` | 신규 추가 | JWT는 stateless이므로 서버 세션 불필요 |
| `requestMatchers()` | `anyRequest().permitAll()` → 경로별 분기 | 인증/인가 엔드포인트 분리 |
| `addFilterBefore()` | 신규 추가 | JWT 토큰 검증 필터를 Spring Security 체인에 삽입 |

---

## 5. 동작 구조

### 실행 흐름

```
Client: POST /api/v1/auth/login {email, password}
  │
  ▼
JwtAuthFilter (OncePerRequestFilter)
  │ Authorization 헤더 확인 → 없음 (로그인 요청이므로)
  │ SecurityContext 비어 있는 채로 통과
  ▼
SecurityFilterChain
  │ "/api/v1/auth/**" → permitAll() → 인증 없이 통과
  ▼
AuthController.login(@Valid LoginRequest)
  │ @Valid → MethodArgumentNotValidException 또는 통과
  ▼
AuthService.login(LoginRequest)
  │ 1. userRepository.findByEmail(email) → User 조회
  │ 2. passwordEncoder.matches(password, user.password) → 검증
  │ 3. jwtProvider.createToken(user.id, user.role) → Access Token
  │ 4. jwtProvider.createRefreshToken(user.id) → Refresh Token
  ▼
AuthController → LoginResponse {accessToken, refreshToken}
  │
  ▼
Client: 200 OK + {accessToken, refreshToken}
```

```
Client: GET /api/v1/users/me (Authorization: Bearer {token})
  │
  ▼
JwtAuthFilter (OncePerRequestFilter)
  │ 1. extractToken(request) → "Bearer " 제거 → token 문자열
  │ 2. jwtProvider.parseToken(token) → Claims {sub, role, exp}
  │ 3. UsernamePasswordAuthenticationToken 생성
  │ 4. SecurityContextHolder.getContext().setAuthentication(auth)
  ▼
SecurityFilterChain
  │ "/api/v1/users/me" → anyRequest().authenticated()
  │ SecurityContext에 인증 정보 있음 → 통과
  ▼
UserController.getMe(@AuthenticationPrincipal)
  │ SecurityContext에서 userId 추출
  ▼
UserService.getUser(userId) → UserResponse
  │
  ▼
Client: 200 OK + {id, email, name}
```

### 컴포넌트별 역할

| 컴포넌트 | 파일 | 역할 | 호출하는 메서드 |
|----------|------|------|---------------|
| JwtAuthFilter | `auth/JwtAuthFilter.java` | HTTP 요청에서 JWT 추출 → 검증 → SecurityContext 설정 | `jwtProvider.parseToken()` |
| AuthController | `auth/AuthController.java` | 로그인/회원가입 HTTP 엔드포인트 | `authService.login()` |
| AuthService | `auth/AuthService.java` | 인증 비즈니스 로직 (비밀번호 검증, 토큰 발급) | `userRepository.findByEmail()`, `jwtProvider.createToken()` |
| JwtProvider | `auth/JwtProvider.java` | JWT 생성/검증 유틸리티 | `Jwts.builder()`, `Jwts.parser()` |
| SecurityConfig | `config/SecurityConfig.java` | 보안 필터 체인 설정 | 선언적 설정 (Bean) |

### 데이터 흐름

```
로그인:
LoginRequest {email: "user@test.com", password: "pass123"}
  → AuthService: findByEmail → User {id: 1, email, passwordHash, role: "USER"}
  → AuthService: passwordEncoder.matches("pass123", passwordHash) → true
  → JwtProvider: Claims {sub: "1", role: "USER", exp: +15min} → "eyJhbG..." (JWT)
  → LoginResponse {accessToken: "eyJhbG...", refreshToken: "eyJhbG..."}

인증된 요청:
Authorization: "Bearer eyJhbG..."
  → JwtAuthFilter: "eyJhbG..." → Claims {sub: "1", role: "USER"}
  → SecurityContext: Authentication {principal: "1", authorities: [ROLE_USER]}
  → Controller: @AuthenticationPrincipal → userId = 1
```

---

## 6. 디자인 패턴

| 패턴 | 적용 위치 | 왜 사용했는가 | 구조 |
|------|----------|-------------|------|
| Filter Chain | `JwtAuthFilter` | HTTP 요청 전처리 (인증 검증) | Servlet Filter → Spring Security Filter Chain |
| Strategy | `PasswordEncoder` | 해싱 알고리즘 교체 용이 | 인터페이스 → BCryptPasswordEncoder 구현체 |

**패턴 상세:**

### Filter Chain
- **의도**: 요청 처리 전에 인증 토큰을 검증하고, SecurityContext에 인증 정보를 설정
- **구조**: `JwtAuthFilter` → `UsernamePasswordAuthenticationFilter` → `AuthorizationFilter`
- **이 프로젝트에서의 적용**:

```java
// JwtAuthFilter.java — OncePerRequestFilter 구현
@Component
public class JwtAuthFilter extends OncePerRequestFilter {

    private final JwtProvider jwtProvider;

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                     HttpServletResponse response,
                                     FilterChain filterChain) throws ServletException, IOException {
        String token = extractToken(request);

        if (token != null) {
            try {
                Claims claims = jwtProvider.parseToken(token);
                var auth = new UsernamePasswordAuthenticationToken(
                    claims.getSubject(), null,
                    List.of(new SimpleGrantedAuthority("ROLE_" + claims.get("role")))
                );
                SecurityContextHolder.getContext().setAuthentication(auth);
            } catch (JwtException e) {
                // 토큰 무효 시 SecurityContext 비워둠 → 이후 AuthorizationFilter에서 401
            }
        }

        filterChain.doFilter(request, response);
    }

    private String extractToken(HttpServletRequest request) {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ")) {
            return header.substring(7);
        }
        return null;
    }
}
```
- 출처: `src/main/java/com/example/auth/JwtAuthFilter.java:15-50`

---

## 7. 설정 / 컨벤션

| 항목 | 값 | 이유 |
|------|---|------|
| 세션 정책 | STATELESS | JWT 기반이므로 서버 세션 불필요 |
| CSRF | 비활성화 | SPA + JWT 구조에서는 CSRF 토큰 대신 Authorization 헤더 사용 |
| Access Token 만료 | 15분 | 보안 가이드(security-common.md) 권장 |
| Refresh Token 만료 | 7일 | 보안 가이드 권장 |
| 비밀번호 해싱 | BCrypt (cost 12) | Argon2id가 권장이나 기존 코드 패턴 유지 |

---

## 8. 테스트에서 사용된 것들

### 테스트 프레임워크

| 라이브러리 | 버전 | 용도 |
|-----------|------|------|
| spring-boot-starter-test | 3.3.0 | 통합 테스트 (JUnit 5 + MockMvc + AssertJ) |
| mockito-junit-jupiter | 5.11.0 | 단위 테스트 mock |

### Mock / Stub / Spy

| 도구 | 사용 방식 | 대상 | 왜 mock했는가 |
|------|----------|------|-------------|
| `@Mock` | Mockito | `UserRepository` | DB 의존성 제거, 서비스 로직만 테스트 |
| `@Mock` | Mockito | `JwtProvider` | 토큰 생성 로직 분리 |
| `@InjectMocks` | Mockito | `AuthService` | mock 주입 대상 |

### 테스트 어노테이션 / 데코레이터

| 어노테이션 | 소속 | 역할 |
|-----------|------|------|
| `@SpringBootTest` | Spring Boot Test | 전체 컨텍스트 로드 통합 테스트 |
| `@AutoConfigureMockMvc` | Spring Boot Test | MockMvc 자동 설정 |
| `@ExtendWith(MockitoExtension.class)` | Mockito | 단위 테스트에서 mock 활성화 |

### Assertion 메서드

| 메서드 | 소속 | 검증 내용 | 예시 |
|--------|------|----------|------|
| `assertThat().isEqualTo()` | AssertJ | 값 동등성 | `assertThat(token).isNotBlank()` |
| `assertThatThrownBy()` | AssertJ | 예외 발생 검증 | `assertThatThrownBy(() -> ...).isInstanceOf(...)` |
| `status().isOk()` | MockMvc | HTTP 상태 코드 | `andExpect(status().isOk())` |
| `jsonPath()` | MockMvc | JSON 응답 필드 | `andExpect(jsonPath("$.token").exists())` |

**대표 테스트 코드:**
```java
// AuthControllerTest.java — 통합 테스트
@Test
void 로그인_성공_시_토큰_반환() throws Exception {
    mockMvc.perform(post("/api/v1/auth/login")
            .contentType(MediaType.APPLICATION_JSON)
            .content("""
                {"email":"test@example.com","password":"password123"}
                """))
        .andExpect(status().isOk())
        .andExpect(jsonPath("$.accessToken").exists())
        .andExpect(jsonPath("$.refreshToken").exists());
}

// AuthServiceTest.java — 단위 테스트 (Mockito)
@Test
void 잘못된_비밀번호_시_예외() {
    given(userRepository.findByEmail("test@test.com"))
        .willReturn(Optional.of(testUser));
    given(passwordEncoder.matches("wrong", testUser.getPassword()))
        .willReturn(false);

    assertThatThrownBy(() ->
        authService.login(new LoginRequest("test@test.com", "wrong")))
        .isInstanceOf(AuthException.class)
        .hasMessage("이메일 또는 비밀번호가 올바르지 않습니다");
}
```
- 출처: `src/test/java/com/example/auth/AuthControllerTest.java:30-45`, `AuthServiceTest.java:50-62`

---

## 9. 새로 알게 된 것

- Spring Boot 3에서 `javax.servlet` → `jakarta.servlet`으로 전환됨. 기존 코드 마이그레이션 시 주의.
- `Jwts.parser()`가 deprecated되고 `Jwts.parser().verifyWith(key).build()` 체이닝으로 변경됨 (jjwt 0.12+).
- `OncePerRequestFilter.shouldNotFilter()`를 오버라이드하면 특정 경로(/api/public/**)를 필터에서 제외할 수 있음. `SecurityConfig`의 `permitAll()`과는 별개로 필터 자체를 안 타게 하는 것.
- `UsernamePasswordAuthenticationToken(principal, credentials, authorities)` — 3인자 생성자는 자동으로 `authenticated = true`로 설정됨. 2인자 생성자는 `false`.

---

## 10. 더 공부할 것

| 주제 | 왜 공부해야 하는가 | 참고 자료 |
|------|-----------------|----------|
| Refresh Token Rotation | 현재는 단순 재발급인데, 탈취 시 연쇄 무효화 필요 | security-common.md 2절, OWASP |
| Spring Security 6 아키텍처 | FilterChain 내부 동작을 더 깊이 이해해야 커스텀 필터 설계 가능 | Spring Security Reference |
| Argon2id vs BCrypt | 현재 BCrypt 사용 중이나 Argon2id가 권장됨, 마이그레이션 비용 파악 필요 | security-common.md 2절 |
