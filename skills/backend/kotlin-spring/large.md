# Kotlin / Spring Boot - 대규모 프로젝트 가이드

> 엔드포인트 100개 이상, 4-레이어 + Facade + Event + CQRS

---

## 핵심 원칙

**중규모와 레이어 구조는 동일하다. 대규모는 Facade + Event + CQRS만 추가된다.**

- **4-레이어**: `api → application → domain ← infrastructure` (중규모와 동일)
- **Facade**: 모듈의 공개 API. 다른 모듈은 반드시 Facade를 통해서만 접근
- **Event**: `ApplicationEventPublisher`로 모듈 간 비동기 통신
- **CQRS**: `application/command/`와 `application/query/` 분리
- **sealed interface 에러**: 도메인별 타입 안전한 에러 (`when` 완전 매칭)
- **value class ID (선택)**: 타입 안전한 ID, 런타임 오버헤드 없음
- **Extension Functions**: DTO 변환을 깔끔하게
- **Kotest + MockK**: Kotlin 네이티브 테스트
- **Coroutines (선택)**: 비동기 처리가 필요한 경우만 도입
- **JPA Entity = Domain Model**: `allopen`/`noarg` 플러그인으로 JPA와 Kotlin 공존

---

## 중규모 대비 추가되는 것

| 추가 요소 | 역할 |
|-----------|------|
| `OrderFacade.kt` | 모듈 루트에 위치. 다른 모듈이 호출하는 유일한 진입점 |
| `OrderCreatedEvent.kt` | 모듈 루트에 위치. 다른 모듈이 구독하는 공개 이벤트 |
| `application/command/` | 상태 변경 유스케이스 (Create, Cancel, ...) |
| `application/query/` | 조회 유스케이스 (Get, Search, ...) |
| `application/event/` | 다른 모듈 이벤트를 구독하는 핸들러 |
| `infrastructure/messaging/` | Kafka 등 외부 메시징 연동 |
| `global/domain/DomainEvent.kt` | 이벤트 기반 통신 마커 인터페이스 |

---

## 디렉토리 구조

```
src/main/kotlin/com/example/shop/
├── ShopApplication.kt
│
├── global/
│   ├── exception/
│   │   ├── AppException.kt             # sealed class
│   │   └── GlobalExceptionHandler.kt
│   ├── config/
│   │   ├── SecurityConfig.kt
│   │   └── JpaConfig.kt
│   ├── auth/
│   │   ├── JwtProvider.kt
│   │   └── CurrentUser.kt
│   └── domain/
│       ├── Money.kt
│       ├── Address.kt
│       ├── BaseEntity.kt
│       └── DomainEvent.kt
│
├── order/
│   ├── OrderFacade.kt                   # 모듈 공개 API
│   ├── OrderCreatedEvent.kt             # 모듈 공개 이벤트
│   ├── api/
│   │   ├── OrderController.kt
│   │   └── dto/
│   │       ├── CreateOrderRequest.kt
│   │       └── OrderResponse.kt
│   ├── application/
│   │   ├── command/
│   │   │   ├── CreateOrderUseCase.kt
│   │   │   └── CancelOrderUseCase.kt
│   │   ├── query/
│   │   │   └── GetOrderUseCase.kt
│   │   ├── event/
│   │   │   └── PaymentCompletedHandler.kt
│   │   └── OrderMapper.kt
│   ├── domain/
│   │   ├── model/
│   │   │   ├── Order.kt                # JPA Entity + business logic
│   │   │   ├── OrderItem.kt
│   │   │   └── OrderStatus.kt
│   │   ├── vo/
│   │   │   └── OrderAmount.kt
│   │   ├── OrderRepository.kt
│   │   └── OrderDomainService.kt
│   └── infrastructure/
│       ├── persistence/
│       │   └── OrderQueryRepository.kt
│       ├── client/
│       │   └── PaymentGatewayClient.kt
│       └── messaging/
│           └── OrderKafkaProducer.kt
│
├── inventory/
│   ├── InventoryFacade.kt
│   ├── StockDecreasedEvent.kt
│   ├── api/ application/ domain/ infrastructure/
│
├── user/
│   ├── UserFacade.kt
│   └── ...
│
└── payment/
    ├── PaymentFacade.kt
    ├── PaymentCompletedEvent.kt
    └── ...
```

