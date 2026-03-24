# Java / Spring Boot - 대규모 프로젝트 가이드

> 엔드포인트 100개 이상, 4-Layer + Facade + Event + CQRS

---

## 핵심 원칙

- **중규모와 레이어 구조는 동일하다**: `api / application / domain / infrastructure`
- **대규모는 3가지만 추가한다**: Facade, Event, CQRS
- **Facade**: 모듈 간 통신의 유일한 진입점
- **Event**: `ApplicationEventPublisher`를 통한 모듈 간 비동기 통신
- **CQRS**: `application/` 하위에 `command/`, `query/`, `event/` 분리
- **도메인 모델에 JPA 어노테이션 직접 사용**: 별도 JPA Entity 불필요

---

## 중규모 대비 추가 사항 정리

| 추가 요소 | 위치 | 역할 |
|-----------|------|------|
| Facade | 모듈 최상위 | 다른 모듈이 이 모듈을 호출하는 유일한 진입점 |
| Event | 모듈 최상위 | 다른 모듈이 구독할 수 있는 공개 이벤트 |
| command/ | application/ 하위 | 쓰기 유즈케이스 |
| query/ | application/ 하위 | 읽기 유즈케이스 |
| event/ | application/ 하위 | 다른 모듈 이벤트 핸들러 |

---

## 디렉토리 구조

```
src/main/java/com/example/shop/
├── ShopApplication.java
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
│   │   └── AuthInterceptor.java
│   └── domain/
│       ├── Money.java
│       ├── Address.java
│       ├── BaseEntity.java
│       └── DomainEvent.java             # 공유 이벤트 인터페이스
│
├── order/
│   ├── OrderFacade.java                  # [대규모 추가] 모듈 공개 API
│   ├── OrderCreatedEvent.java            # [대규모 추가] 모듈 공개 이벤트
│   │
│   ├── api/
│   │   ├── OrderController.java
│   │   ├── OrderAdminController.java
│   │   └── dto/
│   │       ├── CreateOrderRequest.java
│   │       ├── OrderSearchRequest.java
│   │       ├── OrderResponse.java
│   │       └── OrderDetailResponse.java
│   │
│   ├── application/
│   │   ├── command/                      # [대규모 추가] CQRS 쓰기
│   │   │   ├── CreateOrderUseCase.java
│   │   │   ├── CancelOrderUseCase.java
│   │   │   └── RefundOrderUseCase.java
│   │   ├── query/                        # [대규모 추가] CQRS 읽기
│   │   │   ├── GetOrderUseCase.java
│   │   │   └── SearchOrdersUseCase.java
│   │   ├── event/                        # [대규모 추가] 이벤트 핸들러
│   │   │   └── PaymentCompletedHandler.java
│   │   └── OrderMapper.java
│   │
│   ├── domain/
│   │   ├── model/
│   │   │   ├── Order.java
│   │   │   ├── OrderItem.java
│   │   │   ├── OrderStatus.java
│   │   │   └── ShippingInfo.java
│   │   ├── vo/
│   │   │   └── OrderAmount.java
│   │   ├── OrderRepository.java          # interface (JpaRepository)
│   │   └── OrderDomainService.java
│   │
│   └── infrastructure/
│       ├── persistence/
│       │   └── OrderQueryRepository.java
│       ├── client/
│       │   ├── PaymentGatewayClient.java
│       │   └── ShippingApiClient.java
│       └── messaging/
│           └── OrderKafkaProducer.java
│
├── inventory/
│   ├── InventoryFacade.java
│   ├── StockDecreasedEvent.java
│   ├── api/
│   ├── application/
│   │   ├── command/
│   │   ├── query/
│   │   └── event/
│   │       └── OrderCreatedHandler.java  # order 이벤트 구독
│   ├── domain/
│   └── infrastructure/
│
├── user/
│   ├── UserFacade.java
│   ├── api/
│   ├── application/
│   ├── domain/
│   └── infrastructure/
│
└── payment/
    ├── PaymentFacade.java
    ├── PaymentCompletedEvent.java
    ├── api/
    ├── application/
    ├── domain/
    └── infrastructure/

src/test/java/com/example/shop/
├── order/
│   ├── domain/
│   │   └── OrderTest.java
│   └── application/
│       └── CreateOrderUseCaseTest.java
├── ArchitectureTest.java
└── ModulithArchitectureTest.java
```

---

## 의존성 방향 (중규모와 동일)

