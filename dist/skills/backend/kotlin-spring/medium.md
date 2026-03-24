# Kotlin / Spring Boot - 중규모 프로젝트 가이드

> 엔드포인트 50~100개, 성장하는 서비스

---

## 핵심 원칙

- **global/ + 도메인 모듈**: 횡단 관심사는 `global/`에, 비즈니스 로직은 도메인 모듈에 배치
- **4-레이어 도메인 모듈**: `api → application → domain ← infrastructure`
- **sealed class 에러**: 타입 안전한 에러 계층 (`when` 표현식으로 완전 매칭)
- **Extension Functions**: DTO 변환, 유틸리티를 깔끔하게 작성
- **Kotest + MockK**: Kotlin 네이티브 테스트 프레임워크 + 목킹 라이브러리
- **Coroutines (선택)**: 비동기 처리가 필요한 경우만 도입

---

## 아키텍처 개요

### 의존성 방향

```
api → application → domain ← infrastructure
```

- **api**: 외부 요청 수신 (Controller, DTO)
- **application**: 유스케이스 조합 (UseCase, Mapper)
- **domain**: 엔티티, 값 객체, 리포지토리 인터페이스 (순수 도메인)
- **infrastructure**: 외부 시스템 연동 (JPA 구현체, 외부 API 클라이언트)

> `domain`은 다른 레이어를 알지 못한다. `infrastructure`는 `domain`의 인터페이스를 구현한다.

### 레이어 하위 폴더 규칙

- **4개 이상 파일** → 하위 폴더로 분리 (예: `api/dto/`)
- **3개 이하 파일** → 플랫하게 유지 (예: `api/UserController.kt`, `api/UserCreateRequest.kt`)

### 단순 CRUD 도메인

레이어 분리가 과한 단순 도메인은 플랫 구조를 유지한다.

---

## 디렉토리 구조

```
src/main/kotlin/com/example/myapp/
├── MyAppApplication.kt
│
├── global/                             # 횡단 관심사 + 공유 도메인 객체
│   ├── exception/
│   │   ├── AppException.kt            # sealed class
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
│       └── BaseEntity.kt
│
├── order/                              # 도메인 모듈: 4-레이어
│   ├── api/
│   │   ├── OrderController.kt
│   │   └── dto/                        # DTO 4개 이상 → 하위 폴더
│   │       ├── CreateOrderRequest.kt
│   │       ├── OrderResponse.kt
│   │       └── OrderDetailResponse.kt
│   ├── application/
│   │   ├── CreateOrderUseCase.kt
│   │   ├── CancelOrderUseCase.kt
│   │   └── OrderMapper.kt
│   ├── domain/
│   │   ├── Order.kt
│   │   ├── OrderItem.kt
│   │   ├── OrderStatus.kt
│   │   └── OrderRepository.kt         # 인터페이스
│   └── infrastructure/
│       ├── OrderQueryRepository.kt     # domain 인터페이스 구현
│       └── PaymentClient.kt           # 외부 API 클라이언트
│
├── user/                               # 도메인 모듈: DTO 적으면 flat
│   ├── api/
│   │   ├── UserController.kt
│   │   ├── UserCreateRequest.kt       # DTO 3개 이하 → flat
│   │   └── UserResponse.kt
│   ├── application/
│   │   ├── CreateUserUseCase.kt
│   │   └── UserMapper.kt
│   ├── domain/
│   │   ├── User.kt
│   │   ├── UserRole.kt
│   │   └── UserRepository.kt
│   └── infrastructure/
│       └── UserProfileS3Client.kt
│
└── notification/                       # 단순 CRUD → flat 유지
    ├── NotificationController.kt
    ├── NotificationService.kt
    ├── Notification.kt
    └── NotificationRepository.kt

src/test/kotlin/com/example/myapp/
├── order/
│   ├── application/
│   │   ├── CreateOrderUseCaseTest.kt
│   │   └── CancelOrderUseCaseTest.kt
│   └── api/
│       └── OrderControllerTest.kt
├── user/
│   ├── application/
│   │   └── CreateUserUseCaseTest.kt
│   └── api/
│       └── UserControllerTest.kt
└── ArchitectureTest.kt
```

---

## sealed class 에러 계층

