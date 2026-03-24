# Go - 중규모 프로젝트 가이드

> 엔드포인트 50~100개, 성장하는 서비스

---

## 핵심 원칙

- **Standard Layout**: `cmd/server/` + `internal/` 구조
- **4-Layer per module**: `api` → `application` → `domain` ← `infrastructure`
- **global 패키지**: 공유 인프라와 도메인 타입은 `internal/global/`에 배치
- **인터페이스는 소비자 측에서 정의**: Go 관용적 패턴 (domain에 interface, infrastructure에 구현체)
- **AppError 타입**: 일관된 에러 처리 + HTTP 상태 코드 매핑
- **chi router**: 미들웨어 체인 + 서브라우터
- **sqlc + goose**: 타입 안전 쿼리 + 마이그레이션
- **google/wire DI**: 의존성 조립 (선택)
- **testcontainers-go**: 실제 DB로 통합 테스트

---

## 디렉토리 구조

```
project/
├── cmd/
│   └── server/
│       └── main.go
│
├── internal/
│   ├── global/
│   │   ├── exception/
│   │   │   └── apperror.go
│   │   ├── config/
│   │   │   └── config.go
│   │   ├── middleware/
│   │   │   ├── logging.go
│   │   │   ├── cors.go
│   │   │   ├── auth.go
│   │   │   └── recovery.go
│   │   ├── httputil/
│   │   │   └── response.go
│   │   ├── database/
│   │   │   └── postgres.go
│   │   └── domain/
│   │       └── base.go              # 공유 도메인 타입
│   │
│   ├── order/
│   │   ├── api/
│   │   │   ├── handler.go
│   │   │   └── dto.go
│   │   ├── application/
│   │   │   └── service.go
│   │   ├── domain/
│   │   │   ├── order.go             # Aggregate
│   │   │   ├── order_item.go
│   │   │   └── repository.go        # interface
│   │   └── infrastructure/
│   │       ├── postgres_repo.go
│   │       └── payment_client.go
│   │
│   ├── user/
│   │   ├── api/
│   │   │   ├── handler.go
│   │   │   ├── create_request.go    # DTO 적으면 flat
│   │   │   └── response.go
│   │   ├── application/
│   │   │   └── service.go
│   │   ├── domain/
│   │   │   ├── user.go
│   │   │   └── repository.go
│   │   └── infrastructure/
│   │       └── postgres_repo.go
│   │
│   └── notification/               # 단순 CRUD → flat
│       ├── handler.go
│       ├── service.go
│       ├── model.go
│       └── dto.go
│
├── db/
│   ├── sqlc.yaml
│   └── queries/
│
├── migrations/
├── Makefile
└── go.mod
```

### 구조 규칙

| 규칙 | 설명 |
|------|------|
| 4개 레이어 | `api` / `application` / `domain` / `infrastructure` |
| 4+ 파일 → 서브폴더 | 레이어 안에 파일이 4개 이상이면 하위 폴더로 분리 |
| 3개 이하 → flat | 파일이 적으면 폴더 없이 평탄하게 배치 |
| 단순 CRUD → flat | 복잡한 비즈니스 로직 없는 도메인은 레이어 분리 없이 flat |
| 공유 타입 → `global/domain/` | 여러 모듈이 참조하는 도메인 객체는 `internal/global/domain/`에 배치 |

---

## 의존성 방향

```
api → application → domain ← infrastructure
```

- **api**: HTTP 요청/응답 처리. `application`을 호출한다.
- **application**: 유스케이스 오케스트레이션. `domain` 인터페이스에만 의존한다.
- **domain**: 비즈니스 규칙 + Repository 인터페이스 정의. 외부 의존성 없음.
- **infrastructure**: `domain` 인터페이스의 구현체. DB, 외부 API 등.

| 레이어 | 허용 import | 금지 import |
|--------|------------|------------|
| domain | 표준 라이브러리, `global/domain` | chi, sqlc, 외부 패키지 |
| application | domain | chi, sqlc, DB 드라이버 |
| infrastructure | domain, 외부 패키지 | api, application |
| api | application, `global/httputil` | domain 직접 HTTP 응답 |

