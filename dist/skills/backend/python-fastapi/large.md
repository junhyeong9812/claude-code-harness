# Python / FastAPI - 대규모 프로젝트 가이드

> 엔드포인트 100개 이상, 4-Layer + Facade + Event + CQRS

---

## 핵심 원칙

- **중규모와 레이어 구조는 동일하다**: `api → application → domain ← infrastructure` (4-Layer)
- **대규모는 세 가지만 추가한다**: Facade (모듈 간 인터페이스), Event (비동기 통신), CQRS (읽기/쓰기 분리)
- **도메인 모델은 SQLAlchemy 직접 사용**: Mapped Column으로 선언, imperative mapping 사용하지 않는다
- **모듈 간 직접 호출 금지**: 반드시 Facade를 통하거나 Event를 발행한다
- **의존성 조립은 FastAPI Depends**: dependency-injector 같은 별도 IoC 컨테이너를 쓰지 않는다
- **커스텀 예외 계층**: HTTP에 의존하지 않는 비즈니스 예외

---

## 의존성 방향

```
api → application → domain ← infrastructure
```

- `api`: HTTP 요청/응답 처리, DTO 변환, Depends 조립
- `application`: 유스케이스 — command(쓰기), query(읽기), event handler로 분리
- `domain`: 모델(SQLAlchemy), 리포지토리 인터페이스, 비즈니스 규칙, Value Object
- `infrastructure`: 리포지토리 구현, 외부 API 클라이언트, 메시징

**domain은 다른 레이어를 import하지 않는다.** infrastructure가 domain의 인터페이스를 구현하고, application이 domain의 인터페이스에 의존한다.

---

## 디렉토리 구조

```
project/
├── src/
│   └── app/
│       ├── __init__.py
│       ├── main.py
│       │
│       ├── global_/
│       │   ├── exception/
│       │   │   ├── exceptions.py
│       │   │   └── handlers.py
│       │   ├── config/
│       │   │   └── settings.py
│       │   ├── middleware/
│       │   │   └── request_id.py
│       │   ├── database.py
│       │   └── domain/
│       │       ├── events.py           # DomainEvent base, EventBus
│       │       └── base_model.py
│       │
│       ├── order/
│       │   ├── facade.py               # OrderFacade — 모듈의 공개 인터페이스
│       │   ├── events.py               # OrderCreatedEvent 등 (공개 이벤트)
│       │   │
│       │   ├── api/
│       │   │   ├── router.py
│       │   │   ├── dependencies.py
│       │   │   └── dto/
│       │   │       ├── requests.py
│       │   │       └── responses.py
│       │   │
│       │   ├── application/
│       │   │   ├── command/
│       │   │   │   ├── create_order.py
│       │   │   │   └── cancel_order.py
│       │   │   ├── query/
│       │   │   │   ├── get_order.py
│       │   │   │   └── search_orders.py
│       │   │   ├── event/
│       │   │   │   └── payment_completed_handler.py
│       │   │   └── order_mapper.py
│       │   │
│       │   ├── domain/
│       │   │   ├── model/
│       │   │   │   ├── order.py
│       │   │   │   ├── order_item.py
│       │   │   │   └── order_status.py
│       │   │   ├── vo/
│       │   │   │   └── order_amount.py
│       │   │   ├── repository.py       # ABC 인터페이스
│       │   │   └── domain_service.py
│       │   │
│       │   └── infrastructure/
│       │       ├── persistence/
│       │       │   └── sqlalchemy_repo.py
│       │       ├── client/
│       │       │   └── payment_client.py
│       │       └── messaging/
│       │           └── kafka_producer.py
│       │
│       ├── inventory/
│       │   ├── facade.py
│       │   ├── events.py
│       │   ├── api/ application/ domain/ infrastructure/
│       │
│       ├── user/
│       │   ├── facade.py
│       │   └── ...
│       │
│       └── payment/
│           ├── facade.py
│           ├── events.py
│           └── ...
│
├── alembic/
├── tests/
│   ├── unit/
│   │   └── order/
│   │       ├── test_domain.py
│   │       └── test_create_order.py
│   └── integration/
├── pyproject.toml
└── docker-compose.yml
```

