# Java / Spring Boot - 중규모 프로젝트 가이드

> 엔드포인트 50~100개, 성장하는 서비스

---

## 핵심 원칙

- **4-Layer 도메인 모듈**: `api / application / domain / infrastructure`
- **의존성 방향**: `api → application → domain ← infrastructure`
- **domain은 아무것도 의존하지 않는다** (순수 Java)
- **global/**: 횡단 관심사 + 공유 도메인 객체 (별도 `core/` 없음)
- **하위 폴더 규칙**: 파일 4개 이상 → 하위 폴더 허용 (`dto/`, `vo/` 등), 3개 이하 → flat
- **단순 CRUD 도메인**: 레이어 분리 없이 소규모처럼 flat 유지 가능
- **Virtual Threads**: `spring.threads.virtual.enabled=true` (Java 21+)
- **MapStruct**: 컴파일 타임 DTO 매핑
- **ProblemDetail (RFC 7807)**: 표준화된 에러 응답
- **QueryDSL**: 타입 안전 동적 쿼리
- **ArchUnit**: 아키텍처 규칙 테스트로 의존성 방향 강제

---

## 디렉토리 구조

```
src/main/java/com/example/myapp/
├── MyAppApplication.java
│
├── global/
│   ├── exception/
│   │   ├── GlobalExceptionHandler.java
│   │   ├── AppException.java
│   │   └── NotFoundException.java
│   ├── config/
│   │   ├── SecurityConfig.java
│   │   ├── CorsConfig.java
│   │   └── JpaConfig.java
│   ├── auth/
│   │   ├── JwtProvider.java
│   │   ├── AuthInterceptor.java
│   │   └── CurrentUser.java
│   └── domain/                          # 공유 도메인 객체 (core/ 대신)
│       ├── Money.java
│       ├── Address.java
│       └── BaseEntity.java
│
├── order/
│   ├── api/
│   │   ├── OrderController.java
│   │   └── dto/                         # DTO 4개 이상 → 하위 폴더
│   │       ├── CreateOrderRequest.java
│   │       ├── OrderSearchRequest.java
│   │       ├── OrderResponse.java
│   │       └── OrderDetailResponse.java
│   ├── application/
│   │   ├── CreateOrderUseCase.java
│   │   ├── CancelOrderUseCase.java
│   │   ├── SearchOrdersUseCase.java
│   │   └── OrderMapper.java
│   ├── domain/
│   │   ├── Order.java
│   │   ├── OrderItem.java
│   │   ├── OrderStatus.java
│   │   ├── Money.java                   # 도메인 전용 VO (optional)
│   │   └── OrderRepository.java         # 인터페이스
│   └── infrastructure/
│       ├── OrderQueryRepository.java
│       └── PaymentClient.java
│
├── user/
│   ├── api/
│   │   ├── UserController.java
│   │   ├── UserCreateRequest.java       # DTO 적으면 flat
│   │   ├── UserUpdateRequest.java
│   │   └── UserResponse.java
│   ├── application/
│   │   ├── CreateUserUseCase.java
│   │   ├── UpdateUserUseCase.java
│   │   └── UserMapper.java
│   ├── domain/
│   │   ├── User.java
│   │   ├── UserRole.java
│   │   └── UserRepository.java
│   └── infrastructure/
│       └── UserProfileS3Client.java
│
├── product/
│   ├── api/
│   ├── application/
│   ├── domain/
│   └── infrastructure/
│
└── notification/                        # 단순 CRUD → flat 유지
    ├── NotificationController.java
    ├── NotificationService.java
    ├── Notification.java
    └── NotificationRepository.java

src/main/resources/
├── application.yml
└── db/migration/

src/test/java/com/example/myapp/
├── order/
│   └── application/
│       └── CreateOrderUseCaseTest.java
├── user/
│   └── application/
│       └── CreateUserUseCaseTest.java
└── ArchitectureTest.java
```

---

## 의존성 방향

```
api → application → domain ← infrastructure
```

| 레이어 | 역할 | 의존 대상 |
|--------|------|-----------|
| **api** | HTTP 진입점, DTO 정의 | application만 호출 |
| **application** | 유스케이스 오케스트레이션, 트랜잭션 | domain의 Entity + Repository 인터페이스 사용 |
| **domain** | 엔티티, VO, Repository 인터페이스 | **아무것도 의존하지 않음** (순수 Java) |
| **infrastructure** | Repository 구현체, 외부 시스템 클라이언트 | domain 인터페이스를 구현 |

---

## 하위 폴더 규칙

| 파일 수 | 전략 | 예시 |
|---------|------|------|
| 4개 이상 | 하위 폴더 생성 | `api/dto/`, `domain/vo/` |
| 3개 이하 | flat 배치 | `api/UserController.java`, `api/UserCreateRequest.java` |

---

## 공유 도메인 객체 (global/domain)

```java
// global/domain/BaseEntity.java
package com.example.myapp.global.domain;

import jakarta.persistence.Column;
import jakarta.persistence.EntityListeners;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.MappedSuperclass;
import org.springframework.data.annotation.CreatedDate;
import org.springframework.data.annotation.LastModifiedDate;
import org.springframework.data.jpa.domain.support.AuditingEntityListener;

import java.time.LocalDateTime;

@MappedSuperclass
@EntityListeners(AuditingEntityListener.class)
public abstract class BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @CreatedDate
    @Column(updatable = false)
    private LocalDateTime createdAt;

    @LastModifiedDate
    private LocalDateTime updatedAt;

    public Long getId() { return id; }
    public LocalDateTime getCreatedAt() { return createdAt; }
    public LocalDateTime getUpdatedAt() { return updatedAt; }
}
```

---

## 커스텀 예외 계층

```java
// global/exception/AppException.java
package com.example.myapp.global.exception;

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
// global/exception/NotFoundException.java
package com.example.myapp.global.exception;

public class NotFoundException extends AppException {
    public NotFoundException(String resource, Object id) {
        super(resource + "(" + id + ")을(를) 찾을 수 없습니다", "NOT_FOUND");
    }
}
```

---

## 글로벌 예외 핸들러 (ProblemDetail / RFC 7807)

```java
// global/exception/GlobalExceptionHandler.java
package com.example.myapp.global.exception;

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

## Entity (domain 레이어)

```java
// order/domain/Order.java
package com.example.myapp.order.domain;

import com.example.myapp.global.domain.BaseEntity;
import jakarta.persistence.CascadeType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.OneToMany;
import jakarta.persistence.Table;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "orders")
public class Order extends BaseEntity {

    @Column(nullable = false)
    private Long userId;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    private OrderStatus status;

    @Column(nullable = false, precision = 12, scale = 2)
    private BigDecimal totalAmount;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OrderItem> items = new ArrayList<>();

    protected Order() {} // JPA용

    public Order(Long userId, List<OrderItem> items) {
        this.userId = userId;
        this.status = OrderStatus.CREATED;
        items.forEach(this::addItem);
        this.totalAmount = calculateTotal();
    }

    public void addItem(OrderItem item) {
        items.add(item);
        item.assignOrder(this);
    }

    public void cancel() {
        if (status != OrderStatus.CREATED) {
            throw new IllegalStateException("CREATED 상태에서만 취소할 수 있습니다");
        }
        this.status = OrderStatus.CANCELLED;
    }

    private BigDecimal calculateTotal() {
        return items.stream()
            .map(OrderItem::getSubtotal)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    // Getters
    public Long getUserId() { return userId; }
    public OrderStatus getStatus() { return status; }
    public BigDecimal getTotalAmount() { return totalAmount; }
    public List<OrderItem> getItems() { return List.copyOf(items); }
}
```

```java
// order/domain/OrderStatus.java
package com.example.myapp.order.domain;

public enum OrderStatus {
    CREATED, PAID, SHIPPED, DELIVERED, CANCELLED
}
```

---

## Repository 인터페이스 (domain 레이어) + 구현 (infrastructure 레이어)

```java
// order/domain/OrderRepository.java
package com.example.myapp.order.domain;

import java.util.List;
import java.util.Optional;

public interface OrderRepository {
    Order save(Order order);
    Optional<Order> findById(Long id);
    List<Order> findByUserId(Long userId);
}
```

```java
// order/infrastructure/JpaOrderRepository.java (Spring Data JPA 연결)
package com.example.myapp.order.infrastructure;

import com.example.myapp.order.domain.Order;
import com.example.myapp.order.domain.OrderRepository;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * Spring Data JPA가 자동으로 구현체를 생성한다.
 * domain의 OrderRepository 인터페이스를 함께 상속하여
 * application 레이어에서 domain 인터페이스로 주입받을 수 있다.
 */
