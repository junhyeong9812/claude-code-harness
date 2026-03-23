# Go - 소규모 프로젝트 가이드

> 팀 1~3명, 엔드포인트 20개 이하, MVP/내부 툴/단일 마이크로서비스

---

## 핵심 원칙

- **net/http (Go 1.22+)**: `http.NewServeMux()`의 향상된 라우팅 사용
- **chi router**: 미들웨어가 필요하면 chi 사용 (net/http 호환)
- **Flat 레이아웃**: `cmd/` + `internal/` 없이 루트에 파일 배치
- **sqlc**: SQL → 타입 안전 Go 코드 생성
- **goose**: DB 마이그레이션
- **Table-driven 테스트**: Go 표준 테스트 관행

---

## 디렉토리 구조

```
project/
├── main.go                  # 진입점, 서버 시작
├── handler.go               # HTTP 핸들러
├── model.go                 # 도메인 모델, DTO
├── db.go                    # DB 연결
├── config.go                # 환경 설정
├── middleware.go             # 미들웨어 (로깅, CORS 등)
├── db/
│   ├── query.sql            # sqlc 쿼리
│   ├── schema.sql           # DDL
│   ├── sqlc.yaml            # sqlc 설정
│   └── generated/           # sqlc 생성 코드
├── migrations/
│   ├── 001_create_users.sql
│   └── ...
├── handler_test.go          # 테스트
├── go.mod
├── go.sum
└── .env
```

---

## 환경 설정

```go
// config.go
package main

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
// db.go
package main

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

## 모델 / DTO

```go
// model.go
package main

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

// 에러 응답
type ErrorResponse struct {
	Type   string `json:"type"`
	Title  string `json:"title"`
	Status int    `json:"status"`
}
```

---

## HTTP 핸들러

```go
// handler.go
package main

import (
	"encoding/json"
	"net/http"
	"strconv"

	"myproject/db/generated"

	"golang.org/x/crypto/bcrypt"
)

type Handler struct {
	queries *generated.Queries
}

func NewHandler(queries *generated.Queries) *Handler {
	return &Handler{queries: queries}
}

func (h *Handler) CreateUser(w http.ResponseWriter, r *http.Request) {
	var req CreateUserRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "잘못된 요청 형식입니다")
		return
	}

	if errs := req.Validate(); len(errs) > 0 {
		writeJSON(w, http.StatusUnprocessableEntity, map[string]any{
			"type":   "https://api.example.com/errors/validation",
			"title":  "입력값 검증 실패",
			"status": 422,
			"errors": errs,
		})
		return
	}

	// 중복 확인
	_, err := h.queries.GetUserByEmail(r.Context(), req.Email)
	if err == nil {
		writeError(w, http.StatusConflict, "이미 등록된 이메일입니다")
		return
	}

	// 비밀번호 해싱
	hashed, _ := bcrypt.GenerateFromPassword([]byte(req.Password), 12)

	user, err := h.queries.CreateUser(r.Context(), generated.CreateUserParams{
		Email:    req.Email,
		Name:     req.Name,
		Password: string(hashed),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "사용자 생성 실패")
		return
	}

	writeJSON(w, http.StatusCreated, UserResponse{
		ID: user.ID, Email: user.Email, Name: user.Name, CreatedAt: user.CreatedAt,
	})
}

func (h *Handler) GetUser(w http.ResponseWriter, r *http.Request) {
	idStr := r.PathValue("id") // Go 1.22+ net/http
	id, err := strconv.Atoi(idStr)
	if err != nil {
		writeError(w, http.StatusBadRequest, "유효하지 않은 ID입니다")
		return
	}

	user, err := h.queries.GetUser(r.Context(), int32(id))
	if err != nil {
		writeError(w, http.StatusNotFound, "사용자를 찾을 수 없습니다")
		return
	}

	writeJSON(w, http.StatusOK, UserResponse{
		ID: user.ID, Email: user.Email, Name: user.Name, CreatedAt: user.CreatedAt,
	})
}

func (h *Handler) ListUsers(w http.ResponseWriter, r *http.Request) {
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	if limit <= 0 || limit > 100 {
		limit = 20
	}

	users, err := h.queries.ListUsers(r.Context(), generated.ListUsersParams{
		Limit:  int32(limit),
		Offset: int32(offset),
	})
	if err != nil {
		writeError(w, http.StatusInternalServerError, "사용자 목록 조회 실패")
		return
	}

	resp := make([]UserResponse, len(users))
	for i, u := range users {
		resp[i] = UserResponse{ID: u.ID, Email: u.Email, Name: u.Name, CreatedAt: u.CreatedAt}
	}
	writeJSON(w, http.StatusOK, resp)
}

// --- 헬퍼 ---

func writeJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func writeError(w http.ResponseWriter, status int, title string) {
	writeJSON(w, status, ErrorResponse{
		Type:   "https://api.example.com/errors",
		Title:  title,
		Status: status,
	})
}
```

---

## 메인 (서버 시작)

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

	"myproject/db/generated"
)

func main() {
	cfg := LoadConfig()

	db, err := NewDB(cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	queries := generated.New(db)
	h := NewHandler(queries)

	mux := http.NewServeMux()

	// 라우트 등록 (Go 1.22+ 패턴)
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("POST /api/v1/users", h.CreateUser)
	mux.HandleFunc("GET /api/v1/users/{id}", h.GetUser)
	mux.HandleFunc("GET /api/v1/users", h.ListUsers)

	// 미들웨어 적용
	handler := LoggingMiddleware(CORSMiddleware(mux, cfg.CORSOrigin))

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

## 미들웨어

```go
// middleware.go
package main

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

## Table-Driven 테스트

```go
// handler_test.go
package main

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

			// 핸들러에 mock queries 주입 필요
			h := NewHandler(nil) // 실제로는 mock 사용
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
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
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
| `cmd/` + `internal/` 구조 | 파일이 10개 이하면 불필요 |
| 인터페이스 먼저 정의 | 구현체가 하나면 인터페이스 불필요 |
| DI 프레임워크 (wire 등) | 수동 조립으로 충분 |
| gRPC | REST로 충분한 규모 |
| 도메인 이벤트 | 직접 함수 호출이 더 명확 |