---

## 공유 도메인 타입

```go
// internal/global/domain/base.go
package domain

import "time"

// BaseEntity는 모든 엔티티의 공통 필드를 정의한다.
type BaseEntity struct {
	ID        string
	CreatedAt time.Time
	UpdatedAt time.Time
}

// PageRequest는 페이징 요청 파라미터다.
type PageRequest struct {
	Limit  int32
	Offset int32
}

// PageResponse는 페이징 응답 메타데이터다.
type PageResponse struct {
	Total  int64 `json:"total"`
	Limit  int32 `json:"limit"`
	Offset int32 `json:"offset"`
}
```

---

## AppError 타입

```go
// internal/global/exception/apperror.go
package exception

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
// internal/global/httputil/response.go
package httputil

import (
	"encoding/json"
	"errors"
	"net/http"

	"myproject/internal/global/exception"
)

func WriteJSON(w http.ResponseWriter, status int, data any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func HandleError(w http.ResponseWriter, err error) {
	var appErr *exception.AppError
	if errors.As(err, &appErr) {
		WriteJSON(w, appErr.HTTPStatus(), map[string]any{
			"type":   "https://api.example.com/errors/" + string(appErr.Code),
			"title":  appErr.Message,
			"status": appErr.HTTPStatus(),
			"code":   appErr.Code,
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

## Domain 레이어

### Aggregate

```go
// internal/order/domain/order.go
package domain

import (
	"time"

	baseDomain "myproject/internal/global/domain"
)

type OrderStatus string

const (
	StatusPending   OrderStatus = "PENDING"
	StatusConfirmed OrderStatus = "CONFIRMED"
	StatusShipped   OrderStatus = "SHIPPED"
	StatusCancelled OrderStatus = "CANCELLED"
)

var validTransitions = map[OrderStatus][]OrderStatus{
	StatusPending:   {StatusConfirmed, StatusCancelled},
	StatusConfirmed: {StatusShipped, StatusCancelled},
	StatusShipped:   {},
}

func (s OrderStatus) CanTransitionTo(target OrderStatus) bool {
	for _, valid := range validTransitions[s] {
		if valid == target {
			return true
		}
	}
	return false
}

type Order struct {
	baseDomain.BaseEntity
	CustomerID string
	Items      []OrderItem
	Status     OrderStatus
	TotalPrice int64
}

func NewOrder(id, customerID string) *Order {
	return &Order{
		BaseEntity: baseDomain.BaseEntity{
			ID:        id,
			CreatedAt: time.Now(),
			UpdatedAt: time.Now(),
		},
		CustomerID: customerID,
		Status:     StatusPending,
	}
}

func (o *Order) AddItem(item OrderItem) error {
	if o.Status != StatusPending {
		return ErrOrderNotModifiable
	}
	o.Items = append(o.Items, item)
	o.recalcTotal()
	return nil
}

func (o *Order) Confirm() error {
	if !o.Status.CanTransitionTo(StatusConfirmed) {
		return ErrInvalidTransition
	}
	if len(o.Items) == 0 {
		return ErrEmptyOrder
	}
	o.Status = StatusConfirmed
	o.UpdatedAt = time.Now()
	return nil
}

func (o *Order) Cancel() error {
	if !o.Status.CanTransitionTo(StatusCancelled) {
		return ErrInvalidTransition
	}
	o.Status = StatusCancelled
	o.UpdatedAt = time.Now()
	return nil
}

func (o *Order) recalcTotal() {
	var total int64
	for _, item := range o.Items {
		total += item.Subtotal()
	}
	o.TotalPrice = total
}