### 중규모 대비 추가되는 것

| 추가 요소 | 위치 | 역할 |
|-----------|------|------|
| `facade.py` | 모듈 루트 | 모듈의 공개 인터페이스, 외부 모듈은 이것만 호출 |
| `events.py` | 모듈 루트 | 모듈이 발행하는 공개 이벤트 정의 |
| `application/command/` | application 내부 | 쓰기 유스케이스 (CQRS) |
| `application/query/` | application 내부 | 읽기 유스케이스 (CQRS) |
| `application/event/` | application 내부 | 다른 모듈의 이벤트를 구독하여 처리 |
| `global_/domain/events.py` | 공유 | DomainEvent 베이스 클래스, EventBus |

---

## 모듈 간 통신 규칙

```
금지: order/application → inventory/domain  (직접 호출)
허용: order/application → inventory.InventoryFacade
권장: order → publish(OrderCreatedEvent) → inventory/event/handler
```

| 방식 | 언제 사용 | 결합도 |
|------|----------|--------|
| Facade 호출 | 동기적 응답이 필요할 때 (재고 확인 등) | 중간 |
| Event 발행 | 후속 처리가 비동기여도 될 때 (알림, 로그 등) | 낮음 |

**모듈 내부의 domain, application, infrastructure는 외부에 노출하지 않는다.** 외부 모듈은 오직 `facade.py`와 `events.py`만 import한다.

---

## DomainEvent 베이스 + EventBus

```python
# src/app/global_/domain/events.py
from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Callable, Coroutine
from uuid import UUID, uuid4
import logging

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class DomainEvent:
    """모든 도메인 이벤트의 베이스 클래스."""
    event_id: UUID = field(default_factory=uuid4)
    occurred_at: datetime = field(
        default_factory=lambda: datetime.now(timezone.utc),
    )


Handler = Callable[[Any], Coroutine]


class EventBus:
    """인메모리 이벤트 버스. 프로세스 내 pub/sub."""

    def __init__(self):
        self._handlers: dict[type, list[Handler]] = defaultdict(list)

    def subscribe(self, event_type: type, handler: Handler) -> None:
        self._handlers[event_type].append(handler)

    async def publish(self, event: DomainEvent) -> None:
        event_type = type(event)
        for handler in self._handlers.get(event_type, []):
            try:
                await handler(event)
            except Exception:
                logger.exception(
                    "이벤트 핸들러 실패: event=%s handler=%s",
                    event_type.__name__,
                    handler.__name__,
                )
```

---

## 공개 이벤트 정의

각 모듈은 자신이 발행하는 이벤트를 모듈 루트 `events.py`에 정의한다. 다른 모듈은 이 파일만 import한다.

```python
# src/app/order/events.py
from dataclasses import dataclass
from decimal import Decimal
from uuid import UUID

from app.global_.domain.events import DomainEvent


@dataclass(frozen=True)
class OrderCreatedEvent(DomainEvent):
    order_id: UUID = None
    customer_id: UUID = None
    total_amount: Decimal = Decimal("0")


@dataclass(frozen=True)
class OrderCancelledEvent(DomainEvent):
    order_id: UUID = None
    reason: str = ""
```

```python
# src/app/payment/events.py
from dataclasses import dataclass
from uuid import UUID

from app.global_.domain.events import DomainEvent


@dataclass(frozen=True)
class PaymentCompletedEvent(DomainEvent):
    payment_id: UUID = None
    order_id: UUID = None
```

---

## Domain 모델 (SQLAlchemy 직접 사용)

중규모와 동일하게 SQLAlchemy Mapped Column을 사용한다. 비즈니스 로직 메서드를 모델에 둔다.

```python
# src/app/global_/domain/base_model.py
from datetime import datetime

from sqlalchemy import func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class TimestampMixin:
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    updated_at: Mapped[datetime] = mapped_column(
        server_default=func.now(), onupdate=func.now(),
    )
```

