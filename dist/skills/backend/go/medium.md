# Go - 중규모 프로젝트 가이드

> 팀 3~8명, 엔드포인트 20~100개, 성장하는 서비스

---

## 핵심 원칙

- **Standard Layout**: `cmd/` + `internal/` 구조
- **3-Layer**: Handler → Service → Repository
- **인터페이스는 소비자 측에서 정의**: Go 관용적 패턴
- **google/wire 또는 수동 DI**: 의존성 조립
- **AppError 타입**: 일관된 에러 처리
- **sqlc + goose**: 타입 안전 쿼리 + 마이그레이션
- **testcontainers-go**: 실제 DB로 통합 테스트

---

## 디렉토리 구조

```
project/
├── cmd/
│   └── server/
│       └── main.go                # 진입점, DI 조립
│
├── internal/
│   ├── config/
│   │   └── config.go              # 환경 설정
│   │
│   ├── user/                      # 도메인: 사용자
│   │   ├── handler.go             # HTTP 핸들러
│   │   ├── service.go             # 비즈니스 로직
│   │   ├── repository.go          # DB 접근 (sqlc 래핑)
│   │   ├── model.go               # 도메인 모델
│   │   └── dto.go                 # 요청/응답 DTO
│   │
│   ├── order/                     # 도메인: 주문
│   │   ├── handler.go
│   │   ├── service.go
│   │   ├── repository.go
│   │   ├── model.go
│   │   └── dto.go
│   │
│   ├── middleware/
│   │   ├── logging.go
│   │   ├── cors.go
│   │   ├── auth.go
│   │   └── recovery.go
│   │
│   └── platform/                  # 인프라 / 공통
│       ├── database/
│       │   └── postgres.go
│       ├── apperror/
│       │   └── error.go           # AppError 타입
│       └── httputil/
│           └── response.go        # JSON 응답 헬퍼
│
├── db/
│   ├── sqlc.yaml
│   ├── schema.sql
│   ├── queries/
│   │   ├── users.sql
│   │   └── orders.sql
│   └── generated/                 # sqlc 생성 코드
│
├── migrations/
│   ├── 001_create_users.sql
│   └── 002_create_orders.sql
│
├── tests/
│   └── integration/
│       └── user_test.go
│
├── go.mod
├── go.sum
├── Makefile
└── .env
```

---

## AppError 타입

```go
// internal/platform/apperror/error.go
package apperror

import (
	"fmt"
	"net/http"
)

type Code string

const (
	CodeNotFound     Code = "NOT_FOUND"
	CodeConflict     Code = "CONFLICT"
	CodeValidation   Code = "VALIDATION"
	CodeUnauthorized Code = "UNAUTHORIZED"
	CodeForbidden    Code = "FORBIDDEN"
	CodeInternal     Code = "INTERNAL"
)

var statusMap = map[Code]int{
	CodeNotFound:     http.StatusNotFound,
	CodeConflict:     http.StatusConflict,
	CodeValidation:   http.StatusUnprocessableEntity,
	CodeUnauthorized: http.StatusUnauthorized,
	CodeForbidden:    http.StatusForbidden,
	CodeInternal:     http.StatusInternalServerError,
}

type AppError struct {
	Code    Code   `json:"code"`
	Message string `json:"message"`
	Err     error  `json:"-"`
}

func (e *AppError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("%s: %s: %v", e.Code, e.Message, e.Err)
	}
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

func (e *AppError) Unwrap() error {
	return e.Err
}

func (e *AppError) HTTPStatus() int {
	if s, ok := statusMap[e.Code]; ok {
		return s
	}
	return http.StatusInternalServerError
}

// 생성 헬퍼
func NotFound(resource string, id any) *AppError {
	return &AppError{Code: CodeNotFound, Message: fmt.Sprintf("%s(%v)을(를) 찾을 수 없습니다", resource, id)}
}

func Conflict(msg string) *AppError {
	return &AppError{Code: CodeConflict, Message: msg}
}

func Validation(msg string) *AppError {
	return &AppError{Code: CodeValidation, Message: msg}
}

func Internal(err error) *AppError {
	return &AppError{Code: CodeInternal, Message: "서버 내부 오류", Err: err}
}
```

---

## JSON 응답 헬퍼

```go
// internal/platform/httputil/response.go
package httputil

import (
	"encoding/json"
	"errors"
	"net/http"

	"myproject/internal/platform/apperror"
)

func WriteJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func HandleError(w http.ResponseWriter, err error) {
	var appErr *apperror.AppError
	if errors.As(err, &appErr) {
		WriteJSON(w, appErr.HTTPStatus(), map[string]any{
			"type":    "https://api.example.com/errors/" + string(appErr.Code),
			"title":   appErr.Message,
			"status":  appErr.HTTPStatus(),
			"code":    appErr.Code,
		})
		return
	}

	WriteJSON(w, http.StatusInternalServerError, map[string]any{
		"type":   "https://api.example.com/errors/internal",
		"title":  "서버 내부 오류가 발생했습니다",
		"status": 500,
	})
}
```

---

## 인터페이스는 소비자 측에서 정의