// 도메인 에러
var (
	ErrOrderNotFound     = fmt.Errorf("주문을 찾을 수 없습니다")
	ErrOrderNotModifiable = fmt.Errorf("수정할 수 없는 주문 상태입니다")
	ErrInvalidTransition  = fmt.Errorf("유효하지 않은 상태 전환입니다")
	ErrEmptyOrder         = fmt.Errorf("상품이 없는 주문은 확정할 수 없습니다")
)
```

### Entity

```go
// internal/order/domain/order_item.go
package domain

type OrderItem struct {
	ProductID   string
	ProductName string
	UnitPrice   int64
	Quantity    int
}

func NewOrderItem(productID, name string, price int64, qty int) OrderItem {
	return OrderItem{
		ProductID:   productID,
		ProductName: name,
		UnitPrice:   price,
		Quantity:    qty,
	}
}

func (i OrderItem) Subtotal() int64 {
	return i.UnitPrice * int64(i.Quantity)
}
```

### Repository 인터페이스

```go
// internal/order/domain/repository.go
package domain

import "context"

// OrderRepository - domain 레이어에서 인터페이스를 정의하고,
// infrastructure 레이어에서 구현한다.
type OrderRepository interface {
	FindByID(ctx context.Context, id string) (*Order, error)
	FindByCustomerID(ctx context.Context, customerID string, limit, offset int32) ([]*Order, error)
	Save(ctx context.Context, order *Order) error
	Delete(ctx context.Context, id string) error
}
```

---

## Infrastructure 레이어

### Repository 구현체

```go
// internal/order/infrastructure/postgres_repo.go
package infrastructure

import (
	"context"
	"database/sql"

	"myproject/db/generated"
	"myproject/internal/order/domain"
)

type PostgresOrderRepository struct {
	queries *generated.Queries
}

func NewPostgresOrderRepository(db *sql.DB) *PostgresOrderRepository {
	return &PostgresOrderRepository{queries: generated.New(db)}
}

func (r *PostgresOrderRepository) FindByID(ctx context.Context, id string) (*domain.Order, error) {
	row, err := r.queries.GetOrder(ctx, id)
	if err != nil {
		if err == sql.ErrNoRows {
			return nil, domain.ErrOrderNotFound
		}
		return nil, err
	}

	items, err := r.queries.GetOrderItems(ctx, id)
	if err != nil {
		return nil, err
	}

	return r.toDomain(row, items), nil
}

func (r *PostgresOrderRepository) FindByCustomerID(ctx context.Context, customerID string, limit, offset int32) ([]*domain.Order, error) {
	rows, err := r.queries.ListOrdersByCustomer(ctx, generated.ListOrdersByCustomerParams{
		CustomerID: customerID,
		Limit:      limit,
		Offset:     offset,
	})
	if err != nil {
		return nil, err
	}

	orders := make([]*domain.Order, 0, len(rows))
	for _, row := range rows {
		items, err := r.queries.GetOrderItems(ctx, row.ID)
		if err != nil {
			return nil, err
		}
		orders = append(orders, r.toDomain(row, items))
	}
	return orders, nil
}

func (r *PostgresOrderRepository) Save(ctx context.Context, order *domain.Order) error {
	err := r.queries.UpsertOrder(ctx, generated.UpsertOrderParams{
		ID:         order.ID,
		CustomerID: order.CustomerID,
		Status:     string(order.Status),
		TotalPrice: order.TotalPrice,
	})
	if err != nil {
		return err
	}

	// 아이템 저장 (삭제 후 재삽입)
	_ = r.queries.DeleteOrderItems(ctx, order.ID)
	for _, item := range order.Items {
		err := r.queries.InsertOrderItem(ctx, generated.InsertOrderItemParams{
			OrderID:     order.ID,
			ProductID:   item.ProductID,
			ProductName: item.ProductName,
			UnitPrice:   item.UnitPrice,
			Quantity:    int32(item.Quantity),
		})
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *PostgresOrderRepository) Delete(ctx context.Context, id string) error {
	return r.queries.DeleteOrder(ctx, id)
}

func (r *PostgresOrderRepository) toDomain(row generated.Order, items []generated.OrderItem) *domain.Order {
	domainItems := make([]domain.OrderItem, len(items))
	for i, item := range items {
		domainItems[i] = domain.OrderItem{
			ProductID:   item.ProductID,
			ProductName: item.ProductName,
			UnitPrice:   item.UnitPrice,
			Quantity:    int(item.Quantity),
		}
	}
	return &domain.Order{
		BaseEntity: baseDomain.BaseEntity{
			ID:        row.ID,
			CreatedAt: row.CreatedAt,
			UpdatedAt: row.UpdatedAt,
		},
		CustomerID: row.CustomerID,
		Items:      domainItems,
		Status:     domain.OrderStatus(row.Status),
		TotalPrice: row.TotalPrice,
	}
}
```

### 외부 API 클라이언트

```go
// internal/order/infrastructure/payment_client.go
package infrastructure

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
)