---

## 모듈 간 통신 규칙

```
┌─────────────┐    Facade 호출     ┌─────────────┐
│   order/    │ ──────────────────→ │  inventory/ │
│             │                     │             │
│  OrderFacade│ ← InventoryFacade  │  Inventory  │
│             │                     │  Facade     │
└──────┬──────┘                     └──────┬──────┘
       │                                   │
       │  Event 발행                        │  Event 발행
       ▼                                   ▼
 OrderCreatedEvent              StockDecreasedEvent
       │                                   │
       └──── 다른 모듈이 @EventListener로 구독 ───┘
```

| 규칙 | 설명 |
|------|------|
| Facade만 public | 모듈 내부 UseCase, Service는 `internal` 또는 패키지 프라이빗 |
| 동기 호출 = Facade | 다른 모듈의 데이터가 즉시 필요하면 Facade 호출 |
| 비동기 통신 = Event | 사이드이펙트(알림, 재고 차감 등)는 이벤트로 처리 |
| 순환 의존 금지 | A → B → A 직접 호출 금지. 이벤트로 끊는다 |

---

## Facade

```kotlin
// order/OrderFacade.kt
package com.example.shop.order

import com.example.shop.order.application.query.GetOrderUseCase
import com.example.shop.order.domain.model.OrderStatus
import org.springframework.stereotype.Component

/**
 * 주문 모듈의 공개 API.
 * 다른 모듈은 반드시 이 Facade를 통해서만 주문 모듈에 접근한다.
 */
@Component
class OrderFacade(
    private val getOrderUseCase: GetOrderUseCase,
) {
    /** 다른 모듈이 주문 상태를 조회할 때 사용 */
    fun getOrderStatus(orderId: Long): OrderStatus {
        return getOrderUseCase.getStatus(orderId)
    }

    /** 다른 모듈이 주문 금액을 조회할 때 사용 */
    fun getOrderTotal(orderId: Long): java.math.BigDecimal {
        return getOrderUseCase.getTotal(orderId)
    }
}
```

---

## Event

### 공개 이벤트 (모듈 루트)

```kotlin
// global/domain/DomainEvent.kt
package com.example.shop.global.domain

import java.time.Instant

/**
 * 모든 도메인 이벤트의 마커 인터페이스.
 */
interface DomainEvent {
    val occurredAt: Instant
}
```

```kotlin
// order/OrderCreatedEvent.kt
package com.example.shop.order

import com.example.shop.global.domain.DomainEvent
import java.math.BigDecimal
import java.time.Instant

/**
 * 주문 생성 이벤트. 모듈 루트에 위치하여 다른 모듈이 import 가능.
 */
data class OrderCreatedEvent(
    val orderId: Long,
    val userId: Long,
    val totalAmount: BigDecimal,
    override val occurredAt: Instant = Instant.now(),
) : DomainEvent
```

```kotlin
// payment/PaymentCompletedEvent.kt
package com.example.shop.payment

import com.example.shop.global.domain.DomainEvent
import java.math.BigDecimal
import java.time.Instant

data class PaymentCompletedEvent(
    val orderId: Long,
    val paymentId: Long,
    val amount: BigDecimal,
    override val occurredAt: Instant = Instant.now(),
) : DomainEvent
```

### 이벤트 발행 (UseCase에서)