```go
// internal/user/service.go
package user

import "context"

// UserRepository - Service가 필요로 하는 인터페이스를 Service 패키지에서 정의
type UserRepository interface {
	FindByID(ctx context.Context, id int32) (*User, error)
	FindByEmail(ctx context.Context, email string) (*User, error)
	FindAll(ctx context.Context, limit, offset int32) ([]*User, error)
	Create(ctx context.Context, params CreateUserParams) (*User, error)
}

type Service struct {
	repo UserRepository
}

func NewService(repo UserRepository) *Service {
	return &Service{repo: repo}
}

func (s *Service) CreateUser(ctx context.Context, req CreateUserRequest) (*UserResponse, error) {
	if errs := req.Validate(); len(errs) > 0 {
		return nil, apperror.Validation("입력값 검증 실패")
	}

	existing, _ := s.repo.FindByEmail(ctx, req.Email)
	if existing != nil {
		return nil, apperror.Conflict("이미 등록된 이메일입니다")
	}

	hashed, err := hashPassword(req.Password)
	if err != nil {
		return nil, apperror.Internal(err)
	}

	user, err := s.repo.Create(ctx, CreateUserParams{
		Email:    req.Email,
		Name:     req.Name,
		Password: hashed,
	})
	if err != nil {
		return nil, apperror.Internal(err)
	}

	return toUserResponse(user), nil
}

func (s *Service) GetUser(ctx context.Context, id int32) (*UserResponse, error) {
	user, err := s.repo.FindByID(ctx, id)
	if err != nil {
		return nil, apperror.NotFound("사용자", id)
	}
	return toUserResponse(user), nil
}

func (s *Service) ListUsers(ctx context.Context, limit, offset int32) ([]*UserResponse, error) {
	users, err := s.repo.FindAll(ctx, limit, offset)
	if err != nil {
		return nil, apperror.Internal(err)
	}

	resp := make([]*UserResponse, len(users))
	for i, u := range users {
		resp[i] = toUserResponse(u)
	}
	return resp, nil
}
```

---

## Repository 구현체

```go
// internal/user/repository.go
package user

import (
	"context"
	"database/sql"

	"myproject/db/generated"
)

type PostgresRepository struct {
	queries *generated.Queries
}

func NewPostgresRepository(db *sql.DB) *PostgresRepository {
	return &PostgresRepository{queries: generated.New(db)}
}

func (r *PostgresRepository) FindByID(ctx context.Context, id int32) (*User, error) {
	row, err := r.queries.GetUser(ctx, id)
	if err != nil {
		return nil, err
	}
	return &User{ID: row.ID, Email: row.Email, Name: row.Name, CreatedAt: row.CreatedAt}, nil
}

func (r *PostgresRepository) FindByEmail(ctx context.Context, email string) (*User, error) {
	row, err := r.queries.GetUserByEmail(ctx, email)
	if err != nil {
		return nil, err
	}
	return &User{ID: row.ID, Email: row.Email, Name: row.Name, CreatedAt: row.CreatedAt}, nil
}

func (r *PostgresRepository) FindAll(ctx context.Context, limit, offset int32) ([]*User, error) {
	rows, err := r.queries.ListUsers(ctx, generated.ListUsersParams{Limit: limit, Offset: offset})
	if err != nil {
		return nil, err
	}

	users := make([]*User, len(rows))
	for i, row := range rows {
		users[i] = &User{ID: row.ID, Email: row.Email, Name: row.Name, CreatedAt: row.CreatedAt}
	}
	return users, nil
}

func (r *PostgresRepository) Create(ctx context.Context, params CreateUserParams) (*User, error) {
	row, err := r.queries.CreateUser(ctx, generated.CreateUserParams{
		Email: params.Email, Name: params.Name, Password: params.Password,
	})
	if err != nil {
		return nil, err
	}
	return &User{ID: row.ID, Email: row.Email, Name: row.Name, CreatedAt: row.CreatedAt}, nil
}
```

---

## Handler

```go
// internal/user/handler.go
package user

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/go-chi/chi/v5"
	"myproject/internal/platform/httputil"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Post("/", h.createUser)
	r.Get("/{id}", h.getUser)
	r.Get("/", h.listUsers)
	return r
}

func (h *Handler) createUser(w http.ResponseWriter, r *http.Request) {
	var req CreateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteJSON(w, http.StatusBadRequest, map[string]string{"error": "잘못된 요청"})
		return
	}

	user, err := h.service.CreateUser(r.Context(), req)
	if err != nil {
		httputil.HandleError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusCreated, user)
}

func (h *Handler) getUser(w http.ResponseWriter, r *http.Request) {
	id, err := strconv.Atoi(chi.URLParam(r, "id"))
	if err != nil {
		httputil.WriteJSON(w, http.StatusBadRequest, map[string]string{"error": "유효하지 않은 ID"})
		return
	}

	user, err := h.service.GetUser(r.Context(), int32(id))
	if err != nil {
		httputil.HandleError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, user)
}

func (h *Handler) listUsers(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	users, err := h.service.ListUsers(r.Context(), int32(limit), int32(offset))
	if err != nil {
		httputil.HandleError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, users)
}
```

