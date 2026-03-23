# Python / FastAPI - 대규모 프로젝트 가이드

> 팀 8명 이상, 엔드포인트 100개 이상, 헥사고날/클린 아키텍처 + DDD

---

## 핵심 원칙

- **헥사고날 아키텍처**: Domain ← Application ← Infrastructure/Interfaces
- **DDD (Domain-Driven Design)**: Bounded Context, Aggregate, Value Object, Domain Event
- **CQRS**: Command와 Query 분리 (최소한 코드 레벨 분리)
- **Domain 레이어 프레임워크 무의존**: FastAPI, SQLAlchemy import 금지
- **dependency-injector**: IoC 컨테이너로 의존성 조립
- **Unit of Work**: 트랜잭션 경계를 명시적으로 관리

---

## 디렉토리 구조

> 참고: `/home/jun/project/fastapi-architecture` 프로젝트의 실제 구조를 기반으로 확장

```
project/
├── src/
│   └── app/
│       ├── __init__.py
│       ├── main.py                      # FastAPI 앱 생성, 조립
│       │
│       ├── shared/                      # 횡단 관심사
│       │   ├── config.py                # 환경 설정
│       │   ├── database.py              # DB 엔진, 세션
│       │   ├── base_model.py            # SQLAlchemy Base
│       │   ├── event_bus.py             # 도메인 이벤트 버스
│       │   ├── events.py                # 공통 이벤트 정의
│       │   ├── middleware.py            # 요청 ID, 로깅
│       │   └── subscription_context.py  # 이벤트 구독 등록
│       │
│       ├── order/                       # Bounded Context: 주문
│       │   ├── domain/                  # 도메인 레이어 (프레임워크 무의존)
│       │   │   ├── __init__.py
│       │   │   ├── models.py            # Aggregate Root, Entity, VO
│       │   │   ├── value_objects.py      # Money, OrderStatus 등
│       │   │   ├── events.py            # OrderCreated, OrderCancelled
│       │   │   ├── repository.py        # Repository 인터페이스 (ABC)
│       │   │   ├── services.py          # 도메인 서비스
│       │   │   └── exceptions.py        # 도메인 예외
│       │   │
│       │   ├── application/             # 애플리케이션 레이어
│       │   │   ├── __init__.py
│       │   │   ├── commands.py          # Command DTO
│       │   │   ├── queries.py           # Query DTO
│       │   │   ├── command_handlers.py  # Command 처리
│       │   │   ├── query_handlers.py    # Query 처리
│       │   │   ├── unit_of_work.py      # UoW 인터페이스
│       │   │   └── event_handlers.py    # 도메인 이벤트 핸들러
│       │   │
│       │   └── infrastructure/          # 인프라스트럭처 레이어
│       │       ├── __init__.py
│       │       ├── orm.py               # SQLAlchemy 매핑
│       │       ├── repository.py        # Repository 구현체
│       │       ├── unit_of_work.py      # UoW 구현체
│       │       └── api/                 # HTTP 인터페이스
│       │           ├── router.py
│       │           ├── schemas.py       # Pydantic 스키마
│       │           └── dependencies.py
│       │
│       ├── user/                        # Bounded Context: 사용자
│       │   ├── domain/
│       │   ├── application/
│       │   └── infrastructure/
│       │
│       └── catalog/                     # Bounded Context: 상품
│           ├── domain/
│           ├── application/
│           └── infrastructure/
│
├── alembic/
├── tests/
│   ├── unit/
│   │   ├── order/
│   │   │   ├── test_domain.py
│   │   │   └── test_command_handlers.py
│   │   └── user/
│   ├── integration/
│   │   ├── test_order_repository.py
│   │   └── test_order_api.py
│   └── conftest.py
├── pyproject.toml
└── docker-compose.yml
```

---

## 도메인 레이어 (프레임워크 import 0)

### Value Object

