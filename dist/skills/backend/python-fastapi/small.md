# Python / FastAPI - 소규모 프로젝트 가이드

> 엔드포인트 50개 이하, MVP/내부 툴/단일 마이크로서비스

---

## 핵심 원칙

- **도메인 폴더 + 플랫 파일**: 도메인별 폴더 안에 router, service, models, schemas를 같은 레벨에 배치
- **Service 레이어 사용**: 라우터는 요청/응답만, 비즈니스 로직은 Service에 위임
- **Pydantic v2**: 모든 요청/응답에 모델 사용, 검증은 Pydantic에 위임
- **`Depends()` DI**: 설정, DB 세션, 현재 유저 등을 의존성 주입으로 관리
- **공통 코드는 `common/`에**: 예외, 공통 의존성 등 도메인 횡단 코드를 한 곳에 관리

---

## 디렉토리 구조

```
project/
├── app/
│   ├── __init__.py
│   ├── main.py                  # FastAPI 앱 생성, 라우터 등록
│   ├── config.py                # 환경 설정
│   ├── database.py              # DB 엔진, 세션
│   │
│   ├── user/
│   │   ├── __init__.py
│   │   ├── router.py            # APIRouter
│   │   ├── service.py           # 비즈니스 로직
│   │   ├── models.py            # SQLAlchemy 모델
│   │   ├── schemas.py           # Pydantic 스키마
│   │   └── dependencies.py      # Depends
│   │
│   ├── order/
│   │   ├── __init__.py
│   │   ├── router.py
│   │   ├── service.py
│   │   ├── models.py
│   │   └── schemas.py
│   │
│   └── common/
│       ├── __init__.py
│       ├── exceptions.py        # 공통 예외
│       ├── exception_handlers.py
│       └── dependencies.py      # 공통 Depends (get_db)
│
├── alembic/
├── tests/
│   ├── conftest.py
│   ├── user/
│   │   └── test_router.py
│   └── order/
│       └── test_router.py
├── pyproject.toml
└── .env
```

---

## 설정 관리

```python
# app/config.py
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "sqlite+aiosqlite:///./app.db"
    secret_key: str = "change-me"
    debug: bool = False
    cors_origins: list[str] = ["http://localhost:3000"]

    model_config = {"env_file": ".env", "env_file_encoding": "utf-8"}


settings = Settings()
```

---

## 데이터베이스 설정 (SQLAlchemy Async)

```python
# app/database.py
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

from app.config import settings

engine = create_async_engine(settings.database_url, echo=settings.debug)
async_session = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


class Base(DeclarativeBase):
    pass
```

---

## 공통 모듈

### 공통 의존성

```python
# app/common/dependencies.py
from typing import Annotated
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import async_session


async def get_db():
    async with async_session() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise


DbSession = Annotated[AsyncSession, Depends(get_db)]
```

### 공통 예외

```python
# app/common/exceptions.py
class AppException(Exception):
    """애플리케이션 기본 예외."""

    def __init__(self, detail: str, code: str, status_code: int = 400):
        self.detail = detail
        self.code = code
        self.status_code = status_code


class NotFoundException(AppException):
    def __init__(self, detail: str = "리소스를 찾을 수 없습니다"):
        super().__init__(detail=detail, code="not_found", status_code=404)


class ConflictException(AppException):
    def __init__(self, detail: str = "이미 존재하는 리소스입니다"):
        super().__init__(detail=detail, code="conflict", status_code=409)
```

### 예외 핸들러

```python
# app/common/exception_handlers.py
from fastapi import Request, HTTPException
from fastapi.responses import JSONResponse

from app.common.exceptions import AppException


async def app_exception_handler(request: Request, exc: AppException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "type": f"https://api.example.com/errors/{exc.code}",
            "title": exc.detail,
            "status": exc.status_code,
        },
    )


async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "type": f"https://api.example.com/errors/{exc.status_code}",
            "title": exc.detail,
            "status": exc.status_code,
        },
    )


async def unhandled_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={
            "type": "https://api.example.com/errors/internal",
            "title": "서버 내부 오류가 발생했습니다",
            "status": 500,
        },
    )
```

