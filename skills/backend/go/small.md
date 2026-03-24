# Go - 소규모 프로젝트 가이드

> 엔드포인트 50개 이하, MVP/내부 툴/단일 마이크로서비스

---

## 핵심 원칙

- **net/http (Go 1.22+)**: `http.NewServeMux()`의 향상된 라우팅 사용
- **chi router**: 미들웨어가 필요하면 chi 사용 (net/http 호환)
- **도메인 패키지 + Flat 파일**: 도메인별 폴더 안에 handler, service, model, dto를 평탄하게 배치
- **Handler → Service**: Handler는 HTTP 처리, Service는 비즈니스 로직 + DB 호출
- **sqlc**: SQL → 타입 안전 Go 코드 생성
- **goose**: DB 마이그레이션
- **Table-driven 테스트**: Go 표준 테스트 관행

---

## 디렉토리 구조

```
project/
├── main.go                      # 진입점, DI 조립, 서버 시작
│
├── user/
│   ├── handler.go               # HTTP 핸들러
│   ├── service.go               # 비즈니스 로직
│   ├── model.go                 # 도메인 모델
│   └── dto.go                   # 요청/응답 DTO
│
├── order/
│   ├── handler.go
│   ├── service.go
│   ├── model.go
│   └── dto.go
│
├── common/
│   ├── config.go                # 환경 설정
│   ├── database.go              # DB 연결
│   ├── middleware.go            # 로깅, CORS 등
│   └── response.go              # JSON 응답 헬퍼
│
├── db/
│   ├── query.sql
│   ├── schema.sql
│   ├── sqlc.yaml
│   └── generated/
│
├── migrations/
├── go.mod
└── .env
```

---

## 환경 설정

```go
// common/config.go
package common

import (
	"os"
	"strconv"
)

type Config struct {
	Port        int
	DatabaseURL string
	CORSOrigin  string
}

func LoadConfig() Config {
	port, _ := strconv.Atoi(getEnv("PORT", "8080"))
	return Config{
		Port:        port,
		DatabaseURL: getEnv("DATABASE_URL", "postgres://localhost:5432/mydb?sslmode=disable"),
		CORSOrigin:  getEnv("CORS_ORIGIN", "http://localhost:3000"),
	}
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
```

---

## DB 연결

```go
// common/database.go
package common

import (
	"context"
	"database/sql"
	"fmt"

	_ "github.com/lib/pq"
)

func NewDB(databaseURL string) (*sql.DB, error) {
	db, err := sql.Open("postgres", databaseURL)
	if err != nil {
		return nil, fmt.Errorf("DB 연결 실패: %w", err)
	}

	db.SetMaxOpenConns(25)
	db.SetMaxIdleConns(5)

	if err := db.PingContext(context.Background()); err != nil {
		return nil, fmt.Errorf("DB ping 실패: %w", err)
	}

	return db, nil
}
```

---

## JSON 응답 헬퍼

```go
// common/response.go
package common

import (
	"encoding/json"
	"net/http"
)

type ErrorResponse struct {
	Type   string `json:"type"`
	Title  string `json:"title"`
	Status int    `json:"status"`
}

func WriteJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func WriteError(w http.ResponseWriter, status int, title string) {
	WriteJSON(w, status, ErrorResponse{
		Type:   "https://api.example.com/errors",
		Title:  title,
		Status: status,
	})
}
```

---

## 미들웨어

```go
// common/middleware.go
package common

import (
	"log"
	"net/http"
	"time"
)

func LoggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}

		next.ServeHTTP(wrapped, r)

		log.Printf("%s %s %d %s",
			r.Method, r.URL.Path, wrapped.statusCode, time.Since(start))
	})
}

func CORSMiddleware(next http.Handler, origin string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", origin)
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

type responseWriter struct {
	http.ResponseWriter
	statusCode int
}

func (rw *responseWriter) WriteHeader(code int) {
	rw.statusCode = code
	rw.ResponseWriter.WriteHeader(code)
}
```

---

## sqlc 설정 및 쿼리

```yaml
# db/sqlc.yaml
version: "2"
sql:
  - engine: "postgresql"
    queries: "query.sql"
    schema: "schema.sql"
    gen:
      go:
        package: "generated"
        out: "generated"
```

```sql
-- db/schema.sql
CREATE TABLE users (
    id         SERIAL PRIMARY KEY,
    email      VARCHAR(255) NOT NULL UNIQUE,
    name       VARCHAR(100) NOT NULL,
    password   VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
```

```sql
-- db/query.sql
-- name: GetUser :one
SELECT id, email, name, created_at FROM users WHERE id = $1;

-- name: GetUserByEmail :one
SELECT id, email, name, password, created_at FROM users WHERE email = $1;

-- name: ListUsers :many
SELECT id, email, name, created_at FROM users
ORDER BY created_at DESC
LIMIT $1 OFFSET $2;

-- name: CreateUser :one
INSERT INTO users (email, name, password)
VALUES ($1, $2, $3)
RETURNING id, email, name, created_at;

-- name: DeleteUser :exec
DELETE FROM users WHERE id = $1;
```