```
api → application → domain ← infrastructure
```

| 레이어 | 역할 | 의존 대상 |
|--------|------|-----------|
| **api** | HTTP 진입점, DTO 정의 | application만 호출 |
| **application** | 유스케이스 오케스트레이션, 트랜잭션 | domain의 Entity + Repository 인터페이스 사용 |
| **domain** | 엔티티, VO, Repository 인터페이스 | **아무것도 의존하지 않음** |
| **infrastructure** | Repository 구현체, 외부 시스템 클라이언트 | domain 인터페이스를 구현 |

---

## 모듈 간 통신 규칙

```
[order 모듈]                    [inventory 모듈]

OrderController                 InventoryController
     │                               │
CreateOrderUseCase              DecreaseStockUseCase
     │                               ▲
     ├── OrderRepository              │
     │                                │
     ├── OrderFacade ◄────────────────┘  (Facade 호출)
     │
     └── eventPublisher.publish(OrderCreatedEvent)
              │
              └──────────► OrderCreatedHandler  (Event 구독)
                           (inventory 모듈 내부)
```

| 방식 | 규칙 | 사용 시점 |
|------|------|-----------|
| **금지** | 다른 모듈 내부 직접 호출 | - |
| **허용** | Facade를 통한 동기 호출 | 즉시 응답이 필요한 경우 |
| **권장** | Event 기반 비동기 통신 | 모듈 간 완전 분리가 필요한 경우 |

---

## Facade (모듈 공개 API)

```java
// order/OrderFacade.java
package com.example.shop.order;

import com.example.shop.order.application.query.GetOrderUseCase;
import com.example.shop.order.domain.model.Order;
import com.example.shop.order.domain.model.OrderStatus;
import com.example.shop.order.domain.OrderRepository;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;

/**
 * 다른 모듈이 order 모듈에 접근하는 유일한 진입점.
 * 내부 UseCase, Repository를 직접 노출하지 않는다.
 */
@Component
public class OrderFacade {

    private final GetOrderUseCase getOrderUseCase;
    private final OrderRepository orderRepository;

    public OrderFacade(GetOrderUseCase getOrderUseCase,
                       OrderRepository orderRepository) {
        this.getOrderUseCase = getOrderUseCase;
        this.orderRepository = orderRepository;
    }

    @Transactional(readOnly = true)
    public OrderStatus getOrderStatus(Long orderId) {
        return getOrderUseCase.execute(orderId).getStatus();
    }

    @Transactional(readOnly = true)
    public BigDecimal getOrderTotal(Long orderId) {
        return getOrderUseCase.execute(orderId).getTotalAmount();
    }

    @Transactional(readOnly = true)
    public boolean existsById(Long orderId) {
        return orderRepository.findById(orderId).isPresent();
    }
}
```

> **규칙**: 다른 모듈은 `OrderFacade`만 import할 수 있다. `order.application.*`, `order.domain.*`, `order.infrastructure.*`를 직접 import하면 ArchUnit 테스트에서 실패한다.

---

## Event (모듈 공개 이벤트)

```java
// order/OrderCreatedEvent.java
package com.example.shop.order;

import java.math.BigDecimal;
import java.time.Instant;

/**
 * 모듈 최상위에 위치하는 공개 이벤트.
 * 다른 모듈이 이 이벤트를 구독할 수 있다.
 */
public record OrderCreatedEvent(
    Long orderId,
    Long userId,
    BigDecimal totalAmount,
    Instant occurredAt
) {
    public OrderCreatedEvent(Long orderId, Long userId, BigDecimal totalAmount) {
        this(orderId, userId, totalAmount, Instant.now());
    }
}
```

```java
// payment/PaymentCompletedEvent.java
package com.example.shop.payment;

import java.math.BigDecimal;
import java.time.Instant;

public record PaymentCompletedEvent(
    Long paymentId,
    Long orderId,
    BigDecimal amount,
    Instant occurredAt
) {
    public PaymentCompletedEvent(Long paymentId, Long orderId, BigDecimal amount) {
        this(paymentId, orderId, amount, Instant.now());
    }
}
```

### 이벤트 발행 (UseCase 내부)

