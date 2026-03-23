# Go - 대규모 프로젝트 가이드

> 팀 8명 이상, 엔드포인트 100개 이상, 도메인 중심 레이어드 아키텍처

---

## 핵심 원칙

- **4-Layer**: domain / application / infrastructure / interfaces
- **도메인 중심**: 비즈니스 규칙은 domain 패키지에 집중
- **gRPC + HTTP**: gRPC 내부 통신 + HTTP 외부 API
- **Kafka 메시징**: Bounded Context 간 비동기 이벤트
- **엄격한 의존성 규칙**: domain은 외부 패키지 import 금지
- **인터페이스 기반 DI**: 모든 외부 의존성을 인터페이스로 추상화

---

## 디렉토리 구조

```
project/
├── cmd/
│   ├── api/                          # HTTP API 서버
│   │   └── main.go
│   ├── grpc/                         # gRPC 서버
│   │   └── main.go
│   └── worker/                       # 이벤트 소비자
│       └── main.go
│
├── internal/
│   ├── order/                        # Bounded Context: 주문
│   │   ├── domain/
│   │   │   ├── order.go              # Aggregate Root
│   │   │   ├── order_item.go         # Entity
│   │   │   ├── value_objects.go      # Money, Status 등
│   │   │   ├── events.go             # Domain Events
│   │   │   ├── errors.go             # 도메인 에러
│   │   │   └── repository.go         # Repository 인터페이스
│   │   │
│   │   ├── application/
│   │   │   ├── service.go            # Application Service
│   │   │   ├── commands.go           # Command DTO
│   │   │   ├── queries.go            # Query DTO
│   │   │   └── event_handler.go      # 이벤트 핸들러
│   │   │
│   │   ├── infrastructure/
│   │   │   ├── postgres_repo.go      # Repository 구현체
│   │   │   ├── kafka_publisher.go    # 이벤트 발행
│   │   │   └── grpc_client.go        # 다른 서비스 gRPC 호출
│   │   │
│   │   └── interfaces/
│   │       ├── http/
│   │       │   ├── handler.go        # HTTP 핸들러
│   │       │   ├── dto.go            # HTTP 요청/응답 DTO
│   │       │   └── mapper.go         # Domain ↔ DTO 변환
│   │       └── grpc/
│   │           ├── server.go         # gRPC 서버 구현
│   │           └── mapper.go
│   │
│   ├── catalog/                      # Bounded Context: 상품
│   │   ├── domain/
│   │   ├── application/
│   │   ├── infrastructure/
│   │   └── interfaces/
│   │
│   └── shared/                       # 공유 커널
│       ├── domain/
│       │   ├── aggregate.go          # AggregateRoot 기본 타입
│       │   └── event.go             # DomainEvent 인터페이스
│       ├── messaging/
│       │   ├── publisher.go          # EventPublisher 인터페이스
│       │   └── kafka.go             # Kafka 구현체
│       └── middleware/
│           ├── logging.go
│           └── auth.go
│
├── proto/                            # gRPC proto 정의
│   └── order/
│       └── order.proto
│
├── db/
│   ├── sqlc.yaml
│   └── queries/
│
├── migrations/
├── deployments/
│   ├── docker-compose.yml
│   └── k8s/
├── Makefile
└── go.mod
```

---

## 공유 도메인 기본 타입

```go
// internal/shared/domain/aggregate.go
package domain

import "time"

type DomainEvent interface {
	EventName() string
	OccurredAt() time.Time
	AggregateID() string
}

type AggregateRoot struct {
	events []DomainEvent
}

func (a *AggregateRoot) AddEvent(event DomainEvent) {
	a.events = append(a.events, event)
}

func (a *AggregateRoot) CollectEvents() []DomainEvent {
	events := a.events
	a.events = nil
	return events
}
```

```go
// internal/shared/messaging/publisher.go
package messaging

import "context"
import "myproject/internal/shared/domain"

type EventPublisher interface {
	Publish(ctx context.Context, event domain.DomainEvent) error
}
```

---

## Domain 레이어

### Value Objects