```python
# src/app/order/domain/model/order_status.py
from enum import StrEnum


class OrderStatus(StrEnum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    SHIPPING = "shipping"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"

    def can_transition_to(self, target: OrderStatus) -> bool:
        transitions = {
            OrderStatus.PENDING: {OrderStatus.CONFIRMED, OrderStatus.CANCELLED},
            OrderStatus.CONFIRMED: {OrderStatus.SHIPPING, OrderStatus.CANCELLED},
            OrderStatus.SHIPPING: {OrderStatus.DELIVERED},
        }
        return target in transitions.get(self, set())
```

```python
# src/app/order/domain/vo/order_amount.py
from __future__ import annotations

from dataclasses import dataclass
from decimal import Decimal


@dataclass(frozen=True)
class OrderAmount:
    value: Decimal
    currency: str = "KRW"

    def __post_init__(self):
        if self.value < 0:
            raise ValueError("금액은 0 이상이어야 합니다")

    def __add__(self, other: OrderAmount) -> OrderAmount:
        if self.currency != other.currency:
            raise ValueError("통화가 다릅니다")
        return OrderAmount(self.value + other.value, self.currency)

    def __mul__(self, quantity: int) -> OrderAmount:
        return OrderAmount(self.value * quantity, self.currency)
```

```python
# src/app/order/domain/model/order_item.py
from __future__ import annotations

from decimal import Decimal

from sqlalchemy import String, Numeric, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.global_.domain.base_model import Base


class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"))
    product_name: Mapped[str] = mapped_column(String(200))
    quantity: Mapped[int]
    unit_price: Mapped[Decimal] = mapped_column(Numeric(12, 2))

    order: Mapped[Order] = relationship(back_populates="items")

    @property
    def subtotal(self) -> Decimal:
        return self.unit_price * self.quantity
```

```python
# src/app/order/domain/model/order.py
from __future__ import annotations

from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import String, Numeric, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.global_.domain.base_model import Base, TimestampMixin
from app.global_.exception.exceptions import BusinessRuleError
from app.order.domain.model.order_status import OrderStatus

if TYPE_CHECKING:
    from app.order.domain.model.order_item import OrderItem


class Order(Base, TimestampMixin):
    """주문 Aggregate Root. 비즈니스 규칙을 모델 안에 둔다."""

    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(primary_key=True)
    customer_id: Mapped[int] = mapped_column(index=True)
    status: Mapped[OrderStatus] = mapped_column(
        SAEnum(OrderStatus), default=OrderStatus.PENDING,
    )
    total_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    note: Mapped[str | None] = mapped_column(String(500), default=None)

    items: Mapped[list[OrderItem]] = relationship(
        back_populates="order", cascade="all, delete-orphan",
    )

    # --- 비즈니스 규칙 ---

    def confirm(self) -> None:
        """주문 확정. 상품이 있어야 하고, PENDING 상태여야 한다."""
        if not self.status.can_transition_to(OrderStatus.CONFIRMED):
            raise BusinessRuleError(
                message=f"{self.status.value} → confirmed 전환 불가",
            )
        if not self.items:
            raise BusinessRuleError(
                message="상품이 없는 주문은 확정할 수 없습니다",
            )
        self.status = OrderStatus.CONFIRMED

    def cancel(self, reason: str = "") -> None:
        """주문 취소. 배송 시작 전에만 가능."""
        if not self.status.can_transition_to(OrderStatus.CANCELLED):
            raise BusinessRuleError(
                message=f"{self.status.value} → cancelled 전환 불가",
            )
        self.status = OrderStatus.CANCELLED

    def calculate_total(self) -> Decimal:
        """아이템 합계를 계산하여 total_amount에 반영."""
        self.total_amount = sum(
            item.subtotal for item in self.items
        ) if self.items else Decimal("0")
        return self.total_amount
```

---

## Repository 인터페이스 + 구현

```python
# src/app/order/domain/repository.py
from abc import ABC, abstractmethod

from app.order.domain.model.order import Order


class OrderRepository(ABC):
    """주문 리포지토리 인터페이스. domain 레이어에 위치한다."""

    @abstractmethod
    async def find_by_id(self, order_id: int) -> Order | None: ...

    @abstractmethod
    async def find_by_customer_id(
        self, customer_id: int, *, skip: int = 0, limit: int = 20,
    ) -> list[Order]: ...

    @abstractmethod
    async def save(self, order: Order) -> Order: ...

    @abstractmethod
    async def delete(self, order: Order) -> None: ...
```

