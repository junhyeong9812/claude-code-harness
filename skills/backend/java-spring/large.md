# Java / Spring Boot - 대규모 프로젝트 가이드

> 팀 8명 이상, 엔드포인트 100개 이상, 헥사고날(Ports & Adapters) + DDD

---

## 핵심 원칙

- **헥사고날 아키텍처**: Domain ← Application ← Infrastructure/Adapter
- **DDD**: Aggregate Root, Value Object, Domain Event, Bounded Context
- **도메인 모델에 JPA 어노테이션 없음**: 별도 JPA Entity로 매핑
- **Spring Modulith**: 모듈 간 경계 강제, 이벤트 기반 통신
- **CQRS**: Command/Query 분리 (최소 코드 레벨)
- **Domain Events**: `ApplicationEventPublisher`를 통한 이벤트 발행

> 참고: `/home/jun/project/spring-architecture` 프로젝트의 실제 구조를 기반으로 확장

---

## 디렉토리 구조

```
src/main/java/com/example/shop/
├── ShopApplication.java
│
├── order/                                 # Bounded Context: 주문
│   ├── domain/                            # 도메인 레이어 (프레임워크 무의존)
│   │   ├── model/
│   │   │   ├── Order.java                 # Aggregate Root (순수 Java)
│   │   │   ├── OrderItem.java             # Entity
│   │   │   ├── Money.java                 # Value Object
│   │   │   ├── OrderStatus.java           # Value Object (enum)
│   │   │   └── Address.java               # Value Object
│   │   ├── event/
│   │   │   ├── OrderCreatedEvent.java     # Domain Event
│   │   │   └── OrderCancelledEvent.java
│   │   ├── port/
│   │   │   ├── OrderRepository.java       # Outbound Port (인터페이스)
│   │   │   └── PaymentGateway.java        # Outbound Port
│   │   ├── service/
│   │   │   └── OrderDomainService.java    # 도메인 서비스
│   │   └── exception/
│   │       ├── OrderDomainException.java
│   │       └── InvalidTransitionException.java
│   │
│   ├── application/                       # 애플리케이션 레이어
│   │   ├── usecase/
│   │   │   ├── CreateOrderUseCase.java    # 유스케이스 인터페이스
│   │   │   └── CancelOrderUseCase.java
│   │   ├── service/
│   │   │   ├── OrderCommandService.java   # Command 처리
│   │   │   └── OrderQueryService.java     # Query 처리
│   │   ├── command/
│   │   │   ├── CreateOrderCommand.java
│   │   │   └── CancelOrderCommand.java
│   │   └── query/
│   │       └── OrderQueryDto.java
│   │
│   └── adapter/                           # 어댑터 레이어
│       ├── in/
│       │   └── web/
│       │       ├── OrderController.java   # Inbound Adapter (HTTP)
│       │       ├── OrderRequest.java
│       │       └── OrderResponse.java
│       └── out/
│           ├── persistence/
│           │   ├── OrderJpaEntity.java    # JPA Entity (별도!)
│           │   ├── OrderItemJpaEntity.java
│           │   ├── OrderJpaRepository.java
│           │   ├── OrderPersistenceAdapter.java  # Outbound Adapter
│           │   └── OrderMapper.java       # Domain ↔ JPA 변환
│           └── payment/
│               └── StripePaymentAdapter.java
│
├── user/                                  # Bounded Context: 사용자
│   ├── domain/
│   ├── application/
│   └── adapter/
│
├── shared/                                # 공유 커널
│   ├── domain/
│   │   └── DomainEvent.java
│   ├── events/
│   │   └── OrderCreatedEvent.java         # 공유 이벤트 (Context 간)
│   └── SubscriptionContext.java           # 이벤트 구독 등록
│
└── config/
    └── ModulithConfig.java

src/test/java/com/example/shop/
├── order/
│   ├── domain/
│   │   └── OrderTest.java                # 도메인 단위 테스트
│   ├── application/
│   │   └── OrderCommandServiceTest.java
│   └── adapter/
│       └── OrderControllerTest.java
└── ModulithArchitectureTest.java
```