```go
// internal/order/domain/value_objects.go
package domain

import (
	"errors"
	"fmt"
)

// --- Money ---

type Money struct {
	Amount   int64  // 원 단위 (소수점 없음)
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

// --- OrderStatus ---

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

### Aggregate Root

```go
// internal/order/domain/order.go
package domain

import (
	"time"

	sharedDomain "myproject/internal/shared/domain"
)

type Order struct {
	sharedDomain.AggregateRoot

	ID         string
	CustomerID string
	Items      []OrderItem
	Status     OrderStatus
	CreatedAt  time.Time
}

type OrderItem struct {
	ProductID   string
	ProductName string
	UnitPrice   Money
	Quantity    int
}

func NewOrder(id, customerID string) *Order {
	return &Order{
		ID:         id,
		CustomerID: customerID,
		Status:     StatusPending,
		CreatedAt:  time.Now(),
	}
}

func (o *Order) AddItem(productID, name string, price Money, qty int) error {
	if o.Status != StatusPending {
		return ErrInvalidTransition("확정된 주문에 상품을 추가할 수 없습니다")
	}
	o.Items = append(o.Items, OrderItem{
		ProductID: productID, ProductName: name, UnitPrice: price, Quantity: qty,
	})
	return nil
}

func (o *Order) Total() Money {
	total := Money{Amount: 0, Currency: "KRW"}
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
	o.AddEvent(&OrderCreatedEvent{
		OrderID:    o.ID,
		CustomerID: o.CustomerID,
		Total:      o.Total(),
		OccurredAt_: time.Now(),
	})
	return nil
}

func (o *Order) Cancel(reason string) error {
	if !o.Status.CanTransitionTo(StatusCancelled) {
		return ErrInvalidTransition(string(o.Status) + " → CANCELLED 불가")
	}
	o.Status = StatusCancelled
	o.AddEvent(&OrderCancelledEvent{
		OrderID:     o.ID,
		Reason:      reason,
		OccurredAt_: time.Now(),
	})
	return nil
}

// Reconstitute - DB에서 복원 (검증 없이)
func ReconstitueOrder(id, customerID string, items []OrderItem, status OrderStatus, createdAt time.Time) *Order {
	return &Order{
		ID: id, CustomerID: customerID, Items: items, Status: status, CreatedAt: createdAt,
	}
}
```

### 도메인 이벤트

```go
// internal/order/domain/events.go
package domain

import "time"

type OrderCreatedEvent struct {
	OrderID     string
	CustomerID  string
	Total       Money
	OccurredAt_ time.Time
}

func (e *OrderCreatedEvent) EventName() string    { return "order.created" }
func (e *OrderCreatedEvent) OccurredAt() time.Time { return e.OccurredAt_ }
func (e *OrderCreatedEvent) AggregateID() string   { return e.OrderID }

type OrderCancelledEvent struct {
	OrderID     string
	Reason      string
	OccurredAt_ time.Time
}

func (e *OrderCancelledEvent) EventName() string    { return "order.cancelled" }
func (e *OrderCancelledEvent) OccurredAt() time.Time { return e.OccurredAt_ }
func (e *OrderCancelledEvent) AggregateID() string   { return e.OrderID }
```

### 도메인 에러

```go
// internal/order/domain/errors.go
package domain

import "errors"

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

### Repository 인터페이스

```go
// internal/order/domain/repository.go
package domain

import "context"

type OrderRepository interface {
	FindByID(ctx context.Context, id string) (*Order, error)
	FindByCustomer(ctx context.Context, customerID string) ([]*Order, error)
	Save(ctx context.Context, order *Order) error
	Delete(ctx context.Context, id string) error
}
```

---

## Application 레이어