```python
# src/app/order/domain/value_objects.py
from __future__ import annotations
from dataclasses import dataclass
from enum import Enum
from decimal import Decimal


class OrderStatus(Enum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    SHIPPED = "shipped"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"

    def can_transition_to(self, target: OrderStatus) -> bool:
        transitions = {
            OrderStatus.PENDING: {OrderStatus.CONFIRMED, OrderStatus.CANCELLED},
            OrderStatus.CONFIRMED: {OrderStatus.SHIPPED, OrderStatus.CANCELLED},
            OrderStatus.SHIPPED: {OrderStatus.DELIVERED},
        }
        return target in transitions.get(self, set())


@dataclass(frozen=True)
class Money:
    amount: Decimal
    currency: str = "KRW"

    def __post_init__(self):
        if self.amount < 0:
            raise ValueError("금액은 0 이상이어야 합니다")

    def __add__(self, other: Money) -> Money:
        if self.currency != other.currency:
            raise ValueError("통화가 다릅니다")
        return Money(self.amount + other.amount, self.currency)

    def __mul__(self, quantity: int) -> Money:
        return Money(self.amount * quantity, self.currency)


@dataclass(frozen=True)
class Address:
    street: str
    city: str
    zip_code: str
```

### Aggregate Root

```python
# src/app/order/domain/models.py
from __future__ import annotations
from dataclasses import dataclass, field
from datetime import datetime
from uuid import UUID, uuid4

from app.order.domain.value_objects import Money, OrderStatus, Address
from app.order.domain.events import OrderCreated, OrderCancelled
from app.order.domain.exceptions import InvalidOrderTransitionError


@dataclass
class OrderItem:
    product_id: UUID
    product_name: str
    unit_price: Money
    quantity: int

    @property
    def subtotal(self) -> Money:
        return self.unit_price * self.quantity


@dataclass
class Order:
    """주문 Aggregate Root."""
    id: UUID = field(default_factory=uuid4)
    customer_id: UUID = field(default=None)
    items: list[OrderItem] = field(default_factory=list)
    status: OrderStatus = field(default=OrderStatus.PENDING)
    shipping_address: Address | None = None
    created_at: datetime = field(default_factory=datetime.utcnow)

    # 도메인 이벤트 수집
    _events: list = field(default_factory=list, repr=False)

    @property
    def total(self) -> Money:
        if not self.items:
            return Money(amount=0)
        result = self.items[0].subtotal
        for item in self.items[1:]:
            result = result + item.subtotal
        return result

    def add_item(self, product_id: UUID, name: str, price: Money, qty: int) -> None:
        if self.status != OrderStatus.PENDING:
            raise InvalidOrderTransitionError("확정된 주문에는 상품을 추가할 수 없습니다")
        self.items.append(OrderItem(product_id, name, price, qty))

    def confirm(self) -> None:
        if not self.status.can_transition_to(OrderStatus.CONFIRMED):
            raise InvalidOrderTransitionError(
                f"{self.status.value} → confirmed 전환 불가"
            )
        if not self.items:
            raise InvalidOrderTransitionError("상품이 없는 주문은 확정할 수 없습니다")
        self.status = OrderStatus.CONFIRMED
        self._events.append(
            OrderCreated(order_id=self.id, customer_id=self.customer_id, total=self.total)
        )

    def cancel(self, reason: str = "") -> None:
        if not self.status.can_transition_to(OrderStatus.CANCELLED):
            raise InvalidOrderTransitionError(
                f"{self.status.value} → cancelled 전환 불가"
            )
        self.status = OrderStatus.CANCELLED
        self._events.append(
            OrderCancelled(order_id=self.id, reason=reason)
        )

    def collect_events(self) -> list:
        events = self._events.copy()
        self._events.clear()
        return events
```

### 도메인 이벤트

```python
# src/app/order/domain/events.py
from dataclasses import dataclass
from uuid import UUID
from datetime import datetime


@dataclass(frozen=True)
class OrderCreated:
    order_id: UUID
    customer_id: UUID
    total: object  # Money
    occurred_at: datetime = None

    def __post_init__(self):
        if self.occurred_at is None:
            object.__setattr__(self, "occurred_at", datetime.utcnow())


@dataclass(frozen=True)
class OrderCancelled:
    order_id: UUID
    reason: str
    occurred_at: datetime = None

    def __post_init__(self):
        if self.occurred_at is None:
            object.__setattr__(self, "occurred_at", datetime.utcnow())
```

### 도메인 예외

```python
# src/app/order/domain/exceptions.py
from dataclasses import dataclass


@dataclass
class OrderDomainError(Exception):
    message: str


@dataclass
class InvalidOrderTransitionError(OrderDomainError):
    pass


@dataclass
class OrderNotFoundError(OrderDomainError):
    message: str = "주문을 찾을 수 없습니다"
```

### Repository 인터페이스 (Port)

