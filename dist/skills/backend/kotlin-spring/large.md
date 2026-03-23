# Kotlin / Spring Boot - 대규모 프로젝트 가이드

> 팀 8명 이상, 엔드포인트 100개 이상, 헥사고날 아키텍처 + DDD

---

## 핵심 원칙

- **헥사고날 아키텍처**: Domain ← Application ← Infrastructure/Adapter
- **value class (inline)**: 타입 안전한 ID, 런타임 오버헤드 없음
- **Arrow-kt Either**: 예외 대신 타입 안전한 에러 처리
- **Kotlin Coroutines + Spring WebFlux**: 비동기 논블로킹
- **멀티 모듈 Gradle**: 모듈 간 의존성 컴파일 타임 강제
- **Domain 레이어 프레임워크 무의존**: Spring, JPA import 금지

---

## 멀티 모듈 구조

```
project/
├── settings.gradle.kts
├── build.gradle.kts                       # 루트 빌드 설정
│
├── domain/                                # 모듈: 순수 도메인
│   ├── build.gradle.kts                   # 의존성: kotlin-stdlib만
│   └── src/main/kotlin/com/example/shop/domain/
│       ├── order/
│       │   ├── Order.kt                   # Aggregate Root
│       │   ├── OrderItem.kt
│       │   ├── OrderStatus.kt             # enum
│       │   ├── Money.kt                   # value class
│       │   ├── Address.kt                 # data class VO
│       │   ├── OrderId.kt                 # value class ID
│       │   ├── CustomerId.kt              # value class ID
│       │   ├── OrderRepository.kt         # Port 인터페이스
│       │   ├── OrderError.kt              # sealed interface
│       │   └── event/
│       │       ├── OrderCreated.kt
│       │       └── OrderCancelled.kt
│       └── shared/
│           ├── DomainEvent.kt
│           └── AggregateRoot.kt
│
├── application/                           # 모듈: 유스케이스
│   ├── build.gradle.kts                   # 의존성: domain, arrow-core
│   └── src/main/kotlin/com/example/shop/application/
│       ├── order/
│       │   ├── CreateOrderUseCase.kt
│       │   ├── CancelOrderUseCase.kt
│       │   ├── GetOrderUseCase.kt
│       │   ├── command/
│       │   │   ├── CreateOrderCommand.kt
│       │   │   └── CancelOrderCommand.kt
│       │   └── query/
│       │       └── OrderQueryDto.kt
│       └── port/
│           └── EventPublisher.kt          # Outbound Port
│
├── infrastructure/                        # 모듈: 인프라 어댑터
│   ├── build.gradle.kts                   # 의존성: domain, application, spring, r2dbc
│   └── src/main/kotlin/com/example/shop/infrastructure/
│       ├── order/
│       │   ├── persistence/
│       │   │   ├── OrderR2dbcEntity.kt    # R2DBC Entity (별도)
│       │   │   ├── OrderR2dbcRepository.kt
│       │   │   ├── OrderPersistenceAdapter.kt
│       │   │   └── OrderEntityMapper.kt
│       │   └── event/
│       │       └── SpringEventPublisher.kt
│       └── config/
│           ├── R2dbcConfig.kt
│           └── WebFluxConfig.kt
│
├── api/                                   # 모듈: HTTP API
│   ├── build.gradle.kts                   # 의존성: application, spring-webflux
│   └── src/main/kotlin/com/example/shop/api/
│       ├── ShopApplication.kt
│       ├── order/
│       │   ├── OrderRouter.kt             # 함수형 라우터 또는 @RestController
│       │   ├── OrderHandler.kt
│       │   ├── OrderRequest.kt
│       │   └── OrderResponse.kt
│       └── common/
│           ├── ErrorHandler.kt
│           └── SecurityConfig.kt
│
└── tests/
    └── src/test/kotlin/
```

---

## Gradle 멀티 모듈 설정

```kotlin
// settings.gradle.kts
rootProject.name = "shop"
include("domain", "application", "infrastructure", "api")
```

```kotlin
// domain/build.gradle.kts
plugins {
    kotlin("jvm")
}

dependencies {
    // 순수 Kotlin만! Spring, JPA, Arrow 금지
    testImplementation(kotlin("test"))
    testImplementation("io.kotest:kotest-runner-junit5:5.9.0")
    testImplementation("io.kotest:kotest-assertions-core:5.9.0")
}
```