// PaymentClient는 결제 외부 서비스와 통신한다.
// application 레이어에서 인터페이스를 정의하고 여기서 구현한다.
type PaymentClient struct {
	baseURL    string
	httpClient *http.Client
}

func NewPaymentClient(baseURL string) *PaymentClient {
	return &PaymentClient{
		baseURL:    baseURL,
		httpClient: &http.Client{},
	}
}

func (c *PaymentClient) Charge(ctx context.Context, orderID string, amount int64) error {
	body, _ := json.Marshal(map[string]any{
		"order_id": orderID,
		"amount":   amount,
	})

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/charge", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("결제 요청 생성 실패: %w", err)
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := c.httpClient.Do(req)
	if err != nil {
		return fmt.Errorf("결제 요청 실패: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("결제 실패: status %d", resp.StatusCode)
	}
	return nil
}
```

---

## Application 레이어

```go
// internal/order/application/service.go
package application

import (
	"context"

	"github.com/google/uuid"
	"myproject/internal/global/exception"
	"myproject/internal/order/domain"
)

// PaymentGateway - application이 필요로 하는 인터페이스를 여기서 정의한다.
// infrastructure의 PaymentClient가 이를 구현한다.
type PaymentGateway interface {
	Charge(ctx context.Context, orderID string, amount int64) error
}

type OrderService struct {
	repo    domain.OrderRepository
	payment PaymentGateway
}

func NewOrderService(repo domain.OrderRepository, payment PaymentGateway) *OrderService {
	return &OrderService{repo: repo, payment: payment}
}

type CreateOrderInput struct {
	CustomerID string
	Items      []CreateOrderItemInput
}

type CreateOrderItemInput struct {
	ProductID string
	Name      string
	Price     int64
	Quantity  int
}

func (s *OrderService) CreateOrder(ctx context.Context, input CreateOrderInput) (string, error) {
	if len(input.Items) == 0 {
		return "", exception.Validation("주문 항목이 비어있습니다")
	}

	order := domain.NewOrder(uuid.NewString(), input.CustomerID)

	for _, item := range input.Items {
		if err := order.AddItem(domain.NewOrderItem(
			item.ProductID, item.Name, item.Price, item.Quantity,
		)); err != nil {
			return "", exception.Validation(err.Error())
		}
	}

	if err := order.Confirm(); err != nil {
		return "", exception.Validation(err.Error())
	}

	// 결제 처리
	if err := s.payment.Charge(ctx, order.ID, order.TotalPrice); err != nil {
		return "", exception.Internal(err)
	}

	if err := s.repo.Save(ctx, order); err != nil {
		return "", exception.Internal(err)
	}

	return order.ID, nil
}

func (s *OrderService) GetOrder(ctx context.Context, id string) (*domain.Order, error) {
	order, err := s.repo.FindByID(ctx, id)
	if err != nil {
		return nil, exception.NotFound("주문", id)
	}
	return order, nil
}

func (s *OrderService) CancelOrder(ctx context.Context, id string) error {
	order, err := s.repo.FindByID(ctx, id)
	if err != nil {
		return exception.NotFound("주문", id)
	}

	if err := order.Cancel(); err != nil {
		return exception.Validation(err.Error())
	}

	if err := s.repo.Save(ctx, order); err != nil {
		return exception.Internal(err)
	}

	return nil
}
```

---

## API 레이어

### DTO

```go
// internal/order/api/dto.go
package api

import "time"

type CreateOrderRequest struct {
	CustomerID string                   `json:"customer_id"`
	Items      []CreateOrderItemRequest `json:"items"`
}

type CreateOrderItemRequest struct {
	ProductID string `json:"product_id"`
	Name      string `json:"name"`
	Price     int64  `json:"price"`
	Quantity  int    `json:"quantity"`
}

type OrderResponse struct {
	ID         string              `json:"id"`
	CustomerID string              `json:"customer_id"`
	Status     string              `json:"status"`
	Items      []OrderItemResponse `json:"items"`
	TotalPrice int64               `json:"total_price"`
	CreatedAt  time.Time           `json:"created_at"`
}

type OrderItemResponse struct {
	ProductID   string `json:"product_id"`
	ProductName string `json:"product_name"`
	UnitPrice   int64  `json:"unit_price"`
	Quantity    int    `json:"quantity"`
	Subtotal    int64  `json:"subtotal"`
}
```

### Handler

```go
// internal/order/api/handler.go
package api

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"myproject/internal/global/httputil"
	"myproject/internal/order/application"
	"myproject/internal/order/domain"
)

