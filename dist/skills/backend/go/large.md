# Go - 대규모 프로젝트 가이드

> 엔드포인트 100개 이상, 복수 도메인이 얽힌 시스템

---

## 핵심 원칙

**중규모와 레이어 구조는 동일하다. 대규모는 Facade + Event + CQRS만 추가된다.**

- **4-Layer per module**: `api` → `application` → `domain` ← `infrastructure` (중규모와 동일)
- **Facade**: 모듈 간 통신의 유일한 진입점
- **Event**: 도메인 이벤트 기반 비동기 통신 (Kafka)
- **CQRS**: Command/Query 분리 (application 레이어 내부 구조화)
- **AppError 타입**: 일관된 에러 처리 + HTTP 상태 코드 매핑
- **chi router**: 미들웨어 체인 + 서브라우터
- **sqlc + goose**: 타입 안전 쿼리 + 마이그레이션

---

## 중규모 대비 추가되는 것

| 추가 요소 | 역할 | 없으면 생기는 문제 |
|-----------|------|-------------------|
| **Facade** | 모듈 외부에 노출하는 공개 API | 모듈 내부 구조에 직접 의존 → 변경 전파 |
| **Event** | 모듈 간 비동기 통신 | 동기 호출 체인 → 장애 전파 |
| **CQRS** | Command/Query 핸들러 분리 | 서비스 클래스 비대화 |

---

## 디렉토리 구조

```
project/
├── cmd/
│   ├── api/
│   │   └── main.go                      # HTTP API 서버
│   └── worker/
│       └── main.go                      # 이벤트 소비자 (optional)
│
├── internal/
│   ├── global/
│   │   ├── exception/
│   │   │   └── apperror.go
│   │   ├── config/
│   │   │   └── config.go
│   │   ├── middleware/
│   │   │   ├── logging.go
│   │   │   └── auth.go
│   │   ├── httputil/
│   │   │   └── response.go
│   │   ├── database/
│   │   │   └── postgres.go
│   │   └── domain/
│   │       ├── event.go                 # DomainEvent interface
│   │       └── event_bus.go             # EventPublisher interface
│   │
│   ├── order/
│   │   ├── facade.go                    # OrderFacade (모듈 공개 API)
│   │   ├── events.go                    # OrderCreatedEvent 등 (public)
│   │   │
│   │   ├── api/
│   │   │   ├── handler.go
│   │   │   └── dto.go
│   │   │
│   │   ├── application/
│   │   │   ├── command/
│   │   │   │   ├── create_order.go
│   │   │   │   └── cancel_order.go
│   │   │   ├── query/
│   │   │   │   └── get_order.go
│   │   │   └── event/
│   │   │       └── payment_completed_handler.go
│   │   │
│   │   ├── domain/
│   │   │   ├── model/
│   │   │   │   ├── order.go
│   │   │   │   ├── order_item.go
│   │   │   │   └── order_status.go
│   │   │   ├── vo/
│   │   │   │   └── money.go
│   │   │   ├── repository.go
│   │   │   └── domain_service.go
│   │   │
│   │   └── infrastructure/
│   │       ├── persistence/
│   │       │   └── postgres_repo.go
│   │       ├── client/
│   │       │   └── payment_client.go
│   │       └── messaging/
│   │           └── kafka_producer.go
│   │
│   ├── inventory/
│   │   ├── facade.go
│   │   ├── events.go
│   │   ├── api/ application/ domain/ infrastructure/
│   │
│   └── payment/
│       ├── facade.go
│       ├── events.go
│       └── ...
│
├── db/
│   ├── sqlc.yaml
│   └── queries/
│
├── migrations/
├── Makefile
└── go.mod
```

### 중규모와 달라진 점

| 변경 | 설명 |
|------|------|
| `facade.go` | 모듈 루트에 Facade 추가 — 외부 모듈이 호출하는 유일한 진입점 |
| `events.go` | 모듈 루트에 공개 이벤트 정의 — 다른 모듈이 구독 가능 |
| `application/command/` | Command 핸들러 분리 (CQRS) |
| `application/query/` | Query 핸들러 분리 (CQRS) |
| `application/event/` | 외부 모듈 이벤트 핸들러 |
| `cmd/worker/` | 이벤트 소비자 프로세스 (optional) |
| `global/domain/event.go` | DomainEvent 인터페이스 + EventPublisher |