```python
# src/app/order/domain/repository.py
from abc import ABC, abstractmethod
from uuid import UUID

from app.order.domain.models import Order


class OrderRepository(ABC):
    @abstractmethod
    async def find_by_id(self, order_id: UUID) -> Order | None:
        ...

    @abstractmethod
    async def find_by_customer(self, customer_id: UUID) -> list[Order]:
        ...

    @abstractmethod
    async def save(self, order: Order) -> Order:
        ...

    @abstractmethod
    async def delete(self, order: Order) -> None:
        ...
```

---

## Application 레이어 (유스케이스)

### Command / Query DTO

```python
# src/app/order/application/commands.py
from dataclasses import dataclass
from uuid import UUID
from decimal import Decimal


@dataclass(frozen=True)
class CreateOrderCommand:
    customer_id: UUID
    items: list[dict]  # [{product_id, name, price, quantity}]
    street: str
    city: str
    zip_code: str


@dataclass(frozen=True)
class CancelOrderCommand:
    order_id: UUID
    reason: str = ""
```

```python
# src/app/order/application/queries.py
from dataclasses import dataclass
from uuid import UUID


@dataclass(frozen=True)
class GetOrderQuery:
    order_id: UUID


@dataclass(frozen=True)
class ListCustomerOrdersQuery:
    customer_id: UUID
```

### Unit of Work 인터페이스

```python
# src/app/order/application/unit_of_work.py
from abc import ABC, abstractmethod

from app.order.domain.repository import OrderRepository


class OrderUnitOfWork(ABC):
    orders: OrderRepository

    @abstractmethod
    async def __aenter__(self):
        ...

    @abstractmethod
    async def __aexit__(self, exc_type, exc_val, exc_tb):
        ...

    @abstractmethod
    async def commit(self):
        ...

    @abstractmethod
    async def rollback(self):
        ...
```

### Command Handler

```python
# src/app/order/application/command_handlers.py
from uuid import UUID
from decimal import Decimal

from app.order.domain.models import Order
from app.order.domain.value_objects import Money, Address
from app.order.domain.exceptions import OrderNotFoundError
from app.order.application.commands import CreateOrderCommand, CancelOrderCommand
from app.order.application.unit_of_work import OrderUnitOfWork
from app.shared.event_bus import EventBus


class CreateOrderHandler:
    def __init__(self, uow: OrderUnitOfWork, event_bus: EventBus):
        self.uow = uow
        self.event_bus = event_bus

    async def handle(self, cmd: CreateOrderCommand) -> UUID:
        async with self.uow:
            order = Order(customer_id=cmd.customer_id)
            order.shipping_address = Address(
                street=cmd.street, city=cmd.city, zip_code=cmd.zip_code
            )

            for item in cmd.items:
                order.add_item(
                    product_id=item["product_id"],
                    name=item["name"],
                    price=Money(Decimal(str(item["price"]))),
                    qty=item["quantity"],
                )

            order.confirm()
            await self.uow.orders.save(order)
            await self.uow.commit()

            # 도메인 이벤트 발행
            for event in order.collect_events():
                await self.event_bus.publish(event)

            return order.id


class CancelOrderHandler:
    def __init__(self, uow: OrderUnitOfWork, event_bus: EventBus):
        self.uow = uow
        self.event_bus = event_bus

    async def handle(self, cmd: CancelOrderCommand) -> None:
        async with self.uow:
            order = await self.uow.orders.find_by_id(cmd.order_id)
            if not order:
                raise OrderNotFoundError()

            order.cancel(cmd.reason)
            await self.uow.orders.save(order)
            await self.uow.commit()

            for event in order.collect_events():
                await self.event_bus.publish(event)
```

### Query Handler

```python
# src/app/order/application/query_handlers.py
from app.order.domain.models import Order
from app.order.domain.exceptions import OrderNotFoundError
from app.order.application.queries import GetOrderQuery, ListCustomerOrdersQuery
from app.order.application.unit_of_work import OrderUnitOfWork


class GetOrderHandler:
    def __init__(self, uow: OrderUnitOfWork):
        self.uow = uow

    async def handle(self, query: GetOrderQuery) -> Order:
        async with self.uow:
            order = await self.uow.orders.find_by_id(query.order_id)
            if not order:
                raise OrderNotFoundError()
            return order


class ListCustomerOrdersHandler:
    def __init__(self, uow: OrderUnitOfWork):
        self.uow = uow

    async def handle(self, query: ListCustomerOrdersQuery) -> list[Order]:
        async with self.uow:
            return await self.uow.orders.find_by_customer(query.customer_id)
```