```python
# src/app/order/infrastructure/persistence/sqlalchemy_repo.py
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.order.domain.model.order import Order
from app.order.domain.repository import OrderRepository


class SqlAlchemyOrderRepository(OrderRepository):
    def __init__(self, db: AsyncSession):
        self.db = db

    async def find_by_id(self, order_id: int) -> Order | None:
        stmt = (
            select(Order)
            .options(selectinload(Order.items))
            .where(Order.id == order_id)
        )
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def find_by_customer_id(
        self, customer_id: int, *, skip: int = 0, limit: int = 20,
    ) -> list[Order]:
        stmt = (
            select(Order)
            .where(Order.customer_id == customer_id)
            .offset(skip)
            .limit(limit)
            .order_by(Order.created_at.desc())
        )
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def save(self, order: Order) -> Order:
        self.db.add(order)
        await self.db.flush()
        await self.db.refresh(order)
        return order

    async def delete(self, order: Order) -> None:
        await self.db.delete(order)
```

---

## CQRS — Command Handler

Command는 상태를 변경한다. 하나의 Command = 하나의 파일.

```python
# src/app/order/application/command/create_order.py
from decimal import Decimal

from app.order.domain.model.order import Order
from app.order.domain.model.order_item import OrderItem
from app.order.domain.model.order_status import OrderStatus
from app.order.domain.repository import OrderRepository
from app.order.events import OrderCreatedEvent
from app.order.api.dto.requests import CreateOrderRequest
from app.global_.domain.events import EventBus


class CreateOrderCommand:
    def __init__(
        self,
        order_repo: OrderRepository,
        event_bus: EventBus,
    ):
        self.order_repo = order_repo
        self.event_bus = event_bus

    async def execute(self, customer_id: int, dto: CreateOrderRequest) -> Order:
        items = [
            OrderItem(
                product_name=item.product_name,
                quantity=item.quantity,
                unit_price=item.unit_price,
            )
            for item in dto.items
        ]

        total = sum(
            Decimal(str(item.unit_price)) * item.quantity for item in dto.items
        )

        order = Order(
            customer_id=customer_id,
            status=OrderStatus.PENDING,
            total_amount=total,
            note=dto.note,
            items=items,
        )

        order = await self.order_repo.save(order)

        # 이벤트 발행
        await self.event_bus.publish(
            OrderCreatedEvent(
                order_id=order.id,
                customer_id=customer_id,
                total_amount=total,
            )
        )

        return order
```

```python
# src/app/order/application/command/cancel_order.py
from app.global_.exception.exceptions import NotFoundError
from app.order.domain.repository import OrderRepository
from app.order.events import OrderCancelledEvent
from app.global_.domain.events import EventBus


class CancelOrderCommand:
    def __init__(
        self,
        order_repo: OrderRepository,
        event_bus: EventBus,
    ):
        self.order_repo = order_repo
        self.event_bus = event_bus

    async def execute(self, order_id: int, reason: str = "") -> None:
        order = await self.order_repo.find_by_id(order_id)
        if not order:
            raise NotFoundError(message="주문을 찾을 수 없습니다", resource="Order")

        order.cancel(reason)
        await self.order_repo.save(order)

        await self.event_bus.publish(
            OrderCancelledEvent(order_id=order.id, reason=reason)
        )
```

---

## CQRS — Query Handler

Query는 상태를 변경하지 않는다. EventBus가 필요 없다.

```python
# src/app/order/application/query/get_order.py
from app.global_.exception.exceptions import NotFoundError
from app.order.domain.model.order import Order
from app.order.domain.repository import OrderRepository


class GetOrderQuery:
    def __init__(self, order_repo: OrderRepository):
        self.order_repo = order_repo

    async def execute(self, order_id: int) -> Order:
        order = await self.order_repo.find_by_id(order_id)
        if not order:
            raise NotFoundError(message="주문을 찾을 수 없습니다", resource="Order")
        return order
```