---

## 글로벌 도메인 이벤트 인프라

### DomainEvent 인터페이스

```go
// internal/global/domain/event.go
package domain

import "time"

// DomainEvent — 모든 도메인 이벤트가 구현하는 인터페이스
type DomainEvent interface {
	EventName() string
	OccurredAt() time.Time
	AggregateID() string
}
```

### EventPublisher 인터페이스

```go
// internal/global/domain/event_bus.go
package domain

import "context"

// EventPublisher — 이벤트 발행 추상화
type EventPublisher interface {
	Publish(ctx context.Context, event DomainEvent) error
}

// EventSubscriber — 이벤트 구독 추상화
type EventSubscriber interface {
	Subscribe(ctx context.Context, eventName string, handler func(ctx context.Context, payload []byte) error) error
}
```

---

## Facade — 모듈 간 통신의 유일한 진입점

```go
// internal/order/facade.go
package order

import (
	"context"

	"myproject/internal/order/application/command"
	"myproject/internal/order/application/query"
)

// OrderFacade — 다른 모듈이 order에 접근하는 유일한 경로
// 내부 구조(command, query, domain)를 외부에 노출하지 않는다.
type OrderFacade struct {
	createHandler *command.CreateOrderHandler
	cancelHandler *command.CancelOrderHandler
	getHandler    *query.GetOrderHandler
}

func NewOrderFacade(
	createHandler *command.CreateOrderHandler,
	cancelHandler *command.CancelOrderHandler,
	getHandler *query.GetOrderHandler,
) *OrderFacade {
	return &OrderFacade{
		createHandler: createHandler,
		cancelHandler: cancelHandler,
		getHandler:    getHandler,
	}
}

// CreateOrder — 외부 모듈용 주문 생성
func (f *OrderFacade) CreateOrder(ctx context.Context, customerID string, items []OrderItemInput) (string, error) {
	return f.createHandler.Handle(ctx, command.CreateOrderCommand{
		CustomerID: customerID,
		Items:      toCommandItems(items),
	})
}

// GetOrderStatus — 외부 모듈용 주문 상태 조회
func (f *OrderFacade) GetOrderStatus(ctx context.Context, orderID string) (string, error) {
	result, err := f.getHandler.Handle(ctx, query.GetOrderQuery{OrderID: orderID})
	if err != nil {
		return "", err
	}
	return result.Status, nil
}

// OrderItemInput — Facade가 외부에 노출하는 입력 타입
type OrderItemInput struct {
	ProductID string
	Name      string
	Price     int64
	Quantity  int
}

func toCommandItems(inputs []OrderItemInput) []command.OrderItemCommand {
	items := make([]command.OrderItemCommand, len(inputs))
	for i, in := range inputs {
		items[i] = command.OrderItemCommand{
			ProductID: in.ProductID,
			Name:      in.Name,
			Price:     in.Price,
			Quantity:  in.Quantity,
		}
	}
	return items
}
```

### Facade 규칙

| 규칙 | 설명 |
|------|------|
| 위치 | 모듈 루트 (`internal/order/facade.go`) |
| 노출 | 외부 모듈이 필요로 하는 메서드만 공개 |
| 타입 | Facade 전용 입출력 타입 사용 (내부 Command/Query 타입 노출 금지) |
| 내부 위임 | Command/Query 핸들러에 위임만 함 — 비즈니스 로직 없음 |

---

## Event — 모듈 간 비동기 통신

### 모듈 공개 이벤트 정의