```kotlin
// order/application/command/CreateOrderUseCase.kt
package com.example.shop.order.application.command

import com.example.shop.order.OrderCreatedEvent
import com.example.shop.order.api.dto.CreateOrderRequest
import com.example.shop.order.api.dto.OrderResponse
import com.example.shop.order.application.toResponse
import com.example.shop.order.domain.model.Order
import com.example.shop.order.domain.model.OrderItem
import com.example.shop.order.domain.OrderRepository
import org.springframework.context.ApplicationEventPublisher
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class CreateOrderUseCase(
    private val orderRepository: OrderRepository,
    private val eventPublisher: ApplicationEventPublisher,
) {
    fun execute(userId: Long, request: CreateOrderRequest): OrderResponse {
        val order = Order(userId = userId)

        request.items.forEach { item ->
            order.addItem(
                OrderItem(
                    productId = item.productId,
                    quantity = item.quantity,
                    price = item.price,
                )
            )
        }

        val saved = orderRepository.save(order)

        // 도메인 이벤트 발행
        eventPublisher.publishEvent(
            OrderCreatedEvent(
                orderId = saved.id,
                userId = saved.userId,
                totalAmount = saved.totalAmount.amount,
            )
        )

        return saved.toResponse()
    }
}
```

### 이벤트 구독 (@EventListener)

```kotlin
// order/application/event/PaymentCompletedHandler.kt
package com.example.shop.order.application.event

import com.example.shop.payment.PaymentCompletedEvent
import com.example.shop.order.domain.OrderRepository
import org.slf4j.LoggerFactory
import org.springframework.context.event.EventListener
import org.springframework.scheduling.annotation.Async
import org.springframework.stereotype.Component
import org.springframework.transaction.annotation.Transactional

@Component
class PaymentCompletedHandler(
    private val orderRepository: OrderRepository,
) {
    private val log = LoggerFactory.getLogger(javaClass)

    @Async
    @EventListener
    @Transactional
    fun handle(event: PaymentCompletedEvent) {
        log.info("[EVENT] 결제 완료 수신: orderId={}", event.orderId)

        val order = orderRepository.findById(event.orderId).orElseThrow()
        order.markPaid()
        orderRepository.save(order)
    }
}
```

```kotlin
// inventory/application/event/OrderCreatedHandler.kt
package com.example.shop.inventory.application.event

import com.example.shop.order.OrderCreatedEvent
import com.example.shop.inventory.InventoryFacade
import org.slf4j.LoggerFactory
import org.springframework.context.event.EventListener
import org.springframework.scheduling.annotation.Async
import org.springframework.stereotype.Component

@Component
class OrderCreatedHandler(
    private val inventoryFacade: InventoryFacade,
) {
    private val log = LoggerFactory.getLogger(javaClass)

    @Async
    @EventListener
    fun handle(event: OrderCreatedEvent) {
        log.info("[EVENT] 주문 생성 수신 → 재고 차감: orderId={}", event.orderId)
        // 재고 차감 로직
    }
}
```

---

## CQRS (Command / Query 분리)

```kotlin
// order/application/command/CancelOrderUseCase.kt
package com.example.shop.order.application.command

import com.example.shop.global.exception.NotFoundException
import com.example.shop.order.api.dto.OrderResponse
import com.example.shop.order.application.toResponse
import com.example.shop.order.domain.OrderRepository
import org.springframework.data.repository.findByIdOrNull
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class CancelOrderUseCase(
    private val orderRepository: OrderRepository,
) {
    fun execute(orderId: Long): OrderResponse {
        val order = orderRepository.findByIdOrNull(orderId)
            ?: throw NotFoundException("주문", orderId)

        order.cancel()
        return order.toResponse()
    }
}
```

```kotlin
// order/application/query/GetOrderUseCase.kt
package com.example.shop.order.application.query

import com.example.shop.global.exception.NotFoundException
import com.example.shop.order.api.dto.OrderResponse
import com.example.shop.order.application.toResponse
import com.example.shop.order.domain.OrderRepository
import com.example.shop.order.domain.model.OrderStatus
import com.example.shop.order.infrastructure.persistence.OrderQueryRepository
import org.springframework.data.repository.findByIdOrNull
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.math.BigDecimal

@Service
@Transactional(readOnly = true)
class GetOrderUseCase(
    private val orderRepository: OrderRepository,
    private val orderQueryRepository: OrderQueryRepository,
) {
    fun execute(orderId: Long): OrderResponse {
        val order = orderRepository.findByIdOrNull(orderId)
            ?: throw NotFoundException("주문", orderId)
        return order.toResponse()
    }

    fun findByUserId(userId: Long): List<OrderResponse> {
        return orderRepository.findByUserId(userId).map { it.toResponse() }
    }

    /** Facade에서 사용하는 내부 메서드 */
    fun getStatus(orderId: Long): OrderStatus {
        val order = orderRepository.findByIdOrNull(orderId)
            ?: throw NotFoundException("주문", orderId)
        return order.status
    }

    fun getTotal(orderId: Long): BigDecimal {
        val order = orderRepository.findByIdOrNull(orderId)
            ?: throw NotFoundException("주문", orderId)
        return order.totalAmount.amount
    }
}
```