```kotlin
// application/build.gradle.kts
plugins {
    kotlin("jvm")
}

dependencies {
    implementation(project(":domain"))
    implementation("io.arrow-kt:arrow-core:1.2.4")

    testImplementation(kotlin("test"))
    testImplementation("io.kotest:kotest-runner-junit5:5.9.0")
    testImplementation("io.mockk:mockk:1.13.10")
}
```

```kotlin
// infrastructure/build.gradle.kts
plugins {
    kotlin("jvm")
    kotlin("plugin.spring")
}

dependencies {
    implementation(project(":domain"))
    implementation(project(":application"))
    implementation("org.springframework.boot:spring-boot-starter-data-r2dbc")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-reactor")
    runtimeOnly("org.postgresql:r2dbc-postgresql")
}
```

```kotlin
// api/build.gradle.kts
plugins {
    kotlin("jvm")
    kotlin("plugin.spring")
    id("org.springframework.boot")
}

dependencies {
    implementation(project(":domain"))
    implementation(project(":application"))
    implementation(project(":infrastructure"))
    implementation("org.springframework.boot:spring-boot-starter-webflux")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-reactor")
    implementation("io.arrow-kt:arrow-core:1.2.4")
}
```

---

## value class (Inline Class)

```kotlin
// domain/order/OrderId.kt
package com.example.shop.domain.order

@JvmInline
value class OrderId(val value: String) {
    init {
        require(value.isNotBlank()) { "OrderId는 비어있을 수 없습니다" }
    }
}

@JvmInline
value class CustomerId(val value: String) {
    init {
        require(value.isNotBlank()) { "CustomerId는 비어있을 수 없습니다" }
    }
}
```

```kotlin
// domain/order/Money.kt
package com.example.shop.domain.order

data class Money(val amount: Long, val currency: String = "KRW") {
    init {
        require(amount >= 0) { "금액은 0 이상이어야 합니다" }
    }

    operator fun plus(other: Money): Money {
        require(currency == other.currency) { "통화가 다릅니다: $currency vs ${other.currency}" }
        return Money(amount + other.amount, currency)
    }

    operator fun times(quantity: Int): Money = Money(amount * quantity, currency)

    companion object {
        fun krw(amount: Long) = Money(amount, "KRW")
        val ZERO = Money(0, "KRW")
    }
}
```

---

## sealed interface 에러

```kotlin
// domain/order/OrderError.kt
package com.example.shop.domain.order

sealed interface OrderError {
    data class NotFound(val id: OrderId) : OrderError
    data class InvalidTransition(val message: String) : OrderError
    data object EmptyOrder : OrderError
    data class InsufficientStock(val productId: String) : OrderError
}
```

---

## Aggregate Root

```kotlin
// domain/shared/AggregateRoot.kt
package com.example.shop.domain.shared

interface DomainEvent {
    val eventName: String
    val aggregateId: String
    val occurredAt: java.time.Instant
}

abstract class AggregateRoot {
    private val _events = mutableListOf<DomainEvent>()

    protected fun addEvent(event: DomainEvent) {
        _events.add(event)
    }

    fun collectEvents(): List<DomainEvent> {
        val events = _events.toList()
        _events.clear()
        return events
    }
}
```