public interface JpaOrderRepository extends JpaRepository<Order, Long>, OrderRepository {
}
```

```java
// order/infrastructure/OrderQueryRepository.java (QueryDSL)
package com.example.myapp.order.infrastructure;

import com.example.myapp.order.domain.Order;
import com.example.myapp.order.domain.OrderStatus;
import com.example.myapp.order.domain.QOrder;
import com.querydsl.jpa.impl.JPAQueryFactory;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public class OrderQueryRepository {

    private final JPAQueryFactory queryFactory;

    public OrderQueryRepository(JPAQueryFactory queryFactory) {
        this.queryFactory = queryFactory;
    }

    public List<Order> search(Long userId, OrderStatus status, int offset, int limit) {
        QOrder order = QOrder.order;

        var query = queryFactory.selectFrom(order);

        if (userId != null) {
            query.where(order.userId.eq(userId));
        }
        if (status != null) {
            query.where(order.status.eq(status));
        }

        return query
            .orderBy(order.createdAt.desc())
            .offset(offset)
            .limit(limit)
            .fetch();
    }
}
```

```java
// order/infrastructure/PaymentClient.java
package com.example.myapp.order.infrastructure;

import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

@Component
public class PaymentClient {

    private final RestClient restClient;

    public PaymentClient(RestClient.Builder builder) {
        this.restClient = builder.baseUrl("https://payment.example.com").build();
    }

