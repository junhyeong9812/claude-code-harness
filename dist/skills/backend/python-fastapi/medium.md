# Python / FastAPI - 중규모 프로젝트 가이드

> 엔드포인트 50~100개, 성장하는 서비스

---

## 핵심 원칙

- **도메인 모듈 분리**: `global/` (횡단 관심사) + 도메인별 4-Layer 모듈
- **4-Layer 아키텍처**: `api → application → domain ← infrastructure`
- **의존성 방향**: domain 레이어는 어디에도 의존하지 않는다. infrastructure가 domain을 구현한다.
- **Repository 인터페이스**: domain에 Protocol/ABC, infrastructure에 구현체
- **커스텀 예외 계층**: HTTP에 의존하지 않는 비즈니스 예외
- **단순 CRUD 도메인은 flat 유지**: 모든 도메인에 4-Layer를 강제하지 않는다
- **한 레이어에 파일 4개 이상이면 서브 폴더 허용**

---

## 의존성 방향

```
api → application → domain ← infrastructure
```

- `api`: HTTP 요청/응답 처리, DTO 변환, Depends 조립
- `application`: 유스케이스 (비즈니스 흐름 조합)
- `domain`: 모델, 리포지토리 인터페이스, 비즈니스 규칙 (순수 Python)
- `infrastructure`: 리포지토리 구현, 외부 API 클라이언트

**domain은 다른 레이어를 import하지 않는다.** infrastructure가 domain의 인터페이스를 구현하고, application이 domain의 인터페이스에 의존한다.

---

## 디렉토리 구조

```
project/
├── app/
│   ├── __init__.py
│   ├── main.py                         # FastAPI 앱 생성, 라우터/미들웨어 등록
│   │
│   ├── global_/                        # Python에서 global은 예약어이므로 global_
│   │   ├── __init__.py
│   │   ├── exception/
│   │   │   ├── exceptions.py           # AppError, NotFoundError 등
│   │   │   └── handlers.py             # FastAPI exception handlers
│   │   ├── config/
│   │   │   └── settings.py             # pydantic-settings
│   │   ├── auth/
│   │   │   └── jwt.py
│   │   ├── middleware/
│   │   │   └── request_id.py
│   │   ├── database.py
│   │   └── domain/
│   │       ├── money.py                # 공유 Value Object
│   │       └── base_model.py           # SQLAlchemy Base, TimestampMixin 등
│   │
│   ├── order/                          # 도메인 모듈: 4-Layer
│   │   ├── __init__.py
│   │   ├── api/
│   │   │   ├── router.py              # APIRouter
│   │   │   ├── dependencies.py        # Depends for this domain
│   │   │   └── dto/                   # 파일 4개 이상 → 서브 폴더
│   │   │       ├── requests.py
│   │   │       └── responses.py
│   │   ├── application/
│   │   │   ├── create_order.py        # UseCase
│   │   │   ├── cancel_order.py
│   │   │   └── search_orders.py
│   │   ├── domain/
│   │   │   ├── models.py              # SQLAlchemy model
│   │   │   ├── order_status.py        # Enum, 비즈니스 규칙
│   │   │   └── repository.py          # Repository interface (ABC or Protocol)
│   │   └── infrastructure/
│   │       ├── sqlalchemy_repo.py     # Repository 구현체
│   │       └── payment_client.py      # 외부 API 클라이언트
│   │
│   ├── user/                           # 도메인 모듈: 4-Layer (DTO 적으면 flat)
│   │   ├── __init__.py
│   │   ├── api/
│   │   │   ├── router.py
│   │   │   ├── dependencies.py
│   │   │   ├── requests.py            # DTO 적으면 서브 폴더 없이 flat
│   │   │   └── responses.py
│   │   ├── application/
│   │   │   ├── create_user.py
│   │   │   └── user_mapper.py
│   │   ├── domain/
│   │   │   ├── models.py
│   │   │   └── repository.py
│   │   └── infrastructure/
│   │       └── sqlalchemy_repo.py
│   │
│   └── notification/                   # 단순 CRUD → flat 유지
│       ├── router.py
│       ├── service.py
│       ├── models.py
│       └── schemas.py
│
├── alembic/
├── tests/
│   ├── conftest.py
│   ├── factories.py                    # factory_boy 팩토리
│   ├── unit/
│   │   └── order/
│   │       └── test_create_order.py
│   └── integration/
│       └── test_order_api.py
├── pyproject.toml
└── .env
```