---

## 도메인 예시: User

### 모델

```python
# app/user/models.py
from datetime import datetime
from sqlalchemy import String, DateTime, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True)
    name: Mapped[str] = mapped_column(String(100))
    hashed_password: Mapped[str] = mapped_column(String(255))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
```

### 스키마 (Pydantic v2)

```python
# app/user/schemas.py
from datetime import datetime
from pydantic import BaseModel, EmailStr, ConfigDict


class UserCreate(BaseModel):
    email: EmailStr
    name: str
    password: str


class UserUpdate(BaseModel):
    name: str | None = None
    password: str | None = None


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    name: str
    created_at: datetime
```

### 서비스

```python
# app/user/service.py
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.user.models import User
from app.user.schemas import UserCreate, UserUpdate
from app.common.exceptions import NotFoundException, ConflictException


async def create_user(db: AsyncSession, body: UserCreate) -> User:
    """사용자를 생성한다. 이메일 중복 시 ConflictException."""
    stmt = select(User).where(User.email == body.email)
    result = await db.execute(stmt)
    if result.scalar_one_or_none():
        raise ConflictException("이미 등록된 이메일입니다")

    user = User(
        email=body.email,
        name=body.name,
        hashed_password=hash_password(body.password),  # 구현 필요
    )
    db.add(user)
    await db.flush()
    return user


async def get_user(db: AsyncSession, user_id: int) -> User:
    """ID로 사용자를 조회한다. 없으면 NotFoundException."""
    user = await db.get(User, user_id)
    if not user:
        raise NotFoundException("사용자를 찾을 수 없습니다")
    return user


async def list_users(
    db: AsyncSession, skip: int = 0, limit: int = 20
) -> list[User]:
    """사용자 목록을 조회한다."""
    stmt = select(User).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return list(result.scalars().all())


async def update_user(
    db: AsyncSession, user_id: int, body: UserUpdate
) -> User:
    """사용자 정보를 수정한다."""
    user = await get_user(db, user_id)
    update_data = body.model_dump(exclude_unset=True)

    if "password" in update_data:
        update_data["hashed_password"] = hash_password(update_data.pop("password"))

    for key, value in update_data.items():
        setattr(user, key, value)

    await db.flush()
    return user
```

### 라우터

```python
# app/user/router.py
from fastapi import APIRouter, status

from app.common.dependencies import DbSession
from app.user import service
from app.user.schemas import UserCreate, UserUpdate, UserResponse

router = APIRouter(prefix="/users", tags=["users"])


@router.post("", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(body: UserCreate, db: DbSession):
    return await service.create_user(db, body)


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(user_id: int, db: DbSession):
    return await service.get_user(db, user_id)


@router.get("", response_model=list[UserResponse])
async def list_users(db: DbSession, skip: int = 0, limit: int = 20):
    return await service.list_users(db, skip, limit)


@router.patch("/{user_id}", response_model=UserResponse)
async def update_user(user_id: int, body: UserUpdate, db: DbSession):
    return await service.update_user(db, user_id, body)
```

### 도메인 의존성 (필요 시)

```python
# app/user/dependencies.py
from typing import Annotated
from fastapi import Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from app.common.dependencies import DbSession
from app.user.models import User
from app.common.exceptions import AppException

security = HTTPBearer()


async def get_current_user(
    db: DbSession,
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)],
) -> User:
    """JWT 토큰에서 현재 사용자를 추출한다."""
    token = credentials.credentials
    user_id = decode_token(token)  # 구현 필요
    if not user_id:
        raise AppException(
            detail="유효하지 않은 토큰입니다",
            code="unauthorized",
            status_code=401,
        )
    user = await db.get(User, user_id)
    if not user:
        raise AppException(
            detail="사용자를 찾을 수 없습니다",
            code="unauthorized",
            status_code=401,
        )
    return user
```

---

## 도메인 예시: Order

### 모델

