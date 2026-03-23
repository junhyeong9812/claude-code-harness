# Python / FastAPI - 중규모 프로젝트 가이드

> 팀 3~8명, 엔드포인트 20~100개, 성장하는 서비스

---

## 핵심 원칙

- **3-Layer**: Endpoint(Router) → Service → Repository
- **APIRouter 분리**: 도메인/기능별 라우터 모듈
- **커스텀 예외 계층**: HTTP에 의존하지 않는 비즈니스 예외
- **Repository 패턴**: DB 접근 로직 캡슐화
- **팩토리 패턴 테스트**: `factory_boy`로 테스트 데이터 생성

---

## 디렉토리 구조

```
project/
├── app/
│   ├── __init__.py
│   ├── main.py                  # FastAPI 앱 생성, 라우터/미들웨어 등록
│   ├── config.py                # pydantic-settings
│   ├── database.py              # 엔진, 세션, Base
│   ├── exceptions.py            # 커스텀 예외 계층
│   ├── exception_handlers.py    # FastAPI 예외 핸들러
│   ├── middleware.py             # 로깅, 요청 ID 등
│   ├── dependencies.py          # 공통 Depends
│   │
│   ├── users/                   # 도메인: 사용자
│   │   ├── __init__.py
│   │   ├── router.py            # APIRouter 엔드포인트
│   │   ├── service.py           # 비즈니스 로직
│   │   ├── repository.py        # DB 접근
│   │   ├── models.py            # SQLAlchemy 모델
│   │   ├── schemas.py           # Pydantic 스키마
│   │   └── dependencies.py      # 이 도메인 전용 Depends
│   │
│   ├── orders/                  # 도메인: 주문
│   │   ├── __init__.py
│   │   ├── router.py
│   │   ├── service.py
│   │   ├── repository.py
│   │   ├── models.py
│   │   └── schemas.py
│   │
│   └── shared/                  # 공유 유틸리티
│       ├── __init__.py
│       ├── pagination.py
│       └── security.py
│
├── alembic/
│   └── versions/
├── tests/
│   ├── conftest.py
│   ├── factories.py             # factory_boy 팩토리
│   ├── users/
│   │   ├── test_router.py
│   │   └── test_service.py
│   └── orders/
│       ├── test_router.py
│       └── test_service.py
├── pyproject.toml
└── .env
```

---

## 커스텀 예외 계층

```python
# app/exceptions.py
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
# app/exception_handlers.py
from fastapi import Request
from fastapi.responses import JSONResponse

from app.exceptions import AppError, NotFoundError, ConflictError, ValidationError, AuthorizationError

STATUS_MAP = {
    NotFoundError: 404,
    ConflictError: 409,
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

## Repository 패턴

```python
# app/users/repository.py
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.users.models import User


class UserRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def find_by_id(self, user_id: int) -> User | None:
        return await self.db.get(User, user_id)

    async def find_by_email(self, email: str) -> User | None:
        stmt = select(User).where(User.email == email)
        result = await self.db.execute(stmt)
        return result.scalar_one_or_none()

    async def find_all(self, *, skip: int = 0, limit: int = 20) -> list[User]:
        stmt = select(User).offset(skip).limit(limit)
        result = await self.db.execute(stmt)
        return list(result.scalars().all())

    async def save(self, user: User) -> User:
        self.db.add(user)
        await self.db.flush()
        await self.db.refresh(user)
        return user

    async def delete(self, user: User) -> None:
        await self.db.delete(user)
```

---

## Service 레이어

```python
# app/users/service.py
from app.exceptions import NotFoundError, ConflictError
from app.users.models import User
from app.users.repository import UserRepository
from app.users.schemas import UserCreate, UserUpdate
from app.shared.security import hash_password


class UserService:
    def __init__(self, repo: UserRepository):
        self.repo = repo

    async def create_user(self, dto: UserCreate) -> User:
        existing = await self.repo.find_by_email(dto.email)
        if existing:
            raise ConflictError(message="이미 등록된 이메일입니다")

        user = User(
            email=dto.email,
            name=dto.name,
            hashed_password=hash_password(dto.password),
        )
        return await self.repo.save(user)

    async def get_user(self, user_id: int) -> User:
        user = await self.repo.find_by_id(user_id)
        if not user:
            raise NotFoundError(message="", resource="사용자")
        return user

    async def update_user(self, user_id: int, dto: UserUpdate) -> User:
        user = await self.get_user(user_id)
        for field, value in dto.model_dump(exclude_unset=True).items():
            setattr(user, field, value)
        return await self.repo.save(user)

    async def list_users(self, skip: int = 0, limit: int = 20) -> list[User]:
        return await self.repo.find_all(skip=skip, limit=limit)
```

---

## 의존성 조립 (Depends 체이닝)

```python
# app/users/dependencies.py
from typing import Annotated
from fastapi import Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.users.repository import UserRepository
from app.users.service import UserService


def get_user_repository(
    db: Annotated[AsyncSession, Depends(get_db)],
) -> UserRepository:
    return UserRepository(db)


def get_user_service(
    repo: Annotated[UserRepository, Depends(get_user_repository)],
) -> UserService:
    return UserService(repo)