### 구조 결정 기준

| 기준 | flat 유지 | 4-Layer 분리 |
|------|-----------|-------------|
| CRUD만 있는 도메인 | O | |
| 비즈니스 로직이 있는 도메인 | | O |
| 외부 API 연동이 있는 도메인 | | O |
| 레이어 내 파일 수 | 3개 이하 flat | 4개 이상 서브 폴더 |

---

## global_ — 횡단 관심사 + 공유 도메인 객체

`global_`은 모든 도메인 모듈이 공유하는 코드를 모은다. 기존 `core/`, `shared/`, `common/`을 하나로 통합한다.

| 서브 패키지 | 역할 |
|------------|------|
| `exception/` | 커스텀 예외 계층 + FastAPI 핸들러 |
| `config/` | pydantic-settings 기반 설정 |
| `auth/` | JWT, 인증 관련 |
| `middleware/` | 요청 ID, 로깅 미들웨어 |
| `domain/` | 공유 Value Object (Money 등), SQLAlchemy Base |
| `database.py` | 엔진, 세션 팩토리 |

---

## 커스텀 예외 계층

```python
# app/global_/exception/exceptions.py
from dataclasses import dataclass


@dataclass
class AppError(Exception):
    """모든 비즈니스 예외의 기본 클래스. HTTP와 무관하다."""
    message: str
    code: str = "APP_ERROR"


@dataclass
class NotFoundError(AppError):
    """리소스를 찾을 수 없음."""
    code: str = "NOT_FOUND"
    resource: str = ""

    def __post_init__(self):
        if not self.message and self.resource:
            self.message = f"{self.resource}을(를) 찾을 수 없습니다"


@dataclass
class ConflictError(AppError):
    """리소스 충돌 (중복 등)."""
    code: str = "CONFLICT"


@dataclass
class BusinessRuleError(AppError):
    """비즈니스 규칙 위반."""
    code: str = "BUSINESS_RULE_VIOLATION"


@dataclass
class ValidationError(AppError):
    """비즈니스 규칙 검증 실패."""
    code: str = "VALIDATION_ERROR"
    field: str = ""


@dataclass
class AuthorizationError(AppError):
    """권한 없음."""
    code: str = "FORBIDDEN"
```

---

## 예외 핸들러 (HTTP 매핑)

```python
# app/global_/exception/handlers.py
from fastapi import Request
from fastapi.responses import JSONResponse

from app.global_.exception.exceptions import (
    AppError, NotFoundError, ConflictError,
    BusinessRuleError, ValidationError, AuthorizationError,
)

STATUS_MAP = {
    NotFoundError: 404,
    ConflictError: 409,
    BusinessRuleError: 422,
    ValidationError: 422,
    AuthorizationError: 403,
}


def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
    status_code = STATUS_MAP.get(type(exc), 400)
    return JSONResponse(
        status_code=status_code,
        content={
            "type": f"https://api.example.com/errors/{exc.code.lower()}",
            "title": exc.message,
            "status": status_code,
            "code": exc.code,
        },
    )


def register_exception_handlers(app):
    app.add_exception_handler(AppError, app_error_handler)
```

---

## Domain 모델