```python
# app/order/models.py
from datetime import datetime
from sqlalchemy import String, Integer, DateTime, ForeignKey, func
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    product_name: Mapped[str] = mapped_column(String(200))
    quantity: Mapped[int] = mapped_column(Integer, default=1)
    status: Mapped[str] = mapped_column(String(20), default="pending")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
```

### 스키마

```python
# app/order/schemas.py
from datetime import datetime
from pydantic import BaseModel, ConfigDict


class OrderCreate(BaseModel):
    product_name: str
    quantity: int = 1


class OrderResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    user_id: int
    product_name: str
    quantity: int
    status: str
    created_at: datetime
```

### 서비스

```python
# app/order/service.py
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.order.models import Order
from app.order.schemas import OrderCreate
from app.common.exceptions import NotFoundException


async def create_order(
    db: AsyncSession, user_id: int, body: OrderCreate
) -> Order:
    """주문을 생성한다."""
    order = Order(
        user_id=user_id,
        product_name=body.product_name,
        quantity=body.quantity,
    )
    db.add(order)
    await db.flush()
    return order


async def get_order(db: AsyncSession, order_id: int) -> Order:
    """ID로 주문을 조회한다."""
    order = await db.get(Order, order_id)
    if not order:
        raise NotFoundException("주문을 찾을 수 없습니다")
    return order


async def list_orders_by_user(
    db: AsyncSession, user_id: int
) -> list[Order]:
    """특정 사용자의 주문 목록을 조회한다."""
    stmt = select(Order).where(Order.user_id == user_id)
    result = await db.execute(stmt)
    return list(result.scalars().all())
```

### 라우터

```python
# app/order/router.py
from fastapi import APIRouter, status

from app.common.dependencies import DbSession
from app.order import service
from app.order.schemas import OrderCreate, OrderResponse

router = APIRouter(prefix="/orders", tags=["orders"])


@router.post("", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
async def create_order(body: OrderCreate, db: DbSession, user_id: int = 1):
    # 실제로는 get_current_user에서 user_id를 가져온다
    return await service.create_order(db, user_id, body)


@router.get("/{order_id}", response_model=OrderResponse)
async def get_order(order_id: int, db: DbSession):
    return await service.get_order(db, order_id)


@router.get("", response_model=list[OrderResponse])
async def list_orders(db: DbSession, user_id: int = 1):
    return await service.list_orders_by_user(db, user_id)
```

---

## 메인 앱

```python
# app/main.py
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.database import engine, Base
from app.common.exceptions import AppException
from app.common.exception_handlers import (
    app_exception_handler,
    http_exception_handler,
    unhandled_exception_handler,
)
from app.user.router import router as user_router
from app.order.router import router as order_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 시작 시 테이블 생성 (개발용, 운영에선 alembic 사용)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


app = FastAPI(title="My API", lifespan=lifespan)

# --- 미들웨어 ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- 예외 핸들러 ---
app.add_exception_handler(AppException, app_exception_handler)
app.add_exception_handler(HTTPException, http_exception_handler)
app.add_exception_handler(Exception, unhandled_exception_handler)

# --- 라우터 등록 ---
app.include_router(user_router)
app.include_router(order_router)


@app.get("/health")
async def health():
    return {"status": "ok"}
```

---

## 테스트 (pytest + httpx)

### conftest

```python
# tests/conftest.py
import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.database import Base
from app.common.dependencies import get_db
from app.main import app

TEST_DB_URL = "sqlite+aiosqlite:///./test.db"
engine = create_async_engine(TEST_DB_URL)
TestSession = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


@pytest.fixture(autouse=True)
async def setup_db():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)


@pytest.fixture
async def db():
    async with TestSession() as session:
        yield session


@pytest.fixture
async def client(db):
    async def override_get_db():
        yield db

    app.dependency_overrides[get_db] = override_get_db
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as c:
        yield c
    app.dependency_overrides.clear()
```

### User 테스트