```kotlin
// domain/order/Order.kt
package com.example.shop.domain.order

import com.example.shop.domain.order.event.OrderCreated
import com.example.shop.domain.order.event.OrderCancelled
import com.example.shop.domain.shared.AggregateRoot
import java.time.Instant

class Order private constructor(
    val id: OrderId,
    val customerId: CustomerId,
    private val _items: MutableList<OrderItem> = mutableListOf(),
    private var _status: OrderStatus = OrderStatus.PENDING,
    var shippingAddress: Address? = null,
    val createdAt: Instant = Instant.now(),
) : AggregateRoot() {

    val items: List<OrderItem> get() = _items.toList()
    val status: OrderStatus get() = _status

    val total: Money
        get() = _items.fold(Money.ZERO) { acc, item -> acc + item.subtotal }

    fun addItem(productId: String, name: String, price: Money, qty: Int): Result<Unit> {
        if (_status != OrderStatus.PENDING) {
            return Result.failure(IllegalStateException("확정된 주문에 상품 추가 불가"))
        }
        _items.add(OrderItem(productId, name, price, qty))
        return Result.success(Unit)
    }

    fun confirm(): Result<Unit> {
        if (!_status.canTransitionTo(OrderStatus.CONFIRMED)) {
            return Result.failure(IllegalStateException("$_status -> CONFIRMED 불가"))
        }
        if (_items.isEmpty()) {
            return Result.failure(IllegalStateException("빈 주문 확정 불가"))
        }
        _status = OrderStatus.CONFIRMED
        addEvent(OrderCreated(id.value, customerId.value, total, Instant.now()))
        return Result.success(Unit)
    }

    fun cancel(reason: String): Result<Unit> {
        if (!_status.canTransitionTo(OrderStatus.CANCELLED)) {
            return Result.failure(IllegalStateException("$_status -> CANCELLED 불가"))
        }
        _status = OrderStatus.CANCELLED
        addEvent(OrderCancelled(id.value, reason, Instant.now()))
        return Result.success(Unit)
    }

    companion object {
        fun create(id: OrderId, customerId: CustomerId) = Order(id, customerId)

        // DB 복원용 (검증 없음)
        fun reconstitute(
            id: OrderId,
            customerId: CustomerId,
            items: List<OrderItem>,
            status: OrderStatus,
            address: Address?,
            createdAt: Instant,
        ) = Order(id, customerId, items.toMutableList(), status, address, createdAt)
    }
}

data class OrderItem(
    val productId: String,
    val productName: String,
    val unitPrice: Money,
    val quantity: Int,
) {
    val subtotal: Money get() = unitPrice * quantity
}

data class Address(val street: String, val city: String, val zipCode: String)
```

---

## Arrow-kt Either 활용 (Application 레이어)

```kotlin
// application/order/CreateOrderUseCase.kt
package com.example.shop.application.order

import arrow.core.Either
import arrow.core.left
import arrow.core.right
import com.example.shop.domain.order.*
import com.example.shop.application.port.EventPublisher
import java.util.UUID

class CreateOrderUseCase(
    private val orderRepository: OrderRepository,
    private val eventPublisher: EventPublisher,
) {
    suspend fun execute(cmd: CreateOrderCommand): Either<OrderError, OrderId> {
        val orderId = OrderId(UUID.randomUUID().toString())
        val order = Order.create(orderId, CustomerId(cmd.customerId))

        cmd.address?.let {
            order.shippingAddress = Address(it.street, it.city, it.zipCode)
        }

        for (item in cmd.items) {
            order.addItem(item.productId, item.name, Money.krw(item.price), item.quantity)
                .onFailure { return OrderError.InvalidTransition(it.message ?: "").left() }
        }

        order.confirm()
            .onFailure {
                return if (order.items.isEmpty()) OrderError.EmptyOrder.left()
                else OrderError.InvalidTransition(it.message ?: "").left()
            }

        orderRepository.save(order)

        // 도메인 이벤트 발행
        order.collectEvents().forEach { eventPublisher.publish(it) }

        return orderId.right()
    }
}

data class CreateOrderCommand(
    val customerId: String,
    val items: List<OrderItemCommand>,
    val address: AddressCommand?,
)

data class OrderItemCommand(
    val productId: String,
    val name: String,
    val price: Long,
    val quantity: Int,
)

data class AddressCommand(val street: String, val city: String, val zipCode: String)
```

```kotlin
// application/order/CancelOrderUseCase.kt
package com.example.shop.application.order

import arrow.core.Either
import arrow.core.left
import arrow.core.right
import com.example.shop.domain.order.*
import com.example.shop.application.port.EventPublisher

class CancelOrderUseCase(
    private val orderRepository: OrderRepository,
    private val eventPublisher: EventPublisher,
) {
    suspend fun execute(cmd: CancelOrderCommand): Either<OrderError, Unit> {
        val order = orderRepository.findById(OrderId(cmd.orderId))
            ?: return OrderError.NotFound(OrderId(cmd.orderId)).left()

        order.cancel(cmd.reason)
            .onFailure { return OrderError.InvalidTransition(it.message ?: "").left() }

        orderRepository.save(order)
        order.collectEvents().forEach { eventPublisher.publish(it) }

        return Unit.right()
    }
}

data class CancelOrderCommand(val orderId: String, val reason: String = "")
```