```go
// internal/order/events.go
package order

import (
	"time"

	"myproject/internal/global/domain"
)

// OrderCreatedEvent — 다른 모듈이 구독 가능한 공개 이벤트
type OrderCreatedEvent struct {
	OrderID    string
	CustomerID string
	TotalAmount int64
	OccurredAt_ time.Time
}

func (e *OrderCreatedEvent) EventName() string     { return "order.created" }
func (e *OrderCreatedEvent) OccurredAt() time.Time  { return e.OccurredAt_ }
func (e *OrderCreatedEvent) AggregateID() string    { return e.OrderID }

// 컴파일 타임 인터페이스 체크
var _ domain.DomainEvent = (*OrderCreatedEvent)(nil)

type OrderCancelledEvent struct {
	OrderID     string
	Reason      string
	OccurredAt_ time.Time
}

func (e *OrderCancelledEvent) EventName() string     { return "order.cancelled" }
func (e *OrderCancelledEvent) OccurredAt() time.Time  { return e.OccurredAt_ }
func (e *OrderCancelledEvent) AggregateID() string    { return e.OrderID }

var _ domain.DomainEvent = (*OrderCancelledEvent)(nil)
```

### Kafka Publisher 구현

```go
// internal/order/infrastructure/messaging/kafka_producer.go
package messaging

import (
	"context"
	"encoding/json"

	"github.com/segmentio/kafka-go"
	"myproject/internal/global/domain"
)

type KafkaPublisher struct {
	writer *kafka.Writer
}

func NewKafkaPublisher(brokers []string, topic string) *KafkaPublisher {
	return &KafkaPublisher{
		writer: &kafka.Writer{
			Addr:     kafka.TCP(brokers...),
			Topic:    topic,
			Balancer: &kafka.LeastBytes{},
		},
	}
}

func (p *KafkaPublisher) Publish(ctx context.Context, event domain.DomainEvent) error {
	payload, err := json.Marshal(event)
	if err != nil {
		return err
	}

	return p.writer.WriteMessages(ctx, kafka.Message{
		Key:   []byte(event.AggregateID()),
		Value: payload,
		Headers: []kafka.Header{
			{Key: "event_name", Value: []byte(event.EventName())},
		},
	})
}
```

### 이벤트 핸들러 (다른 모듈의 이벤트를 구독)

```go
// internal/order/application/event/payment_completed_handler.go
package event

import (
	"context"
	"encoding/json"

	"myproject/internal/order/domain/model"
	"myproject/internal/payment"
)

type PaymentCompletedHandler struct {
	repo model.OrderRepository
}

func NewPaymentCompletedHandler(repo model.OrderRepository) *PaymentCompletedHandler {
	return &PaymentCompletedHandler{repo: repo}
}

// Handle — payment 모듈의 PaymentCompletedEvent를 처리
func (h *PaymentCompletedHandler) Handle(ctx context.Context, payload []byte) error {
	var event payment.PaymentCompletedEvent
	if err := json.Unmarshal(payload, &event); err != nil {
		return err
	}

	order, err := h.repo.FindByID(ctx, event.OrderID)
	if err != nil {
		return err
	}

	if err := order.Confirm(); err != nil {
		return err
	}

	return h.repo.Save(ctx, order)
}
```

---

## CQRS — Command/Query 분리

### Command Handler

```go
// internal/order/application/command/create_order.go
package command

import (
	"context"
	"time"

	"myproject/internal/global/domain"
	"myproject/internal/order"
	orderModel "myproject/internal/order/domain/model"
	"myproject/internal/order/domain/vo"

	"github.com/google/uuid"
)

type CreateOrderCommand struct {
	CustomerID string
	Items      []OrderItemCommand
}

type OrderItemCommand struct {
	ProductID string
	Name      string
	Price     int64
	Quantity  int
}

type CreateOrderHandler struct {
	repo      orderModel.OrderRepository
	publisher domain.EventPublisher
}

func NewCreateOrderHandler(repo orderModel.OrderRepository, pub domain.EventPublisher) *CreateOrderHandler {
	return &CreateOrderHandler{repo: repo, publisher: pub}
}

func (h *CreateOrderHandler) Handle(ctx context.Context, cmd CreateOrderCommand) (string, error) {
	o := orderModel.NewOrder(uuid.NewString(), cmd.CustomerID)

	for _, item := range cmd.Items {
		price, err := vo.NewMoney(item.Price, "KRW")
		if err != nil {
			return "", err
		}
		if err := o.AddItem(item.ProductID, item.Name, price, item.Quantity); err != nil {
			return "", err
		}
	}

	if err := h.repo.Save(ctx, o); err != nil {
		return "", err
	}

	// 이벤트 발행
	h.publisher.Publish(ctx, &order.OrderCreatedEvent{
		OrderID:     o.ID,
		CustomerID:  o.CustomerID,
		TotalAmount: o.Total().Amount,
		OccurredAt_: time.Now(),
	})

	return o.ID, nil
}
```