    public void requestPayment(Long orderId, java.math.BigDecimal amount) {
        restClient.post()
            .uri("/api/payments")
            .body(new PaymentRequest(orderId, amount))
            .retrieve()
            .toBodilessEntity();
    }

    record PaymentRequest(Long orderId, java.math.BigDecimal amount) {}
}
```

---

## UseCase / Service (application 레이어)

```java
// order/application/CreateOrderUseCase.java
package com.example.myapp.order.application;

import com.example.myapp.order.api.dto.CreateOrderRequest;
import com.example.myapp.order.api.dto.OrderResponse;
import com.example.myapp.order.domain.Order;
import com.example.myapp.order.domain.OrderItem;
import com.example.myapp.order.domain.OrderRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional
public class CreateOrderUseCase {

    private final OrderRepository orderRepository;
    private final OrderMapper orderMapper;

    public CreateOrderUseCase(OrderRepository orderRepository, OrderMapper orderMapper) {
        this.orderRepository = orderRepository;
        this.orderMapper = orderMapper;
    }

    public OrderResponse execute(CreateOrderRequest request) {
        List<OrderItem> items = request.items().stream()
            .map(i -> new OrderItem(i.productId(), i.quantity(), i.price()))
            .toList();

        var order = new Order(request.userId(), items);
        orderRepository.save(order);

        return orderMapper.toResponse(order);
    }
}
```

```java
// user/application/CreateUserUseCase.java
package com.example.myapp.user.application;

import com.example.myapp.global.exception.NotFoundException;
import com.example.myapp.user.api.UserCreateRequest;
import com.example.myapp.user.api.UserResponse;
import com.example.myapp.user.domain.User;
import com.example.myapp.user.domain.UserRepository;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class CreateUserUseCase {

    private final UserRepository userRepository;
    private final UserMapper userMapper;
    private final PasswordEncoder passwordEncoder;

    public CreateUserUseCase(UserRepository userRepository, UserMapper userMapper,
                             PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.userMapper = userMapper;
        this.passwordEncoder = passwordEncoder;
    }

    public UserResponse execute(UserCreateRequest request) {
        if (userRepository.existsByEmail(request.email())) {
            throw new IllegalArgumentException("이미 등록된 이메일입니다");
        }

        var user = new User(
            request.email(),
            request.name(),
            passwordEncoder.encode(request.password())
        );
        userRepository.save(user);

        return userMapper.toResponse(user);
    }
}
```

---

## Controller (api 레이어)

```java
// order/api/OrderController.java
package com.example.myapp.order.api;