```kotlin
// global/exception/AppException.kt
package com.example.myapp.global.exception

sealed class AppException(
    override val message: String,
    val code: String,
) : RuntimeException(message)

class NotFoundException(
    resource: String,
    id: Any,
) : AppException("${resource}(${id})을(를) 찾을 수 없습니다", "NOT_FOUND")

class ConflictException(
    override val message: String,
) : AppException(message, "CONFLICT")

class BusinessValidationException(
    override val message: String,
    val field: String? = null,
) : AppException(message, "BUSINESS_VALIDATION")

class UnauthorizedException(
    override val message: String = "인증이 필요합니다",
) : AppException(message, "UNAUTHORIZED")
```

---

## 글로벌 예외 핸들러 (when 완전 매칭)

```kotlin
// global/exception/GlobalExceptionHandler.kt
package com.example.myapp.global.exception

import org.springframework.http.HttpStatus
import org.springframework.http.ProblemDetail
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice
import java.net.URI

@RestControllerAdvice
class GlobalExceptionHandler {

    @ExceptionHandler(AppException::class)
    fun handleAppException(ex: AppException): ProblemDetail {
        val status = when (ex) {
            is NotFoundException -> HttpStatus.NOT_FOUND
            is ConflictException -> HttpStatus.CONFLICT
            is BusinessValidationException -> HttpStatus.UNPROCESSABLE_ENTITY
            is UnauthorizedException -> HttpStatus.UNAUTHORIZED
        }
        return ProblemDetail.forStatusAndDetail(status, ex.message).apply {
            type = URI.create("https://api.example.com/errors/${ex.code.lowercase()}")
            setProperty("code", ex.code)
        }
    }

    @ExceptionHandler(MethodArgumentNotValidException::class)
    fun handleValidation(ex: MethodArgumentNotValidException): ProblemDetail {
        val errors = ex.bindingResult.fieldErrors.associate {
            it.field to (it.defaultMessage ?: "유효하지 않은 값")
        }
        return ProblemDetail.forStatus(HttpStatus.UNPROCESSABLE_ENTITY).apply {
            title = "입력값 검증 실패"
            type = URI.create("https://api.example.com/errors/validation")
            setProperty("errors", errors)
        }
    }

    @ExceptionHandler(Exception::class)
    fun handleUnexpected(ex: Exception): ProblemDetail {
        return ProblemDetail.forStatus(HttpStatus.INTERNAL_SERVER_ERROR).apply {
            title = "서버 내부 오류가 발생했습니다"
        }
    }
}
```

---

## 공유 도메인 객체

```kotlin
// global/domain/Money.kt
package com.example.myapp.global.domain

import jakarta.persistence.Embeddable
import java.math.BigDecimal

@Embeddable
data class Money(
    val amount: BigDecimal,
    val currency: String = "KRW",
) {
    operator fun plus(other: Money): Money {
        require(currency == other.currency) { "통화가 다릅니다: $currency vs ${other.currency}" }
        return copy(amount = amount + other.amount)
    }

    operator fun times(quantity: Int): Money =
        copy(amount = amount * BigDecimal(quantity))
}
```

```kotlin
// global/domain/BaseEntity.kt
package com.example.myapp.global.domain

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

---

## Domain 레이어

```kotlin
// order/domain/OrderStatus.kt
package com.example.myapp.order.domain

enum class OrderStatus {
    CREATED, PAID, SHIPPED, DELIVERED, CANCELLED
}
```

```kotlin
// order/domain/Order.kt
package com.example.myapp.order.domain

import com.example.myapp.global.domain.BaseEntity
import com.example.myapp.global.domain.Money
import jakarta.persistence.*

@Entity
@Table(name = "orders")
class Order(
    val userId: Long,

    @Enumerated(EnumType.STRING)
    var status: OrderStatus = OrderStatus.CREATED,

    @Embedded
    var totalAmount: Money = Money(java.math.BigDecimal.ZERO),

    @OneToMany(mappedBy = "order", cascade = [CascadeType.ALL], orphanRemoval = true)
    val items: MutableList<OrderItem> = mutableListOf(),
) : BaseEntity() {

    fun addItem(item: OrderItem) {
        items.add(item)
        item.order = this
        recalculateTotal()
    }

    fun cancel() {
        require(status == OrderStatus.CREATED) {
            "취소할 수 없는 주문 상태입니다: $status"
        }
        status = OrderStatus.CANCELLED
    }

    private fun recalculateTotal() {
        totalAmount = items
            .map { it.price * it.quantity }
            .fold(Money(java.math.BigDecimal.ZERO)) { acc, m -> acc + m }
    }
}
```

```kotlin
// order/domain/OrderRepository.kt
package com.example.myapp.order.domain