# 타입 별칭
UserServiceDep = Annotated[UserService, Depends(get_user_service)]
```

---

## Router (엔드포인트)

```python
# app/users/router.py
from fastapi import APIRouter, status
from app.users.dependencies import UserServiceDep
from app.users.schemas import UserCreate, UserResponse

router = APIRouter(prefix="/users", tags=["users"])


@router.post("", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(body: UserCreate, service: UserServiceDep):
    user = await service.create_user(body)
    return user


@router.get("/{user_id}", response_model=UserResponse)
async def get_user(user_id: int, service: UserServiceDep):
    return await service.get_user(user_id)


@router.get("", response_model=list[UserResponse])
async def list_users(service: UserServiceDep, skip: int = 0, limit: int = 20):
    return await service.list_users(skip=skip, limit=limit)
```

---

## 앱 등록

```python
# app/main.py
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.exception_handlers import register_exception_handlers
from app.middleware import RequestIdMiddleware
from app.users.router import router as users_router
from app.orders.router import router as orders_router

app = FastAPI(title="My Service")

# 미들웨어
app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins,
                   allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.add_middleware(RequestIdMiddleware)

# 예외 핸들러
register_exception_handlers(app)

# 라우터
app.include_router(users_router, prefix="/api/v1")
app.include_router(orders_router, prefix="/api/v1")


@app.get("/health")
async def health():
    return {"status": "ok"}
```

---

## 미들웨어 (요청 ID + 로깅)

```python
# app/middleware.py
import uuid
import time
import logging
import structlog
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request

logger = structlog.get_logger()


class RequestIdMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        request_id = request.headers.get("X-Request-ID", str(uuid.uuid4()))
        request.state.request_id = request_id

        start = time.perf_counter()
        response = await call_next(request)
        elapsed = time.perf_counter() - start

        logger.info(
            "request_completed",
            method=request.method,
            path=request.url.path,
            status=response.status_code,
            duration_ms=round(elapsed * 1000, 2),
            request_id=request_id,
        )
        response.headers["X-Request-ID"] = request_id
        return response
```

---

## 테스트 (factory_boy)

```python
# tests/factories.py
import factory
from app.users.models import User


class UserFactory(factory.Factory):
    class Meta:
        model = User

    id = factory.Sequence(lambda n: n + 1)
    email = factory.LazyAttribute(lambda o: f"user{o.id}@example.com")
    name = factory.Faker("name", locale="ko_KR")
    hashed_password = "hashed_dummy"
```

```python
# tests/users/test_service.py
import pytest
from unittest.mock import AsyncMock

from app.users.service import UserService
from app.users.schemas import UserCreate
from app.exceptions import ConflictError, NotFoundError
from tests.factories import UserFactory


@pytest.fixture
def mock_repo():
    repo = AsyncMock()
    return repo


@pytest.fixture
def service(mock_repo):
    return UserService(mock_repo)


@pytest.mark.anyio
async def test_create_user_success(service, mock_repo):
    mock_repo.find_by_email.return_value = None
    mock_repo.save.return_value = UserFactory(email="new@test.com")

    dto = UserCreate(email="new@test.com", name="테스트", password="pass123")
    user = await service.create_user(dto)

    assert user.email == "new@test.com"
    mock_repo.save.assert_called_once()


@pytest.mark.anyio
async def test_create_user_duplicate_email(service, mock_repo):
    mock_repo.find_by_email.return_value = UserFactory()

    dto = UserCreate(email="dup@test.com", name="중복", password="pass123")
    with pytest.raises(ConflictError):
        await service.create_user(dto)


@pytest.mark.anyio
async def test_get_user_not_found(service, mock_repo):
    mock_repo.find_by_id.return_value = None

    with pytest.raises(NotFoundError):
        await service.get_user(9999)
```

```python
# tests/users/test_router.py (통합 테스트)
import pytest


@pytest.mark.anyio
async def test_create_and_get_user(client):
    # 생성
    res = await client.post(
        "/api/v1/users",
        json={"email": "int@test.com", "name": "통합", "password": "pass123"},
    )
    assert res.status_code == 201
    user_id = res.json()["id"]

    # 조회
    res = await client.get(f"/api/v1/users/{user_id}")
    assert res.status_code == 200
    assert res.json()["email"] == "int@test.com"
```

---

## 페이지네이션 공통 유틸

```python
# app/shared/pagination.py
from pydantic import BaseModel, Field
from typing import Generic, TypeVar, Sequence

T = TypeVar("T")


class PaginationParams(BaseModel):
    skip: int = Field(0, ge=0)
    limit: int = Field(20, ge=1, le=100)


class PaginatedResponse(BaseModel, Generic[T]):
    items: Sequence[T]
    total: int
    skip: int
    limit: int
```

---

## 중규모에서 지켜야 할 규칙

| 규칙 | 설명 |
|------|------|
| Router는 얇게 | 검증과 변환만 수행, 비즈니스 로직은 Service |
| Service는 Repository만 의존 | 다른 Service 의존 시 순환 주의 |
| 예외는 비즈니스 언어로 | `HTTPException` 대신 `NotFoundError`, `ConflictError` |
| 테스트는 Service 단위 우선 | Mock Repository로 빠른 단위 테스트 |
| 모델과 스키마 분리 | SQLAlchemy 모델 =/= Pydantic 스키마 |