---

## 도메인 모델

```go
// user/model.go
package user

import "time"

type User struct {
	ID        int32
	Email     string
	Name      string
	Password  string
	CreatedAt time.Time
}
```

---

## DTO (요청/응답)

```go
// user/dto.go
package user

import "time"

// 요청 DTO
type CreateUserRequest struct {
	Email    string `json:"email"`
	Name     string `json:"name"`
	Password string `json:"password"`
}

func (r CreateUserRequest) Validate() map[string]string {
	errs := map[string]string{}
	if r.Email == "" {
		errs["email"] = "이메일은 필수입니다"
	}
	if r.Name == "" {
		errs["name"] = "이름은 필수입니다"
	}
	if len(r.Password) < 8 {
		errs["password"] = "비밀번호는 8자 이상이어야 합니다"
	}
	return errs
}

// 응답 DTO
type UserResponse struct {
	ID        int32     `json:"id"`
	Email     string    `json:"email"`
	Name      string    `json:"name"`
	CreatedAt time.Time `json:"created_at"`
}
```

---

## Service (비즈니스 로직)

```go
// user/service.go
package user

import (
	"context"
	"errors"
	"fmt"

	"myproject/db/generated"

	"golang.org/x/crypto/bcrypt"
)

var (
	ErrDuplicateEmail = errors.New("이미 등록된 이메일입니다")
	ErrUserNotFound   = errors.New("사용자를 찾을 수 없습니다")
)

type Service struct {
	queries *generated.Queries
}

func NewService(queries *generated.Queries) *Service {
	return &Service{queries: queries}
}

func (s *Service) CreateUser(ctx context.Context, req CreateUserRequest) (UserResponse, error) {
	// 중복 확인
	_, err := s.queries.GetUserByEmail(ctx, req.Email)
	if err == nil {
		return UserResponse{}, ErrDuplicateEmail
	}

	// 비밀번호 해싱
	hashed, err := bcrypt.GenerateFromPassword([]byte(req.Password), 12)
	if err != nil {
		return UserResponse{}, fmt.Errorf("비밀번호 해싱 실패: %w", err)
	}

	user, err := s.queries.CreateUser(ctx, generated.CreateUserParams{
		Email:    req.Email,
		Name:     req.Name,
		Password: string(hashed),
	})
	if err != nil {
		return UserResponse{}, fmt.Errorf("사용자 생성 실패: %w", err)
	}

	return UserResponse{
		ID: user.ID, Email: user.Email, Name: user.Name, CreatedAt: user.CreatedAt,
	}, nil
}

func (s *Service) GetUser(ctx context.Context, id int32) (UserResponse, error) {
	user, err := s.queries.GetUser(ctx, id)
	if err != nil {
		return UserResponse{}, ErrUserNotFound
	}

	return UserResponse{
		ID: user.ID, Email: user.Email, Name: user.Name, CreatedAt: user.CreatedAt,
	}, nil
}

func (s *Service) ListUsers(ctx context.Context, limit, offset int32) ([]UserResponse, error) {
	users, err := s.queries.ListUsers(ctx, generated.ListUsersParams{
		Limit:  limit,
		Offset: offset,
	})
	if err != nil {
		return nil, fmt.Errorf("사용자 목록 조회 실패: %w", err)
	}

	resp := make([]UserResponse, len(users))
	for i, u := range users {
		resp[i] = UserResponse{
			ID: u.ID, Email: u.Email, Name: u.Name, CreatedAt: u.CreatedAt,
		}
	}
	return resp, nil
}
```

---

## HTTP 핸들러