```java
// order/application/command/CreateOrderUseCase.java (이벤트 발행 부분)
@Service
@Transactional
public class CreateOrderUseCase {

    private final OrderRepository orderRepository;
    private final OrderMapper orderMapper;
    private final ApplicationEventPublisher eventPublisher;

    // ... 생성자 생략

    public OrderResponse execute(CreateOrderRequest request) {
        var order = new Order(request.userId(), /* items */);
        orderRepository.save(order);

        // 모듈 공개 이벤트 발행
        eventPublisher.publishEvent(
            new OrderCreatedEvent(order.getId(), order.getUserId(), order.getTotalAmount())
        );

        return orderMapper.toResponse(order);
    }
}
```

---

## CQRS (Command / Query 분리)

### Command (쓰기 유즈케이스)

```java
// order/application/command/CreateOrderUseCase.java
package com.example.shop.order.application.command;

import com.example.shop.order.api.dto.CreateOrderRequest;
import com.example.shop.order.api.dto.OrderResponse;
import com.example.shop.order.application.OrderMapper;
import com.example.shop.order.domain.model.Order;
import com.example.shop.order.domain.model.OrderItem;
import com.example.shop.order.domain.OrderRepository;
import com.example.shop.order.OrderCreatedEvent;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class CreateOrderUseCase {

    private final OrderRepository orderRepository;
    private final OrderMapper orderMapper;
    private final ApplicationEventPublisher eventPublisher;

    public CreateOrderUseCase(OrderRepository orderRepository,
                              OrderMapper orderMapper,
                              ApplicationEventPublisher eventPublisher) {
        this.orderRepository = orderRepository;
        this.orderMapper = orderMapper;
        this.eventPublisher = eventPublisher;
    }

    public OrderResponse execute(CreateOrderRequest request) {
        var items = request.items().stream()
            .map(i -> new OrderItem(i.productId(), i.quantity(), i.price()))
            .toList();

        var order = new Order(request.userId(), items);
        orderRepository.save(order);

        eventPublisher.publishEvent(
            new OrderCreatedEvent(order.getId(), order.getUserId(), order.getTotalAmount())
        );

        return orderMapper.toResponse(order);
    }
}
```

```java
// order/application/command/CancelOrderUseCase.java
package com.example.shop.order.application.command;

import com.example.shop.global.exception.NotFoundException;
import com.example.shop.order.domain.OrderRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional
public class CancelOrderUseCase {

    private final OrderRepository orderRepository;

    public CancelOrderUseCase(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    public void execute(Long orderId) {
        var order = orderRepository.findById(orderId)
            .orElseThrow(() -> new NotFoundException("Order", orderId));

        order.cancel();
        orderRepository.save(order);
    }
}
```

### Query (읽기 유즈케이스)

```java
// order/application/query/GetOrderUseCase.java
package com.example.shop.order.application.query;

import com.example.shop.global.exception.NotFoundException;
import com.example.shop.order.domain.model.Order;
import com.example.shop.order.domain.OrderRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@Transactional(readOnly = true)
public class GetOrderUseCase {

    private final OrderRepository orderRepository;

    public GetOrderUseCase(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    public Order execute(Long orderId) {
        return orderRepository.findById(orderId)
            .orElseThrow(() -> new NotFoundException("Order", orderId));
    }
}
```

```java
// order/application/query/SearchOrdersUseCase.java
package com.example.shop.order.application.query;

import com.example.shop.order.api.dto.OrderSearchRequest;
import com.example.shop.order.api.dto.OrderResponse;
import com.example.shop.order.application.OrderMapper;
import com.example.shop.order.infrastructure.persistence.OrderQueryRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Service
@Transactional(readOnly = true)
public class SearchOrdersUseCase {

    private final OrderQueryRepository orderQueryRepository;
    private final OrderMapper orderMapper;

    public SearchOrdersUseCase(OrderQueryRepository orderQueryRepository,
                               OrderMapper orderMapper) {
        this.orderQueryRepository = orderQueryRepository;
        this.orderMapper = orderMapper;
    }

    public List<OrderResponse> execute(OrderSearchRequest request) {
        return orderQueryRepository
            .search(request.userId(), request.status(), request.offset(), request.limit())
            .stream()
            .map(orderMapper::toResponse)
            .toList();
    }
}
```

### Controller에서 Command/Query 분리

```java
// order/api/OrderController.java
package com.example.shop.order.api;

import com.example.shop.order.api.dto.*;
import com.example.shop.order.application.command.CreateOrderUseCase;
import com.example.shop.order.application.command.CancelOrderUseCase;
import com.example.shop.order.application.query.SearchOrdersUseCase;
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

---

## Event Handler (다른 모듈 이벤트 구독)

```java
// order/application/event/PaymentCompletedHandler.java
package com.example.shop.order.application.event;