---

## Coroutines + WebFlux Handler

```kotlin
// api/order/OrderHandler.kt
package com.example.shop.api.order

import arrow.core.Either
import com.example.shop.application.order.*
import com.example.shop.domain.order.OrderError
import org.springframework.http.HttpStatus
import org.springframework.http.ProblemDetail
import org.springframework.web.reactive.function.server.*
import java.net.URI

class OrderHandler(
    private val createOrderUseCase: CreateOrderUseCase,
    private val cancelOrderUseCase: CancelOrderUseCase,
    private val getOrderUseCase: GetOrderUseCase,
) {
    suspend fun createOrder(request: ServerRequest): ServerResponse {
        val body = request.awaitBody<CreateOrderHttpRequest>()
        val cmd = body.toCommand()

        return when (val result = createOrderUseCase.execute(cmd)) {
            is Either.Right -> ServerResponse.status(HttpStatus.CREATED)
                .bodyValueAndAwait(mapOf("id" to result.value.value))
            is Either.Left -> toErrorResponse(result.value)
        }
    }

    suspend fun getOrder(request: ServerRequest): ServerResponse {
        val orderId = request.pathVariable("id")
        return when (val result = getOrderUseCase.execute(orderId)) {
            is Either.Right -> ServerResponse.ok().bodyValueAndAwait(result.value.toResponse())
            is Either.Left -> toErrorResponse(result.value)
        }
    }

    suspend fun cancelOrder(request: ServerRequest): ServerResponse {
        val orderId = request.pathVariable("id")
        val body = request.awaitBodyOrNull<CancelOrderHttpRequest>()
        val cmd = CancelOrderCommand(orderId, body?.reason ?: "")

        return when (val result = cancelOrderUseCase.execute(cmd)) {
            is Either.Right -> ServerResponse.noContent().buildAndAwait()
            is Either.Left -> toErrorResponse(result.value)
        }
    }

    private suspend fun toErrorResponse(error: OrderError): ServerResponse {
        val (status, message) = when (error) {
            is OrderError.NotFound -> HttpStatus.NOT_FOUND to "주문(${error.id.value})을 찾을 수 없습니다"
            is OrderError.InvalidTransition -> HttpStatus.UNPROCESSABLE_ENTITY to error.message
            is OrderError.EmptyOrder -> HttpStatus.UNPROCESSABLE_ENTITY to "빈 주문은 확정할 수 없습니다"
            is OrderError.InsufficientStock -> HttpStatus.CONFLICT to "재고 부족: ${error.productId}"
        }
        val problem = ProblemDetail.forStatusAndDetail(status, message).apply {
            type = URI.create("https://api.example.com/errors/${error::class.simpleName?.lowercase()}")
        }
        return ServerResponse.status(status).bodyValueAndAwait(problem)
    }
}
```

```kotlin
// api/order/OrderRouter.kt
package com.example.shop.api.order

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.web.reactive.function.server.coRouter

@Configuration
class OrderRouter {

    @Bean
    fun orderRoutes(handler: OrderHandler) = coRouter {
        "/api/v1/orders".nest {
            POST("", handler::createOrder)
            GET("/{id}", handler::getOrder)
            POST("/{id}/cancel", handler::cancelOrder)
        }
    }
}
```

---

## Repository Port

```kotlin
// domain/order/OrderRepository.kt
package com.example.shop.domain.order

interface OrderRepository {
    suspend fun findById(id: OrderId): Order?
    suspend fun findByCustomerId(customerId: CustomerId): List<Order>
    suspend fun save(order: Order)
    suspend fun delete(id: OrderId)
}
```

---

## R2DBC Adapter (Infrastructure)