type Handler struct {
	service *application.OrderService
}

func NewHandler(service *application.OrderService) *Handler {
	return &Handler{service: service}
}

func (h *Handler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Post("/", h.createOrder)
	r.Get("/{id}", h.getOrder)
	r.Post("/{id}/cancel", h.cancelOrder)
	return r
}

func (h *Handler) createOrder(w http.ResponseWriter, r *http.Request) {
	var req CreateOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteJSON(w, http.StatusBadRequest, map[string]string{"error": "잘못된 요청"})
		return
	}

	// DTO → Application Input 변환
	input := application.CreateOrderInput{
		CustomerID: req.CustomerID,
		Items:      make([]application.CreateOrderItemInput, len(req.Items)),
	}
	for i, item := range req.Items {
		input.Items[i] = application.CreateOrderItemInput{
			ProductID: item.ProductID,
			Name:      item.Name,
			Price:     item.Price,
			Quantity:  item.Quantity,
		}
	}

	orderID, err := h.service.CreateOrder(r.Context(), input)
	if err != nil {
		httputil.HandleError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusCreated, map[string]string{"id": orderID})
}

func (h *Handler) getOrder(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	order, err := h.service.GetOrder(r.Context(), id)
	if err != nil {
		httputil.HandleError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, toOrderResponse(order))
}

func (h *Handler) cancelOrder(w http.ResponseWriter, r *http.Request) {
	id := chi.URLParam(r, "id")

	if err := h.service.CancelOrder(r.Context(), id); err != nil {
		httputil.HandleError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}

// Domain → Response DTO 변환
func toOrderResponse(order *domain.Order) OrderResponse {
	items := make([]OrderItemResponse, len(order.Items))
	for i, item := range order.Items {
		items[i] = OrderItemResponse{
			ProductID:   item.ProductID,
			ProductName: item.ProductName,
			UnitPrice:   item.UnitPrice,
			Quantity:    item.Quantity,
			Subtotal:    item.Subtotal(),
		}
	}
	return OrderResponse{
		ID:         order.ID,
		CustomerID: order.CustomerID,
		Status:     string(order.Status),
		Items:      items,
		TotalPrice: order.TotalPrice,
		CreatedAt:  order.CreatedAt,
	}
}
```

---

## chi 라우터 설정 + DI 조립 (수동)

```go
// cmd/server/main.go
package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	chiMiddleware "github.com/go-chi/chi/v5/middleware"

	"myproject/internal/global/config"
	"myproject/internal/global/database"
	"myproject/internal/global/middleware"
	orderAPI "myproject/internal/order/api"
	orderApp "myproject/internal/order/application"
	orderInfra "myproject/internal/order/infrastructure"
	userAPI "myproject/internal/user/api"
	userApp "myproject/internal/user/application"
	userInfra "myproject/internal/user/infrastructure"
)