---

## Domain 레이어 (JPA Entity + 비즈니스 로직)

### Domain Model (JPA @Entity)

> `allopen` + `noarg` 플러그인으로 JPA와 Kotlin을 자연스럽게 공존시킨다.
> 별도 JPA Entity를 만들지 않는다. 도메인 모델이 곧 JPA Entity이다.

```kotlin
// build.gradle.kts (plugins)
plugins {
    kotlin("plugin.spring")        // @Service, @Component 등에 open 추가
    kotlin("plugin.jpa")           // @Entity, @Embeddable 등에 noarg 생성자 추가
    kotlin("plugin.allopen")       // 추가 allopen 설정
}

allOpen {
    annotation("jakarta.persistence.Entity")
    annotation("jakarta.persistence.MappedSuperclass")
    annotation("jakarta.persistence.Embeddable")
}
```

```kotlin
// global/domain/BaseEntity.kt
package com.example.shop.global.domain

import jakarta.persistence.*
import org.springframework.data.annotation.CreatedDate
import org.springframework.data.annotation.LastModifiedDate
import org.springframework.data.jpa.domain.support.AuditingEntityListener
import java.time.Instant

@MappedSuperclass
@EntityListeners(AuditingEntityListener::class)
abstract class BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0

    @CreatedDate
    @Column(updatable = false)
    var createdAt: Instant = Instant.now()
        protected set

    @LastModifiedDate
    var updatedAt: Instant = Instant.now()
        protected set
}
```

```kotlin
// order/domain/model/Order.kt
package com.example.shop.order.domain.model

import com.example.shop.global.domain.BaseEntity
import com.example.shop.global.domain.Money
import jakarta.persistence.*
import java.math.BigDecimal

@Entity
@Table(name = "orders")
class Order(
    val userId: Long,

    @Enumerated(EnumType.STRING)
    var status: OrderStatus = OrderStatus.CREATED,

    @Embedded
    var totalAmount: Money = Money(BigDecimal.ZERO),

    @OneToMany(mappedBy = "order", cascade = [CascadeType.ALL], orphanRemoval = true)
    val items: MutableList<OrderItem> = mutableListOf(),
) : BaseEntity() {

    // ── 비즈니스 로직 ──

    fun addItem(item: OrderItem) {
        require(status == OrderStatus.CREATED) {
            "확정된 주문에 상품을 추가할 수 없습니다: $status"
        }
        items.add(item)
        item.order = this
        recalculateTotal()
    }

    fun confirm() {
        require(status.canTransitionTo(OrderStatus.CONFIRMED)) {
            "$status → CONFIRMED 전이 불가"
        }
        require(items.isNotEmpty()) { "빈 주문은 확정할 수 없습니다" }
        status = OrderStatus.CONFIRMED
    }

    fun markPaid() {
        require(status.canTransitionTo(OrderStatus.PAID)) {
            "$status → PAID 전이 불가"
        }
        status = OrderStatus.PAID
    }

    fun cancel() {
        require(status.canTransitionTo(OrderStatus.CANCELLED)) {
            "$status → CANCELLED 전이 불가"
        }
        status = OrderStatus.CANCELLED
    }

    private fun recalculateTotal() {
        totalAmount = items
            .map { it.price * it.quantity }
            .fold(Money(BigDecimal.ZERO)) { acc, m -> acc + m }
    }
}
```