import org.springframework.data.jpa.repository.JpaRepository

interface OrderRepository : JpaRepository<Order, Long> {
    fun findByUserId(userId: Long): List<Order>
}
```

---

## Application 레이어 (UseCase)

```kotlin
// order/application/CreateOrderUseCase.kt
package com.example.myapp.order.application

import com.example.myapp.global.exception.NotFoundException
import com.example.myapp.order.api.dto.CreateOrderRequest
import com.example.myapp.order.api.dto.OrderResponse
import com.example.myapp.order.domain.Order
import com.example.myapp.order.domain.OrderItem
import com.example.myapp.order.domain.OrderRepository
import com.example.myapp.order.infrastructure.PaymentClient
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class CreateOrderUseCase(
    private val orderRepository: OrderRepository,
    private val paymentClient: PaymentClient,
) {
    fun execute(userId: Long, request: CreateOrderRequest): OrderResponse {
        val order = Order(userId = userId)

        request.items.forEach { itemRequest ->
            order.addItem(
                OrderItem(
                    productId = itemRequest.productId,
                    quantity = itemRequest.quantity,
                    price = itemRequest.price,
                )
            )
        }

        val savedOrder = orderRepository.save(order)
        paymentClient.requestPayment(savedOrder.id, savedOrder.totalAmount)

        return savedOrder.toResponse()
    }
}
```

```kotlin
// order/application/CancelOrderUseCase.kt
package com.example.myapp.order.application

import com.example.myapp.global.exception.NotFoundException
import com.example.myapp.order.api.dto.OrderResponse
import com.example.myapp.order.domain.OrderRepository
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

---

## Extension Functions for Mapping

```kotlin
// order/application/OrderMapper.kt
package com.example.myapp.order.application

import com.example.myapp.order.api.dto.OrderDetailResponse
import com.example.myapp.order.api.dto.OrderResponse
import com.example.myapp.order.domain.Order
import com.example.myapp.order.domain.OrderItem

// Entity → Response 변환
fun Order.toResponse() = OrderResponse(
    id = id,
    userId = userId,
    status = status,
    totalAmount = totalAmount.amount,
    createdAt = createdAt,
)

// Entity → DetailResponse 변환
fun Order.toDetailResponse() = OrderDetailResponse(
    id = id,
    userId = userId,
    status = status,
    totalAmount = totalAmount.amount,
    items = items.map { it.toResponse() },
    createdAt = createdAt,
)

fun OrderItem.toResponse() = OrderDetailResponse.ItemResponse(
    productId = productId,
    quantity = quantity,
    price = price.amount,
)

// List 변환
fun List<Order>.toResponses() = map { it.toResponse() }
```

```kotlin
// user/application/UserMapper.kt
package com.example.myapp.user.application

import com.example.myapp.user.api.UserResponse
import com.example.myapp.user.domain.User

fun User.toResponse() = UserResponse(
    id = id,
    email = email,
    name = name,
    role = role,
    createdAt = createdAt,
)

fun List<User>.toResponses() = map { it.toResponse() }
```

---

## API 레이어 (Controller + DTO)

### Controller

```kotlin
// order/api/OrderController.kt
package com.example.myapp.order.api

import com.example.myapp.order.api.dto.CreateOrderRequest
import com.example.myapp.order.api.dto.OrderResponse
import com.example.myapp.order.application.CancelOrderUseCase
import com.example.myapp.order.application.CreateOrderUseCase
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/v1/orders")
class OrderController(
    private val createOrderUseCase: CreateOrderUseCase,
    private val cancelOrderUseCase: CancelOrderUseCase,
) {
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    fun create(
        @RequestAttribute("userId") userId: Long,
        @Valid @RequestBody request: CreateOrderRequest,
    ): OrderResponse = createOrderUseCase.execute(userId, request)

    @PostMapping("/{id}/cancel")
    fun cancel(@PathVariable id: Long): OrderResponse =
        cancelOrderUseCase.execute(id)
}
```

### DTO (data class)

```kotlin
// order/api/dto/CreateOrderRequest.kt
package com.example.myapp.order.api.dto

import com.example.myapp.global.domain.Money
import jakarta.validation.Valid
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotEmpty

data class CreateOrderRequest(
    @field:NotEmpty
    @field:Valid
    val items: List<OrderItemRequest>,
)

data class OrderItemRequest(
    val productId: Long,
    @field:Min(1) val quantity: Int,
    val price: Money,
)
```