```go
// user/handler.go
package user

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"

	"myproject/common"
)

type Handler struct {
	service *Service
}

func NewHandler(service *Service) *Handler {
	return &Handler{service: service}
}

// RegisterRoutes는 mux에 user 도메인의 라우트를 등록한다.
func (h *Handler) RegisterRoutes(mux *http.ServeMux) {
	mux.HandleFunc("POST /api/v1/users", h.CreateUser)
	mux.HandleFunc("GET /api/v1/users/{id}", h.GetUser)
	mux.HandleFunc("GET /api/v1/users", h.ListUsers)
}

func (h *Handler) CreateUser(w http.ResponseWriter, r *http.Request) {
	var req CreateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		common.WriteError(w, http.StatusBadRequest, "잘못된 요청 형식입니다")
		return
	}

	if errs := req.Validate(); len(errs) > 0 {
		common.WriteJSON(w, http.StatusUnprocessableEntity, map[string]any{
			"type":   "https://api.example.com/errors/validation",
			"title":  "입력값 검증 실패",
			"status": 422,
			"errors": errs,
		})
		return
	}

	user, err := h.service.CreateUser(r.Context(), req)
	if err != nil {
		if errors.Is(err, ErrDuplicateEmail) {
			common.WriteError(w, http.StatusConflict, err.Error())
			return
		}
		common.WriteError(w, http.StatusInternalServerError, "사용자 생성 실패")
		return
	}

	common.WriteJSON(w, http.StatusCreated, user)
}

func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
	idStr := r.PathValue("id") // Go 1.22+ net/http
	id, err := strconv.Atoi(idStr)
	if err != nil {
		common.WriteError(w, http.StatusBadRequest, "유효하지 않은 ID입니다")
		return
	}

	user, err := h.service.GetUser(r.Context(), int32(id))
	if err != nil {
		if errors.Is(err, ErrUserNotFound) {
			common.WriteError(w, http.StatusNotFound, err.Error())
			return
		}
		common.WriteError(w, http.StatusInternalServerError, "사용자 조회 실패")
		return
	}

	common.WriteJSON(w, http.StatusOK, user)
}

func (h *Handler) ListUsers(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	users, err := h.service.ListUsers(r.Context(), int32(limit), int32(offset))
	if err != nil {
		common.WriteError(w, http.StatusInternalServerError, "사용자 목록 조회 실패")
		return
	}

	common.WriteJSON(w, http.StatusOK, users)
}
```

---

## 메인 (DI 조립 + 서버 시작)

```go
// main.go
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os/signal"
	"syscall"
	"time"

	"myproject/common"
	"myproject/db/generated"
	"myproject/user"
)

func main() {
	cfg := common.LoadConfig()

	db, err := common.NewDB(cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	queries := generated.New(db)

	// DI 조립
	userService := user.NewService(queries)
	userHandler := user.NewHandler(userService)

	// 라우트 등록
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		common.WriteJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	userHandler.RegisterRoutes(mux)

	// 미들웨어 적용
	handler := common.LoggingMiddleware(common.CORSMiddleware(mux, cfg.CORSOrigin))

	server := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Port),
		Handler:      handler,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// Graceful shutdown
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		log.Printf("서버 시작: http://localhost:%d", cfg.Port)
		if err := server.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatal(err)
		}
	}()

	<-ctx.Done()
	log.Println("서버 종료 중...")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	server.Shutdown(shutdownCtx)
}
```

---

## Table-Driven 테스트

```go
// user/handler_test.go
package user

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestCreateUser_Validation(t *testing.T) {
	tests := []struct {
		name       string
		body       CreateUserRequest
		wantStatus int
	}{
		{
			name:       "이메일 누락",
			body:       CreateUserRequest{Email: "", Name: "테스트", Password: "12345678"},
			wantStatus: http.StatusUnprocessableEntity,
		},
		{
			name:       "이름 누락",
			body:       CreateUserRequest{Email: "test@test.com", Name: "", Password: "12345678"},
			wantStatus: http.StatusUnprocessableEntity,
		},
		{
			name:       "비밀번호 짧음",
			body:       CreateUserRequest{Email: "test@test.com", Name: "테스트", Password: "short"},
			wantStatus: http.StatusUnprocessableEntity,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			body, _ := json.Marshal(tt.body)
			req := httptest.NewRequest(http.MethodPost, "/api/v1/users", bytes.NewReader(body))
			req.Header.Set("Content-Type", "application/json")
			rec := httptest.NewRecorder()

			// 핸들러에 mock service 주입
			h := NewHandler(nil) // 검증은 service 호출 전에 실패하므로 nil 가능
			h.CreateUser(rec, req)

			if rec.Code != tt.wantStatus {
				t.Errorf("got %d, want %d", rec.Code, tt.wantStatus)
			}
		})
	}
}

func TestHealthEndpoint(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()

	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
	})
	mux.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("got %d, want 200", rec.Code)
	}
}
```

---

## 소규모에서 하지 말아야 할 것

| 안티패턴 | 이유 |
|----------|------|
| `cmd/` + `internal/` 구조 분리 | 엔드포인트 50개 이하에서는 불필요한 복잡성 |
| DI 프레임워크 (wire 등) | 수동 조립으로 충분 |
| gRPC | REST로 충분한 규모 |
| 도메인 이벤트 | 직접 함수 호출이 더 명확 |
| Repository 별도 레이어 | Service에서 sqlc 직접 호출로 충분 |

---

## 전환 시그널

다음 신호가 보이면 **중규모 구조**(`cmd/internal` + Repository 레이어)로 전환을 검토한다:

- 도메인 폴더 안 파일이 **10개를 넘기기** 시작할 때
- Service 하나가 **200줄 이상**으로 커질 때
- **외부 시스템 연동**(결제, 알림 등)이 생길 때
