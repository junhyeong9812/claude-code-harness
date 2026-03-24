# Java / Spring Boot - 소규모 프로젝트 가이드

> 엔드포인트 50개 이하, MVP/내부 툴/단일 마이크로서비스

---

## 핵심 원칙

- **Spring Boot 3.x + Java 21**: Records, Pattern Matching, Virtual Threads
- **도메인 폴더 + 플랫 파일**: 도메인별 폴더 안에 관련 파일을 평탄하게 배치
- **Records as DTO**: 불변 데이터 전달 객체
- **Service 레이어**: Controller와 Repository 사이에 비즈니스 로직 분리
- **JpaRepository**: Spring Data JPA 기본 인터페이스 활용
- **@ControllerAdvice**: 글로벌 예외 핸들링
- **Flyway**: DB 마이그레이션

---

## 디렉토리 구조

```
src/main/java/com/example/myapp/
├── MyAppApplication.java
│
├── user/
│   ├── UserController.java
│   ├── UserService.java
│   ├── UserRepository.java
│   ├── User.java                      # Entity
│   ├── UserCreateRequest.java         # Record DTO
│   ├── UserResponse.java              # Record DTO
│   └── UserNotFoundException.java
│
├── order/
│   ├── OrderController.java
│   ├── OrderService.java
│   ├── OrderRepository.java
│   ├── Order.java
│   ├── OrderItem.java
│   ├── CreateOrderRequest.java
│   ├── OrderResponse.java
│   └── InsufficientStockException.java
│
├── product/
│   ├── ProductController.java
│   ├── ProductService.java
│   ├── ProductRepository.java
│   ├── Product.java
│   ├── ProductRequest.java
│   └── ProductResponse.java
│
└── common/
    ├── GlobalExceptionHandler.java
    ├── SecurityConfig.java
    └── PageResponse.java

src/main/resources/
├── application.yml
├── db/migration/
│   └── V1__create_users.sql
└── ...

src/test/java/com/example/myapp/
├── user/
│   └── UserControllerTest.java
└── MyAppApplicationTests.java
```

---

## Entity

```java
// user/User.java
package com.example.myapp.user;

import jakarta.persistence.*;
import java.time.Instant;

@Entity
@Table(name = "users")
public class User {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, unique = true, length = 255)
    private String email;

    @Column(nullable = false, length = 100)
    private String name;

    @Column(nullable = false)
    private String password;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt = Instant.now();

    protected User() {} // JPA 전용

    public User(String email, String name, String password) {
        this.email = email;
        this.name = name;
        this.password = password;
    }

    // Getters
    public Long getId() { return id; }
    public String getEmail() { return email; }
    public String getName() { return name; }
    public String getPassword() { return password; }
    public Instant getCreatedAt() { return createdAt; }
}
```

---

## Record DTO

```java
// user/UserCreateRequest.java
package com.example.myapp.user;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record UserCreateRequest(
    @NotBlank @Email String email,
    @NotBlank @Size(max = 100) String name,
    @NotBlank @Size(min = 8) String password
) {}
```

```java
// user/UserResponse.java
package com.example.myapp.user;

import java.time.Instant;

public record UserResponse(
    Long id,
    String email,
    String name,
    Instant createdAt
) {
    public static UserResponse from(User user) {
        return new UserResponse(
            user.getId(),
            user.getEmail(),
            user.getName(),
            user.getCreatedAt()
        );
    }
}
```

---

## 도메인 예외

```java
// user/UserNotFoundException.java
package com.example.myapp.user;

public class UserNotFoundException extends RuntimeException {

    public UserNotFoundException(Long id) {
        super("사용자를 찾을 수 없습니다: id=" + id);
    }
}
```

---

## Repository

```java
// user/UserRepository.java
package com.example.myapp.user;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);
}
```

---

## Service

```java
// user/UserService.java
package com.example.myapp.user;

import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class UserService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public UserService(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Transactional
    public UserResponse createUser(UserCreateRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new IllegalArgumentException("이미 등록된 이메일입니다");
        }

        var user = new User(
            request.email(),
            request.name(),
            passwordEncoder.encode(request.password())
        );
        userRepository.save(user);
        return UserResponse.from(user);
    }

    public UserResponse getUser(Long id) {
        var user = userRepository.findById(id)
            .orElseThrow(() -> new UserNotFoundException(id));
        return UserResponse.from(user);
    }

    public Page<UserResponse> listUsers(int page, int size) {
        return userRepository.findAll(PageRequest.of(page, Math.min(size, 100)))
            .map(UserResponse::from);
    }
}
```

