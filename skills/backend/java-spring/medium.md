# Java / Spring Boot - 중규모 프로젝트 가이드

> 팀 3~8명, 엔드포인트 20~100개, 성장하는 서비스

---

## 핵심 원칙

- **Package-by-feature**: 기능별 패키지 분리
- **Virtual Threads**: `spring.threads.virtual.enabled=true` (Java 21+)
- **MapStruct**: 컴파일 타임 DTO 매핑
- **ProblemDetail (RFC 7807)**: 표준화된 에러 응답
- **QueryDSL**: 타입 안전 동적 쿼리
- **ArchUnit**: 아키텍처 규칙 테스트

---

## 디렉토리 구조

```
src/main/java/com/example/myapp/
├── MyAppApplication.java
│
├── user/                              # 기능: 사용자
│   ├── UserController.java            # @RestController
│   ├── UserService.java               # 비즈니스 로직
│   ├── UserRepository.java            # JpaRepository
│   ├── User.java                      # @Entity
│   ├── UserMapper.java                # MapStruct 매퍼
│   ├── dto/
│   │   ├── UserCreateRequest.java     # Record
│   │   ├── UserUpdateRequest.java
│   │   └── UserResponse.java
│   └── exception/
│       └── UserNotFoundException.java
│
├── order/                             # 기능: 주문
│   ├── OrderController.java
│   ├── OrderService.java
│   ├── OrderRepository.java
│   ├── Order.java
│   ├── OrderItem.java
│   ├── OrderMapper.java
│   ├── dto/
│   │   ├── CreateOrderRequest.java
│   │   └── OrderResponse.java
│   └── exception/
│       └── InsufficientStockException.java
│
├── common/
│   ├── exception/
│   │   ├── AppException.java          # 기본 비즈니스 예외
│   │   ├── NotFoundException.java
│   │   ├── ConflictException.java
│   │   └── GlobalExceptionHandler.java
│   ├── config/
│   │   ├── SecurityConfig.java
│   │   └── JpaConfig.java
│   └── dto/
│       └── PageResponse.java
│
src/main/resources/
├── application.yml
└── db/migration/

src/test/java/com/example/myapp/
├── user/
│   ├── UserServiceTest.java
│   └── UserControllerTest.java
├── order/
│   └── OrderServiceTest.java
└── ArchitectureTest.java
```

---

## 커스텀 예외 계층

```java
// common/exception/AppException.java
package com.example.myapp.common.exception;

public abstract class AppException extends RuntimeException {
    private final String code;

    protected AppException(String message, String code) {
        super(message);
        this.code = code;
    }

    public String getCode() { return code; }
}
```

```java
// common/exception/NotFoundException.java
package com.example.myapp.common.exception;

public class NotFoundException extends AppException {
    public NotFoundException(String resource, Object id) {
        super(resource + "(" + id + ")을(를) 찾을 수 없습니다", "NOT_FOUND");
    }
}
```

```java
// common/exception/ConflictException.java
package com.example.myapp.common.exception;

public class ConflictException extends AppException {
    public ConflictException(String message) {
        super(message, "CONFLICT");
    }
}
```

---

## 글로벌 예외 핸들러 (ProblemDetail / RFC 7807)

```java
// common/exception/GlobalExceptionHandler.java
package com.example.myapp.common.exception;

import org.springframework.http.HttpStatus;
import org.springframework.http.ProblemDetail;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;

import java.net.URI;
import java.util.stream.Collectors;

@RestControllerAdvice
public class GlobalExceptionHandler {

    @ExceptionHandler(NotFoundException.class)
    public ProblemDetail handleNotFound(NotFoundException ex) {
        return buildProblem(HttpStatus.NOT_FOUND, ex.getMessage(), ex.getCode());
    }

    @ExceptionHandler(ConflictException.class)
    public ProblemDetail handleConflict(ConflictException ex) {
        return buildProblem(HttpStatus.CONFLICT, ex.getMessage(), ex.getCode());
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
        return buildProblem(HttpStatus.INTERNAL_SERVER_ERROR,
            "서버 내부 오류가 발생했습니다", "INTERNAL");
    }

    private ProblemDetail buildProblem(HttpStatus status, String detail, String code) {
        var problem = ProblemDetail.forStatusAndDetail(status, detail);
        problem.setType(URI.create("https://api.example.com/errors/" + code.toLowerCase()));
        problem.setProperty("code", code);
        return problem;
    }
}
```