func main() {
	cfg := config.Load()

	db, err := database.NewPostgres(cfg.DatabaseURL)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	// === 의존성 조립 (수동 DI) ===

	// Order 모듈
	orderRepo := orderInfra.NewPostgresOrderRepository(db)
	paymentClient := orderInfra.NewPaymentClient(cfg.PaymentURL)
	orderService := orderApp.NewOrderService(orderRepo, paymentClient)
	orderHandler := orderAPI.NewHandler(orderService)

	// User 모듈
	userRepo := userInfra.NewPostgresUserRepository(db)
	userService := userApp.NewUserService(userRepo)
	userHandler := userAPI.NewHandler(userService)

	// === 라우터 ===
	r := chi.NewRouter()

	// 글로벌 미들웨어
	r.Use(chiMiddleware.RequestID)
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(middleware.CORS(cfg.CORSOrigin))

	// 헬스체크
	r.Get("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})

	// API 라우트
	r.Route("/api/v1", func(r chi.Router) {
		r.Mount("/orders", orderHandler.Routes())
		r.Mount("/users", userHandler.Routes())
	})

	// === 서버 시작 ===
	server := &http.Server{
		Addr:         fmt.Sprintf(":%d", cfg.Port),
		Handler:      r,
		ReadTimeout:  5 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	go func() {
		log.Printf("서버 시작: :%d", cfg.Port)
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

## google/wire DI (선택)

```go
// cmd/server/wire.go
//go:build wireinject

package main

import (
	"database/sql"

	"github.com/google/wire"
	orderAPI "myproject/internal/order/api"
	orderApp "myproject/internal/order/application"
	orderDomain "myproject/internal/order/domain"
	orderInfra "myproject/internal/order/infrastructure"
)

func InitializeOrderHandler(db *sql.DB, paymentURL string) *orderAPI.Handler {
	wire.Build(
		orderInfra.NewPostgresOrderRepository,
		wire.Bind(new(orderDomain.OrderRepository), new(*orderInfra.PostgresOrderRepository)),
		orderInfra.NewPaymentClient,
		wire.Bind(new(orderApp.PaymentGateway), new(*orderInfra.PaymentClient)),
		orderApp.NewOrderService,
		orderAPI.NewHandler,
	)
	return nil
}
```

---

## testcontainers-go 통합 테스트

```go
// internal/order/infrastructure/postgres_repo_test.go
package infrastructure_test

import (
	"context"
	"database/sql"
	"testing"
	"time"

	_ "github.com/lib/pq"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/wait"

	"myproject/internal/order/domain"
	"myproject/internal/order/infrastructure"
)

func setupTestDB(t *testing.T) *sql.DB {
	t.Helper()
	ctx := context.Background()

	container, err := postgres.Run(ctx, "postgres:16-alpine",
		postgres.WithDatabase("testdb"),
		postgres.WithUsername("test"),
		postgres.WithPassword("test"),
		testcontainers.WithWaitStrategy(
			wait.ForLog("database system is ready to accept connections").
				WithOccurrence(2).
				WithStartupTimeout(5*time.Second),
		),
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
	t.Cleanup(func() { db.Close() })

	// 스키마 적용
	_, err = db.ExecContext(ctx, `
		CREATE TABLE orders (
			id          TEXT PRIMARY KEY,
			customer_id TEXT NOT NULL,
			status      TEXT NOT NULL DEFAULT 'PENDING',
			total_price BIGINT NOT NULL DEFAULT 0,
			created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
			updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
		);
		CREATE TABLE order_items (
			id           SERIAL PRIMARY KEY,
			order_id     TEXT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
			product_id   TEXT NOT NULL,
			product_name TEXT NOT NULL,
			unit_price   BIGINT NOT NULL,
			quantity     INT NOT NULL
		);
	`)
	if err != nil {
		t.Fatal(err)
	}

	return db
}

func TestPostgresOrderRepository_SaveAndFind(t *testing.T) {
	db := setupTestDB(t)
	repo := infrastructure.NewPostgresOrderRepository(db)
	ctx := context.Background()

	// 주문 생성
	order := domain.NewOrder("order-1", "customer-1")
	order.AddItem(domain.NewOrderItem("prod-1", "상품A", 10000, 2))
	order.AddItem(domain.NewOrderItem("prod-2", "상품B", 5000, 1))
	order.Confirm()

	// 저장
	if err := repo.Save(ctx, order); err != nil {
		t.Fatalf("주문 저장 실패: %v", err)
	}

	// 조회
	found, err := repo.FindByID(ctx, "order-1")
	if err != nil {
		t.Fatalf("주문 조회 실패: %v", err)
	}

	if found.CustomerID != "customer-1" {
		t.Errorf("고객ID 불일치: got %s, want customer-1", found.CustomerID)
	}
	if len(found.Items) != 2 {
		t.Errorf("아이템 수 불일치: got %d, want 2", len(found.Items))
	}
	if found.TotalPrice != 25000 {
		t.Errorf("총액 불일치: got %d, want 25000", found.TotalPrice)
	}
	if found.Status != domain.StatusConfirmed {
		t.Errorf("상태 불일치: got %s, want CONFIRMED", found.Status)
	}
}

func TestPostgresOrderRepository_FindNotFound(t *testing.T) {
	db := setupTestDB(t)
	repo := infrastructure.NewPostgresOrderRepository(db)

	_, err := repo.FindByID(context.Background(), "nonexistent")
	if err == nil {
		t.Error("존재하지 않는 주문 조회 시 에러가 발생해야 함")
	}
}
```

---

## Makefile

```makefile
.PHONY: run build test test-integration lint sqlc migrate-up migrate-down wire

# 빌드 & 실행
run:
	go run ./cmd/server

build:
	go build -o bin/server ./cmd/server

# 테스트
test:
	go test ./... -v -race -short

test-integration:
	go test ./... -v -race -run Integration

# 코드 생성
sqlc:
	sqlc generate

wire:
	cd cmd/server && wire

# 마이그레이션
migrate-up:
	goose -dir migrations postgres "$(DATABASE_URL)" up

migrate-down:
	goose -dir migrations postgres "$(DATABASE_URL)" down

migrate-create:
	goose -dir migrations create $(NAME) sql

# 린트
lint:
	golangci-lint run ./...
```

---

## 중규모에서 지켜야 할 규칙

| 규칙 | 설명 |
|------|------|
| 의존성 방향 준수 | `api → application → domain ← infrastructure` |
| 인터페이스는 소비자 측에서 | Repository는 `domain/`에, 외부 서비스 인터페이스는 `application/`에 정의 |
| `internal/` 아래에 패키지 | 외부 노출 방지 |
| `AppError`로 에러 통일 | `errors.As`로 타입 확인, HTTP 상태 코드 자동 매핑 |
| Handler는 얇게 | DTO 파싱 + 변환만, 비즈니스 로직은 application으로 위임 |
| context 전달 | 모든 함수에 `ctx context.Context` 첫 번째 인자 |
| 단순 CRUD는 flat | notification처럼 단순한 도메인은 레이어 분리 없이 flat 유지 |
| table-driven 테스트 | 모든 경우를 테이블로 나열 |

---

## 전환 시그널

다음 신호가 보이면 **대규모 구조**(도메인 이벤트 + gRPC + Kafka)로 전환을 검토한다:

- 모듈 간 직접 호출이 복잡하게 얽히기 시작할 때
- 팀이 15명 이상으로 커져서 모듈 경계 강제가 필요할 때
- 한 모듈의 변경이 다른 모듈에 사이드이펙트를 일으킬 때