---

## Controller

```java
// user/UserController.java
package com.example.myapp.user;

import jakarta.validation.Valid;
import org.springframework.data.domain.Page;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse createUser(@Valid @RequestBody UserCreateRequest request) {
        return userService.createUser(request);
    }

    @GetMapping("/{id}")
    public UserResponse getUser(@PathVariable Long id) {
        return userService.getUser(id);
    }

    @GetMapping
    public Page<UserResponse> listUsers(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return userService.listUsers(page, size);
    }
}
```

---

## 글로벌 예외 핸들러

```java
// common/GlobalExceptionHandler.java
package com.example.myapp.common;

import com.example.myapp.user.UserNotFoundException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.net.URI;
import java.util.stream.Collectors;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(UserNotFoundException.class)
    public ProblemDetail handleNotFound(UserNotFoundException ex) {
        var problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.NOT_FOUND, ex.getMessage()
        );
        problem.setType(URI.create("https://api.example.com/errors/not-found"));
        return problem;
    }

    @ExceptionHandler(IllegalArgumentException.class)
    public ProblemDetail handleConflict(IllegalArgumentException ex) {
        var problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.CONFLICT, ex.getMessage()
        );
        problem.setType(URI.create("https://api.example.com/errors/conflict"));
        return problem;
    }

    @ExceptionHandler(MethodArgumentNotValidException.class)
    public ProblemDetail handleValidation(MethodArgumentNotValidException ex) {
        var errors = ex.getBindingResult().getFieldErrors().stream()
            .collect(Collectors.toMap(
                e -> e.getField(),
                e -> e.getDefaultMessage() != null ? e.getDefaultMessage() : "유효하지 않은 값"
            ));

        var problem = ProblemDetail.forStatus(HttpStatus.UNPROCESSABLE_ENTITY);
        problem.setTitle("입력값 검증 실패");
        problem.setType(URI.create("https://api.example.com/errors/validation"));
        problem.setProperty("errors", errors);
        return problem;
    }

    @ExceptionHandler(Exception.class)
    public ProblemDetail handleUnexpected(Exception ex) {
        var problem = ProblemDetail.forStatus(HttpStatus.INTERNAL_SERVER_ERROR);
        problem.setTitle("서버 내부 오류가 발생했습니다");
        problem.setType(URI.create("https://api.example.com/errors/internal"));
        return problem;
    }
}
```

---

## 공용 DTO

```java
// common/PageResponse.java
package com.example.myapp.common;

import java.util.List;

public record PageResponse<T>(
    List<T> content,
    int page,
    int size,
    long totalElements,
    int totalPages
) {
    public static <T> PageResponse<T> from(org.springframework.data.domain.Page<T> page) {
        return new PageResponse<>(
            page.getContent(),
            page.getNumber(),
            page.getSize(),
            page.getTotalElements(),
            page.getTotalPages()
        );
    }
}
```

---

## 설정

```java
// common/SecurityConfig.java
package com.example.myapp.common;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;

@Configuration
public class SecurityConfig {

    @Bean
    public PasswordEncoder passwordEncoder() {
        return new BCryptPasswordEncoder();
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http) throws Exception {
        return http
            .csrf(csrf -> csrf.disable())
            .authorizeHttpRequests(auth -> auth
                .requestMatchers("/actuator/health").permitAll()
                .requestMatchers("/api/**").permitAll()
                .anyRequest().authenticated()
            )
            .build();
    }
}
```

```yaml
# src/main/resources/application.yml
spring:
  application:
    name: my-app
  datasource:
    url: jdbc:postgresql://localhost:5432/mydb
    username: ${DB_USERNAME:postgres}
    password: ${DB_PASSWORD:postgres}
  jpa:
    hibernate:
      ddl-auto: validate  # Flyway가 스키마 관리
    open-in-view: false    # OSIV 비활성화 (필수)
    properties:
      hibernate:
        format_sql: true
  flyway:
    enabled: true
    locations: classpath:db/migration

server:
  port: ${PORT:8080}
  shutdown: graceful

logging:
  level:
    org.hibernate.SQL: DEBUG
```