---

## 도메인 모델 (JPA 어노테이션 없음!)

### Value Objects

```java
// order/domain/model/Money.java
package com.example.shop.order.domain.model;

import java.math.BigDecimal;
import java.util.Objects;

public record Money(BigDecimal amount, String currency) {

    public Money {
        if (amount.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("금액은 0 이상이어야 합니다");
        }
        if (currency == null || currency.isBlank()) {
            currency = "KRW";
        }
    }

    public static Money krw(long amount) {
        return new Money(BigDecimal.valueOf(amount), "KRW");
    }

    public Money add(Money other) {
        if (!this.currency.equals(other.currency)) {
            throw new IllegalArgumentException("통화가 다릅니다");
        }
        return new Money(this.amount.add(other.amount), this.currency);
    }

    public Money multiply(int quantity) {
        return new Money(this.amount.multiply(BigDecimal.valueOf(quantity)), this.currency);
    }
}
```

```java
// order/domain/model/OrderStatus.java
package com.example.shop.order.domain.model;

import java.util.Map;
import java.util.Set;

public enum OrderStatus {
    PENDING, CONFIRMED, SHIPPED, DELIVERED, CANCELLED;

    private static final Map<OrderStatus, Set<OrderStatus>> TRANSITIONS = Map.of(
        PENDING, Set.of(CONFIRMED, CANCELLED),
        CONFIRMED, Set.of(SHIPPED, CANCELLED),
        SHIPPED, Set.of(DELIVERED)
    );

    public boolean canTransitionTo(OrderStatus target) {
        return TRANSITIONS.getOrDefault(this, Set.of()).contains(target);
    }
}
```

### Aggregate Root (순수 Java)

```java
// order/domain/model/Order.java
package com.example.shop.order.domain.model;

import com.example.shop.order.domain.event.OrderCreatedEvent;
import com.example.shop.order.domain.event.OrderCancelledEvent;
import com.example.shop.order.domain.exception.InvalidTransitionException;

import java.time.Instant;
import java.util.*;

public class Order {

    private final UUID id;
    private final UUID customerId;
    private final List<OrderItem> items = new ArrayList<>();
    private OrderStatus status;
    private Address shippingAddress;
    private final Instant createdAt;

    // 도메인 이벤트 수집
    private final List<Object> domainEvents = new ArrayList<>();

    public Order(UUID id, UUID customerId) {
        this.id = id;
        this.customerId = customerId;
        this.status = OrderStatus.PENDING;
        this.createdAt = Instant.now();
    }

    // 복원용 생성자 (검증 없음)
    public Order(UUID id, UUID customerId, List<OrderItem> items,
                 OrderStatus status, Address address, Instant createdAt) {
        this.id = id;
        this.customerId = customerId;
        this.items.addAll(items);
        this.status = status;
        this.shippingAddress = address;
        this.createdAt = createdAt;
    }

    public void addItem(UUID productId, String name, Money price, int qty) {
        if (status != OrderStatus.PENDING) {
            throw new InvalidTransitionException("확정된 주문에 상품을 추가할 수 없습니다");
        }
        items.add(new OrderItem(productId, name, price, qty));
    }

    public Money total() {
        return items.stream()
            .map(OrderItem::subtotal)
            .reduce(Money.krw(0), Money::add);
    }

    public void confirm() {
        if (!status.canTransitionTo(OrderStatus.CONFIRMED)) {
            throw new InvalidTransitionException(status + " → CONFIRMED 불가");
        }
        if (items.isEmpty()) {
            throw new InvalidTransitionException("상품이 없는 주문은 확정할 수 없습니다");
        }
        status = OrderStatus.CONFIRMED;
        domainEvents.add(new OrderCreatedEvent(id, customerId, total()));
    }

    public void cancel(String reason) {
        if (!status.canTransitionTo(OrderStatus.CANCELLED)) {
            throw new InvalidTransitionException(status + " → CANCELLED 불가");
        }
        status = OrderStatus.CANCELLED;
        domainEvents.add(new OrderCancelledEvent(id, reason));
    }

    public List<Object> collectDomainEvents() {
        var events = List.copyOf(domainEvents);
        domainEvents.clear();
        return events;
    }

    // Getters
    public UUID getId() { return id; }
    public UUID getCustomerId() { return customerId; }
    public List<OrderItem> getItems() { return Collections.unmodifiableList(items); }
    public OrderStatus getStatus() { return status; }
    public Address getShippingAddress() { return shippingAddress; }
    public Instant getCreatedAt() { return createdAt; }

    public void setShippingAddress(Address address) { this.shippingAddress = address; }
}
```