```kotlin
// order/domain/model/OrderItem.kt
package com.example.shop.order.domain.model

import com.example.shop.global.domain.BaseEntity
import com.example.shop.global.domain.Money
import jakarta.persistence.*

@Entity
@Table(name = "order_items")
class OrderItem(
    val productId: Long,
    val quantity: Int,

    @Embedded
    val price: Money,

    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "order_id")
    var order: Order? = null,
) : BaseEntity()
```

```kotlin
// order/domain/model/OrderStatus.kt
package com.example.shop.order.domain.model

enum class OrderStatus {
    CREATED, CONFIRMED, PAID, SHIPPED, DELIVERED, CANCELLED;

    private companion object {
        val TRANSITIONS = mapOf(
            CREATED to setOf(CONFIRMED, CANCELLED),
            CONFIRMED to setOf(PAID, CANCELLED),
            PAID to setOf(SHIPPED, CANCELLED),
            SHIPPED to setOf(DELIVERED),
        )
    }

    fun canTransitionTo(target: OrderStatus): Boolean =
        TRANSITIONS[this]?.contains(target) == true
}
```

### Value Object

```kotlin
// order/domain/vo/OrderAmount.kt
package com.example.shop.order.domain.vo

import java.math.BigDecimal

/**
 * 주문 금액 관련 계산을 캡슐화하는 VO.
 */
data class OrderAmount(
    val itemTotal: BigDecimal,
    val discountAmount: BigDecimal = BigDecimal.ZERO,
    val shippingFee: BigDecimal = BigDecimal.ZERO,
) {
    val finalAmount: BigDecimal
        get() = itemTotal - discountAmount + shippingFee

    init {
        require(itemTotal >= BigDecimal.ZERO) { "상품 금액은 0 이상이어야 합니다" }
        require(discountAmount >= BigDecimal.ZERO) { "할인 금액은 0 이상이어야 합니다" }
    }
}
```

### Repository 인터페이스

```kotlin
// order/domain/OrderRepository.kt
package com.example.shop.order.domain

import com.example.shop.order.domain.model.Order
import org.springframework.data.jpa.repository.JpaRepository

interface OrderRepository : JpaRepository<Order, Long> {
    fun findByUserId(userId: Long): List<Order>
}
```

### Domain Service

```kotlin
// order/domain/OrderDomainService.kt
package com.example.shop.order.domain

import com.example.shop.order.domain.model.Order
import org.springframework.stereotype.Service

/**
 * 단일 Aggregate로 해결할 수 없는 도메인 로직.
 * 예: 주문 금액 + 쿠폰 할인 + 배송비 계산 등.
 */
@Service
class OrderDomainService {

    fun calculateFinalAmount(order: Order, discountRate: Double): java.math.BigDecimal {
        val total = order.totalAmount.amount
        val discount = total.multiply(java.math.BigDecimal.valueOf(discountRate))
        return total.subtract(discount)
    }
}
```

---

## sealed interface 에러

```kotlin
// order/domain/OrderError.kt
package com.example.shop.order.domain

/**
 * 주문 도메인의 타입 안전 에러.
 * when 완전 매칭으로 모든 에러 케이스 처리를 컴파일 타임에 보장한다.
 */
sealed interface OrderError {
    data class NotFound(val orderId: Long) : OrderError
    data class InvalidTransition(val from: String, val to: String) : OrderError
    data object EmptyOrder : OrderError
    data class InsufficientStock(val productId: Long) : OrderError
    data class PaymentFailed(val reason: String) : OrderError
}

/**
 * 에러를 예외로 변환하는 확장 함수.
 * GlobalExceptionHandler와 연동하여 적절한 HTTP 응답을 반환한다.
 */
fun OrderError.toException(): RuntimeException = when (this) {
    is OrderError.NotFound ->
        com.example.shop.global.exception.NotFoundException("주문", orderId)
    is OrderError.InvalidTransition ->
        com.example.shop.global.exception.BusinessValidationException("$from → $to 전이 불가")
    is OrderError.EmptyOrder ->
        com.example.shop.global.exception.BusinessValidationException("빈 주문은 처리할 수 없습니다")
    is OrderError.InsufficientStock ->
        com.example.shop.global.exception.ConflictException("재고 부족: productId=$productId")
    is OrderError.PaymentFailed ->
        com.example.shop.global.exception.BusinessValidationException("결제 실패: $reason")
}
```