```go
// internal/order/application/command/cancel_order.go
package command

import (
	"context"
	"time"

	"myproject/internal/global/domain"
	"myproject/internal/order"
	orderModel "myproject/internal/order/domain/model"
)

type CancelOrderCommand struct {
	OrderID string
	Reason  string
}

type CancelOrderHandler struct {
	repo      orderModel.OrderRepository
	publisher domain.EventPublisher
}

func NewCancelOrderHandler(repo orderModel.OrderRepository, pub domain.EventPublisher) *CancelOrderHandler {
	return &CancelOrderHandler{repo: repo, publisher: pub}
}

func (h *CancelOrderHandler) Handle(ctx context.Context, cmd CancelOrderCommand) error {
	o, err := h.repo.FindByID(ctx, cmd.OrderID)
	if err != nil {
		return err
	}

	if err := o.Cancel(cmd.Reason); err != nil {
		return err
	}

	if err := h.repo.Save(ctx, o); err != nil {
		return err
	}

	h.publisher.Publish(ctx, &order.OrderCancelledEvent{
		OrderID:     cmd.OrderID,
		Reason:      cmd.Reason,
		OccurredAt_: time.Now(),
	})

	return nil
}
```

### Query Handler

```go
// internal/order/application/query/get_order.go
package query

import (
	"context"

	orderModel "myproject/internal/order/domain/model"
)

type GetOrderQuery struct {
	OrderID string
}

type GetOrderResult struct {
	ID         string
	CustomerID string
	Status     string
	TotalAmount int64
}

type GetOrderHandler struct {
	repo orderModel.OrderRepository
}

func NewGetOrderHandler(repo orderModel.OrderRepository) *GetOrderHandler {
	return &GetOrderHandler{repo: repo}
}

func (h *GetOrderHandler) Handle(ctx context.Context, q GetOrderQuery) (*GetOrderResult, error) {
	o, err := h.repo.FindByID(ctx, q.OrderID)
	if err != nil {
		return nil, err
	}

	return &GetOrderResult{
		ID:          o.ID,
		CustomerID:  o.CustomerID,
		Status:      string(o.Status),
		TotalAmount: o.Total().Amount,
	}, nil
}
```

---

## Domain 레이어

### Aggregate Root

```go
// internal/order/domain/model/order.go
package model

import (
	"errors"
	"time"

	"myproject/internal/order/domain/vo"
)

type Order struct {
	ID         string
	CustomerID string
	Items      []OrderItem
	Status     OrderStatus
	CreatedAt  time.Time
}

func NewOrder(id, customerID string) *Order {
	return &Order{
		ID:         id,
		CustomerID: customerID,
		Status:     StatusPending,
		CreatedAt:  time.Now(),
	}
}

func (o *Order) AddItem(productID, name string, price vo.Money, qty int) error {
	if o.Status != StatusPending {
		return errors.New("확정된 주문에 상품을 추가할 수 없습니다")
	}
	o.Items = append(o.Items, OrderItem{
		ProductID: productID, ProductName: name, UnitPrice: price, Quantity: qty,
	})
	return nil
}

func (o *Order) Total() vo.Money {
	total := vo.Money{Amount: 0, Currency: "KRW"}
	for _, item := range o.Items {
		subtotal := item.UnitPrice.Multiply(item.Quantity)
		total, _ = total.Add(subtotal)
	}
	return total
}

func (o *Order) Confirm() error {
	if !o.Status.CanTransitionTo(StatusConfirmed) {
		return ErrInvalidTransition(string(o.Status) + " → CONFIRMED 불가")
	}
	if len(o.Items) == 0 {
		return ErrEmptyOrder
	}
	o.Status = StatusConfirmed
	return nil
}

func (o *Order) Cancel(reason string) error {
	if !o.Status.CanTransitionTo(StatusCancelled) {
		return ErrInvalidTransition(string(o.Status) + " → CANCELLED 불가")
	}
	o.Status = StatusCancelled
	return nil
}

// Reconstitute — DB에서 복원 (검증 없이)
func Reconstitute(id, customerID string, items []OrderItem, status OrderStatus, createdAt time.Time) *Order {
	return &Order{
		ID: id, CustomerID: customerID, Items: items, Status: status, CreatedAt: createdAt,
	}
}

// --- 도메인 에러 ---

var (
	ErrOrderNotFound = errors.New("주문을 찾을 수 없습니다")
	ErrEmptyOrder    = errors.New("상품이 없는 주문은 확정할 수 없습니다")
)

type InvalidTransitionError struct {
	Message string
}

func (e InvalidTransitionError) Error() string { return e.Message }

func ErrInvalidTransition(msg string) error {
	return InvalidTransitionError{Message: msg}
}
```