---

## Flyway 마이그레이션

```sql
-- src/main/resources/db/migration/V1__create_users.sql
CREATE TABLE users (
    id         BIGSERIAL PRIMARY KEY,
    email      VARCHAR(255) NOT NULL UNIQUE,
    name       VARCHAR(100) NOT NULL,
    password   VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_users_email ON users (email);
```

---

## 테스트

```java
// src/test/java/com/example/myapp/user/UserControllerTest.java
package com.example.myapp.user;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
class UserControllerTest {

    @Autowired MockMvc mockMvc;
    @Autowired UserRepository userRepository;

    @BeforeEach
    void setUp() {
        userRepository.deleteAll();
    }

    @Test
    void 사용자_생성_성공() throws Exception {
        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"email":"test@example.com","name":"테스트","password":"password123"}
                    """))
            .andExpect(status().isCreated())
            .andExpect(jsonPath("$.email").value("test@example.com"))
            .andExpect(jsonPath("$.id").exists());
    }

    @Test
    void 중복_이메일_409() throws Exception {
        String body = """
            {"email":"dup@test.com","name":"중복","password":"password123"}
            """;
        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON).content(body));
        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isConflict());
    }

    @Test
    void 존재하지_않는_사용자_404() throws Exception {
        mockMvc.perform(get("/api/v1/users/9999"))
            .andExpect(status().isNotFound());
    }

    @Test
    void 입력값_검증_실패_422() throws Exception {
        mockMvc.perform(post("/api/v1/users")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""
                    {"email":"invalid","name":"","password":"short"}
                    """))
            .andExpect(status().isUnprocessableEntity());
    }
}
```

---

## 헬스체크

```java
// Spring Boot Actuator 사용
// build.gradle에 추가: implementation 'org.springframework.boot:spring-boot-starter-actuator'
// application.yml에 추가:
// management:
//   endpoints:
//     web:
//       exposure:
//         include: health
```

---

## 필수 의존성 (build.gradle)

```groovy
dependencies {
    implementation 'org.springframework.boot:spring-boot-starter-web'
    implementation 'org.springframework.boot:spring-boot-starter-data-jpa'
    implementation 'org.springframework.boot:spring-boot-starter-validation'
    implementation 'org.springframework.boot:spring-boot-starter-security'
    implementation 'org.springframework.boot:spring-boot-starter-actuator'
    implementation 'org.flywaydb:flyway-core'
    runtimeOnly 'org.postgresql:postgresql'

    testImplementation 'org.springframework.boot:spring-boot-starter-test'
    testRuntimeOnly 'com.h2database:h2'
}
```

---

## 소규모에서 하지 말아야 할 것

| 안티패턴 | 이유 |
|----------|------|
| 레이어별 하위 폴더 분리 | `controller/`, `service/`, `repository/` 폴더로 나누면 도메인 응집도가 떨어짐 |
| MapStruct 도입 | `Record.from()` 정적 메서드로 충분 |
| QueryDSL | JpaRepository 기본 메서드와 `@Query`로 충분 |
| 멀티 모듈 | 단일 모듈로 충분 |

---

## 전환 시그널

아래 징후가 나타나면 중규모 가이드로 전환을 검토한다:

| 시그널 | 설명 |
|--------|------|
| 엔드포인트 50개 초과 | API가 50개를 넘기면 도메인 간 의존성이 복잡해짐 |
| 도메인 폴더 7개 이상 | 패키지 탐색이 어려워지고 공통 모듈 추출이 필요해짐 |
| Service 간 순환 참조 | 도메인 간 결합도가 높아져 모듈 분리가 필요 |
| 테스트 실행 시간 3분 초과 | 테스트 격리 및 슬라이스 테스트 도입 필요 |
| 배포 파이프라인 분리 요구 | 독립 배포가 필요하면 멀티 모듈 검토 |
| 공통 코드 비율 30% 초과 | `common/` 폴더가 비대해지면 라이브러리 추출 검토 |