```python
# src/app/order/application/query/search_orders.py
from app.order.domain.model.order import Order
from app.order.domain.repository import OrderRepository


class SearchOrdersQuery:
    def __init__(self, order_repo: OrderRepository):
        self.order_repo = order_repo

    async def execute(
        self, customer_id: int, *, skip: int = 0, limit: int = 20,
    ) -> list[Order]:
        return await self.order_repo.find_by_customer_id(
            customer_id, skip=skip, limit=limit,
        )
```

---

## Facade — 모듈의 공개 인터페이스

외부 모듈은 order 내부를 직접 import하지 않는다. Facade만 사용한다.

```python
# src/app/order/facade.py
from decimal import Decimal

from app.order.domain.model.order import Order
from app.order.domain.model.order_status import OrderStatus
from app.order.domain.repository import OrderRepository


class OrderFacade:
    """order 모듈의 공개 인터페이스.

    다른 모듈(payment, inventory 등)은 이 클래스만 import한다.
    order 내부의 domain, application, infrastructure를 직접 접근하지 않는다.
    """

    def __init__(self, order_repo: OrderRepository):
        self.order_repo = order_repo

    async def get_order_total(self, order_id: int) -> Decimal:
        """결제 모듈에서 주문 금액을 조회할 때 사용."""
        order = await self.order_repo.find_by_id(order_id)
        if not order:
            return Decimal("0")
        return order.total_amount

    async def get_order_status(self, order_id: int) -> OrderStatus | None:
        """배송 모듈에서 주문 상태를 확인할 때 사용."""
        order = await self.order_repo.find_by_id(order_id)
        return order.status if order else None

    async def confirm_order(self, order_id: int) -> None:
        """결제 완료 후 주문을 확정할 때 사용."""
        order = await self.order_repo.find_by_id(order_id)
        if order:
            order.confirm()
            await self.order_repo.save(order)
```

---

## Event Handler — 다른 모듈의 이벤트 처리

```python
# src/app/order/application/event/payment_completed_handler.py
import logging

from app.payment.events import PaymentCompletedEvent
from app.order.facade import OrderFacade

logger = logging.getLogger(__name__)


async def handle_payment_completed(event: PaymentCompletedEvent) -> None:
    """결제 완료 이벤트를 수신하여 주문을 확정한다.

    이 핸들러는 payment 모듈의 이벤트를 구독한다.
    order 내부 로직은 OrderFacade를 통해 실행한다.
    """
    logger.info("결제 완료 수신: order_id=%s", event.order_id)
    # Facade를 통해 주문 확정
    # 실제로는 Depends로 주입받은 facade를 사용한다 (아래 이벤트 구독 등록 참고)
```

### 이벤트 구독 등록

```python
# src/app/main.py (이벤트 등록 부분)
from app.global_.domain.events import EventBus
from app.payment.events import PaymentCompletedEvent
from app.order.events import OrderCreatedEvent


def register_event_subscriptions(event_bus: EventBus, order_facade, inventory_facade):
    """모든 모듈의 이벤트 구독을 등록한다."""

    # payment → order: 결제 완료 시 주문 확정
    async def on_payment_completed(event: PaymentCompletedEvent):
        await order_facade.confirm_order(event.order_id)

    event_bus.subscribe(PaymentCompletedEvent, on_payment_completed)

    # order → inventory: 주문 생성 시 재고 차감
    async def on_order_created(event: OrderCreatedEvent):
        await inventory_facade.deduct_stock(event.order_id)

    event_bus.subscribe(OrderCreatedEvent, on_order_created)
```

---

## 모듈 간 통신 예시

```python
# 금지 — order가 inventory 내부를 직접 접근
from app.inventory.domain.model.stock import Stock  # WRONG
from app.inventory.infrastructure.persistence.sqlalchemy_repo import ...  # WRONG

# 허용 — Facade를 통한 동기 호출
from app.inventory.facade import InventoryFacade

class CreateOrderCommand:
    def __init__(self, order_repo, event_bus, inventory_facade: InventoryFacade):
        self.inventory_facade = inventory_facade

    async def execute(self, ...):
        # 재고 확인 (동기적 응답 필요)
        available = await self.inventory_facade.check_stock(product_id, quantity)
        if not available:
            raise BusinessRuleError(message="재고 부족")
        ...

# 권장 — 이벤트를 통한 비동기 통신
# order 모듈은 OrderCreatedEvent만 발행하고, inventory가 구독하여 처리
await self.event_bus.publish(
    OrderCreatedEvent(order_id=order.id, ...)
)
```