### Entity

```go
// internal/order/domain/model/order_item.go
package model

import "myproject/internal/order/domain/vo"

type OrderItem struct {
	ProductID   string
	ProductName string
	UnitPrice   vo.Money
	Quantity    int
}
```

### Value Object

```go
// internal/order/domain/vo/money.go
package vo

import (
	"errors"
	"fmt"
)

type Money struct {
	Amount   int64
	Currency string
}

func NewMoney(amount int64, currency string) (Money, error) {
	if amount < 0 {
		return Money{}, errors.New("금액은 0 이상이어야 합니다")
	}
	if currency == "" {
		currency = "KRW"
	}
	return Money{Amount: amount, Currency: currency}, nil
}

func (m Money) Add(other Money) (Money, error) {
	if m.Currency != other.Currency {
		return Money{}, fmt.Errorf("통화가 다릅니다: %s vs %s", m.Currency, other.Currency)
	}
	return Money{Amount: m.Amount + other.Amount, Currency: m.Currency}, nil
}

func (m Money) Multiply(qty int) Money {
	return Money{Amount: m.Amount * int64(qty), Currency: m.Currency}
}
```

### 상태 전이

```go
// internal/order/domain/model/order_status.go
package model

type OrderStatus string

const (
	StatusPending   OrderStatus = "PENDING"
	StatusConfirmed OrderStatus = "CONFIRMED"
	StatusShipped   OrderStatus = "SHIPPED"
	StatusDelivered OrderStatus = "DELIVERED"
	StatusCancelled OrderStatus = "CANCELLED"
)

var validTransitions = map[OrderStatus][]OrderStatus{
	StatusPending:   {StatusConfirmed, StatusCancelled},
	StatusConfirmed: {StatusShipped, StatusCancelled},
	StatusShipped:   {StatusDelivered},
}

func (s OrderStatus) CanTransitionTo(target OrderStatus) bool {
	for _, valid := range validTransitions[s] {
		if valid == target {
			return true
		}
	}
	return false
}
```

### Repository 인터페이스

```go
// internal/order/domain/repository.go
package model

import "context"

type OrderRepository interface {
	FindByID(ctx context.Context, id string) (*Order, error)
	FindByCustomer(ctx context.Context, customerID string) ([]*Order, error)
	Save(ctx context.Context, order *Order) error
}
```

### Domain Service (선택)

```go
// internal/order/domain/domain_service.go
package model

import "context"

// OrderValidator — 여러 Aggregate에 걸친 비즈니스 규칙
type OrderValidator struct {
	repo OrderRepository
}

func NewOrderValidator(repo OrderRepository) *OrderValidator {
	return &OrderValidator{repo: repo}
}

// ValidateCustomerOrderLimit — 고객당 동시 주문 제한
func (v *OrderValidator) ValidateCustomerOrderLimit(ctx context.Context, customerID string, limit int) error {
	orders, err := v.repo.FindByCustomer(ctx, customerID)
	if err != nil {
		return err
	}
	active := 0
	for _, o := range orders {
		if o.Status == StatusPending || o.Status == StatusConfirmed {
			active++
		}
	}
	if active >= limit {
		return ErrInvalidTransition("동시 주문 한도 초과")
	}
	return nil
}
```

---

## HTTP API 레이어