import com.example.myapp.order.api.dto.CreateOrderRequest;
import com.example.myapp.order.api.dto.OrderResponse;
import com.example.myapp.order.api.dto.OrderSearchRequest;
import com.example.myapp.order.application.CreateOrderUseCase;
import com.example.myapp.order.application.CancelOrderUseCase;
import com.example.myapp.order.application.SearchOrdersUseCase;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

import java.util.List;

@RestController
@RequestMapping("/api/v1/orders")
public class OrderController {

    private final CreateOrderUseCase createOrderUseCase;
    private final CancelOrderUseCase cancelOrderUseCase;
    private final SearchOrdersUseCase searchOrdersUseCase;

    public OrderController(CreateOrderUseCase createOrderUseCase,
                           CancelOrderUseCase cancelOrderUseCase,
                           SearchOrdersUseCase searchOrdersUseCase) {
        this.createOrderUseCase = createOrderUseCase;
        this.cancelOrderUseCase = cancelOrderUseCase;
        this.searchOrdersUseCase = searchOrdersUseCase;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public OrderResponse create(@Valid @RequestBody CreateOrderRequest request) {
        return createOrderUseCase.execute(request);
    }

    @DeleteMapping("/{id}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void cancel(@PathVariable Long id) {
        cancelOrderUseCase.execute(id);
    }

    @GetMapping
    public List<OrderResponse> search(@ModelAttribute OrderSearchRequest request) {
        return searchOrdersUseCase.execute(request);
    }
}
```

```java
// user/api/UserController.java
package com.example.myapp.user.api;

import com.example.myapp.user.application.CreateUserUseCase;
import com.example.myapp.user.application.UpdateUserUseCase;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final CreateUserUseCase createUserUseCase;
    private final UpdateUserUseCase updateUserUseCase;

    public UserController(CreateUserUseCase createUserUseCase,
                          UpdateUserUseCase updateUserUseCase) {
        this.createUserUseCase = createUserUseCase;
        this.updateUserUseCase = updateUserUseCase;
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public UserResponse create(@Valid @RequestBody UserCreateRequest request) {
        return createUserUseCase.execute(request);
    }

    @PutMapping("/{id}")
    public UserResponse update(@PathVariable Long id,
                               @Valid @RequestBody UserUpdateRequest request) {
        return updateUserUseCase.execute(id, request);
    }
}
```

---

## MapStruct 매퍼

```java
// order/application/OrderMapper.java
package com.example.myapp.order.application;

import com.example.myapp.order.api.dto.OrderResponse;
import com.example.myapp.order.api.dto.OrderDetailResponse;
import com.example.myapp.order.domain.Order;
import org.mapstruct.Mapper;
import org.mapstruct.Mapping;

@Mapper(componentModel = "spring")
public interface OrderMapper {

    @Mapping(target = "itemCount", expression = "java(order.getItems().size())")
    OrderResponse toResponse(Order order);