---

## DTO (Pydantic v2)

```python
# src/app/order/api/dto/requests.py
from decimal import Decimal

from pydantic import BaseModel, Field


class OrderItemRequest(BaseModel):
    product_name: str = Field(..., max_length=200)
    quantity: int = Field(..., gt=0)
    unit_price: Decimal = Field(..., gt=0, decimal_places=2)


class CreateOrderRequest(BaseModel):
    items: list[OrderItemRequest] = Field(..., min_length=1)
    note: str | None = Field(None, max_length=500)
```

```python
# src/app/order/api/dto/responses.py
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel

from app.order.domain.model.order_status import OrderStatus


class OrderItemResponse(BaseModel):
    id: int
    product_name: str
    quantity: int
    unit_price: Decimal

    model_config = {"from_attributes": True}


class OrderResponse(BaseModel):
    id: int
    customer_id: int
    status: OrderStatus
    total_amount: Decimal
    note: str | None
    items: list[OrderItemResponse]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
```

---

## 의존성 조립 (Depends 체이닝)

```python
# src/app/order/api/dependencies.py
from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.global_.database import get_db
from app.global_.domain.events import EventBus
from app.order.domain.repository import OrderRepository
from app.order.infrastructure.persistence.sqlalchemy_repo import SqlAlchemyOrderRepository
from app.order.application.command.create_order import CreateOrderCommand
from app.order.application.command.cancel_order import CancelOrderCommand
from app.order.application.query.get_order import GetOrderQuery
from app.order.facade import OrderFacade


# --- 공유 인스턴스 ---
_event_bus = EventBus()

def get_event_bus() -> EventBus:
    return _event_bus


# --- Repository ---
def get_order_repository(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> OrderRepository:
    return SqlAlchemyOrderRepository(db)


# --- Command ---
def get_create_order_command(
    order_repo: Annotated[OrderRepository, Depends(get_order_repository)],
    event_bus: Annotated[EventBus, Depends(get_event_bus)],
) -> CreateOrderCommand:
    return CreateOrderCommand(order_repo=order_repo, event_bus=event_bus)


def get_cancel_order_command(
    order_repo: Annotated[OrderRepository, Depends(get_order_repository)],
    event_bus: Annotated[EventBus, Depends(get_event_bus)],
) -> CancelOrderCommand:
    return CancelOrderCommand(order_repo=order_repo, event_bus=event_bus)


# --- Query ---
def get_get_order_query(
    order_repo: Annotated[OrderRepository, Depends(get_order_repository)],
) -> GetOrderQuery:
    return GetOrderQuery(order_repo=order_repo)


# --- Facade ---
def get_order_facade(
    order_repo: Annotated[OrderRepository, Depends(get_order_repository)],
) -> OrderFacade:
    return OrderFacade(order_repo=order_repo)


# --- 타입 별칭 ---
CreateOrderDep = Annotated[CreateOrderCommand, Depends(get_create_order_command)]
CancelOrderDep = Annotated[CancelOrderCommand, Depends(get_cancel_order_command)]
GetOrderDep = Annotated[GetOrderQuery, Depends(get_get_order_query)]
OrderFacadeDep = Annotated[OrderFacade, Depends(get_order_facade)]
```

---

## Router (api 레이어)

```python
# src/app/order/api/router.py
from fastapi import APIRouter, status

from app.order.api.dependencies import CreateOrderDep, CancelOrderDep, GetOrderDep
from app.order.api.dto.requests import CreateOrderRequest
from app.order.api.dto.responses import OrderResponse

router = APIRouter(prefix="/orders", tags=["orders"])


@router.post("", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
async def create_order(
    body: CreateOrderRequest,
    command: CreateOrderDep,
    customer_id: int = 1,  # 실제로는 인증에서 추출
):
    order = await command.execute(customer_id=customer_id, dto=body)
    return order


@router.get("/{order_id}", response_model=OrderResponse)
async def get_order(
    order_id: int,
    query: GetOrderDep,
):
    return await query.execute(order_id=order_id)


@router.post("/{order_id}/cancel", status_code=status.HTTP_204_NO_CONTENT)
async def cancel_order(
    order_id: int,
    command: CancelOrderDep,
    reason: str = "",
):
    await command.execute(order_id=order_id, reason=reason)
```