### Domain Event

```java
// order/domain/event/OrderCreatedEvent.java
package com.example.shop.order.domain.event;

import com.example.shop.order.domain.model.Money;
import java.time.Instant;
import java.util.UUID;

public record OrderCreatedEvent(
    UUID orderId,
    UUID customerId,
    Money total,
    Instant occurredAt
) {
    public OrderCreatedEvent(UUID orderId, UUID customerId, Money total) {
        this(orderId, customerId, total, Instant.now());
    }
}
```

### Port (Repository 인터페이스)

```java
// order/domain/port/OrderRepository.java
package com.example.shop.order.domain.port;

import com.example.shop.order.domain.model.Order;
import java.util.Optional;
import java.util.UUID;

public interface OrderRepository {
    Optional<Order> findById(UUID id);
    List<Order> findByCustomerId(UUID customerId);
    void save(Order order);
    void delete(UUID id);
}
```

---

## JPA Entity (별도! 도메인 모델과 분리)

```java
// order/adapter/out/persistence/OrderJpaEntity.java
package com.example.shop.order.adapter.out.persistence;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;

@Entity
@Table(name = "orders")
public class OrderJpaEntity {

    @Id
    private UUID id;

    @Column(name = "customer_id", nullable = false)
    private UUID customerId;

    @Column(nullable = false, length = 20)
    private String status;

    @Column(name = "shipping_street") private String shippingStreet;
    @Column(name = "shipping_city") private String shippingCity;
    @Column(name = "shipping_zip") private String shippingZip;

    @Column(name = "created_at", nullable = false)
    private Instant createdAt;

    @OneToMany(mappedBy = "order", cascade = CascadeType.ALL, orphanRemoval = true)
    private List<OrderItemJpaEntity> items = new ArrayList<>();

    // Getters, Setters (JPA용)
    // ...
}
```

### Persistence Adapter (Outbound Adapter)

```java
// order/adapter/out/persistence/OrderPersistenceAdapter.java
package com.example.shop.order.adapter.out.persistence;

import com.example.shop.order.domain.model.Order;
import com.example.shop.order.domain.port.OrderRepository;
import org.springframework.stereotype.Component;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Component
public class OrderPersistenceAdapter implements OrderRepository {

    private final OrderJpaRepository jpaRepository;
    private final OrderMapper mapper;

    public OrderPersistenceAdapter(OrderJpaRepository jpaRepository, OrderMapper mapper) {
        this.jpaRepository = jpaRepository;
        this.mapper = mapper;
    }

    @Override
    public Optional<Order> findById(UUID id) {
        return jpaRepository.findById(id).map(mapper::toDomain);
    }

    @Override
    public List<Order> findByCustomerId(UUID customerId) {
        return jpaRepository.findByCustomerId(customerId).stream()
            .map(mapper::toDomain)
            .toList();
    }

    @Override
    public void save(Order order) {
        var entity = mapper.toJpaEntity(order);
        jpaRepository.save(entity);
    }

    @Override
    public void delete(UUID id) {
        jpaRepository.deleteById(id);
    }
}
```

### Domain ↔ JPA Entity 매퍼