```python
# tests/user/test_router.py
import pytest


@pytest.mark.anyio
async def test_create_user(client):
    response = await client.post(
        "/users",
        json={"email": "test@example.com", "name": "테스트", "password": "secret123"},
    )
    assert response.status_code == 201
    data = response.json()
    assert data["email"] == "test@example.com"
    assert "id" in data


@pytest.mark.anyio
async def test_create_duplicate_user(client):
    payload = {"email": "dup@example.com", "name": "중복", "password": "secret123"}
    await client.post("/users", json=payload)
    response = await client.post("/users", json=payload)
    assert response.status_code == 409


@pytest.mark.anyio
async def test_get_user(client):
    res = await client.post(
        "/users",
        json={"email": "get@example.com", "name": "조회", "password": "secret123"},
    )
    user_id = res.json()["id"]
    response = await client.get(f"/users/{user_id}")
    assert response.status_code == 200
    assert response.json()["email"] == "get@example.com"


@pytest.mark.anyio
async def test_get_user_not_found(client):
    response = await client.get("/users/9999")
    assert response.status_code == 404


@pytest.mark.anyio
async def test_list_users(client):
    await client.post(
        "/users",
        json={"email": "a@example.com", "name": "A", "password": "secret123"},
    )
    response = await client.get("/users")
    assert response.status_code == 200
    assert len(response.json()) >= 1
```

### Order 테스트

```python
# tests/order/test_router.py
import pytest


@pytest.mark.anyio
async def test_create_order(client):
    response = await client.post(
        "/orders",
        json={"product_name": "키보드", "quantity": 2},
    )
    assert response.status_code == 201
    data = response.json()
    assert data["product_name"] == "키보드"
    assert data["quantity"] == 2


@pytest.mark.anyio
async def test_get_order(client):
    res = await client.post(
        "/orders",
        json={"product_name": "마우스"},
    )
    order_id = res.json()["id"]
    response = await client.get(f"/orders/{order_id}")
    assert response.status_code == 200


@pytest.mark.anyio
async def test_get_order_not_found(client):
    response = await client.get("/orders/9999")
    assert response.status_code == 404


@pytest.mark.anyio
async def test_health(client):
    response = await client.get("/health")
    assert response.status_code == 200
```

---

## 보안 체크리스트

- [x] CORS 설정 (허용 오리진 명시)
- [x] 비밀번호 해싱 (bcrypt/argon2)
- [x] 환경 변수로 시크릿 관리
- [ ] Rate Limiting (`slowapi` 패키지)
- [ ] HTTPS 강제 (프록시 뒤에서 `X-Forwarded-Proto` 확인)

---

## 필수 패키지 (pyproject.toml)

```toml
[project]
dependencies = [
    "fastapi>=0.110",
    "uvicorn[standard]>=0.29",
    "sqlalchemy[asyncio]>=2.0",
    "aiosqlite>=0.20",       # SQLite async (개발용)
    "asyncpg>=0.29",         # PostgreSQL async (운영용)
    "pydantic-settings>=2.0",
    "alembic>=1.13",
    "python-jose[cryptography]>=3.3",  # JWT
    "passlib[bcrypt]>=1.7",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "anyio[trio]>=4.0",
    "httpx>=0.27",
    "ruff>=0.4",
]
```

---

## 소규모에서 하지 말아야 할 것

| 안티패턴 | 이유 |
|----------|------|
| 레이어별 하위 폴더 분리 | `routers/`, `services/`, `models/` 식의 기술 분류는 도메인 응집도를 떨어뜨린다 |
| DI 컨테이너 (dependency-injector) | `Depends()`로 충분 |
| 도메인 이벤트 | 직접 함수 호출이 더 명확 |
| 멀티 패키지 구조 | 단일 `app/` 패키지로 충분 |

---

## 전환 시그널

다음 조건이 나타나면 중규모 아키텍처(Repository 패턴, 유스케이스 분리 등)로 전환을 검토한다:

- 도메인 폴더 안 파일이 **10개를 넘기기** 시작할 때
- Service 하나가 **200줄 이상**으로 커질 때
- **외부 시스템 연동**(결제, 알림, 서드파티 API)이 생길 때
