# Kotlin / Spring Boot - 소규모 프로젝트 가이드

> 엔드포인트 50개 이하, MVP/내부 툴/단일 마이크로서비스

---

## 핵심 원칙

- **도메인 폴더 + 플랫 파일**: 도메인별 폴더 안에 Controller, Service, Repository, Entity, DTO를 같은 레벨에 배치
- **data class DTO**: 불변 데이터 전달, copy() 활용
- **Null Safety**: `?` 연산자로 NPE 원천 차단
- **Extension Functions**: 유틸리티를 깔끔하게 확장
- **allopen/noarg 플러그인**: JPA Entity를 위한 컴파일러 플러그인
- **MockK**: Kotlin 친화적 Mocking 라이브러리

---

## 디렉토리 구조

```
src/main/kotlin/com/example/myapp/
├── MyAppApplication.kt
├── user/
│   ├── UserController.kt
│   ├── UserService.kt
│   ├── UserRepository.kt
│   ├── User.kt                        # Entity
│   ├── UserDto.kt                     # data class DTO
│   └── UserMapper.kt
├── order/
│   ├── OrderController.kt
│   ├── OrderService.kt
│   ├── OrderRepository.kt
│   ├── Order.kt
│   ├── OrderItem.kt
│   ├── OrderDto.kt
│   └── OrderMapper.kt
├── product/
│   └── ...
└── common/
    ├── GlobalExceptionHandler.kt
    ├── SecurityConfig.kt
    └── PageResponse.kt

src/main/resources/
├── application.yml
└── db/migration/
    └── V1__create_users.sql

src/test/kotlin/com/example/myapp/
├── user/
│   ├── UserControllerTest.kt
│   └── UserServiceTest.kt
├── order/
│   └── OrderControllerTest.kt
└── MyAppApplicationTests.kt
```

---

## Entity (allopen/noarg 플러그인 필요)

```kotlin
// user/User.kt
package com.example.myapp.user

import jakarta.persistence.*
import java.time.Instant

@Entity
@Table(name = "users")
class User(
    @Column(nullable = false, unique = true, length = 255)
    var email: String,

    @Column(nullable = false, length = 100)
    var name: String,

    @Column(nullable = false)
    var password: String,

    @Column(name = "created_at", nullable = false, updatable = false)
    val createdAt: Instant = Instant.now(),

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    val id: Long = 0,
)
```

---

## data class DTO

```kotlin
// user/UserDto.kt
package com.example.myapp.user

import jakarta.validation.constraints.Email
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.time.Instant

data class UserCreateRequest(
    @field:NotBlank @field:Email
    val email: String,

    @field:NotBlank @field:Size(max = 100)
    val name: String,

    @field:NotBlank @field:Size(min = 8)
    val password: String,
)

data class UserResponse(
    val id: Long,
    val email: String,
    val name: String,
    val createdAt: Instant,
)
```

---

## Mapper

```kotlin
// user/UserMapper.kt
package com.example.myapp.user

fun User.toResponse() = UserResponse(
    id = id,
    email = email,
    name = name,
    createdAt = createdAt,
)

fun List<User>.toResponses() = map { it.toResponse() }
```

---

## Repository

```kotlin
// user/UserRepository.kt
package com.example.myapp.user

import org.springframework.data.jpa.repository.JpaRepository

interface UserRepository : JpaRepository<User, Long> {
    fun findByEmail(email: String): User?
    fun existsByEmail(email: String): Boolean
}
```

---

## Service

```kotlin
// user/UserService.kt
package com.example.myapp.user

import org.springframework.http.HttpStatus
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.web.server.ResponseStatusException

@Service
class UserService(
    private val userRepository: UserRepository,
    private val passwordEncoder: PasswordEncoder,
) {
    fun createUser(request: UserCreateRequest): UserResponse {
        if (userRepository.existsByEmail(request.email)) {
            throw ResponseStatusException(HttpStatus.CONFLICT, "이미 등록된 이메일입니다")
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
        val user = userRepository.findById(id).orElseThrow {
            ResponseStatusException(HttpStatus.NOT_FOUND, "사용자를 찾을 수 없습니다")
        }
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

## Controller

```kotlin
// user/UserController.kt
package com.example.myapp.user

import jakarta.validation.Valid
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/v1/users")
class UserController(
    private val userService: UserService,
) {
    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    fun createUser(@Valid @RequestBody request: UserCreateRequest): UserResponse {
        return userService.createUser(request)
    }

    @GetMapping("/{id}")
    fun getUser(@PathVariable id: Long): UserResponse {
        return userService.getUser(id)
    }

    @GetMapping
    fun listUsers(
        @RequestParam(defaultValue = "0") page: Int,
        @RequestParam(defaultValue = "20") size: Int,
    ): List<UserResponse> {
        return userService.listUsers(page, size)
    }
}
```

---

## common/ 공통 모듈

### 글로벌 예외 핸들러

```kotlin
// common/GlobalExceptionHandler.kt
package com.example.myapp.common

import org.springframework.http.HttpStatus
import org.springframework.http.ProblemDetail
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestControllerAdvice
import org.springframework.web.server.ResponseStatusException
import java.net.URI

@RestControllerAdvice
class GlobalExceptionHandler {

    @ExceptionHandler(ResponseStatusException::class)
    fun handleResponseStatus(ex: ResponseStatusException): ProblemDetail {
        return ProblemDetail.forStatusAndDetail(
            HttpStatus.valueOf(ex.statusCode.value()),
            ex.reason ?: "오류가 발생했습니다"
        ).apply {
            type = URI.create("https://api.example.com/errors/${statusCode.value()}")
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
            type = URI.create("https://api.example.com/errors/internal")
        }
    }
}
```

### 공통 응답

```kotlin
// common/PageResponse.kt
package com.example.myapp.common