```java
// order/adapter/out/persistence/OrderMapper.java
package com.example.shop.order.adapter.out.persistence;

import com.example.shop.order.domain.model.*;
import org.springframework.stereotype.Component;

import java.util.stream.Collectors;

@Component
public class OrderMapper {

    public Order toDomain(OrderJpaEntity entity) {
        var items = entity.getItems().stream()
            .map(i -> new OrderItem(
                i.getProductId(),
                i.getProductName(),
                new Money(i.getUnitPrice(), i.getCurrency()),
                i.getQuantity()
            ))
            .toList();

        Address address = null;
        if (entity.getShippingStreet() != null) {
            address = new Address(entity.getShippingStreet(),
                entity.getShippingCity(), entity.getShippingZip());
        }

        return new Order(
            entity.getId(),
            entity.getCustomerId(),
            items,
            OrderStatus.valueOf(entity.getStatus()),
            address,
            entity.getCreatedAt()
        );
    }

    public OrderJpaEntity toJpaEntity(Order order) {
        var entity = new OrderJpaEntity();
        entity.setId(order.getId());
        entity.setCustomerId(order.getCustomerId());
        entity.setStatus(order.getStatus().name());
        entity.setCreatedAt(order.getCreatedAt());

        if (order.getShippingAddress() != null) {
            entity.setShippingStreet(order.getShippingAddress().street());
            entity.setShippingCity(order.getShippingAddress().city());
            entity.setShippingZip(order.getShippingAddress().zipCode());
        }

        var items = order.getItems().stream()
            .map(i -> {
                var itemEntity = new OrderItemJpaEntity();
                itemEntity.setProductId(i.productId());
                itemEntity.setProductName(i.productName());
                itemEntity.setUnitPrice(i.unitPrice().amount());
                itemEntity.setCurrency(i.unitPrice().currency());
                itemEntity.setQuantity(i.quantity());
                itemEntity.setOrder(entity);
                return itemEntity;
            })
            .collect(Collectors.toList());
        entity.setItems(items);

        return entity;
    }
}
```

---

## Application 레이어 (Use Case)

```java
// order/application/service/OrderCommandService.java
package com.example.shop.order.application.service;

import com.example.shop.order.application.command.CreateOrderCommand;
import com.example.shop.order.application.command.CancelOrderCommand;
import com.example.shop.order.domain.exception.OrderDomainException;
import com.example.shop.order.domain.model.*;
import com.example.shop.order.domain.port.OrderRepository;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.UUID;

@Service
@Transactional
public class OrderCommandService {

    private final OrderRepository orderRepository;
    private final ApplicationEventPublisher eventPublisher;

    public OrderCommandService(OrderRepository orderRepository,
                                ApplicationEventPublisher eventPublisher) {
        this.orderRepository = orderRepository;
        this.eventPublisher = eventPublisher;
    }

    public UUID createOrder(CreateOrderCommand cmd) {
        var order = new Order(UUID.randomUUID(), cmd.customerId());
        order.setShippingAddress(new Address(cmd.street(), cmd.city(), cmd.zipCode()));

        for (var item : cmd.items()) {
            order.addItem(item.productId(), item.name(),
                Money.krw(item.price()), item.quantity());
        }

        order.confirm();
        orderRepository.save(order);

        // Spring ApplicationEvent로 도메인 이벤트 발행
        order.collectDomainEvents().forEach(eventPublisher::publishEvent);

        return order.getId();
    }

    public void cancelOrder(CancelOrderCommand cmd) {
        var order = orderRepository.findById(cmd.orderId())
            .orElseThrow(() -> new OrderDomainException("주문을 찾을 수 없습니다"));

        order.cancel(cmd.reason());
        orderRepository.save(order);

        order.collectDomainEvents().forEach(eventPublisher::publishEvent);
    }
}
```

---

## Spring Modulith

```java
// config/ModulithConfig.java
package com.example.shop.config;

import org.springframework.modulith.Modulith;

@Modulith(
    sharedModules = "shared"
)
public class ModulithConfig {
}
```