---

## DI 조립 (수동)

```go
// cmd/server/main.go
package main

import (
	"log"
	"net/http"

	"github.com/go-chi/chi/v5"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"

	"myproject/internal/config"
	"myproject/internal/middleware"
	"myproject/internal/order"
	"myproject/internal/platform/database"
	"myproject/internal/user"
)

func main() {
	cfg := config.Load()

	db, err := database.NewPostgres(cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	// 의존성 조립 (수동 DI)
	userRepo := user.NewPostgresRepository(db)
	userService := user.NewService(userRepo)
	userHandler := user.NewHandler(userService)

	orderRepo := order.NewPostgresRepository(db)
	orderService := order.NewService(orderRepo)
	orderHandler := order.NewHandler(orderService)

	// 라우터
	r := chi.NewRouter()
	r.Use(chiMiddleware.RequestID)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.CORS(cfg.CORSOrigin))

	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{"status":"ok"}`))
	})

	r.Route("/api/v1", func(r chi.Router) {
		r.Mount("/users", userHandler.Routes())
		r.Mount("/orders", orderHandler.Routes())
	})

	log.Printf("서버 시작: :%d", cfg.Port)
	http.ListenAndServe(fmt.Sprintf(":%d", cfg.Port), r)
}
```

---

## google/wire DI (선택)

```go
// cmd/server/wire.go
//go:build wireinject

package main

import (
	"database/sql"

	"github.com/google/wire"
	"myproject/internal/user"
)

func InitializeUserHandler(db *sql.DB) *user.Handler {
	wire.Build(
		user.NewPostgresRepository,
		wire.Bind(new(user.UserRepository), new(*user.PostgresRepository)),
		user.NewService,
		user.NewHandler,
	)
	return nil
}
```

---

## testcontainers-go 통합 테스트

```go
// tests/integration/user_test.go
package integration

import (
	"context"
	"database/sql"
	"testing"

	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"myproject/internal/user"
)

func setupTestDB(t *testing.T) *sql.DB {
	ctx := context.Background()
	container, err := postgres.Run(ctx, "postgres:16-alpine",
		postgres.WithDatabase("testdb"),
		postgres.WithUsername("test"),
		postgres.WithPassword("test"),
	)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { container.Terminate(ctx) })

	connStr, err := container.ConnectionString(ctx, "sslmode=disable")
	if err != nil {
		t.Fatal(err)
	}

	db, err := sql.Open("postgres", connStr)
	if err != nil {
		t.Fatal(err)
	}

	// 스키마 적용
	_, err = db.ExecContext(ctx, `
		CREATE TABLE users (
			id SERIAL PRIMARY KEY,
			email VARCHAR(255) UNIQUE NOT NULL,
			name VARCHAR(100) NOT NULL,
			password VARCHAR(255) NOT NULL,
			created_at TIMESTAMPTZ DEFAULT NOW()
		)
	`)
	if err != nil {
		t.Fatal(err)
	}

	return db
}

func TestUserService_CreateUser(t *testing.T) {
	db := setupTestDB(t)
	defer db.Close()

	repo := user.NewPostgresRepository(db)
	service := user.NewService(repo)

	resp, err := service.CreateUser(context.Background(), user.CreateUserRequest{
		Email:    "test@example.com",
		Name:     "테스트",
		Password: "password123",
	})
	if err != nil {
		t.Fatalf("사용자 생성 실패: %v", err)
	}

	if resp.Email != "test@example.com" {
		t.Errorf("이메일 불일치: got %s, want test@example.com", resp.Email)
	}
}

func TestUserService_CreateDuplicateUser(t *testing.T) {
	db := setupTestDB(t)
	defer db.Close()

	repo := user.NewPostgresRepository(db)
	service := user.NewService(repo)

	req := user.CreateUserRequest{Email: "dup@test.com", Name: "중복", Password: "password123"}
	_, _ = service.CreateUser(context.Background(), req)
	_, err := service.CreateUser(context.Background(), req)

	if err == nil {
		t.Error("중복 이메일에 대해 에러가 발생해야 함")
	}
}
```

---

## Makefile

```makefile
.PHONY: run test sqlc migrate

run:
	go run ./cmd/server

test:
	go test ./... -v -race

sqlc:
	sqlc generate

migrate-up:
	goose -dir migrations postgres "$(DATABASE_URL)" up

migrate-down:
	goose -dir migrations postgres "$(DATABASE_URL)" down

lint:
	golangci-lint run ./...
```

---

## 중규모에서 지켜야 할 규칙

| 규칙 | 설명 |
|------|------|
| 인터페이스는 소비자 측에서 | Repository 인터페이스를 Service 패키지에 정의 |
| `internal/` 아래에 패키지 | 외부 노출 방지 |
| `AppError`로 에러 통일 | `errors.As`로 타입 확인 |
| Handler는 얇게 | 파싱/검증만, 비즈니스 로직은 Service |
| context 전달 | 모든 함수에 `ctx context.Context` 첫 번째 인자 |
| table-driven 테스트 | 모든 경우를 테이블로 나열 |
