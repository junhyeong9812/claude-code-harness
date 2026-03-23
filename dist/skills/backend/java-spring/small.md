# Java / Spring Boot - 소규모 프로젝트 가이드

> 팀 1~3명, 엔드포인트 20개 이하, MVP/내부 툴/단일 마이크로서비스

---

## 핵심 원칙

- **Spring Boot 3.x + Java 21**: Records, Pattern Matching, Virtual Threads
- **Flat 패키지 구조**: 패키지 중첩 최소화
- **Records as DTO**: 불변 데이터 전달 객체
- **JpaRepository**: Spring Data JPA 기본 인터페이스 활용
- **@ControllerAdvice**: 글로벌 예외 핸들링
- **Flyway**: DB 마이그레이션

---

## 디렉토리 구조

```
src/main/java/com/example/myapp/
├── MyAppApplication.java          # @SpringBootApplication
├── UserController.java            # @RestController
├── UserRepository.java            # JpaRepository 인터페이스
├── User.java                      # @Entity JPA 모델
├── UserCreateRequest.java         # Record DTO (요청)
├── UserResponse.java              # Record DTO (응답)
├── GlobalExceptionHandler.java    # @ControllerAdvice
└── SecurityConfig.java            # 보안 설정

src/main/resources/
├── application.yml
├── db/migration/
│   └── V1__create_users.sql
└── ...

src/test/java/com/example/myapp/
├── UserControllerTest.java
└── MyAppApplicationTests.java
```

---

## Entity

```java
// User.java
package com.example.myapp;

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
// UserCreateRequest.java
package com.example.myapp;

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
// UserResponse.java
package com.example.myapp;

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

## Repository

```java
// UserRepository.java
package com.example.myapp;

import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    boolean existsByEmail(String email);
}
```

---

## Controller

```java
// UserController.java
package com.example.myapp;

import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.List;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public UserController(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse createUser(@Valid @RequestBody UserCreateRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "이미 등록된 이메일입니다");
        }

        var user = new User(
            request.email(),
            request.name(),
            passwordEncoder.encode(request.password())
        );
        userRepository.save(user);
        return UserResponse.from(user);
    }

    @GetMapping("/{id}")
    public UserResponse getUser(@PathVariable Long id) {
        var user = userRepository.findById(id)
            .orElseThrow(() -> new ResponseStatusException(
                HttpStatus.NOT_FOUND, "사용자를 찾을 수 없습니다"));
        return UserResponse.from(user);
    }

    @GetMapping
    public List<UserResponse> listUsers(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return userRepository.findAll(
                org.springframework.data.domain.PageRequest.of(page, Math.min(size, 100)))
            .map(UserResponse::from)
            .getContent();
    }
}
```

---

## 글로벌 예외 핸들러

```java
// GlobalExceptionHandler.java
package com.example.myapp;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.server.ResponseStatusException;

import java.net.URI;
import java.util.Map;
import java.util.stream.Collectors;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(ResponseStatusException.class)
    public ProblemDetail handleResponseStatus(ResponseStatusException ex) {
        var problem = ProblemDetail.forStatusAndDetail(
            HttpStatus.valueOf(ex.getStatusCode().value()),
            ex.getReason()
        );
        problem.setType(URI.create("https://api.example.com/errors/" +
            ex.getStatusCode().value()));
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

## 설정

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
// src/test/java/com/example/myapp/UserControllerTest.java
package com.example.myapp;

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
| Service 레이어 분리 | Controller에서 Repository 직접 호출로 충분 |
| MapStruct 도입 | `Record.from()` 정적 메서드로 충분 |
| Package-by-feature | 파일이 적을 때는 flat 구조가 더 명확 |
| QueryDSL | JpaRepository 기본 메서드와 `@Query`로 충분 |
| 멀티 모듈 | 단일 모듈로 충분 |