```python
# app/order/domain/models.py
from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import String, Numeric, ForeignKey, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.global_.domain.base_model import Base, TimestampMixin
from app.order.domain.order_status import OrderStatus


class Order(Base, TimestampMixin):
    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    status: Mapped[OrderStatus] = mapped_column(
        SAEnum(OrderStatus), default=OrderStatus.PENDING,
    )
    total_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    note: Mapped[str | None] = mapped_column(String(500), default=None)

    items: Mapped[list[OrderItem]] = relationship(
        back_populates="order", cascade="all, delete-orphan",
    )

    def cancel(self) -> None:
        """비즈니스 규칙: 배송 시작 전에만 취소 가능."""
        if self.status not in (OrderStatus.PENDING, OrderStatus.CONFIRMED):
            from app.global_.exception.exceptions import BusinessRuleError
            raise BusinessRuleError(
                message=f"상태가 {self.status.value}인 주문은 취소할 수 없습니다",
            )
        self.status = OrderStatus.CANCELLED


class OrderItem(Base):
    __tablename__ = "order_items"

    id: Mapped[int] = mapped_column(primary_key=True)
    order_id: Mapped[int] = mapped_column(ForeignKey("orders.id"))
    product_name: Mapped[str] = mapped_column(String(200))
    quantity: Mapped[int]
    unit_price: Mapped[Decimal] = mapped_column(Numeric(12, 2))

    order: Mapped[Order] = relationship(back_populates="items")
```

```python
# app/order/domain/order_status.py
from enum import StrEnum


class OrderStatus(StrEnum):
    PENDING = "pending"
    CONFIRMED = "confirmed"
    SHIPPING = "shipping"
    DELIVERED = "delivered"
    CANCELLED = "cancelled"
```

```python
# app/global_/domain/base_model.py
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

---

## Repository 인터페이스 (domain) + 구현 (infrastructure)

domain에 인터페이스를 두고, infrastructure에서 구현한다. domain은 SQLAlchemy의 세션에 의존하지 않는다.

```python
# app/order/domain/repository.py
from abc import ABC, abstractmethod

from app.order.domain.models import Order


class OrderRepository(ABC):
    """주문 리포지토리 인터페이스. domain 레이어에 위치한다."""

    @abstractmethod
    async def find_by_id(self, order_id: int) -> Order | None: ...

    @abstractmethod
    async def find_by_user_id(
        self, user_id: int, *, skip: int = 0, limit: int = 20,
    ) -> list[Order]: ...

    @abstractmethod
    async def save(self, order: Order) -> Order: ...

    @abstractmethod
    async def delete(self, order: Order) -> None: ...
```

```python
# app/order/infrastructure/sqlalchemy_repo.py
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.order.domain.models import Order
from app.order.domain.repository import OrderRepository