```go
// internal/order/api/handler.go
package api

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"myproject/internal/global/httputil"
	"myproject/internal/order/application/command"
	"myproject/internal/order/application/query"
)

type OrderHandler struct {
	createHandler *command.CreateOrderHandler
	cancelHandler *command.CancelOrderHandler
	getHandler    *query.GetOrderHandler
}

func NewOrderHandler(
	createHandler *command.CreateOrderHandler,
	cancelHandler *command.CancelOrderHandler,
	getHandler *query.GetOrderHandler,
) *OrderHandler {
	return &OrderHandler{
		createHandler: createHandler,
		cancelHandler: cancelHandler,
		getHandler:    getHandler,
	}
}

func (h *OrderHandler) Routes() chi.Router {
	r := chi.NewRouter()
	r.Post("/", h.createOrder)
	r.Get("/{id}", h.getOrder)
	r.Post("/{id}/cancel", h.cancelOrder)
	return r
}

func (h *OrderHandler) createOrder(w http.ResponseWriter, r *http.Request) {
	var req CreateOrderRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		httputil.WriteJSON(w, http.StatusBadRequest, map[string]string{"error": "잘못된 요청"})
		return
	}

	orderID, err := h.createHandler.Handle(r.Context(), command.CreateOrderCommand{
		CustomerID: req.CustomerID,
		Items:      toCommandItems(req.Items),
	})
	if err != nil {
		httputil.HandleError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusCreated, map[string]string{"id": orderID})
}

func (h *OrderHandler) getOrder(w http.ResponseWriter, r *http.Request) {
	result, err := h.getHandler.Handle(r.Context(), query.GetOrderQuery{
		OrderID: chi.URLParam(r, "id"),
	})
	if err != nil {
		httputil.HandleError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, result)
}

func (h *OrderHandler) cancelOrder(w http.ResponseWriter, r *http.Request) {
	var req CancelOrderRequest
	json.NewDecoder(r.Body).Decode(&req)

	err := h.cancelHandler.Handle(r.Context(), command.CancelOrderCommand{
		OrderID: chi.URLParam(r, "id"),
		Reason:  req.Reason,
	})
	if err != nil {
		httputil.HandleError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
```

```go
// internal/order/api/dto.go
package api

import "myproject/internal/order/application/command"

type CreateOrderRequest struct {
	CustomerID string             `json:"customer_id"`
	Items      []OrderItemRequest `json:"items"`
}

type OrderItemRequest struct {
	ProductID string `json:"product_id"`
	Name      string `json:"name"`
	Price     int64  `json:"price"`
	Quantity  int    `json:"quantity"`
}

type CancelOrderRequest struct {
	Reason string `json:"reason"`
}

func toCommandItems(items []OrderItemRequest) []command.OrderItemCommand {
	result := make([]command.OrderItemCommand, len(items))
	for i, item := range items {
		result[i] = command.OrderItemCommand{
			ProductID: item.ProductID,
			Name:      item.Name,
			Price:     item.Price,
			Quantity:  item.Quantity,
		}
	}
	return result
}
```

---

## 모듈 간 통신 규칙

### 원칙

```
금지: order/application → inventory/domain      (내부 직접 접근)
금지: order/application → inventory/application  (내부 직접 접근)
허용: order/application → inventory.Facade       (동기 호출)
권장: order → event → inventory                  (비동기 이벤트)
```

### 동기 호출 (Facade 경유)

```go
// internal/order/application/command/create_order.go 에서
// inventory 모듈의 재고를 확인해야 할 때:

type CreateOrderHandler struct {
	repo           orderModel.OrderRepository
	publisher      domain.EventPublisher
	inventoryFacade *inventory.InventoryFacade  // Facade만 의존
}

func (h *CreateOrderHandler) Handle(ctx context.Context, cmd CreateOrderCommand) (string, error) {
	// Facade를 통해 재고 확인
	available, err := h.inventoryFacade.CheckStock(ctx, cmd.Items[0].ProductID, cmd.Items[0].Quantity)
	if err != nil {
		return "", err
	}
	if !available {
		return "", errors.New("재고 부족")
	}
	// ... 주문 생성 로직
}
```

### 비동기 호출 (이벤트 기반 — 권장)

