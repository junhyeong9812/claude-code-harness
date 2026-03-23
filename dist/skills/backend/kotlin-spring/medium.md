# Kotlin / Spring Boot - 중규모 프로젝트 가이드

> 팀 3~8명, 엔드포인트 20~100개, 성장하는 서비스

---

## 핵심 원칙

- **Package-by-feature**: 기능별 패키지 분리
- **sealed class 에러**: 타입 안전한 에러 계층 (`when` 표현식으로 완전 매칭)
- **Coroutines (선택)**: 비동기 처리가 필요한 경우만 도입
- **Kotest**: Kotlin 네이티브 테스트 프레임워크
- **Extension Functions**: DTO 변환, 유틸리티를 깔끔하게 작성

---

## 디렉토리 구조

```
src/main/kotlin/com/example/myapp/
├── MyAppApplication.kt
│
├── user/                              # 기능: 사용자
│   ├── UserController.kt
│   ├── UserService.kt
│   ├── UserRepository.kt
│   ├── User.kt                        # @Entity
│   ├── UserDto.kt                     # data class DTO
│   └── UserMapper.kt                  # Extension functions
│
├── order/                             # 기능: 주문
│   ├── OrderController.kt
│   ├── OrderService.kt
│   ├── OrderRepository.kt
│   ├── Order.kt
│   ├── OrderItem.kt
│   ├── OrderDto.kt
│   └── OrderMapper.kt
│
├── common/
│   ├── exception/
│   │   ├── AppException.kt           # sealed class 에러 계층
│   │   └── GlobalExceptionHandler.kt
│   ├── config/
│   │   ├── SecurityConfig.kt
│   │   └── JpaConfig.kt
│   └── extension/
│       └── RepositoryExtensions.kt    # 공통 확장 함수
│
src/test/kotlin/com/example/myapp/
├── user/
│   ├── UserServiceTest.kt            # Kotest
│   └── UserControllerTest.kt
├── order/
│   └── OrderServiceTest.kt
└── ArchitectureTest.kt
```

---

## sealed class 에러 계층

```kotlin
// common/exception/AppException.kt
package com.example.myapp.common.exception

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
// common/exception/GlobalExceptionHandler.kt
package com.example.myapp.common.exception

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

## Service

```kotlin
// user/UserService.kt
package com.example.myapp.user

import com.example.myapp.common.exception.ConflictException
import com.example.myapp.common.exception.NotFoundException
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional(readOnly = true)
class UserService(
    private val userRepository: UserRepository,
    private val passwordEncoder: PasswordEncoder,
) {
    @Transactional
    fun createUser(request: UserCreateRequest): UserResponse {
        if (userRepository.existsByEmail(request.email)) {
            throw ConflictException("이미 등록된 이메일입니다")
        }

        val user = User(
            email = request.email,
            name = request.name,
            password = passwordEncoder.encode(request.password),
        )
        userRepository.save(user)
        return user.toResponse()
    }

    fun getUser(id: Long): UserResponse {
        val user = userRepository.findByIdOrNull(id)
            ?: throw NotFoundException("사용자", id)
        return user.toResponse()
    }

    @Transactional
    fun updateUser(id: Long, request: UserUpdateRequest): UserResponse {
        val user = userRepository.findByIdOrNull(id)
            ?: throw NotFoundException("사용자", id)

        request.name?.let { user.name = it }
        request.email?.let { user.email = it }

        return user.toResponse()
    }

    fun listUsers(page: Int, size: Int): List<UserResponse> {
        return userRepository
            .findAll(org.springframework.data.domain.PageRequest.of(page, minOf(size, 100)))
            .map { it.toResponse() }
            .content
    }
}
```

---

## Extension Functions for Mapping

```kotlin
// user/UserMapper.kt
package com.example.myapp.user

// Entity → Response 변환
fun User.toResponse() = UserResponse(
    id = id,
    email = email,
    name = name,
    createdAt = createdAt,
)