---

## 테스트 — 도메인 단위 테스트 (순수 Python)

도메인 모델의 비즈니스 규칙을 테스트한다. DB, 프레임워크 없이 실행된다.

```python
# tests/unit/order/test_domain.py
import pytest
from decimal import Decimal
from unittest.mock import MagicMock

from app.order.domain.model.order import Order
from app.order.domain.model.order_item import OrderItem
from app.order.domain.model.order_status import OrderStatus
from app.order.domain.vo.order_amount import OrderAmount
from app.global_.exception.exceptions import BusinessRuleError


def _make_order(**kwargs) -> Order:
    """테스트용 Order 생성 헬퍼. SQLAlchemy 세션 없이 객체만 만든다."""
    defaults = {
        "id": 1,
        "customer_id": 100,
        "status": OrderStatus.PENDING,
        "total_amount": Decimal("0"),
    }
    defaults.update(kwargs)
    order = Order(**defaults)
    return order


def _make_item(**kwargs) -> OrderItem:
    defaults = {
        "id": 1,
        "order_id": 1,
        "product_name": "테스트 상품",
        "quantity": 2,
        "unit_price": Decimal("10000"),
    }
    defaults.update(kwargs)
    return OrderItem(**defaults)


def test_order_cancel_from_pending():
    order = _make_order(status=OrderStatus.PENDING)
    order.cancel()
    assert order.status == OrderStatus.CANCELLED


def test_order_cancel_from_shipping_raises():
    order = _make_order(status=OrderStatus.SHIPPING)
    with pytest.raises(BusinessRuleError):
        order.cancel()


def test_order_confirm_without_items_raises():
    order = _make_order()
    order.items = []
    with pytest.raises(BusinessRuleError, match="상품이 없는"):
        order.confirm()


def test_order_confirm_with_items():
    order = _make_order()
    order.items = [_make_item()]
    order.confirm()
    assert order.status == OrderStatus.CONFIRMED


def test_order_status_transitions():
    assert OrderStatus.PENDING.can_transition_to(OrderStatus.CONFIRMED)
    assert OrderStatus.PENDING.can_transition_to(OrderStatus.CANCELLED)
    assert not OrderStatus.DELIVERED.can_transition_to(OrderStatus.CANCELLED)
    assert not OrderStatus.CANCELLED.can_transition_to(OrderStatus.PENDING)


def test_order_amount_addition():
    a = OrderAmount(Decimal("10000"))
    b = OrderAmount(Decimal("5000"))
    result = a + b
    assert result.value == Decimal("15000")


def test_order_amount_different_currency_raises():
    krw = OrderAmount(Decimal("10000"), "KRW")
    usd = OrderAmount(Decimal("10"), "USD")
    with pytest.raises(ValueError, match="통화가 다릅니다"):
        krw + usd


def test_order_amount_negative_raises():
    with pytest.raises(ValueError, match="0 이상"):
        OrderAmount(Decimal("-1"))
```

---

## 테스트 — Command Handler 단위 테스트