```go
// 1. order 모듈에서 이벤트 발행 (위 CreateOrderHandler 참고)
// h.publisher.Publish(ctx, &order.OrderCreatedEvent{...})

// 2. inventory 모듈에서 이벤트 구독
// internal/inventory/application/event/order_created_handler.go
package event

import (
	"context"
	"encoding/json"

	"myproject/internal/inventory/domain/model"
	"myproject/internal/order"
)

type OrderCreatedHandler struct {
	repo model.InventoryRepository
}

func NewOrderCreatedHandler(repo model.InventoryRepository) *OrderCreatedHandler {
	return &OrderCreatedHandler{repo: repo}
}

func (h *OrderCreatedHandler) Handle(ctx context.Context, payload []byte) error {
	var event order.OrderCreatedEvent
	if err := json.Unmarshal(payload, &event); err != nil {
		return err
	}
	// 재고 차감 로직
	return h.repo.Reserve(ctx, event.OrderID)
}
```

### 통신 방식 선택 기준

| 상황 | 방식 | 이유 |
|------|------|------|
| 결과가 즉시 필요 | Facade (동기) | 재고 확인 후 주문 생성 |
| 결과가 즉시 불필요 | Event (비동기) | 주문 후 알림 발송 |
| 실패해도 원래 작업은 성공 | Event (비동기) | 주문 후 포인트 적립 |
| 실패하면 원래 작업도 실패 | Facade (동기) | 결제 실패 → 주문 실패 |

---

## 의존성 규칙

```
┌────────────────────────────────────┐
│         api (HTTP 핸들러)           │  ← chi, JSON
├────────────────────────────────────┤
│   application (Command/Query)      │  ← domain 인터페이스만 의존
├────────────────────────────────────┤
│   infrastructure (DB, Kafka)       │  ← PostgreSQL, Kafka, Redis
├────────────────────────────────────┤
│     domain (Business Rules)        │  ← 표준 라이브러리만, 외부 import 금지
└────────────────────────────────────┘

+ Facade: 모듈 루트에서 application을 조합
+ Event:  모듈 루트에서 공개 이벤트 정의
```

| 레이어 | 허용 import | 금지 import |
|--------|------------|------------|
| domain | 표준 라이브러리, global/domain | chi, sqlc, kafka |
| application | domain, global/domain, 다른 모듈의 Facade | chi, sqlc, kafka |
| infrastructure | domain, application, 외부 라이브러리 | - |
| api | application, global/httputil | domain 모델 직접 HTTP 응답 |
| facade | application (command, query) | infrastructure |
| events | global/domain | infrastructure |

---

## 도메인 단위 테스트

```go
// internal/order/domain/model/order_test.go
package model

import (
	"testing"
	"time"

	"myproject/internal/order/domain/vo"
)

func TestOrder_AddItem(t *testing.T) {
	order := NewOrder("o1", "c1")
	price, _ := vo.NewMoney(10000, "KRW")

	err := order.AddItem("p1", "상품A", price, 2)
	if err != nil {
		t.Fatalf("상품 추가 실패: %v", err)
	}

	if len(order.Items) != 1 {
		t.Errorf("상품 1개여야 함, got %d", len(order.Items))
	}
}

func TestOrder_Total(t *testing.T) {
	order := NewOrder("o1", "c1")
	price, _ := vo.NewMoney(10000, "KRW")
	order.AddItem("p1", "상품A", price, 2)
	order.AddItem("p2", "상품B", price, 3)

	total := order.Total()
	if total.Amount != 50000 {
		t.Errorf("합계 50000이어야 함, got %d", total.Amount)
	}
}

func TestOrder_Confirm(t *testing.T) {
	order := NewOrder("o1", "c1")
	price, _ := vo.NewMoney(10000, "KRW")
	order.AddItem("p1", "상품A", price, 2)

	if err := order.Confirm(); err != nil {
		t.Fatalf("주문 확정 실패: %v", err)
	}

	if order.Status != StatusConfirmed {
		t.Errorf("상태가 CONFIRMED여야 함, got %s", order.Status)
	}
}

func TestOrder_EmptyCannotConfirm(t *testing.T) {
	order := NewOrder("o1", "c1")
	if err := order.Confirm(); err == nil {
		t.Error("빈 주문 확정 시 에러가 발생해야 함")
	}
}

func TestOrder_DeliveredCannotCancel(t *testing.T) {
	order := Reconstitute("o1", "c1", nil, StatusDelivered, time.Now())
	if err := order.Cancel("변심"); err == nil {
		t.Error("배송 완료 주문 취소 시 에러가 발생해야 함")
	}
}

func TestOrder_ConfirmedCannotAddItem(t *testing.T) {
	order := NewOrder("o1", "c1")
	price, _ := vo.NewMoney(10000, "KRW")
	order.AddItem("p1", "상품A", price, 1)
	order.Confirm()

	err := order.AddItem("p2", "상품B", price, 1)
	if err == nil {
		t.Error("확정된 주문에 상품 추가 시 에러가 발생해야 함")
	}
}

func TestMoney_DifferentCurrencyAdd(t *testing.T) {
	krw, _ := vo.NewMoney(1000, "KRW")
	usd, _ := vo.NewMoney(1, "USD")
	_, err := krw.Add(usd)
	if err == nil {
		t.Error("다른 통화 더하기 시 에러가 발생해야 함")
	}
}
```