data class PageResponse<T>(
    val content: List<T>,
    val page: Int,
    val size: Int,
    val totalElements: Long,
    val totalPages: Int,
)
```

---

## Extension Functions 활용

```kotlin
// common/Extensions.kt
package com.example.myapp.common

import org.springframework.data.repository.CrudRepository

// Repository extension: findById가 null을 반환하도록
fun <T, ID> CrudRepository<T, ID>.findByIdOrNull(id: ID): T? =
    findById(id!!).orElse(null)
```

---

## Gradle 플러그인 설정

```kotlin
// build.gradle.kts
plugins {
    kotlin("jvm") version "2.0.0"
    kotlin("plugin.spring") version "2.0.0"   // allopen
    kotlin("plugin.jpa") version "2.0.0"       // noarg for JPA
    id("org.springframework.boot") version "3.3.0"
    id("io.spring.dependency-management") version "1.1.5"
}

// noarg: JPA Entity에 기본 생성자 자동 생성
noArg {
    annotation("jakarta.persistence.Entity")
}

// allopen: JPA Entity를 open으로 (lazy loading 지원)
allOpen {
    annotation("jakarta.persistence.Entity")
    annotation("jakarta.persistence.MappedSuperclass")
    annotation("jakarta.persistence.Embeddable")
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-web")
    implementation("org.springframework.boot:spring-boot-starter-data-jpa")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin")
    implementation("org.flywaydb:flyway-core")
    runtimeOnly("org.postgresql:postgresql")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("io.mockk:mockk:1.13.10")
    testImplementation("com.ninja-squad:springmockk:4.0.2")
}
```

---

## 테스트 (MockK)

```kotlin
// src/test/kotlin/com/example/myapp/user/UserControllerTest.kt
package com.example.myapp.user

import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post

@SpringBootTest
@AutoConfigureMockMvc
class UserControllerTest {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Test
    fun `사용자 생성 성공`() {
        mockMvc.post("/api/v1/users") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"test@test.com","name":"테스트","password":"password123"}"""
        }.andExpect {
            status { isCreated() }
            jsonPath("$.email") { value("test@test.com") }
        }
    }

    @Test
    fun `존재하지 않는 사용자 404`() {
        mockMvc.get("/api/v1/users/9999")
            .andExpect { status { isNotFound() } }
    }

    @Test
    fun `입력값 검증 실패 422`() {
        mockMvc.post("/api/v1/users") {
            contentType = MediaType.APPLICATION_JSON
            content = """{"email":"invalid","name":"","password":"short"}"""
        }.andExpect {
            status { isUnprocessableEntity() }
        }
    }
}
```

### Service 단위 테스트

```kotlin
// src/test/kotlin/com/example/myapp/user/UserServiceTest.kt
package com.example.myapp.user

import io.mockk.every
import io.mockk.mockk
import io.mockk.verify
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.web.server.ResponseStatusException

class UserServiceTest {

    private val userRepository = mockk<UserRepository>(relaxed = true)
    private val passwordEncoder = mockk<PasswordEncoder>()
    private val userService = UserService(userRepository, passwordEncoder)

    @Test
    fun `이메일 중복 시 CONFLICT 예외`() {
        every { userRepository.existsByEmail("dup@test.com") } returns true

        assertThrows<ResponseStatusException> {
            userService.createUser(
                UserCreateRequest("dup@test.com", "테스트", "password123")
            )
        }
    }

    @Test
    fun `사용자 생성 시 비밀번호 인코딩`() {
        every { userRepository.existsByEmail(any()) } returns false
        every { passwordEncoder.encode("password123") } returns "encoded"
        every { userRepository.save(any()) } returnsArgument 0

        userService.createUser(
            UserCreateRequest("new@test.com", "테스트", "password123")
        )

        verify { passwordEncoder.encode("password123") }
    }
}
```

---

## Null Safety 활용 예시

```kotlin
// Kotlin의 null safety로 안전한 코드
fun getUserEmail(id: Long): String {
    // ?. 연산자: null이면 체인 중단
    val user = userRepository.findByIdOrNull(id)
    return user?.email ?: throw ResponseStatusException(HttpStatus.NOT_FOUND)
}

// let 스코프 함수로 null 안전 변환
fun findAndConvert(id: Long): UserResponse? {
    return userRepository.findByIdOrNull(id)?.let { it.toResponse() }
}
```

---

## 소규모에서 하지 말아야 할 것

| 안티패턴 | 이유 |
|----------|------|
| 레이어별 하위 폴더 분리 | `controller/`, `service/`, `repository/` 폴더로 나누면 도메인 응집도가 떨어짐 |
| sealed class 에러 | `ResponseStatusException`으로 충분 |
| Coroutines | 블로킹 I/O 기반 Spring MVC에서 불필요 |
| 멀티 모듈 | 단일 모듈로 충분 |
| Arrow-kt | 소규모에서는 과도한 FP 추상화 |

---

## 전환 시그널

다음 조건이 보이면 중규모 구조로 전환을 검토한다:

- **도메인 폴더 안 파일이 10개를 넘기기 시작할 때** - 도메인 내부에 하위 구조가 필요하다는 신호
- **Service 하나가 200줄 이상으로 커질 때** - 비즈니스 로직을 분리해야 할 시점
- **외부 시스템 연동이 생길 때** - 인프라 레이어 분리가 필요해짐