---

## Infrastructure 레이어

### ORM 매핑 (도메인 모델과 분리)

```python
# src/app/order/infrastructure/orm.py
from sqlalchemy import Table, Column, String, Integer, DateTime, Numeric, ForeignKey, Uuid
from sqlalchemy.orm import registry, relationship

from app.shared.base_model import Base
from app.order.domain.models import Order, OrderItem

mapper_registry = registry()

orders_table = Table(
    "orders",
    Base.metadata,
    Column("id", Uuid, primary_key=True),
    Column("customer_id", Uuid, nullable=False, index=True),
    Column("status", String(20), nullable=False, default="pending"),
    Column("shipping_street", String(255)),
    Column("shipping_city", String(100)),
    Column("shipping_zip_code", String(20)),
    Column("created_at", DateTime(timezone=True)),
)

order_items_table = Table(
    "order_items",
    Base.metadata,
    Column("id", Integer, primary_key=True, autoincrement=True),
    Column("order_id", Uuid, ForeignKey("orders.id"), nullable=False),
    Column("product_id", Uuid, nullable=False),
    Column("product_name", String(200)),
    Column("unit_price", Numeric(12, 2)),
    Column("currency", String(3), default="KRW"),
    Column("quantity", Integer, nullable=False),
)


def start_mappers():
    """Imperative mapping: 도메인 모델에 SQLAlchemy 의존성을 주입하지 않는다."""
    mapper_registry.map_imperatively(
        Order,
        orders_table,
        properties={
            "items": relationship(OrderItem, lazy="joined"),
        },
    )
    mapper_registry.map_imperatively(OrderItem, order_items_table)
```

### Repository 구현체 (Adapter)

```python
# src/app/order/infrastructure/repository.py
from uuid import UUID
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.order.domain.models import Order
from app.order.domain.repository import OrderRepository


class SqlAlchemyOrderRepository(OrderRepository):
    def __init__(self, session: AsyncSession):
        self.session = session

    async def find_by_id(self, order_id: UUID) -> Order | None:
        return await self.session.get(Order, order_id)

    async def find_by_customer(self, customer_id: UUID) -> list[Order]:
        stmt = select(Order).where(Order.customer_id == customer_id)
        result = await self.session.execute(stmt)
        return list(result.scalars().all())

    async def save(self, order: Order) -> Order:
        self.session.add(order)
        await self.session.flush()
        return order

    async def delete(self, order: Order) -> None:
        await self.session.delete(order)
```

### Unit of Work 구현체

```python
# src/app/order/infrastructure/unit_of_work.py
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.order.application.unit_of_work import OrderUnitOfWork
from app.order.infrastructure.repository import SqlAlchemyOrderRepository


class SqlAlchemyOrderUnitOfWork(OrderUnitOfWork):
    def __init__(self, session_factory: async_sessionmaker):
        self.session_factory = session_factory

    async def __aenter__(self):
        self.session: AsyncSession = self.session_factory()
        self.orders = SqlAlchemyOrderRepository(self.session)
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if exc_type:
            await self.rollback()
        await self.session.close()

    async def commit(self):
        await self.session.commit()

    async def rollback(self):
        await self.session.rollback()
```

---

## 이벤트 버스

```python
# src/app/shared/event_bus.py
from collections import defaultdict
from typing import Any, Callable, Coroutine
import logging

logger = logging.getLogger(__name__)

Handler = Callable[[Any], Coroutine]


class EventBus:
    def __init__(self):
        self._handlers: dict[type, list[Handler]] = defaultdict(list)

    def subscribe(self, event_type: type, handler: Handler) -> None:
        self._handlers[event_type].append(handler)

    async def publish(self, event: Any) -> None:
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

```python
# src/app/shared/subscription_context.py
from app.shared.event_bus import EventBus
from app.order.domain.events import OrderCreated, OrderCancelled


def register_subscriptions(event_bus: EventBus):
    """모든 도메인 이벤트 구독을 등록한다."""

    async def on_order_created(event: OrderCreated):
        # 알림 전송, 재고 차감 등
        print(f"[EVENT] 주문 생성: {event.order_id}")

    async def on_order_cancelled(event: OrderCancelled):
        # 재고 복구, 환불 처리 등
        print(f"[EVENT] 주문 취소: {event.order_id} 사유: {event.reason}")

    event_bus.subscribe(OrderCreated, on_order_created)
    event_bus.subscribe(OrderCancelled, on_order_cancelled)