```go
// internal/order/application/service.go
package application

import (
	"context"

	"myproject/internal/order/domain"
	"myproject/internal/shared/messaging"

	"github.com/google/uuid"
)

type OrderService struct {
	repo      domain.OrderRepository
	publisher messaging.EventPublisher
}

func NewOrderService(repo domain.OrderRepository, pub messaging.EventPublisher) *OrderService {
	return &OrderService{repo: repo, publisher: pub}
}

func (s *OrderService) CreateOrder(ctx context.Context, cmd CreateOrderCommand) (string, error) {
	order := domain.NewOrder(uuid.NewString(), cmd.CustomerID)

	for _, item := range cmd.Items {
		price, err := domain.NewMoney(item.Price, "KRW")
		if err != nil {
			return "", err
		}
		if err := order.AddItem(item.ProductID, item.Name, price, item.Quantity); err != nil {
			return "", err
		}
	}

	if err := order.Confirm(); err != nil {
		return "", err
	}

	if err := s.repo.Save(ctx, order); err != nil {
		return "", err
	}

	// 도메인 이벤트 발행
	for _, event := range order.CollectEvents() {
		if err := s.publisher.Publish(ctx, event); err != nil {
			// 로깅 후 계속 진행 또는 Outbox 패턴 사용
			return order.ID, err
		}
	}

	return order.ID, nil
}

func (s *OrderService) CancelOrder(ctx context.Context, cmd CancelOrderCommand) error {
	order, err := s.repo.FindByID(ctx, cmd.OrderID)
	if err != nil {
		return domain.ErrOrderNotFound
	}

	if err := order.Cancel(cmd.Reason); err != nil {
		return err
	}

	if err := s.repo.Save(ctx, order); err != nil {
		return err
	}

	for _, event := range order.CollectEvents() {
		s.publisher.Publish(ctx, event)
	}

	return nil
}

func (s *OrderService) GetOrder(ctx context.Context, query GetOrderQuery) (*domain.Order, error) {
	order, err := s.repo.FindByID(ctx, query.OrderID)
	if err != nil {
		return nil, domain.ErrOrderNotFound
	}
	return order, nil
}
```

```go
// internal/order/application/commands.go
package application

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

type CancelOrderCommand struct {
	OrderID string
	Reason  string
}
```

```go
// internal/order/application/queries.go
package application

type GetOrderQuery struct {
	OrderID string
}

type ListCustomerOrdersQuery struct {
	CustomerID string
}
```

---

## Infrastructure 레이어

### Kafka Publisher

```go
// internal/order/infrastructure/kafka_publisher.go
package infrastructure

import (
	"context"
	"encoding/json"

	"github.com/segmentio/kafka-go"
	sharedDomain "myproject/internal/shared/domain"
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

func (p *KafkaPublisher) Publish(ctx context.Context, event sharedDomain.DomainEvent) error {
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

### gRPC proto

```protobuf
// proto/order/order.proto
syntax = "proto3";

package order;
option go_package = "myproject/proto/order";

service OrderService {
  rpc CreateOrder(CreateOrderRequest) returns (CreateOrderResponse);
  rpc GetOrder(GetOrderRequest) returns (OrderResponse);
  rpc CancelOrder(CancelOrderRequest) returns (google.protobuf.Empty);
}

message CreateOrderRequest {
  string customer_id = 1;
  repeated OrderItemRequest items = 2;
}

message OrderItemRequest {
  string product_id = 1;
  string name = 2;
  int64 price = 3;
  int32 quantity = 4;
}

message CreateOrderResponse {
  string order_id = 1;
}

message GetOrderRequest {
  string order_id = 1;
}

message OrderResponse {
  string id = 1;
  string customer_id = 2;
  string status = 3;
  repeated OrderItemResponse items = 4;
}

message OrderItemResponse {
  string product_id = 1;
  string product_name = 2;
  int64 unit_price = 3;
  int32 quantity = 4;
}

message CancelOrderRequest {
  string order_id = 1;
  string reason = 2;
}
```

---

## HTTP 인터페이스

```go
// internal/order/interfaces/http/handler.go
package http

import (
	"encoding/json"
	"net/http"

	"github.com/go-chi/chi/v5"
	"myproject/internal/order/application"
	"myproject/internal/platform/httputil"
)

type OrderHandler struct {
	service *application.OrderService
}

func NewOrderHandler(service *application.OrderService) *OrderHandler {
	return &OrderHandler{service: service}
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

	cmd := toCreateCommand(req)
	orderID, err := h.service.CreateOrder(r.Context(), cmd)
	if err != nil {
		httputil.HandleError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusCreated, map[string]string{"id": orderID})
}