```java
// shared/SubscriptionContext.java (이벤트 구독)
package com.example.shop.shared;

import com.example.shop.order.domain.event.OrderCreatedEvent;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

@Component
public class SubscriptionContext {

    @Async
    @EventListener
    public void onOrderCreated(OrderCreatedEvent event) {
        // 알림 전송, 재고 차감 등
        System.out.println("[EVENT] 주문 생성: " + event.orderId());
    }
}
```

### Modulith 아키텍처 테스트

```java
// src/test/java/com/example/shop/ModulithArchitectureTest.java
package com.example.shop;

import org.junit.jupiter.api.Test;
import org.springframework.modulith.core.ApplicationModules;

class ModulithArchitectureTest {

    ApplicationModules modules = ApplicationModules.of(ShopApplication.class);

    @Test
    void 모듈_구조_검증() {
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

---

## 도메인 단위 테스트

```java
// src/test/java/com/example/shop/order/domain/OrderTest.java
package com.example.shop.order.domain;

import com.example.shop.order.domain.exception.InvalidTransitionException;
import com.example.shop.order.domain.model.*;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.*;

class OrderTest {

    @Test
    void 주문_생성_후_확정() {
        var order = new Order(UUID.randomUUID(), UUID.randomUUID());
        order.addItem(UUID.randomUUID(), "상품A", Money.krw(10000), 2);
        order.addItem(UUID.randomUUID(), "상품B", Money.krw(5000), 1);

        assertThat(order.total()).isEqualTo(Money.krw(25000));

        order.confirm();
        assertThat(order.getStatus()).isEqualTo(OrderStatus.CONFIRMED);
        assertThat(order.collectDomainEvents()).hasSize(1);
    }

    @Test
    void 빈_주문은_확정_불가() {
        var order = new Order(UUID.randomUUID(), UUID.randomUUID());
        assertThatThrownBy(order::confirm)
            .isInstanceOf(InvalidTransitionException.class);
    }

    @Test
    void 확정된_주문에_상품_추가_불가() {
        var order = new Order(UUID.randomUUID(), UUID.randomUUID());
        order.addItem(UUID.randomUUID(), "상품A", Money.krw(10000), 1);
        order.confirm();

        assertThatThrownBy(() ->
            order.addItem(UUID.randomUUID(), "상품B", Money.krw(5000), 1))
            .isInstanceOf(InvalidTransitionException.class);
    }

    @Test
    void 금액_음수_불가() {
        assertThatThrownBy(() -> new Money(java.math.BigDecimal.valueOf(-1), "KRW"))
            .isInstanceOf(IllegalArgumentException.class);
    }
}
```

---

## 의존성 규칙

```
┌─────────────────────────────────────┐
│   adapter/in (Controller, gRPC)     │  ← Spring MVC, Validation
├─────────────────────────────────────┤
│   adapter/out (JPA, External API)   │  ← JPA, HTTP Client
├─────────────────────────────────────┤
│   application (Use Cases)           │  ← Spring @Service, @Transactional
├─────────────────────────────────────┤
│   domain (Business Rules)           │  ← 순수 Java, 프레임워크 import 금지
└─────────────────────────────────────┘
```

| 레이어 | 허용 import | 금지 import |
|--------|------------|------------|
| domain | 표준 Java 라이브러리만 | Spring, JPA, Lombok |
| application | domain, Spring(@Service, @Transactional) | JPA, HTTP |
| adapter/out | domain, application, JPA/외부 | - |
| adapter/in | application, Spring MVC | domain 모델 직접 HTTP 반환 |

---

## 대규모에서 반드시 지켜야 할 것

| 규칙 | 설명 |
|------|------|
| Domain에 JPA 어노테이션 없음 | 별도 JPA Entity 클래스 사용 |
| Aggregate 간 ID 참조 | `Order`가 `User`를 직접 참조하지 않음, `customerId`만 보유 |
| Domain Event로 Context 간 통신 | `ApplicationEventPublisher` 사용 |
| Spring Modulith | 모듈 경계 검증 자동화 |
| 복원용 생성자 분리 | DB 로드 시 비즈니스 검증 건너뜀 |
| CQRS | Command/Query Service 분리 |