import com.example.shop.global.exception.NotFoundException;
import com.example.shop.order.domain.OrderRepository;
import com.example.shop.payment.PaymentCompletedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * payment 모듈의 PaymentCompletedEvent를 구독한다.
 * payment 모듈은 이 핸들러의 존재를 모른다 (완전 분리).
 */
@Component
public class PaymentCompletedHandler {

    private final OrderRepository orderRepository;

    public PaymentCompletedHandler(OrderRepository orderRepository) {
        this.orderRepository = orderRepository;
    }

    @EventListener
    @Transactional
    public void handle(PaymentCompletedEvent event) {
        var order = orderRepository.findById(event.orderId())
            .orElseThrow(() -> new NotFoundException("Order", event.orderId()));

        order.markAsPaid();
        orderRepository.save(order);
    }
}
```

```java
// inventory/application/event/OrderCreatedHandler.java
package com.example.shop.inventory.application.event;

import com.example.shop.inventory.domain.InventoryRepository;
import com.example.shop.order.OrderCreatedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * order 모듈의 OrderCreatedEvent를 구독하여 재고를 차감한다.
 * order 모듈은 이 핸들러의 존재를 모른다.
 */
@Component
public class OrderCreatedHandler {

    private final InventoryRepository inventoryRepository;

    public OrderCreatedHandler(InventoryRepository inventoryRepository) {
        this.inventoryRepository = inventoryRepository;
    }

    @Async
    @EventListener
    @Transactional
    public void handle(OrderCreatedEvent event) {
        // 재고 차감 로직
        // inventoryRepository를 사용하여 처리
    }
}
```

---

## Domain Model (JPA Entity + 비즈니스 로직)

```java
// order/domain/model/Order.java
package com.example.shop.order.domain.model;

import com.example.shop.global.domain.BaseEntity;
import jakarta.persistence.*;

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

    @Embedded
    private ShippingInfo shippingInfo;

    protected Order() {} // JPA용

    public Order(Long userId, List<OrderItem> items) {
        this.userId = userId;
        this.status = OrderStatus.CREATED;
        items.forEach(this::addItem);
        this.totalAmount = calculateTotal();
    }

    // ── 비즈니스 로직 ──

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

    public void markAsPaid() {
        if (status != OrderStatus.CREATED) {
            throw new IllegalStateException("CREATED 상태에서만 결제 확정할 수 있습니다");
        }
        this.status = OrderStatus.PAID;
    }

    public void ship(ShippingInfo shippingInfo) {
        if (status != OrderStatus.PAID) {
            throw new IllegalStateException("PAID 상태에서만 배송할 수 있습니다");
        }
        this.shippingInfo = shippingInfo;
        this.status = OrderStatus.SHIPPED;
    }

    private BigDecimal calculateTotal() {
        return items.stream()
            .map(OrderItem::getSubtotal)
            .reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    // ── Getters ──

    public Long getUserId() { return userId; }
    public OrderStatus getStatus() { return status; }
    public BigDecimal getTotalAmount() { return totalAmount; }
    public List<OrderItem> getItems() { return List.copyOf(items); }
    public ShippingInfo getShippingInfo() { return shippingInfo; }
}
```

```java
// order/domain/model/OrderStatus.java
package com.example.shop.order.domain.model;

public enum OrderStatus {
    CREATED, PAID, SHIPPED, DELIVERED, CANCELLED
}
```

```java
// order/domain/model/ShippingInfo.java
package com.example.shop.order.domain.model;

import jakarta.persistence.Column;
import jakarta.persistence.Embeddable;

@Embeddable
public class ShippingInfo {

    @Column(name = "shipping_address")
    private String address;

    @Column(name = "shipping_receiver")
    private String receiver;

    @Column(name = "shipping_phone")
    private String phone;

    protected ShippingInfo() {}

    public ShippingInfo(String address, String receiver, String phone) {
        this.address = address;
        this.receiver = receiver;
        this.phone = phone;
    }

    public String getAddress() { return address; }
    public String getReceiver() { return receiver; }
    public String getPhone() { return phone; }
}
```

```java
// order/domain/OrderRepository.java
package com.example.shop.order.domain;

import com.example.shop.order.domain.model.Order;

import java.util.List;
import java.util.Optional;