---

## Service 레이어

```java
// user/UserService.java
package com.example.myapp.user;

import com.example.myapp.common.exception.ConflictException;
import com.example.myapp.common.exception.NotFoundException;
import com.example.myapp.user.dto.UserCreateRequest;
import com.example.myapp.user.dto.UserResponse;
import com.example.myapp.user.dto.UserUpdateRequest;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional(readOnly = true)
public class UserService {

    private final UserRepository userRepository;
    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;

    public UserService(UserRepository userRepository, UserMapper userMapper,
                       PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.userMapper = userMapper;
        this.passwordEncoder = passwordEncoder;
    }

    @Transactional
    public UserResponse createUser(UserCreateRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new ConflictException("이미 등록된 이메일입니다");
        }

        var user = new User(
            request.email(),
            request.name(),
            passwordEncoder.encode(request.password())
        );
        userRepository.save(user);
        return userMapper.toResponse(user);
    }

    public UserResponse getUser(Long id) {
        var user = userRepository.findById(id)
            .orElseThrow(() -> new NotFoundException("사용자", id));
        return userMapper.toResponse(user);
    }

    @Transactional
    public UserResponse updateUser(Long id, UserUpdateRequest request) {
        var user = userRepository.findById(id)
            .orElseThrow(() -> new NotFoundException("사용자", id));
        userMapper.updateEntity(request, user);
        return userMapper.toResponse(user);
    }

    public List<UserResponse> listUsers(int page, int size) {
        return userRepository
            .findAll(org.springframework.data.domain.PageRequest.of(page, Math.min(size, 100)))
            .map(userMapper::toResponse)
            .getContent();
    }
}
```

---

## MapStruct 매퍼

```java
// user/UserMapper.java
package com.example.myapp.user;

import com.example.myapp.user.dto.UserResponse;
import com.example.myapp.user.dto.UserUpdateRequest;
import org.mapstruct.BeanMapping;
import org.mapstruct.Mapper;
import org.mapstruct.MappingTarget;
import org.mapstruct.NullValuePropertyMappingStrategy;

@Mapper(componentModel = "spring")
public interface UserMapper {

    UserResponse toResponse(User user);

    @BeanMapping(nullValuePropertyMappingStrategy = NullValuePropertyMappingStrategy.IGNORE)
    void updateEntity(UserUpdateRequest request, @MappingTarget User user);
}
```

---

## Controller

```java
// user/UserController.java
package com.example.myapp.user;

import com.example.myapp.user.dto.UserCreateRequest;
import com.example.myapp.user.dto.UserResponse;
import com.example.myapp.user.dto.UserUpdateRequest;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;

    public UserController(UserService userService) {
        this.userService = userService;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse create(@Valid @RequestBody UserCreateRequest request) {
        return userService.createUser(request);
    }

    @GetMapping("/{id}")
    public UserResponse get(@PathVariable Long id) {
        return userService.getUser(id);
    }

    @PutMapping("/{id}")
    public UserResponse update(@PathVariable Long id,
                               @Valid @RequestBody UserUpdateRequest request) {
        return userService.updateUser(id, request);
    }

    @GetMapping
    public List<UserResponse> list(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        return userService.listUsers(page, size);
    }
}
```

---

## QueryDSL 동적 쿼리

```java
// user/UserRepositoryCustom.java
package com.example.myapp.user;

import java.util.List;

public interface UserRepositoryCustom {
    List<User> search(String keyword, String sortBy);
}
```

```java
// user/UserRepositoryCustomImpl.java
package com.example.myapp.user;

import com.querydsl.core.types.OrderSpecifier;
import com.querydsl.jpa.impl.JPAQueryFactory;
import java.util.List;

public class UserRepositoryCustomImpl implements UserRepositoryCustom {

    private final JPAQueryFactory queryFactory;

    public UserRepositoryCustomImpl(JPAQueryFactory queryFactory) {
        this.queryFactory = queryFactory;
    }

    @Override
    public List<User> search(String keyword, String sortBy) {
        QUser user = QUser.user;

        var query = queryFactory.selectFrom(user);

        if (keyword != null && !keyword.isBlank()) {
            query.where(
                user.name.containsIgnoreCase(keyword)
                    .or(user.email.containsIgnoreCase(keyword))
            );
        }

        OrderSpecifier<?> order = switch (sortBy) {
            case "name" -> user.name.asc();
            case "email" -> user.email.asc();
            default -> user.createdAt.desc();
        };

        return query.orderBy(order).limit(100).fetch();
    }
}
```