```kotlin
// infrastructure/order/persistence/OrderPersistenceAdapter.kt
package com.example.shop.infrastructure.order.persistence

import com.example.shop.domain.order.*
import org.springframework.stereotype.Component

@Component
class OrderPersistenceAdapter(
    private val r2dbcRepository: OrderR2dbcRepository,
    private val mapper: OrderEntityMapper,
) : OrderRepository {

    override suspend fun findById(id: OrderId): Order? {
        return r2dbcRepository.findById(id.value)?.let { mapper.toDomain(it) }
    }

    override suspend fun findByCustomerId(customerId: CustomerId): List<Order> {
        return r2dbcRepository.findByCustomerId(customerId.value)
            .map { mapper.toDomain(it) }
    }

    override suspend fun save(order: Order) {
        val entity = mapper.toEntity(order)
        r2dbcRepository.save(entity)
    }

    override suspend fun delete(id: OrderId) {
        r2dbcRepository.deleteById(id.value)
    }
}
```

---

## 도메인 단위 테스트

```kotlin
// domain/src/test/kotlin/com/example/shop/domain/order/OrderTest.kt
package com.example.shop.domain.order

import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.collections.shouldHaveSize
import io.kotest.matchers.shouldBe
import io.kotest.matchers.types.shouldBeInstanceOf

class OrderTest : DescribeSpec({

    describe("Order") {
        val orderId = OrderId("order-1")
        val customerId = CustomerId("customer-1")

        it("상품 추가 후 확정하면 이벤트가 발생한다") {
            val order = Order.create(orderId, customerId)
            order.addItem("p1", "상품A", Money.krw(10000), 2)
            order.confirm()

            order.status shouldBe OrderStatus.CONFIRMED
            order.total shouldBe Money.krw(20000)
            order.collectEvents() shouldHaveSize 1
        }

        it("빈 주문은 확정할 수 없다") {
            val order = Order.create(orderId, customerId)
            val result = order.confirm()
            result.isFailure shouldBe true
        }

        it("확정된 주문에 상품을 추가할 수 없다") {
            val order = Order.create(orderId, customerId)
            order.addItem("p1", "상품A", Money.krw(10000), 1)
            order.confirm()

            val result = order.addItem("p2", "상품B", Money.krw(5000), 1)
            result.isFailure shouldBe true
        }

        it("value class ID는 빈 문자열을 허용하지 않는다") {
            val exception = runCatching { OrderId("") }.exceptionOrNull()
            exception.shouldBeInstanceOf<IllegalArgumentException>()
        }
    }

    describe("Money") {
        it("다른 통화끼리 더할 수 없다") {
            val krw = Money.krw(1000)
            val usd = Money(1, "USD")

            val exception = runCatching { krw + usd }.exceptionOrNull()
            exception.shouldBeInstanceOf<IllegalArgumentException>()
        }

        it("음수 금액을 생성할 수 없다") {
            val exception = runCatching { Money(-1) }.exceptionOrNull()
            exception.shouldBeInstanceOf<IllegalArgumentException>()
        }
    }
})
```

---

## 의존성 규칙 (Gradle 모듈로 컴파일 타임 강제)

```
┌─────────────────────────────┐
│         api (WebFlux)       │  ← Spring WebFlux, Coroutines
├─────────────────────────────┤
│   infrastructure (R2DBC)    │  ← Spring Data R2DBC, Kafka
├─────────────────────────────┤
│   application (Use Cases)   │  ← Arrow-kt, domain만 의존
├─────────────────────────────┤
│   domain (Business Rules)   │  ← 순수 Kotlin, 외부 import 금지
└─────────────────────────────┘

Gradle 모듈이므로 domain이 infrastructure를 import하면 컴파일 에러!
```

| 모듈 | 허용 의존성 | 금지 |
|------|------------|------|
| domain | kotlin-stdlib만 | Spring, Arrow, JPA, R2DBC |
| application | domain, Arrow-kt | Spring, R2DBC |
| infrastructure | domain, application, Spring, R2DBC | api |
| api | application, infrastructure, Spring WebFlux | domain 모델 직접 반환 |

---

## 대규모에서 반드시 지켜야 할 것

| 규칙 | 설명 |
|------|------|
| Gradle 멀티 모듈 | 의존성 방향을 컴파일 타임에 강제 |
| value class ID | `OrderId`, `CustomerId` 등 타입 안전 ID |
| sealed interface 에러 | `when` 완전 매칭으로 모든 에러 처리 |
| Arrow Either | 예외 대신 타입 안전 에러 전파 |
| suspend 함수 | Repository, UseCase 모두 suspend |
| Domain에 Spring 금지 | `domain/build.gradle.kts`에 Spring 의존성 없음 |