public interface OrderRepository {
    Order save(Order order);
    Optional<Order> findById(Long id);
    List<Order> findByUserId(Long userId);
}
```

---

## 공유 이벤트 인터페이스

```java
// global/domain/DomainEvent.java
package com.example.shop.global.domain;

import java.time.Instant;

/**
 * 모든 모듈 공개 이벤트가 구현하는 마커 인터페이스.
 * 이벤트 로깅, 추적 등 공통 처리에 활용한다.
 */
public interface DomainEvent {
    Instant occurredAt();
}
```

---

## Spring Modulith (모듈 경계 검증, 선택사항)

```java
// src/test/java/com/example/shop/ModulithArchitectureTest.java
package com.example.shop;

import org.junit.jupiter.api.Test;
import org.springframework.modulith.core.ApplicationModules;

class ModulithArchitectureTest {

    ApplicationModules modules = ApplicationModules.of(ShopApplication.class);

    @Test
    void 모듈_구조_검증() {
        // 모듈 간 불법 의존을 자동 탐지한다.
        // order 내부 클래스를 inventory에서 직접 import하면 실패.
        modules.verify();
    }

    @Test
    void 모듈_문서_생성() {
        new org.springframework.modulith.docs.Documenter(modules)
            .writeModulesAsPlantUml()
            .writeIndividualModulesAsPlantUml();
    }
}
```

> Spring Modulith는 모듈 최상위 패키지(`order/`)의 public 클래스만 다른 모듈에 노출한다. `OrderFacade`와 `OrderCreatedEvent`는 최상위에 있으므로 공개되고, `order.application.*`, `order.domain.*` 등은 자동으로 내부 패키지로 취급된다.

---

## ArchUnit 아키텍처 테스트

```java
// src/test/java/com/example/shop/ArchitectureTest.java
package com.example.shop;

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
        classes = new ClassFileImporter().importPackages("com.example.shop");
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
            .whereLayer("API").mayNotBeAccessedByAnyLayer()
            .whereLayer("Application").mayOnlyBeAccessedByLayers("API")
            .whereLayer("Domain").mayOnlyBeAccessedByLayers("Application", "Infrastructure")
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

    /**
     * 모듈 간 통신은 Facade와 Event만 허용.
     * 다른 모듈의 내부 패키지(api, application, domain, infrastructure)를 직접 접근하면 실패.
     */
    @Test
    void 모듈_간_내부_직접_접근_금지() {
        // order 모듈 내부를 다른 모듈에서 직접 접근 불가
        noClasses().that().resideInAnyPackage(
                "..inventory..", "..user..", "..payment.."
            )
            .should().dependOnClassesThat().resideInAnyPackage(
                "..order.api..", "..order.application..", "..order.domain..", "..order.infrastructure.."
            )
            .check(classes);
    }

    @Test
    void global_패키지는_도메인_모듈에_의존하지_않는다() {
        noClasses().that().resideInAPackage("..global..")
            .should().dependOnClassesThat().resideInAnyPackage(
                "..order..", "..user..", "..inventory..", "..payment.."
            )
            .check(classes);
    }
}
```

---

## 도메인 단위 테스트

```java
// src/test/java/com/example/shop/order/domain/OrderTest.java
package com.example.shop.order.domain;

import com.example.shop.order.domain.model.*;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;
import java.util.List;

import static org.assertj.core.api.Assertions.*;

class OrderTest {

    @Test
    void 주문_생성_시_상태는_CREATED() {
        var item = new OrderItem(1L, 2, BigDecimal.valueOf(10000));
        var order = new Order(1L, List.of(item));

        assertThat(order.getStatus()).isEqualTo(OrderStatus.CREATED);
        assertThat(order.getTotalAmount()).isEqualByComparingTo(BigDecimal.valueOf(20000));
    }

    @Test
    void 결제_확정_후_상태는_PAID() {
        var item = new OrderItem(1L, 1, BigDecimal.valueOf(5000));
        var order = new Order(1L, List.of(item));

        order.markAsPaid();

        assertThat(order.getStatus()).isEqualTo(OrderStatus.PAID);
    }

    @Test
    void CREATED_상태에서만_취소_가능() {
        var item = new OrderItem(1L, 1, BigDecimal.valueOf(5000));
        var order = new Order(1L, List.of(item));
        order.markAsPaid();

        assertThatThrownBy(order::cancel)
            .isInstanceOf(IllegalStateException.class)
            .hasMessageContaining("CREATED");
    }