---

## value class ID (선택)

> 모듈 간 ID 전달 시 타입 혼동을 방지하고 싶을 때 사용한다.
> JPA Entity의 ID와는 별개로, Facade나 Event에서 사용하는 용도이다.

```kotlin
// order/domain/vo/OrderId.kt
package com.example.shop.order.domain.vo

@JvmInline
value class OrderId(val value: Long) {
    init {
        require(value > 0) { "OrderId는 양수여야 합니다" }
    }
}
```

```kotlin
// Facade에서 활용 예시
@Component
class OrderFacade(private val getOrderUseCase: GetOrderUseCase) {
    fun getOrderStatus(orderId: OrderId): OrderStatus {
        return getOrderUseCase.getStatus(orderId.value)
    }
}
```

---

## Extension Functions for Mapping

```kotlin
// order/application/OrderMapper.kt
package com.example.shop.order.application

import com.example.shop.order.api.dto.OrderResponse
import com.example.shop.order.domain.model.Order
import com.example.shop.order.domain.model.OrderItem

fun Order.toResponse() = OrderResponse(
    id = id,
    userId = userId,
    status = status,
    totalAmount = totalAmount.amount,
    itemCount = items.size,
    createdAt = createdAt,
)

fun List<Order>.toResponses() = map { it.toResponse() }
```

---

## API 레이어

```kotlin
// order/api/OrderController.kt
package com.example.shop.order.api

import com.example.shop.order.api.dto.CreateOrderRequest
import com.example.shop.order.api.dto.OrderResponse
import com.example.shop.order.application.command.CancelOrderUseCase
import com.example.shop.order.application.command.CreateOrderUseCase
import com.example.shop.order.application.query.GetOrderUseCase
import com.example.shop.order.application.toResponse
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/v1/orders")
class OrderController(
    private val createOrderUseCase: CreateOrderUseCase,
    private val cancelOrderUseCase: CancelOrderUseCase,
    private val getOrderUseCase: GetOrderUseCase,
) {
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    fun create(
        @RequestAttribute("userId") userId: Long,
        @Valid @RequestBody request: CreateOrderRequest,
    ): OrderResponse = createOrderUseCase.execute(userId, request)

    @GetMapping("/{id}")
    fun get(@PathVariable id: Long): OrderResponse =
        getOrderUseCase.execute(id)

    @PostMapping("/{id}/cancel")
    fun cancel(@PathVariable id: Long): OrderResponse =
        cancelOrderUseCase.execute(id)
}
```

---

## Infrastructure 레이어

```kotlin
// order/infrastructure/persistence/OrderQueryRepository.kt
package com.example.shop.order.infrastructure.persistence

import com.example.shop.order.domain.model.Order
import com.example.shop.order.domain.model.OrderStatus
import jakarta.persistence.EntityManager
import org.springframework.stereotype.Repository

@Repository
class OrderQueryRepository(
    private val em: EntityManager,
) {
    fun findByUserIdAndStatus(userId: Long, status: OrderStatus): List<Order> {
        return em.createQuery(
            """
            SELECT o FROM Order o
            JOIN FETCH o.items
            WHERE o.userId = :userId AND o.status = :status
            """.trimIndent(),
            Order::class.java,
        )
            .setParameter("userId", userId)
            .setParameter("status", status)
            .resultList
    }

    fun findRecentOrders(limit: Int): List<Order> {
        return em.createQuery(
            "SELECT o FROM Order o ORDER BY o.createdAt DESC",
            Order::class.java,
        )
            .setMaxResults(limit)
            .resultList
    }
}
```

