# Python / FastAPI - 소규모 프로젝트 가이드

> 팀 1~3명, 엔드포인트 20개 이하, MVP/내부 툴/단일 마이크로서비스

---

## 핵심 원칙

- **단일 `main.py` 중심**: 라우터 분리는 파일이 300줄 넘을 때만
- **Pydantic v2**: 모든 요청/응답에 모델 사용, 검증은 Pydantic에 위임
- **`Depends()` DI**: 설정, DB 세션, 현재 유저 등을 의존성 주입으로 관리
- **과도한 레이어링 금지**: Service 클래스 없이 라우터 함수에서 직접 처리 가능

---

## 디렉토리 구조

```
project/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI 앱, 라우터, 미들웨어 등록
│   ├── config.py            # 환경 설정 (pydantic-settings)
│   ├── database.py          # DB 엔진, 세션 팩토리
│   ├── models.py            # SQLAlchemy 모델
│   ├── schemas.py           # Pydantic 요청/응답 스키마
│   └── dependencies.py      # 공통 Depends (get_db, get_current_user)
├── alembic/                  # DB 마이그레이션
│   └── versions/
├── alembic.ini
├── tests/
│   ├── conftest.py
│   └── test_main.py
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


async def get_db():
    async with async_session() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
```

---

## 모델 정의

```python
# app/models.py
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

---

## Pydantic 스키마 (v2)

```python
# app/schemas.py
from datetime import datetime
from pydantic import BaseModel, EmailStr, ConfigDict


class UserCreate(BaseModel):
    email: EmailStr
    name: str
    password: str


class UserResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    email: str
    name: str
    created_at: datetime


class ErrorResponse(BaseModel):
    detail: str
    code: str | None = None
```

---

## 의존성 주입

```python
# app/dependencies.py
from typing import Annotated
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db

# 타입 별칭
DbSession = Annotated[AsyncSession, Depends(get_db)]

security = HTTPBearer()


async def get_current_user(
    db: DbSession,
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(security)],
):
    """JWT 토큰에서 현재 사용자를 추출한다."""
    token = credentials.credentials
    # JWT 디코딩 로직
    user_id = decode_token(token)  # 구현 필요
    if not user_id:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="유효하지 않은 토큰입니다",
        )
    # DB에서 사용자 조회
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    return user
```

---

## 메인 앱 및 라우터

```python
# app/main.py
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import select

from app.config import settings
from app.database import engine, Base
from app.dependencies import DbSession
from app.models import User
from app.schemas import UserCreate, UserResponse


@asynccontextmanager
async def lifespan(app: FastAPI):
    # 시작 시 테이블 생성 (개발용, 운영에선 alembic 사용)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    await engine.dispose()


app = FastAPI(title="My API", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# --- 헬스체크 ---
@app.get("/health")
async def health():
    return {"status": "ok"}


# --- 사용자 CRUD ---
@app.post("/users", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
async def create_user(body: UserCreate, db: DbSession):
    # 중복 검사
    stmt = select(User).where(User.email == body.email)
    result = await db.execute(stmt)
    if result.scalar_one_or_none():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="이미 등록된 이메일입니다",
        )

    user = User(
        email=body.email,
        name=body.name,
        hashed_password=hash_password(body.password),  # 구현 필요
    )
    db.add(user)
    await db.flush()
    return user


@app.get("/users/{user_id}", response_model=UserResponse)
async def get_user(user_id: int, db: DbSession):
    user = await db.get(User, user_id)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="사용자를 찾을 수 없습니다",
        )
    return user


@app.get("/users", response_model=list[UserResponse])
async def list_users(db: DbSession, skip: int = 0, limit: int = 20):
    stmt = select(User).offset(skip).limit(limit)
    result = await db.execute(stmt)
    return result.scalars().all()
```

---

## 에러 처리

```python
# app/main.py 에 추가
from fastapi import Request
from fastapi.responses import JSONResponse


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "type": f"https://api.example.com/errors/{exc.status_code}",
            "title": exc.detail,
            "status": exc.status_code,
        },
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    # 운영 환경에서는 상세 에러를 노출하지 않는다
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

## 테스트 (pytest + httpx)

```python
# tests/conftest.py
import pytest
from httpx import AsyncClient, ASGITransport
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession

from app.database import Base, get_db
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

```python
# tests/test_main.py
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
async def test_get_user_not_found(client):
    response = await client.get("/users/9999")
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
| Service 클래스 만들기 | 라우터 함수가 곧 서비스. 로직이 복잡해질 때 분리 |
| Repository 패턴 도입 | SQLAlchemy 세션이 이미 Repository 역할 |
| DI 컨테이너 (dependency-injector) | `Depends()`로 충분 |
| 도메인 이벤트 | 직접 함수 호출이 더 명확 |
| 멀티 모듈 구조 | 단일 패키지로 충분 |