```

---

## HTTP 인터페이스 (API Router)

```python
# src/app/order/infrastructure/api/schemas.py
from uuid import UUID
from decimal import Decimal
from datetime import datetime
from pydantic import BaseModel, ConfigDict


class OrderItemRequest(BaseModel):
    product_id: UUID
    name: str
    price: Decimal
    quantity: int


class CreateOrderRequest(BaseModel):
    items: list[OrderItemRequest]
    street: str
    city: str
    zip_code: str


class OrderItemResponse(BaseModel):
    product_id: UUID
    product_name: str
    quantity: int


class OrderResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: UUID
    status: str
    items: list[OrderItemResponse]
    created_at: datetime
```

```python
# src/app/order/infrastructure/api/router.py
from uuid import UUID
from fastapi import APIRouter, Depends, status

from app.order.application.commands import CreateOrderCommand, CancelOrderCommand
from app.order.application.queries import GetOrderQuery, ListCustomerOrdersQuery
from app.order.infrastructure.api.schemas import CreateOrderRequest, OrderResponse
from app.order.infrastructure.api.dependencies import (
    get_create_order_handler,
    get_cancel_order_handler,
    get_get_order_handler,
    get_current_user_id,
)

router = APIRouter(prefix="/orders", tags=["orders"])


@router.post("", status_code=status.HTTP_201_CREATED)
async def create_order(
    body: CreateOrderRequest,
    customer_id: UUID = Depends(get_current_user_id),
    handler=Depends(get_create_order_handler),
):
    cmd = CreateOrderCommand(
        customer_id=customer_id,
        items=[item.model_dump() for item in body.items],
        street=body.street,
        city=body.city,
        zip_code=body.zip_code,
    )
    order_id = await handler.handle(cmd)
    return {"id": str(order_id)}


@router.get("/{order_id}", response_model=OrderResponse)
async def get_order(
    order_id: UUID,
    handler=Depends(get_get_order_handler),
):
    query = GetOrderQuery(order_id=order_id)
    return await handler.handle(query)


@router.post("/{order_id}/cancel", status_code=status.HTTP_204_NO_CONTENT)
async def cancel_order(
    order_id: UUID,
    reason: str = "",
    handler=Depends(get_cancel_order_handler),
):
    cmd = CancelOrderCommand(order_id=order_id, reason=reason)
    await handler.handle(cmd)
```

---

## DI 컨테이너 (dependency-injector)

```python
# src/app/container.py
from dependency_injector import containers, providers
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker

from app.shared.config import Settings
from app.shared.event_bus import EventBus
from app.order.infrastructure.unit_of_work import SqlAlchemyOrderUnitOfWork
from app.order.application.command_handlers import CreateOrderHandler, CancelOrderHandler
from app.order.application.query_handlers import GetOrderHandler


class Container(containers.DeclarativeContainer):
    config = providers.Singleton(Settings)

    db_engine = providers.Singleton(
        create_async_engine,
        url=config.provided.database_url,
    )
    session_factory = providers.Singleton(
        async_sessionmaker,
        bind=db_engine,
    )

    event_bus = providers.Singleton(EventBus)

    # Unit of Work
    order_uow = providers.Factory(
        SqlAlchemyOrderUnitOfWork,
        session_factory=session_factory,
    )

    # Command Handlers
    create_order_handler = providers.Factory(
        CreateOrderHandler,
        uow=order_uow,
        event_bus=event_bus,
    )
    cancel_order_handler = providers.Factory(
        CancelOrderHandler,
        uow=order_uow,
        event_bus=event_bus,
    )

    # Query Handlers
    get_order_handler = providers.Factory(
        GetOrderHandler,
        uow=order_uow,
    )
```

---

## 테스트 전략

### 도메인 단위 테스트 (외부 의존성 없음)

```python
# tests/unit/order/test_domain.py
import pytest
from uuid import uuid4
from decimal import Decimal

from app.order.domain.models import Order
from app.order.domain.value_objects import Money, OrderStatus
from app.order.domain.exceptions import InvalidOrderTransitionError