---

## 대규모에서 반드시 지켜야 할 것

| 규칙 | 설명 |
|------|------|
| Facade로만 접근 | 다른 모듈 내부에 직접 접근 금지 |
| 이벤트로 느슨한 결합 | 동기 호출 최소화, 이벤트 기반 권장 |
| CQRS로 핸들러 분리 | 서비스 클래스가 비대해지면 Command/Query 분리 |
| Domain 순수성 | 외부 패키지 import 절대 금지 |
| Aggregate 간 ID 참조 | 다른 Aggregate를 직접 포함하지 않음 |
| Reconstitute 패턴 | DB 복원 시 비즈니스 검증 건너뜀 |

---

## 헥사고날은 언제 쓰는가

**기본 구조는 4-Layer다. 헥사고날은 아래 조건을 모두 만족할 때만 고려한다.**

| 조건 | 설명 |
|------|------|
| 인프라 교체가 현실적 | DB를 PostgreSQL → DynamoDB로 바꾸거나, REST → gRPC로 전환하는 계획이 실제로 있다 |
| 포트/어댑터 경계가 명확 | 인바운드(HTTP, gRPC, MQ)와 아웃바운드(DB, 외부 API)가 3개 이상 |
| 팀이 헥사고날 경험 있음 | 포트/어댑터 개념을 팀 전체가 이해하고 있다 |

### 헥사고날 적용 시 변경 사항

```
# 4-Layer (기본)
internal/order/
├── api/              → 그대로
├── application/      → 그대로
├── domain/           → 그대로
└── infrastructure/   → 그대로

# 헥사고날 전환
internal/order/
├── port/
│   ├── in/           → UseCase 인터페이스 (application이 구현)
│   └── out/          → Repository, Client 인터페이스 (infrastructure가 구현)
├── adapter/
│   ├── in/
│   │   ├── http/     → HTTP 핸들러
│   │   └── grpc/     → gRPC 핸들러
│   └── out/
│       ├── persistence/
│       └── messaging/
├── application/      → port/in 구현
└── domain/           → 그대로
```

**핵심: 4-Layer에서 헥사고날로의 전환은 `api` → `adapter/in`, `infrastructure` → `adapter/out`, repository 인터페이스 → `port/out` 으로 이동하는 것이다. domain과 application은 변하지 않는다.**

대부분의 프로젝트에서는 4-Layer + Facade + Event + CQRS로 충분하다. 헥사고날은 인프라 교체가 현실적일 때만 가치가 있다.

---

## gRPC (선택)

서비스 간 내부 통신이 필요한 경우 gRPC를 추가할 수 있다. 필수가 아니다.

```
project/
├── cmd/
│   └── grpc/
│       └── main.go           # gRPC 서버 (선택)
├── proto/
│   └── order/
│       └── order.proto       # proto 정의 (선택)
```

gRPC 추가 시에도 Facade 패턴은 동일하게 적용한다. gRPC 핸들러가 Facade를 호출하는 구조로 만든다.