func (h *OrderHandler) getOrder(w http.ResponseWriter, r *http.Request) {
	query := application.GetOrderQuery{OrderID: chi.URLParam(r, "id")}
	order, err := h.service.GetOrder(r.Context(), query)
	if err != nil {
		httputil.HandleError(w, err)
		return
	}

	httputil.WriteJSON(w, http.StatusOK, toOrderResponse(order))
}

func (h *OrderHandler) cancelOrder(w http.ResponseWriter, r *http.Request) {
	var req CancelOrderRequest
	json.NewDecoder(r.Body).Decode(&req)

	cmd := application.CancelOrderCommand{
		OrderID: chi.URLParam(r, "id"),
		Reason:  req.Reason,
	}
	if err := h.service.CancelOrder(r.Context(), cmd); err != nil {
		httputil.HandleError(w, err)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
```

---

## 도메인 단위 테스트

```go
// internal/order/domain/order_test.go
package domain

import "testing"

func TestOrder_Confirm(t *testing.T) {
	order := NewOrder("o1", "c1")
	price, _ := NewMoney(10000, "KRW")
	order.AddItem("p1", "상품A", price, 2)

	if err := order.Confirm(); err != nil {
		t.Fatalf("주문 확정 실패: %v", err)
	}

	if order.Status != StatusConfirmed {
		t.Errorf("상태가 CONFIRMED여야 함, got %s", order.Status)
	}

	events := order.CollectEvents()
	if len(events) != 1 {
		t.Errorf("이벤트 1개여야 함, got %d", len(events))
	}
}

func TestOrder_EmptyCannotConfirm(t *testing.T) {
	order := NewOrder("o1", "c1")
	if err := order.Confirm(); err == nil {
		t.Error("빈 주문 확정 시 에러가 발생해야 함")
	}
}

func TestOrder_DeliveredCannotCancel(t *testing.T) {
	order := ReconstitueOrder("o1", "c1", nil, StatusDelivered, time.Now())
	if err := order.Cancel("변심"); err == nil {
		t.Error("배송 완료 주문 취소 시 에러가 발생해야 함")
	}
}

func TestMoney_Add_DifferentCurrency(t *testing.T) {
	krw, _ := NewMoney(1000, "KRW")
	usd, _ := NewMoney(1, "USD")
	_, err := krw.Add(usd)
	if err == nil {
		t.Error("다른 통화 더하기 시 에러가 발생해야 함")
	}
}
```

---

## 의존성 규칙

```
┌────────────────────────────────────┐
│       interfaces (HTTP, gRPC)      │  ← chi, gRPC, JSON
├────────────────────────────────────┤
│     infrastructure (DB, Kafka)     │  ← PostgreSQL, Kafka, Redis
├────────────────────────────────────┤
│     application (Use Cases)        │  ← domain 인터페이스만 의존
├────────────────────────────────────┤
│     domain (Business Rules)        │  ← 표준 라이브러리만, 외부 import 금지
└────────────────────────────────────┘
```

| 레이어 | 허용 import | 금지 import |
|--------|------------|------------|
| domain | 표준 라이브러리, shared/domain | chi, sqlc, kafka, gRPC |
| application | domain | chi, sqlc, kafka |
| infrastructure | domain, application, 외부 | - |
| interfaces | application, 외부 | domain 모델 직접 HTTP 응답 |

---

## 대규모에서 반드시 지켜야 할 것

| 규칙 | 설명 |
|------|------|
| Domain 순수성 | 외부 패키지 import 절대 금지 |
| Aggregate 간 ID 참조 | 다른 Aggregate를 직접 포함하지 않음 |
| Kafka로 Context 간 통신 | 동기 호출 최소화, 이벤트 기반 |
| Reconstitute 패턴 | DB 복원 시 비즈니스 검증 건너뜀 |
| Outbox 패턴 | 이벤트 발행 보장 (DB 트랜잭션 + Outbox 테이블) |
| gRPC 내부 통신 | 서비스 간 통신은 gRPC, 외부는 HTTP |