// List 변환
fun List<User>.toResponses() = map { it.toResponse() }
```

```kotlin
// common/extension/RepositoryExtensions.kt
package com.example.myapp.common.extension

import org.springframework.data.repository.CrudRepository

fun <T, ID> CrudRepository<T, ID>.findByIdOrNull(id: ID & Any): T? =
    findById(id).orElse(null)
```

---

## Controller

```kotlin
// user/UserController.kt
package com.example.myapp.user

import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/v1/users")
class UserController(private val userService: UserService) {

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    fun create(@Valid @RequestBody request: UserCreateRequest) =
        userService.createUser(request)

    @GetMapping("/{id}")
    fun get(@PathVariable id: Long) = userService.getUser(id)

    @PutMapping("/{id}")
    fun update(
        @PathVariable id: Long,
        @Valid @RequestBody request: UserUpdateRequest,
    ) = userService.updateUser(id, request)

    @GetMapping
    fun list(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
    ) = userService.listUsers(page, size)
}
```

---

## DTO

```kotlin
// user/UserDto.kt
package com.example.myapp.user

import jakarta.validation.constraints.Email
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.time.Instant

data class UserCreateRequest(
    @field:NotBlank @field:Email val email: String,
    @field:NotBlank @field:Size(max = 100) val name: String,
    @field:NotBlank @field:Size(min = 8) val password: String,
)

data class UserUpdateRequest(
    @field:Size(max = 100) val name: String? = null,
    @field:Email val email: String? = null,
)

data class UserResponse(
    val id: Long,
    val email: String,
    val name: String,
    val createdAt: Instant,
)
```

---

## Kotest 테스트

```kotlin
// src/test/kotlin/com/example/myapp/user/UserServiceTest.kt
package com.example.myapp.user

import com.example.myapp.common.exception.ConflictException
import com.example.myapp.common.exception.NotFoundException
import io.kotest.assertions.throwables.shouldThrow
import io.kotest.core.spec.style.DescribeSpec
import io.kotest.matchers.shouldBe
import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.springframework.security.crypto.password.PasswordEncoder
import java.time.Instant
import java.util.Optional

class UserServiceTest : DescribeSpec({

    val userRepository = mockk<UserRepository>(relaxed = true)
    val passwordEncoder = mockk<PasswordEncoder>()
    val service = UserService(userRepository, passwordEncoder)

    describe("createUser") {
        it("새 사용자를 생성한다") {
            every { userRepository.existsByEmail("test@test.com") } returns false
            every { passwordEncoder.encode("pass1234") } returns "hashed"
            every { userRepository.save(any()) } answers {
                firstArg<User>().apply {
                    // id는 JPA가 생성하므로 테스트에서는 reflection 등으로 설정
                }
            }

            val request = UserCreateRequest("test@test.com", "테스트", "pass1234")
            val result = service.createUser(request)

            result.email shouldBe "test@test.com"
            verify { userRepository.save(any()) }
        }

        it("중복 이메일이면 ConflictException") {
            every { userRepository.existsByEmail("dup@test.com") } returns true

            shouldThrow<ConflictException> {
                service.createUser(UserCreateRequest("dup@test.com", "중복", "pass1234"))
            }
        }
    }

    describe("getUser") {
        it("존재하지 않으면 NotFoundException") {
            every { userRepository.findById(999L) } returns Optional.empty()

            shouldThrow<NotFoundException> {
                service.getUser(999L)
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

## 중규모에서 지켜야 할 규칙

| 규칙 | 설명 |
|------|------|
| sealed class 에러 | `when` 완전 매칭으로 모든 에러 케이스 처리 보장 |
| Extension function으로 매핑 | MapStruct 대신 Kotlin 확장 함수 |
| `?.let {}` 활용 | null 안전 변환 체이닝 |
| Controller는 얇게 | Service 메서드 위임만 |
| `@Transactional(readOnly=true)` | 읽기 전용 명시 |
| Kotest describe 스타일 | BDD 스타일 테스트로 가독성 향상 |