---

## Virtual Threads 설정

```yaml
# application.yml
spring:
  threads:
    virtual:
      enabled: true  # Java 21+ Virtual Threads 활성화
```

---

## ArchUnit 아키텍처 테스트

```java
// src/test/java/com/example/myapp/ArchitectureTest.java
package com.example.myapp;

import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.domain.JavaClasses;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.*;
import static com.tngtech.archunit.library.Architectures.layeredArchitecture;

class ArchitectureTest {

    static JavaClasses classes;

    @BeforeAll
    static void setup() {
        classes = new ClassFileImporter().importPackages("com.example.myapp");
    }

    @Test
    void 서비스는_컨트롤러에_의존하지_않는다() {
        noClasses().that().resideInAnyPackage("..service..", "..exception..")
            .should().dependOnClassesThat().resideInAPackage("..controller..")
            .check(classes);
    }

    @Test
    void 컨트롤러는_리포지토리에_직접_접근하지_않는다() {
        noClasses().that().haveNameMatching(".*Controller")
            .should().dependOnClassesThat().haveNameMatching(".*Repository")
            .check(classes);
    }

    @Test
    void 레이어드_아키텍처_준수() {
        layeredArchitecture()
            .consideringAllDependencies()
            .layer("Controller").definedBy("..controller..", "..*Controller")
            .layer("Service").definedBy("..service..", "..*Service")
            .layer("Repository").definedBy("..repository..", "..*Repository")
            .whereLayer("Controller").mayNotBeAccessedByAnyLayer()
            .whereLayer("Service").mayOnlyBeAccessedByLayers("Controller")
            .whereLayer("Repository").mayOnlyBeAccessedByLayers("Service")
            .check(classes);
    }
}
```

---

## Service 단위 테스트

```java
// src/test/java/com/example/myapp/user/UserServiceTest.java
package com.example.myapp.user;

import com.example.myapp.common.exception.ConflictException;
import com.example.myapp.common.exception.NotFoundException;
import com.example.myapp.user.dto.UserCreateRequest;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import java.util.Optional;

import static org.assertj.core.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.*;

@ExtendWith(MockitoExtension.class)
class UserServiceTest {

    @Mock UserRepository userRepository;
    @Mock UserMapper userMapper;
    @Mock PasswordEncoder passwordEncoder;
    @InjectMocks UserService userService;

    @Test
    void 사용자_생성_성공() {
        given(userRepository.existsByEmail("test@test.com")).willReturn(false);
        given(passwordEncoder.encode("pass123")).willReturn("hashed");
        given(userMapper.toResponse(any())).willReturn(
            new com.example.myapp.user.dto.UserResponse(1L, "test@test.com", "테스트", null));

        var result = userService.createUser(
            new UserCreateRequest("test@test.com", "테스트", "pass123"));

        assertThat(result.email()).isEqualTo("test@test.com");
        then(userRepository).should().save(any(User.class));
    }

    @Test
    void 중복_이메일_ConflictException() {
        given(userRepository.existsByEmail("dup@test.com")).willReturn(true);

        assertThatThrownBy(() ->
            userService.createUser(new UserCreateRequest("dup@test.com", "중복", "pass123")))
            .isInstanceOf(ConflictException.class);
    }

    @Test
    void 존재하지_않는_사용자_NotFoundException() {
        given(userRepository.findById(999L)).willReturn(Optional.empty());

        assertThatThrownBy(() -> userService.getUser(999L))
            .isInstanceOf(NotFoundException.class);
    }
}
```

---

## 중규모에서 지켜야 할 규칙

| 규칙 | 설명 |
|------|------|
| Package-by-feature | `user/`, `order/` 등 기능별 분리 |
| Controller는 Service만 호출 | Repository 직접 접근 금지 |
| `@Transactional(readOnly=true)` | 읽기 전용 메서드에 명시 |
| OSIV 비활성화 | `spring.jpa.open-in-view=false` |
| ProblemDetail 사용 | RFC 7807 표준 에러 응답 |
| ArchUnit으로 규칙 강제 | 의존성 방향 자동 검증 |