```kotlin
// order/api/dto/OrderResponse.kt
package com.example.myapp.order.api.dto

import com.example.myapp.order.domain.OrderStatus
import java.math.BigDecimal
import java.time.Instant

data class OrderResponse(
    val id: Long,
    val userId: Long,
    val status: OrderStatus,
    val totalAmount: BigDecimal,
    val createdAt: Instant,
)
```

```kotlin
// order/api/dto/OrderDetailResponse.kt
package com.example.myapp.order.api.dto

import com.example.myapp.order.domain.OrderStatus
import java.math.BigDecimal
import java.time.Instant

data class OrderDetailResponse(
    val id: Long,
    val userId: Long,
    val status: OrderStatus,
    val totalAmount: BigDecimal,
    val items: List<ItemResponse>,
    val createdAt: Instant,
) {
    data class ItemResponse(
        val productId: Long,
        val quantity: Int,
        val price: BigDecimal,
    )
}
```

### User API (DTO flat 예시)

```kotlin
// user/api/UserController.kt
package com.example.myapp.user.api

import com.example.myapp.user.application.CreateUserUseCase
import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/v1/users")
class UserController(
    private val createUserUseCase: CreateUserUseCase,
) {
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    fun create(@Valid @RequestBody request: UserCreateRequest): UserResponse =
        createUserUseCase.execute(request)
}
```

```kotlin
// user/api/UserCreateRequest.kt
package com.example.myapp.user.api

import jakarta.validation.constraints.Email
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size

data class UserCreateRequest(
    @field:NotBlank @field:Email val email: String,
    @field:NotBlank @field:Size(max = 100) val name: String,
    @field:NotBlank @field:Size(min = 8) val password: String,
)
```

```kotlin
// user/api/UserResponse.kt
package com.example.myapp.user.api

import com.example.myapp.user.domain.UserRole
import java.time.Instant

data class UserResponse(
    val id: Long,
    val email: String,
    val name: String,
    val role: UserRole,
    val createdAt: Instant,
)
```

---

## Infrastructure 레이어

```kotlin
// order/infrastructure/OrderQueryRepository.kt
package com.example.myapp.order.infrastructure

import com.example.myapp.order.domain.Order
import com.example.myapp.order.domain.OrderStatus
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
}
```

```kotlin
// order/infrastructure/PaymentClient.kt
package com.example.myapp.order.infrastructure

import com.example.myapp.global.domain.Money
import org.springframework.stereotype.Component
import org.springframework.web.client.RestClient

@Component
class PaymentClient(
    private val restClient: RestClient,
) {
    fun requestPayment(orderId: Long, amount: Money) {
        restClient.post()
            .uri("/api/payments")
            .body(PaymentRequest(orderId, amount.amount, amount.currency))
            .retrieve()
            .toBodilessEntity()
    }

    private data class PaymentRequest(
        val orderId: Long,
        val amount: java.math.BigDecimal,
        val currency: String,
    )
}
```

---

## Kotest 테스트

### UseCase 단위 테스트 (MockK)

```kotlin
// src/test/kotlin/com/example/myapp/order/application/CreateOrderUseCaseTest.kt
package com.example.myapp.order.application

import com.example.myapp.global.domain.Money
import com.example.myapp.order.api.dto.CreateOrderRequest
import com.example.myapp.order.api.dto.OrderItemRequest
import com.example.myapp.order.domain.Order
import com.example.myapp.order.domain.OrderRepository
import com.example.myapp.order.domain.OrderStatus
import com.example.myapp.order.infrastructure.PaymentClient
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import io.mockk.*
import java.math.BigDecimal

class CreateOrderUseCaseTest : DescribeSpec({

    val orderRepository = mockk<OrderRepository>()
    val paymentClient = mockk<PaymentClient>(relaxed = true)
    val useCase = CreateOrderUseCase(orderRepository, paymentClient)

    afterEach { clearAllMocks() }

    describe("execute") {
        it("주문을 생성하고 결제를 요청한다") {
            // given
            val request = CreateOrderRequest(
                items = listOf(
                    OrderItemRequest(
                        productId = 1L,
                        quantity = 2,
                        price = Money(BigDecimal(10000)),
                    )
                )
            )
            every { orderRepository.save(any()) } answers { firstArg() }

            // when
            val result = useCase.execute(userId = 1L, request = request)

            // then
            result.status shouldBe OrderStatus.CREATED
            verify { orderRepository.save(any()) }
            verify { paymentClient.requestPayment(any(), any()) }
        }
    }
})
```