```kotlin
// order/infrastructure/client/PaymentGatewayClient.kt
package com.example.shop.order.infrastructure.client

import org.springframework.stereotype.Component
import org.springframework.web.client.RestClient
import java.math.BigDecimal

@Component
class PaymentGatewayClient(
    private val restClient: RestClient,
) {
    fun requestPayment(orderId: Long, amount: BigDecimal): PaymentResult {
        val response = restClient.post()
            .uri("/api/payments")
            .body(PaymentRequest(orderId, amount))
            .retrieve()
            .body(PaymentResponse::class.java)

        return PaymentResult(
            paymentId = response?.paymentId ?: throw IllegalStateException("결제 응답 없음"),
            success = true,
        )
    }

    private data class PaymentRequest(val orderId: Long, val amount: BigDecimal)
    private data class PaymentResponse(val paymentId: Long)
    data class PaymentResult(val paymentId: Long, val success: Boolean)
}
```

```kotlin
// order/infrastructure/messaging/OrderKafkaProducer.kt
package com.example.shop.order.infrastructure.messaging

import com.example.shop.order.OrderCreatedEvent
import org.slf4j.LoggerFactory
import org.springframework.context.event.EventListener
import org.springframework.kafka.core.KafkaTemplate
import org.springframework.stereotype.Component

/**
 * 내부 ApplicationEvent를 Kafka로 전파.
 * 외부 시스템(알림, 분석 등)이 구독한다.
 */
@Component
class OrderKafkaProducer(
    private val kafkaTemplate: KafkaTemplate<String, Any>,
) {
    private val log = LoggerFactory.getLogger(javaClass)

    @EventListener
    fun onOrderCreated(event: OrderCreatedEvent) {
        log.info("[KAFKA] 주문 생성 이벤트 전파: orderId={}", event.orderId)
        kafkaTemplate.send("order.created", event.orderId.toString(), event)
    }
}
```

---

## Kotest 도메인 테스트

```kotlin
// src/test/kotlin/com/example/shop/order/domain/OrderTest.kt
package com.example.shop.order.domain

import com.example.shop.global.domain.Money
import com.example.shop.order.domain.model.Order
import com.example.shop.order.domain.model.OrderItem
import com.example.shop.order.domain.model.OrderStatus
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import java.math.BigDecimal

class OrderTest : DescribeSpec({

    describe("Order") {
        it("상품 추가 후 확정하면 CONFIRMED 상태가 된다") {
            val order = Order(userId = 1L)
            order.addItem(OrderItem(productId = 1L, quantity = 2, price = Money(BigDecimal(10000))))
            order.confirm()

            order.status shouldBe OrderStatus.CONFIRMED
            order.totalAmount shouldBe Money(BigDecimal(20000))
        }

        it("빈 주문은 확정할 수 없다") {
            val order = Order(userId = 1L)

            shouldThrow<IllegalArgumentException> {
                order.confirm()
            }
        }

        it("확정된 주문에 상품을 추가할 수 없다") {
            val order = Order(userId = 1L)
            order.addItem(OrderItem(productId = 1L, quantity = 1, price = Money(BigDecimal(10000))))
            order.confirm()

            shouldThrow<IllegalArgumentException> {
                order.addItem(OrderItem(productId = 2L, quantity = 1, price = Money(BigDecimal(5000))))
            }
        }

        it("결제 완료 후 배송 처리가 가능하다") {
            val order = Order(userId = 1L)
            order.addItem(OrderItem(productId = 1L, quantity = 1, price = Money(BigDecimal(10000))))
            order.confirm()
            order.markPaid()

            order.status shouldBe OrderStatus.PAID
        }
    }

    describe("OrderStatus 전이") {
        it("CREATED → CONFIRMED 가능") {
            OrderStatus.CREATED.canTransitionTo(OrderStatus.CONFIRMED) shouldBe true
        }

        it("CREATED → SHIPPED 불가") {
            OrderStatus.CREATED.canTransitionTo(OrderStatus.SHIPPED) shouldBe false
        }

        it("DELIVERED → CANCELLED 불가 (최종 상태)") {
            OrderStatus.DELIVERED.canTransitionTo(OrderStatus.CANCELLED) shouldBe false
        }
    }

    describe("Money") {
        it("다른 통화끼리 더할 수 없다") {
            val krw = Money(BigDecimal(1000), "KRW")
            val usd = Money(BigDecimal(1), "USD")

            shouldThrow<IllegalArgumentException> { krw + usd }
        }
    }
})
```

---