def test_order_add_item_and_confirm():
    order = Order(customer_id=uuid4())
    order.add_item(uuid4(), "상품A", Money(Decimal("10000")), 2)
    order.add_item(uuid4(), "상품B", Money(Decimal("5000")), 1)

    assert order.total == Money(Decimal("25000"))
    order.confirm()
    assert order.status == OrderStatus.CONFIRMED

    events = order.collect_events()
    assert len(events) == 1
    assert events[0].order_id == order.id


def test_empty_order_cannot_confirm():
    order = Order(customer_id=uuid4())
    with pytest.raises(InvalidOrderTransitionError):
        order.confirm()


def test_confirmed_order_cannot_add_item():
    order = Order(customer_id=uuid4())
    order.add_item(uuid4(), "상품A", Money(Decimal("10000")), 1)
    order.confirm()

    with pytest.raises(InvalidOrderTransitionError):
        order.add_item(uuid4(), "상품B", Money(Decimal("5000")), 1)


def test_money_different_currency():
    krw = Money(Decimal("1000"), "KRW")
    usd = Money(Decimal("1"), "USD")
    with pytest.raises(ValueError):
        krw + usd


def test_order_status_transitions():
    assert OrderStatus.PENDING.can_transition_to(OrderStatus.CONFIRMED)
    assert not OrderStatus.DELIVERED.can_transition_to(OrderStatus.CANCELLED)
```

### Command Handler 단위 테스트

```python
# tests/unit/order/test_command_handlers.py
import pytest
from unittest.mock import AsyncMock, MagicMock
from uuid import uuid4
from decimal import Decimal

from app.order.application.commands import CreateOrderCommand
from app.order.application.command_handlers import CreateOrderHandler


@pytest.fixture
def mock_uow():
    uow = AsyncMock()
    uow.orders = AsyncMock()
    uow.__aenter__ = AsyncMock(return_value=uow)
    uow.__aexit__ = AsyncMock(return_value=False)
    return uow


@pytest.fixture
def mock_event_bus():
    return AsyncMock()


@pytest.mark.anyio
async def test_create_order(mock_uow, mock_event_bus):
    handler = CreateOrderHandler(mock_uow, mock_event_bus)
    cmd = CreateOrderCommand(
        customer_id=uuid4(),
        items=[{"product_id": uuid4(), "name": "상품", "price": "10000", "quantity": 2}],
        street="강남대로 1",
        city="서울",
        zip_code="06000",
    )

    order_id = await handler.handle(cmd)

    assert order_id is not None
    mock_uow.orders.save.assert_called_once()
    mock_uow.commit.assert_called_once()
    mock_event_bus.publish.assert_called()
```

---

## 의존성 규칙 (엄격 준수)

```
┌─────────────────────────────────────────┐
│            Interfaces (API)             │  ← FastAPI, Pydantic
├─────────────────────────────────────────┤
│          Infrastructure (DB)            │  ← SQLAlchemy, PostgreSQL
├─────────────────────────────────────────┤
│          Application (Use Cases)        │  ← 순수 Python, ABC 인터페이스만
├─────────────────────────────────────────┤
│          Domain (Business Rules)        │  ← 순수 Python, 외부 import 금지
└─────────────────────────────────────────┘

의존성 방향: Interfaces → Infrastructure → Application → Domain
Domain은 아무것도 import하지 않는다.
```

| 레이어 | 허용 import | 금지 import |
|--------|------------|------------|
| Domain | 표준 라이브러리만 | FastAPI, SQLAlchemy, Pydantic |
| Application | Domain | FastAPI, SQLAlchemy |
| Infrastructure | Domain, Application, 외부 라이브러리 | - |
| Interfaces (API) | Application (Command/Query), Pydantic | Domain 모델 직접 반환 |

---

## 대규모에서 반드시 지켜야 할 것

| 규칙 | 설명 |
|------|------|
| Domain 레이어 순수성 | `from sqlalchemy`, `from fastapi` 절대 금지 |
| Aggregate 경계 | Aggregate 간 직접 참조 금지, ID로만 참조 |
| 이벤트로 Context 간 통신 | Order → User 직접 호출 X, 이벤트 발행 |
| Imperative Mapping | 도메인 모델에 `@mapper` 데코레이터 사용 금지 |
| UoW로 트랜잭션 관리 | `db.commit()`을 Repository에서 호출하지 않음 |
| Command/Query 분리 | 쓰기와 읽기 경로를 명확히 구분 |