### UseCase 단위 테스트 (취소)

```kotlin
// src/test/kotlin/com/example/myapp/order/application/CancelOrderUseCaseTest.kt
package com.example.myapp.order.application

import com.example.myapp.global.exception.NotFoundException
import com.example.myapp.order.domain.Order
import com.example.myapp.order.domain.OrderRepository
import com.example.myapp.order.domain.OrderStatus
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import io.mockk.clearAllMocks
import io.mockk.every
import io.mockk.mockk
import org.springframework.data.repository.findByIdOrNull

class CancelOrderUseCaseTest : DescribeSpec({

    val orderRepository = mockk<OrderRepository>()
    val useCase = CancelOrderUseCase(orderRepository)

    afterEach { clearAllMocks() }

    describe("execute") {
        it("CREATED 상태의 주문을 취소한다") {
            val order = Order(userId = 1L)
            every { orderRepository.findByIdOrNull(1L) } returns order

            val result = useCase.execute(1L)

            result.status shouldBe OrderStatus.CANCELLED
        }

        it("존재하지 않는 주문이면 NotFoundException") {
            every { orderRepository.findByIdOrNull(999L) } returns null

            shouldThrow<NotFoundException> {
                useCase.execute(999L)
            }
        }
    }
})
```

### Controller 통합 테스트

```kotlin
// src/test/kotlin/com/example/myapp/user/api/UserControllerTest.kt
package com.example.myapp.user.api

import com.example.myapp.user.application.CreateUserUseCase
import com.example.myapp.user.domain.UserRole
import com.ninjasquad.springmockk.MockkBean
import io.kotest.core.spec.style.DescribeSpec
import io.mockk.every
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.post
import java.time.Instant

@WebMvcTest(UserController::class)
class UserControllerTest(
    private val mockMvc: MockMvc,
    @MockkBean private val createUserUseCase: CreateUserUseCase,
) : DescribeSpec({

    describe("POST /api/v1/users") {
        it("201 Created를 반환한다") {
            every { createUserUseCase.execute(any()) } returns UserResponse(
                id = 1L,
                email = "test@test.com",
                name = "테스트",
                role = UserRole.USER,
                createdAt = Instant.now(),
            )

            mockMvc.post("/api/v1/users") {
                contentType = MediaType.APPLICATION_JSON
                content = """
                    {
                        "email": "test@test.com",
                        "name": "테스트",
                        "password": "pass1234"
                    }
                """.trimIndent()
            }.andExpect {
                status { isCreated() }
                jsonPath("$.email") { value("test@test.com") }
            }
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

// Coroutine 기반 서비스 (WebFlux 필요)
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

## 전환 시그널

아래 신호가 나타나면 대규모(헥사고날 + 멀티 모듈) 아키텍처로의 전환을 검토한다.

| 시그널 | 설명 |
|--------|------|
| **모듈 간 의존성 복잡화** | 모듈 간 직접 호출이 복잡하게 얽히기 시작할 때. 이벤트 기반 통신이나 명시적 인터페이스 경계가 필요해진다. |
| **팀 규모 확대** | 팀이 15명 이상으로 커져서 모듈 경계를 컴파일 타임에 강제해야 할 때. 멀티 모듈 Gradle로 의존성을 물리적으로 차단한다. |
| **변경 사이드이펙트** | 한 모듈의 변경이 다른 모듈에 예상치 못한 사이드이펙트를 일으킬 때. 도메인 순수성과 포트/어댑터 분리가 필요해진다. |

---

## 중규모에서 지켜야 할 규칙

| 규칙 | 설명 |
|------|------|
| 의존성 방향 준수 | `api → application → domain ← infrastructure` 역방향 금지 |
| sealed class 에러 | `when` 완전 매칭으로 모든 에러 케이스 처리 보장 |
| UseCase 단위 분리 | 하나의 UseCase = 하나의 유스케이스, 비대한 Service 방지 |
| Extension function 매핑 | MapStruct 대신 Kotlin 확장 함수로 변환 |
| Controller는 얇게 | UseCase 메서드 위임만 |
| `@Transactional(readOnly=true)` | 읽기 전용 UseCase에 명시 |
| 하위 폴더 규칙 | 4개 이상 파일이면 하위 폴더, 3개 이하면 flat |
| 단순 CRUD는 flat | 불필요한 레이어 분리 지양 |
| Kotest DescribeSpec | BDD 스타일 테스트로 가독성 향상 |