    OrderDetailResponse toDetailResponse(Order order);
}
```

```java
// user/application/UserMapper.java
package com.example.myapp.user.application;

import com.example.myapp.user.api.UserResponse;
import com.example.myapp.user.api.UserUpdateRequest;
import com.example.myapp.user.domain.User;
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

## ArchUnit 아키텍처 테스트 (4-Layer 의존성 규칙)

```java
// src/test/java/com/example/myapp/ArchitectureTest.java
package com.example.myapp;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.library.Architectures.layeredArchitecture;

class ArchitectureTest {

    static JavaClasses classes;

    @BeforeAll
    static void setup() {
        classes = new ClassFileImporter().importPackages("com.example.myapp");
    }

    /**
     * 4-Layer 의존성 방향 검증:
     *   api → application → domain ← infrastructure
     */
    @Test
    void 도메인_모듈_4레이어_의존성_규칙() {
        layeredArchitecture()
            .consideringAllDependencies()
            .layer("API").definedBy("..api..")
            .layer("Application").definedBy("..application..")
            .layer("Domain").definedBy("..domain..")
            .layer("Infrastructure").definedBy("..infrastructure..")
            // API는 Application만 접근 가능
            .whereLayer("API").mayNotBeAccessedByAnyLayer()
            // Application은 API에서만 접근 가능
            .whereLayer("Application").mayOnlyBeAccessedByLayers("API")
            // Domain은 Application, Infrastructure에서 접근 가능
            .whereLayer("Domain").mayOnlyBeAccessedByLayers("Application", "Infrastructure")
            // Infrastructure는 아무도 직접 접근하지 않음 (Spring이 DI로 주입)
            .whereLayer("Infrastructure").mayNotBeAccessedByAnyLayer()
            .check(classes);
    }

    @Test
    void domain_레이어는_다른_레이어에_의존하지_않는다() {
        noClasses().that().resideInAPackage("..domain..")
            .should().dependOnClassesThat().resideInAnyPackage(
                "..api..", "..application..", "..infrastructure.."
            )
            .check(classes);
    }

    @Test
    void api_레이어는_infrastructure에_직접_접근하지_않는다() {
        noClasses().that().resideInAPackage("..api..")
            .should().dependOnClassesThat().resideInAPackage("..infrastructure..")
            .check(classes);
    }

    @Test
    void application_레이어는_infrastructure에_직접_접근하지_않는다() {
        noClasses().that().resideInAPackage("..application..")
            .should().dependOnClassesThat().resideInAPackage("..infrastructure..")
            .check(classes);
    }

    @Test
    void global_패키지는_도메인_모듈에_의존하지_않는다() {
        noClasses().that().resideInAPackage("..global..")
            .should().dependOnClassesThat().resideInAnyPackage(
                "..order..", "..user..", "..product..", "..notification.."
            )
            .check(classes);
    }
}
```

---

## UseCase 단위 테스트

```java
// src/test/java/com/example/myapp/order/application/CreateOrderUseCaseTest.java
package com.example.myapp.order.application;

import com.example.myapp.order.api.dto.CreateOrderRequest;
import com.example.myapp.order.api.dto.OrderResponse;
import com.example.myapp.order.domain.Order;
import com.example.myapp.order.domain.OrderRepository;
import com.example.myapp.order.domain.OrderStatus;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;

@ExtendWith(MockitoExtension.class)
class CreateOrderUseCaseTest {

    @Mock OrderRepository orderRepository;
    @Mock OrderMapper orderMapper;
    @InjectMocks CreateOrderUseCase createOrderUseCase;

    @Test
    void 주문_생성_성공() {
        // given
        var itemRequest = new CreateOrderRequest.ItemRequest(1L, 2, BigDecimal.valueOf(10000));
        var request = new CreateOrderRequest(1L, List.of(itemRequest));

        given(orderRepository.save(any(Order.class))).willAnswer(inv -> inv.getArgument(0));
        given(orderMapper.toResponse(any(Order.class))).willReturn(
            new OrderResponse(1L, 1L, OrderStatus.CREATED, BigDecimal.valueOf(20000), 1));

        // when
        var result = createOrderUseCase.execute(request);

        // then
        assertThat(result.status()).isEqualTo(OrderStatus.CREATED);
        assertThat(result.totalAmount()).isEqualTo(BigDecimal.valueOf(20000));
        then(orderRepository).should().save(any(Order.class));
    }
}
```

```java
// src/test/java/com/example/myapp/user/application/CreateUserUseCaseTest.java
package com.example.myapp.user.application;

import com.example.myapp.user.api.UserCreateRequest;
import com.example.myapp.user.api.UserResponse;
import com.example.myapp.user.domain.User;
import com.example.myapp.user.domain.UserRepository;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.then;

@ExtendWith(MockitoExtension.class)
class CreateUserUseCaseTest {

    @Mock UserRepository userRepository;
    @Mock UserMapper userMapper;
    @Mock PasswordEncoder passwordEncoder;
    @InjectMocks CreateUserUseCase createUserUseCase;

    @Test
    void 사용자_생성_성공() {
        // given
        given(userRepository.existsByEmail("test@test.com")).willReturn(false);
        given(passwordEncoder.encode("pass123")).willReturn("hashed");
        given(userMapper.toResponse(any())).willReturn(
            new UserResponse(1L, "test@test.com", "테스트"));

        // when
        var result = createUserUseCase.execute(
            new UserCreateRequest("test@test.com", "테스트", "pass123"));

        // then
        assertThat(result.email()).isEqualTo("test@test.com");
        then(userRepository).should().save(any(User.class));
    }

    @Test
    void 중복_이메일이면_예외_발생() {
        // given
        given(userRepository.existsByEmail("dup@test.com")).willReturn(true);

        // when & then
        assertThatThrownBy(() ->
            createUserUseCase.execute(
                new UserCreateRequest("dup@test.com", "중복", "pass123")))
            .isInstanceOf(IllegalArgumentException.class)
            .hasMessageContaining("이미 등록된 이메일");
    }
}
```

---

## 설정 (application.yml)

```yaml
# application.yml
spring:
  threads:
    virtual:
      enabled: true                  # Java 21+ Virtual Threads

  jpa:
    open-in-view: false              # OSIV 비활성화 (필수)
    hibernate:
      ddl-auto: validate             # Flyway로 DDL 관리
    properties:
      hibernate:
        default_batch_fetch_size: 100
        format_sql: true

  flyway:
    enabled: true
    baseline-on-migrate: true

server:
  shutdown: graceful

logging:
  level:
    org.hibernate.SQL: debug
    org.hibernate.orm.jdbc.bind: trace
```

---

## 중규모에서 지켜야 할 규칙

| 규칙 | 설명 |
|------|------|
| 4-Layer 도메인 모듈 | `api / application / domain / infrastructure` |
| 의존성 방향 | `api → application → domain ← infrastructure` |
| domain은 순수 Java | Spring, JPA 어노테이션만 예외적으로 허용 |
| UseCase 단위 분리 | 하나의 유스케이스 = 하나의 클래스 |
| Controller는 UseCase만 호출 | Repository 직접 접근 금지 |
| `@Transactional(readOnly=true)` | 읽기 전용 UseCase에 명시 |
| OSIV 비활성화 | `spring.jpa.open-in-view=false` |
| ProblemDetail 사용 | RFC 7807 표준 에러 응답 |
| ArchUnit으로 규칙 강제 | 4-Layer 의존성 방향 자동 검증 |
| 하위 폴더 규칙 | 파일 4개 이상이면 하위 폴더, 3개 이하면 flat |
| 단순 CRUD는 flat | notification처럼 복잡도 낮으면 레이어 분리 불필요 |

---

## 전환 시그널

### 소규모 → 중규모 전환이 필요한 시점

| 시그널 | 설명 |
|--------|------|
| Service 클래스가 300줄 이상 | 유스케이스 분리가 필요한 시점 |
| 도메인 간 의존이 생김 | Order가 User를 직접 참조하기 시작하면 레이어 분리 필요 |
| Repository 커스텀 쿼리 증가 | QueryDSL 도입 + infrastructure 레이어 분리 시점 |
| DTO가 도메인별 4개 이상 | dto/ 하위 폴더 + api 레이어 분리 시점 |
| 외부 시스템 연동 추가 | 결제, 알림 등 외부 API 호출이 생기면 infrastructure 분리 |
| 테스트에서 Mock이 5개 이상 | 의존성이 과도하다는 신호, 레이어 분리로 책임 축소 |

### 중규모 → 대규모 전환이 필요한 시점

| 시그널 | 설명 |
|--------|------|
| 엔드포인트 100개 초과 | 모듈 간 경계가 명확해져야 함 |
| 도메인 모듈 간 순환 의존 | 이벤트 기반 통신 또는 모듈 분리 필요 |
| 배포 단위 분리 요구 | 마이크로서비스 또는 멀티 모듈 전환 |
| 도메인 이벤트 필요 | `ApplicationEventPublisher` → 별도 이벤트 모듈 |
| 팀이 도메인별로 분리 | 코드 소유권 경계가 필요한 시점 |