```python
# tests/unit/order/test_create_order.py
import pytest
from decimal import Decimal
from unittest.mock import AsyncMock

from app.order.application.command.create_order import CreateOrderCommand
from app.order.api.dto.requests import CreateOrderRequest, OrderItemRequest


@pytest.fixture
def mock_repo():
    repo = AsyncMock()
    repo.save.side_effect = lambda order: order  # save가 order를 그대로 반환
    return repo


@pytest.fixture
def mock_event_bus():
    return AsyncMock()


@pytest.fixture
def command(mock_repo, mock_event_bus):
    return CreateOrderCommand(order_repo=mock_repo, event_bus=mock_event_bus)


@pytest.mark.anyio
async def test_create_order_saves_and_publishes_event(command, mock_repo, mock_event_bus):
    # Given
    dto = CreateOrderRequest(
        items=[
            OrderItemRequest(
                product_name="테스트 상품",
                quantity=3,
                unit_price=Decimal("10000.00"),
            ),
        ],
        note="배송 메모",
    )

    # When
    order = await command.execute(customer_id=1, dto=dto)

    # Then — 저장 확인
    mock_repo.save.assert_called_once()
    saved_order = mock_repo.save.call_args[0][0]
    assert len(saved_order.items) == 1
    assert saved_order.total_amount == Decimal("30000.00")
    assert saved_order.note == "배송 메모"

    # Then — 이벤트 발행 확인
    mock_event_bus.publish.assert_called_once()
    event = mock_event_bus.publish.call_args[0][0]
    assert event.customer_id == 1
    assert event.total_amount == Decimal("30000.00")


@pytest.mark.anyio
async def test_create_order_multiple_items(command, mock_repo):
    # Given
    dto = CreateOrderRequest(
        items=[
            OrderItemRequest(product_name="A", quantity=2, unit_price=Decimal("5000")),
            OrderItemRequest(product_name="B", quantity=1, unit_price=Decimal("3000")),
        ],
    )

    # When
    order = await command.execute(customer_id=1, dto=dto)

    # Then: 2 * 5000 + 1 * 3000 = 13000
    assert order.total_amount == Decimal("13000")
    assert len(order.items) == 2
```

---

## 대규모에서 지켜야 할 규칙

| 규칙 | 설명 |
|------|------|
| 레이어 구조는 중규모와 동일 | api → application → domain ← infrastructure |
| 모듈 간 통신은 Facade 또는 Event | 다른 모듈의 내부(domain, application, infrastructure)를 직접 import하지 않는다 |
| Command/Query 분리 | 쓰기(Command)는 이벤트를 발행하고, 읽기(Query)는 발행하지 않는다 |
| 이벤트는 모듈 루트에 정의 | `order/events.py`에 공개 이벤트, 내부 이벤트는 별도 |
| Facade는 얇게 유지 | 비즈니스 로직은 domain에, Facade는 위임만 한다 |
| 도메인 모델은 SQLAlchemy 직접 사용 | imperative mapping 불필요, Mapped Column으로 선언 |
| 테스트는 프레임워크 없이 | 도메인 테스트는 순수 Python, Command 테스트는 AsyncMock |

---

## 헥사고날은 언제 쓰는가

4-Layer + Facade + Event + CQRS로 대부분의 대규모 프로젝트를 커버할 수 있다. 헥사고날 아키텍처(포트/어댑터)는 다음 조건을 **모두** 만족할 때만 검토한다.

### 도입 조건

| 조건 | 설명 |
|------|------|
| 인프라 교체가 실제로 예정됨 | DB를 PostgreSQL → DynamoDB로 바꾸는 일정이 잡혀 있다 |
| 도메인 모델이 프레임워크와 완전 분리되어야 함 | 같은 도메인을 CLI, gRPC, 배치 등 여러 인터페이스에서 사용 |
| 팀이 헥사고날 경험이 있음 | 경험 없는 팀이 도입하면 매핑 레이어만 늘어나고 생산성 하락 |

### 비용

- **imperative mapping 필요**: 도메인 모델과 ORM 테이블을 분리하고 `mapper_registry.map_imperatively()`로 연결해야 한다. 복잡한 관계(상속, 다형성)에서 매핑 코드가 비대해진다.
- **DTO 변환 레이어 증가**: Port 인터페이스마다 별도의 DTO가 필요하다. 같은 데이터가 Domain Model → Application DTO → Port DTO → Adapter DTO로 4번 변환될 수 있다.
- **보일러플레이트 증가**: 인터페이스 하나당 Port(ABC) + Adapter(구현체) 쌍이 필요하다.
- **디버깅 복잡도**: 호출 경로가 길어져서 스택 트레이스를 따라가기 어렵다.

**결론**: 도메인 모델에 SQLAlchemy를 직접 쓰는 것은 "프레임워크 결합"이 아니라 "인프라 결합"이다. 대부분의 프로젝트에서 DB를 교체하는 일은 없으므로, 이 결합은 실용적인 트레이드오프다. 헥사고날이 필요한 시점이 오면 domain 레이어만 분리하면 된다 — 4-Layer 구조이므로 전환 비용이 크지 않다.