    @Test
    void PAID_상태에서_배송_처리() {
        var item = new OrderItem(1L, 1, BigDecimal.valueOf(5000));
        var order = new Order(1L, List.of(item));
        order.markAsPaid();

        order.ship(new ShippingInfo("서울시 강남구", "홍길동", "010-1234-5678"));

        assertThat(order.getStatus()).isEqualTo(OrderStatus.SHIPPED);
        assertThat(order.getShippingInfo().getReceiver()).isEqualTo("홍길동");
    }

    @Test
    void CREATED_상태가_아니면_결제_확정_불가() {
        var item = new OrderItem(1L, 1, BigDecimal.valueOf(5000));
        var order = new Order(1L, List.of(item));
        order.cancel();

        assertThatThrownBy(order::markAsPaid)
            .isInstanceOf(IllegalStateException.class);
    }
}
```

---

## 대규모에서 반드시 지켜야 할 것

| 규칙 | 설명 |
|------|------|
| 4-Layer 유지 | 중규모와 동일한 `api / application / domain / infrastructure` |
| Facade로 모듈 간 통신 | 다른 모듈의 내부를 직접 호출하지 않음 |
| Event로 비동기 분리 | `ApplicationEventPublisher`로 이벤트 발행, `@EventListener`로 구독 |
| CQRS 분리 | `command/` (쓰기), `query/` (읽기), `event/` (핸들러) |
| Aggregate 간 ID 참조 | `Order`가 `User`를 직접 참조하지 않음, `userId`만 보유 |
| Domain에 JPA 직접 사용 | 별도 JPA Entity 불필요, 도메인 모델이 곧 JPA Entity |
| ArchUnit으로 규칙 강제 | 4-Layer 의존성 + 모듈 간 내부 접근 금지 |
| UseCase 단위 분리 | 하나의 유즈케이스 = 하나의 클래스 |
| `@Transactional(readOnly=true)` | Query 유즈케이스에 명시 |

---

## 헥사고날은 언제 쓰는가

헥사고날 아키텍처(Ports & Adapters)는 위의 4-Layer 구조보다 훨씬 높은 비용이 든다. **아래 조건을 전부 만족할 때만** 도입을 검토한다.

### 도입 조건 (전부 만족 시)

| 조건 | 설명 |
|------|------|
| Inbound Adapter 3개 이상 | HTTP + gRPC + Message Consumer 등 진입점이 다양 |
| 외부 시스템 교체가 빈번 | 결제사, 배송사 등 외부 연동이 자주 바뀜 |
| 극도로 복잡한 도메인 | 프레임워크 의존 없이 순수 Java 단위 테스트가 필수 |
| 팀 규모 20명 이상 | 레이어 간 계약(Port)이 명확해야 병렬 개발 가능 |

### 헥사고날 적용 시 달라지는 점

```
order/
├── domain/
│   ├── model/
│   │   └── Order.java              # 순수 Java (JPA 어노테이션 없음!)
│   ├── port/
│   │   ├── OrderRepository.java    # Outbound Port (인터페이스)
│   │   └── PaymentGateway.java     # Outbound Port
│   └── service/
│       └── OrderDomainService.java
├── application/
│   └── service/
│       └── OrderCommandService.java
└── adapter/
    ├── in/
    │   ├── web/
    │   │   └── OrderController.java
    │   └── grpc/
    │       └── OrderGrpcService.java
    └── out/
        └── persistence/
            ├── OrderJpaEntity.java        # 별도 JPA Entity
            ├── OrderPersistenceAdapter.java
            └── OrderMapper.java           # Domain ↔ JPA 변환
```

### 비용

| 항목 | 비용 |
|------|------|
| Feature당 파일 수 | 15~20개 (4-Layer 대비 2배) |
| JPA Entity + Mapper 동기화 | 도메인 모델 변경 시 JPA Entity + Mapper도 함께 수정 |
| DB 교체 빈도 | 현실적으로 거의 없음 (MySQL → PostgreSQL 전환이 일어나는 프로젝트는 극소수) |
| ROI | 위 조건을 만족하지 않으면 추가 비용 대비 이득이 거의 없음 |

> **조건을 만족하지 않으면 대규모 4-Layer 구조를 쓰세요.** 4-Layer + Facade + Event + CQRS만으로 엔드포인트 100개 이상 규모를 충분히 감당할 수 있다.