## Coroutines 도입 (선택)

비동기 처리가 필요한 경우만 도입한다.

```kotlin
// 의존성 추가
// implementation("org.jetbrains.kotlinx:kotlinx-coroutines-reactor")

@Service
class AsyncNotificationService(
    private val notificationClient: NotificationClient,
) {
    suspend fun sendNotification(userId: Long, message: String) {
        coroutineScope {
            launch { notificationClient.sendEmail(userId, message) }
            launch { notificationClient.sendPush(userId, message) }
        }
    }
}
```

---

## 의존성 규칙

```
┌─────────────────────────────────────┐
│   api (Controller, DTO)             │  ← Spring MVC, Validation
├─────────────────────────────────────┤
│   application (UseCase, Event)      │  ← Spring @Service, @Transactional
│    ├── command/  (상태 변경)          │
│    ├── query/    (조회)              │
│    └── event/    (이벤트 핸들러)      │
├─────────────────────────────────────┤
│   domain (Entity, VO, Repository)   │  ← JPA Entity + 비즈니스 로직
├─────────────────────────────────────┤
│   infrastructure (JPA 구현, Client)  │  ← QueryRepository, 외부 API
└─────────────────────────────────────┘
```

| 레이어 | 허용 import | 금지 import |
|--------|------------|------------|
| domain | JPA, global.domain | application, api, infrastructure |
| application | domain, global, Spring | infrastructure 직접 참조 최소화 |
| api | application | domain 모델 직접 HTTP 반환 |
| infrastructure | domain, Spring Data | application, api |

---

## 헥사고날은 언제 쓰는가

위 4-레이어 + Facade + Event + CQRS로 대부분의 대규모 프로젝트를 커버할 수 있다.
헥사고날(Ports & Adapters) + 멀티 모듈 Gradle은 아래 조건을 **모두** 만족할 때 도입한다.

| 조건 | 설명 |
|------|------|
| **프레임워크 교체 가능성** | JPA → R2DBC, Spring MVC → WebFlux 등 인프라 교체가 현실적으로 예상될 때 |
| **도메인 순수성 강제** | 도메인 레이어에서 JPA, Spring import를 완전히 금지해야 할 때 |
| **팀 15명 이상** | 의존성 방향을 컨벤션이 아닌 컴파일 타임에 강제해야 할 때 |
| **별도 배포 단위** | 모듈별로 독립 배포하거나, 향후 마이크로서비스 분리가 확정된 경우 |

### 헥사고날 전환 시 변경 사항

```
4-레이어 (현재)              →  헥사고날
─────────────────────────────────────────
단일 모듈                    →  멀티 모듈 Gradle (domain, application, infrastructure, api)
domain/Order.kt (@Entity)   →  domain/Order.kt (순수 Kotlin) + infrastructure/OrderJpaEntity.kt
OrderRepository (JPA 상속)   →  domain/OrderRepository (인터페이스) + infrastructure/OrderPersistenceAdapter
build.gradle.kts 1개        →  모듈별 build.gradle.kts (의존성 컴파일 타임 강제)
```

**전환 비용이 크므로, 위 조건을 만족하지 않으면 4-레이어를 유지한다.**

---

## 대규모에서 반드시 지켜야 할 것

| 규칙 | 설명 |
|------|------|
| Facade로 모듈 경계 | 다른 모듈은 Facade만 호출. 내부 UseCase 직접 접근 금지 |
| Event로 비동기 통신 | `ApplicationEventPublisher` 사용. 순환 의존 방지 |
| CQRS | command/query 패키지 분리. 조회는 `readOnly = true` |
| sealed interface 에러 | 도메인별 에러 타입. `when` 완전 매칭 |
| Extension function 매핑 | MapStruct 대신 Kotlin 확장 함수 |
| allopen/noarg 플러그인 | JPA Entity에 필수. Kotlin과 JPA 공존의 핵심 |
| Kotest DescribeSpec | BDD 스타일 테스트 |
| Controller는 얇게 | UseCase 위임만. 비즈니스 로직 금지 |
| `@Transactional(readOnly=true)` | 조회 UseCase에 명시 |