class SqlAlchemyOrderRepository(OrderRepository):
    """OrderRepository의 SQLAlchemy 구현체. infrastructure 레이어에 위치한다."""

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

    async def find_by_user_id(
        self, user_id: int, *, skip: int = 0, limit: int = 20,
    ) -> list[Order]:
        stmt = (
            select(Order)
            .where(Order.user_id == user_id)
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

## UseCase (application 레이어)

UseCase는 비즈니스 흐름을 조합한다. 하나의 UseCase = 하나의 비즈니스 행위.

```python
# app/order/application/create_order.py
from decimal import Decimal

from app.global_.exception.exceptions import NotFoundError
from app.order.domain.models import Order, OrderItem
from app.order.domain.order_status import OrderStatus
from app.order.domain.repository import OrderRepository
from app.order.api.dto.requests import CreateOrderRequest


class CreateOrderUseCase:
    def __init__(
        self,
        order_repo: OrderRepository,
    ):
        self.order_repo = order_repo

    async def execute(self, user_id: int, dto: CreateOrderRequest) -> Order:
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
            user_id=user_id,
            status=OrderStatus.PENDING,
            total_amount=total,
            note=dto.note,
            items=items,
        )

        return await self.order_repo.save(order)
```

---

## DTO (Pydantic v2)

```python
# app/order/api/dto/requests.py
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
# app/order/api/dto/responses.py
from datetime import datetime
from decimal import Decimal

from pydantic import BaseModel

from app.order.domain.order_status import OrderStatus


class OrderItemResponse(BaseModel):
    id: int
    product_name: str
    quantity: int
    unit_price: Decimal

    model_config = {"from_attributes": True}


class OrderResponse(BaseModel):
    id: int
    user_id: int
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
# app/order/api/dependencies.py
from typing import Annotated

from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.global_.database import get_db
from app.order.domain.repository import OrderRepository
from app.order.infrastructure.sqlalchemy_repo import SqlAlchemyOrderRepository
from app.order.application.create_order import CreateOrderUseCase


def get_order_repository(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> OrderRepository:
    """infrastructure 구현체를 domain 인터페이스 타입으로 반환한다."""
    return SqlAlchemyOrderRepository(db)


def get_create_order_use_case(
    order_repo: Annotated[OrderRepository, Depends(get_order_repository)],
) -> CreateOrderUseCase:
    return CreateOrderUseCase(order_repo=order_repo)


# 타입 별칭: router에서 간결하게 사용
CreateOrderDep = Annotated[CreateOrderUseCase, Depends(get_create_order_use_case)]
```

**포인트**: `get_order_repository`가 반환 타입을 `OrderRepository`(인터페이스)로 선언한다. 구현체 교체 시 이 함수만 바꾸면 된다.

---

## Router (api 레이어)

```python
# app/order/api/router.py
from fastapi import APIRouter, status

from app.order.api.dependencies import CreateOrderDep
from app.order.api.dto.requests import CreateOrderRequest
from app.order.api.dto.responses import OrderResponse

router = APIRouter(prefix="/orders", tags=["orders"])


@router.post("", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
async def create_order(
    body: CreateOrderRequest,
    use_case: CreateOrderDep,
    user_id: int = 1,  # 실제로는 인증에서 추출
):
    order = await use_case.execute(user_id=user_id, dto=body)
    return order
```

---

## 앱 등록

```python
# app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.global_.config.settings import settings
from app.global_.exception.handlers import register_exception_handlers
from app.global_.middleware.request_id import RequestIdMiddleware
from app.order.api.router import router as order_router
from app.user.api.router import router as user_router
from app.notification.router import router as notification_router

app = FastAPI(title="My Service")

# 미들웨어
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(RequestIdMiddleware)

# 예외 핸들러
register_exception_handlers(app)

# 라우터
app.include_router(order_router, prefix="/api/v1")
app.include_router(user_router, prefix="/api/v1")
app.include_router(notification_router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok"}
```

---

## structlog 미들웨어

```python
# app/global_/middleware/request_id.py
import uuid
import time

import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

logger = structlog.get_logger()


class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        request.state.request_id = request_id

        # structlog에 request_id를 바인딩하여 이후 모든 로그에 자동 포함
        structlog.contextvars.clear_contextvars()
        structlog.contextvars.bind_contextvars(request_id=request_id)

        start = time.perf_counter()
        response = await call_next(request)
        elapsed = time.perf_counter() - start

        logger.info(
            "request_completed",
            method=request.method,
            path=request.url.path,
            status=response.status_code,
            duration_ms=round(elapsed * 1000, 2),
        )
        response.headers["X-Request-ID"] = request_id
        return response
```

---

## 테스트 — factory_boy 팩토리

```python
# tests/factories.py
import factory
from decimal import Decimal

from app.order.domain.models import Order, OrderItem
from app.order.domain.order_status import OrderStatus


class OrderItemFactory(factory.Factory):
    class Meta:
        model = OrderItem

    id = factory.Sequence(lambda n: n + 1)
    product_name = factory.Faker("word")
    quantity = factory.LazyFunction(lambda: 2)
    unit_price = Decimal("10000.00")


class OrderFactory(factory.Factory):
    class Meta:
        model = Order

    id = factory.Sequence(lambda n: n + 1)
    user_id = 1
    status = OrderStatus.PENDING
    total_amount = Decimal("20000.00")
    note = None
    items = factory.LazyFunction(list)
```

---

## 테스트 — 단위 테스트 (AsyncMock)

```python
# tests/unit/order/test_create_order.py
import pytest
from decimal import Decimal
from unittest.mock import AsyncMock

from app.order.application.create_order import CreateOrderUseCase
from app.order.api.dto.requests import CreateOrderRequest, OrderItemRequest
from tests.factories import OrderFactory


@pytest.fixture
def mock_repo():
    return AsyncMock()


@pytest.fixture
def use_case(mock_repo):
    return CreateOrderUseCase(order_repo=mock_repo)


@pytest.mark.anyio
async def test_create_order_success(use_case, mock_repo):
    # Given
    expected = OrderFactory(total_amount=Decimal("30000.00"))
    mock_repo.save.return_value = expected

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
    order = await use_case.execute(user_id=1, dto=dto)

    # Then
    assert order.total_amount == Decimal("30000.00")
    mock_repo.save.assert_called_once()
    saved_order = mock_repo.save.call_args[0][0]
    assert len(saved_order.items) == 1
    assert saved_order.note == "배송 메모"


@pytest.mark.anyio
async def test_create_order_calculates_total(use_case, mock_repo):
    # Given
    mock_repo.save.side_effect = lambda order: order

    dto = CreateOrderRequest(
        items=[
            OrderItemRequest(product_name="A", quantity=2, unit_price=Decimal("5000")),
            OrderItemRequest(product_name="B", quantity=1, unit_price=Decimal("3000")),
        ],
    )

    # When
    order = await use_case.execute(user_id=1, dto=dto)

    # Then: 2 * 5000 + 1 * 3000 = 13000
    assert order.total_amount == Decimal("13000")
```

---

## 테스트 — 통합 테스트

```python
# tests/integration/test_order_api.py
import pytest


@pytest.mark.anyio
async def test_create_and_get_order(client):
    # 주문 생성
    res = await client.post(
        "/api/v1/orders",
        json={
            "items": [
                {"product_name": "테스트", "quantity": 1, "unit_price": "10000.00"},
            ],
            "note": "통합 테스트",
        },
    )
    assert res.status_code == 201
    order_id = res.json()["id"]
    assert res.json()["status"] == "pending"

    # 주문 조회
    res = await client.get(f"/api/v1/orders/{order_id}")
    assert res.status_code == 200
    assert res.json()["note"] == "통합 테스트"
```

---

## 중규모에서 지켜야 할 규칙

| 규칙 | 설명 |
|------|------|
| domain은 외부 의존 금지 | domain 레이어는 FastAPI, SQLAlchemy 세션 등에 의존하지 않는다 (모델은 예외) |
| api는 얇게 | DTO 변환과 Depends 조립만 수행, 비즈니스 로직은 application |
| UseCase 1개 = 행위 1개 | `CreateOrderUseCase`, `CancelOrderUseCase`처럼 분리 |
| 예외는 비즈니스 언어로 | `HTTPException` 대신 `NotFoundError`, `BusinessRuleError` |
| infrastructure는 교체 가능하게 | Repository 인터페이스를 domain에, 구현을 infrastructure에 |
| 테스트는 UseCase 단위 우선 | Mock Repository로 빠른 단위 테스트 |
| 단순 CRUD는 flat | 모든 도메인에 4-Layer를 강제하면 보일러플레이트만 늘어난다 |
| 모듈 간 의존은 인터페이스를 통해 | 다른 모듈의 구현체를 직접 import하지 않는다 |

---

## 전환 시그널 — 대규모로 넘어가야 할 때

다음 시그널이 보이면 대규모 아키텍처(이벤트 기반, 모듈 경계 강제 등)로 전환을 검토한다:

- **모듈 간 직접 호출이 복잡하게 얽히기 시작할 때** — 한 모듈이 3개 이상의 다른 모듈을 직접 호출하거나, 순환 의존이 발생하면 이벤트 기반 통신이 필요하다.
- **팀이 15명 이상으로 커져서 모듈 경계 강제가 필요할 때** — 코드 리뷰만으로 모듈 경계를 지키기 어려우면, 아키텍처 레벨에서 강제해야 한다.
- **한 모듈의 변경이 다른 모듈에 사이드이펙트를 일으킬 때** — 주문 모듈 수정이 결제, 알림, 배송 모듈에 연쇄적으로 영향을 주면 결합도가 너무 높은 것이다.
