# Node.js / Express - 중규모 프로젝트 가이드

> 팀 3~8명, 엔드포인트 20~100개, 성장하는 서비스

---

## 핵심 원칙

- **3-Layer**: Controller → Service → Repository
- **tsyringe DI**: 의존성 주입으로 테스트 용이성 확보
- **커스텀 에러 계층**: HTTP와 분리된 비즈니스 예외
- **Prisma 트랜잭션**: `$transaction`으로 데이터 일관성 보장
- **구조화된 로깅**: pino로 JSON 로깅

---

## 디렉토리 구조

```
project/
├── src/
│   ├── index.ts                    # 서버 시작
│   ├── app.ts                      # Express 앱 설정
│   ├── container.ts                # tsyringe DI 등록
│   │
│   ├── modules/
│   │   ├── users/
│   │   │   ├── user.controller.ts  # 라우터 + 요청 처리
│   │   │   ├── user.service.ts     # 비즈니스 로직
│   │   │   ├── user.repository.ts  # DB 접근
│   │   │   ├── user.schema.ts      # Zod 검증 스키마
│   │   │   └── user.types.ts       # DTO 타입
│   │   │
│   │   └── orders/
│   │       ├── order.controller.ts
│   │       ├── order.service.ts
│   │       ├── order.repository.ts
│   │       ├── order.schema.ts
│   │       └── order.types.ts
│   │
│   ├── common/
│   │   ├── errors/
│   │   │   ├── app-error.ts        # 기본 에러 클래스
│   │   │   ├── not-found.error.ts
│   │   │   ├── conflict.error.ts
│   │   │   └── validation.error.ts
│   │   ├── middleware/
│   │   │   ├── error-handler.ts
│   │   │   ├── request-logger.ts
│   │   │   ├── validate.ts
│   │   │   └── auth.ts
│   │   └── lib/
│   │       ├── prisma.ts
│   │       ├── config.ts
│   │       └── logger.ts           # pino 설정
│   │
│   └── types/
│       └── index.ts
│
├── prisma/
│   ├── schema.prisma
│   └── migrations/
├── tests/
│   ├── modules/
│   │   ├── users/
│   │   │   ├── user.service.test.ts
│   │   │   └── user.controller.test.ts
│   │   └── orders/
│   └── helpers/
│       └── test-client.ts
├── package.json
└── tsconfig.json
```

---

## 커스텀 에러 계층

```typescript
// src/common/errors/app-error.ts
export abstract class AppError extends Error {
  abstract readonly statusCode: number;
  abstract readonly code: string;

  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
  }

  toJSON() {
    return {
      type: `https://api.example.com/errors/${this.code}`,
      title: this.message,
      status: this.statusCode,
      code: this.code,
    };
  }
}
```

```typescript
// src/common/errors/not-found.error.ts
import { AppError } from "./app-error";

export class NotFoundError extends AppError {
  readonly statusCode = 404;
  readonly code = "NOT_FOUND";

  constructor(resource: string, id?: string | number) {
    super(id ? `${resource}(${id})을(를) 찾을 수 없습니다` : `${resource}을(를) 찾을 수 없습니다`);
  }
}
```

```typescript
// src/common/errors/conflict.error.ts
import { AppError } from "./app-error";

export class ConflictError extends AppError {
  readonly statusCode = 409;
  readonly code = "CONFLICT";
}
```

```typescript
// src/common/errors/validation.error.ts
import { AppError } from "./app-error";

export class BusinessValidationError extends AppError {
  readonly statusCode = 422;
  readonly code = "BUSINESS_VALIDATION";
}
```

---

## 에러 핸들러 미들웨어

```typescript
// src/common/middleware/error-handler.ts
import { Request, Response, NextFunction } from "express";
import { AppError } from "../errors/app-error";
import { logger } from "../lib/logger";

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction,
) {
  if (err instanceof AppError) {
    logger.warn({ err, path: req.path }, "비즈니스 에러");
    res.status(err.statusCode).json(err.toJSON());
    return;
  }

  logger.error({ err, path: req.path }, "예상치 못한 에러");
  res.status(500).json({
    type: "https://api.example.com/errors/internal",
    title: "서버 내부 오류가 발생했습니다",
    status: 500,
  });
}
```

---

## 구조화된 로깅 (pino)

```typescript
// src/common/lib/logger.ts
import pino from "pino";
import { config } from "./config";

export const logger = pino({
  level: config.NODE_ENV === "production" ? "info" : "debug",
  transport:
    config.NODE_ENV === "development"
      ? { target: "pino-pretty", options: { colorize: true } }
      : undefined,
  formatters: {
    level: (label) => ({ level: label }),
  },
  timestamp: pino.stdTimeFunctions.isoTime,
});
```

```typescript
// src/common/middleware/request-logger.ts
import { Request, Response, NextFunction } from "express";
import { randomUUID } from "crypto";
import { logger } from "../lib/logger";

export function requestLogger(req: Request, res: Response, next: NextFunction) {
  const requestId = (req.headers["x-request-id"] as string) ?? randomUUID();
  req.headers["x-request-id"] = requestId;
  res.setHeader("X-Request-ID", requestId);

  const start = Date.now();
  res.on("finish", () => {
    logger.info({
      requestId,
      method: req.method,
      path: req.path,
      status: res.statusCode,
      durationMs: Date.now() - start,
    });
  });

  next();
}
```

---

## DI 컨테이너 (tsyringe)

```typescript
// src/container.ts
import "reflect-metadata";
import { container } from "tsyringe";
import { PrismaClient } from "@prisma/client";
import { UserRepository } from "./modules/users/user.repository";
import { UserService } from "./modules/users/user.service";
import { OrderRepository } from "./modules/orders/order.repository";
import { OrderService } from "./modules/orders/order.service";

// Prisma 싱글톤
container.registerInstance("PrismaClient", new PrismaClient());

// Repository
container.register("UserRepository", { useClass: UserRepository });
container.register("OrderRepository", { useClass: OrderRepository });

// Service
container.register("UserService", { useClass: UserService });
container.register("OrderService", { useClass: OrderService });

export { container };
```

---

## Repository

```typescript
// src/modules/users/user.repository.ts
import { injectable, inject } from "tsyringe";
import { PrismaClient, User } from "@prisma/client";

@injectable()
export class UserRepository {
  constructor(@inject("PrismaClient") private prisma: PrismaClient) {}

  async findById(id: number): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { id } });
  }

  async findByEmail(email: string): Promise<User | null> {
    return this.prisma.user.findUnique({ where: { email } });
  }

  async findAll(skip = 0, take = 20): Promise<User[]> {
    return this.prisma.user.findMany({
      skip,
      take,
      orderBy: { createdAt: "desc" },
    });
  }

  async create(data: { email: string; name: string; password: string }): Promise<User> {
    return this.prisma.user.create({ data });
  }

  async update(id: number, data: Partial<Pick<User, "name" | "email">>): Promise<User> {
    return this.prisma.user.update({ where: { id }, data });
  }

  async delete(id: number): Promise<void> {
    await this.prisma.user.delete({ where: { id } });
  }
}
```

---

## Service

```typescript
// src/modules/users/user.service.ts
import { injectable, inject } from "tsyringe";
import bcrypt from "bcryptjs";
import { UserRepository } from "./user.repository";
import { NotFoundError } from "../../common/errors/not-found.error";
import { ConflictError } from "../../common/errors/conflict.error";
import type { CreateUserDto, UserResponseDto } from "./user.types";

@injectable()
export class UserService {
  constructor(@inject("UserRepository") private userRepo: UserRepository) {}

  async createUser(dto: CreateUserDto): Promise<UserResponseDto> {
    const existing = await this.userRepo.findByEmail(dto.email);
    if (existing) {
      throw new ConflictError("이미 등록된 이메일입니다");
    }

    const hashedPassword = await bcrypt.hash(dto.password, 12);
    const user = await this.userRepo.create({
      email: dto.email,
      name: dto.name,
      password: hashedPassword,
    });

    return this.toResponse(user);
  }

  async getUser(id: number): Promise<UserResponseDto> {
    const user = await this.userRepo.findById(id);
    if (!user) {
      throw new NotFoundError("사용자", id);
    }
    return this.toResponse(user);
  }

  async listUsers(skip = 0, limit = 20): Promise<UserResponseDto[]> {
    const users = await this.userRepo.findAll(skip, limit);
    return users.map(this.toResponse);
  }

  private toResponse(user: { id: number; email: string; name: string; createdAt: Date }): UserResponseDto {
    return {
      id: user.id,
      email: user.email,
      name: user.name,
      createdAt: user.createdAt.toISOString(),
    };
  }
}
```

---

## Controller

```typescript
// src/modules/users/user.controller.ts
import { Router, Request, Response } from "express";
import { container } from "../../container";
import { UserService } from "./user.service";
import { validate } from "../../common/middleware/validate";
import { createUserSchema, getUserParamsSchema, listUsersQuerySchema } from "./user.schema";

const router = Router();

router.post("/", validate(createUserSchema), async (req: Request, res: Response) => {
  const service = container.resolve<UserService>("UserService");
  const user = await service.createUser(req.body);
  res.status(201).json(user);
});

router.get("/:id", validate(getUserParamsSchema), async (req: Request, res: Response) => {
  const service = container.resolve<UserService>("UserService");
  const user = await service.getUser(Number(req.params.id));
  res.json(user);
});

router.get("/", validate(listUsersQuerySchema), async (req: Request, res: Response) => {
  const service = container.resolve<UserService>("UserService");
  const users = await service.listUsers(
    Number(req.query.skip) || 0,
    Number(req.query.limit) || 20,
  );
  res.json(users);
});

export default router;
```

---

## Prisma 트랜잭션 예시

```typescript
// src/modules/orders/order.service.ts (일부)
import { injectable, inject } from "tsyringe";
import { PrismaClient } from "@prisma/client";

@injectable()
export class OrderService {
  constructor(
    @inject("PrismaClient") private prisma: PrismaClient,
    @inject("OrderRepository") private orderRepo: OrderRepository,
  ) {}

  async createOrder(customerId: number, items: OrderItemDto[]): Promise<OrderResponseDto> {
    // 트랜잭션으로 주문 + 재고 차감을 원자적으로 처리
    return this.prisma.$transaction(async (tx) => {
      // 재고 확인 및 차감
      for (const item of items) {
        const product = await tx.product.findUnique({ where: { id: item.productId } });
        if (!product || product.stock < item.quantity) {
          throw new BusinessValidationError(`상품(${item.productId}) 재고가 부족합니다`);
        }
        await tx.product.update({
          where: { id: item.productId },
          data: { stock: { decrement: item.quantity } },
        });
      }

      // 주문 생성
      const order = await tx.order.create({
        data: {
          customerId,
          status: "CONFIRMED",
          items: {
            create: items.map((i) => ({
              productId: i.productId,
              quantity: i.quantity,
              unitPrice: i.unitPrice,
            })),
          },
        },
        include: { items: true },
      });

      return this.toResponse(order);
    });
  }
}
```

---

## Service 단위 테스트

```typescript
// tests/modules/users/user.service.test.ts
import { describe, it, expect, vi, beforeEach } from "vitest";
import { UserService } from "../../../src/modules/users/user.service";
import { UserRepository } from "../../../src/modules/users/user.repository";
import { ConflictError } from "../../../src/common/errors/conflict.error";
import { NotFoundError } from "../../../src/common/errors/not-found.error";

describe("UserService", () => {
  let service: UserService;
  let mockRepo: Partial<UserRepository>;

  beforeEach(() => {
    mockRepo = {
      findByEmail: vi.fn(),
      findById: vi.fn(),
      findAll: vi.fn(),
      create: vi.fn(),
    };
    service = new UserService(mockRepo as UserRepository);
  });

  describe("createUser", () => {
    it("새 사용자를 생성한다", async () => {
      vi.mocked(mockRepo.findByEmail!).mockResolvedValue(null);
      vi.mocked(mockRepo.create!).mockResolvedValue({
        id: 1,
        email: "test@test.com",
        name: "테스트",
        password: "hashed",
        createdAt: new Date(),
        updatedAt: new Date(),
      });

      const result = await service.createUser({
        email: "test@test.com",
        name: "테스트",
        password: "password123",
      });

      expect(result.email).toBe("test@test.com");
      expect(result).not.toHaveProperty("password");
    });

    it("중복 이메일이면 ConflictError를 던진다", async () => {
      vi.mocked(mockRepo.findByEmail!).mockResolvedValue({ id: 1 } as any);

      await expect(
        service.createUser({ email: "dup@test.com", name: "중복", password: "pass" }),
      ).rejects.toThrow(ConflictError);
    });
  });

  describe("getUser", () => {
    it("존재하지 않는 사용자면 NotFoundError", async () => {
      vi.mocked(mockRepo.findById!).mockResolvedValue(null);

      await expect(service.getUser(999)).rejects.toThrow(NotFoundError);
    });
  });
});
```

---

## 중규모에서 지켜야 할 규칙

| 규칙 | 설명 |
|------|------|
| Controller는 얇게 | 검증과 응답 변환만, 비즈니스 로직은 Service |
| Service는 에러를 AppError로 | HTTP 상태코드를 Service에서 직접 쓰지 않음 |
| Repository로 DB 접근 캡슐화 | Service가 Prisma를 직접 호출하지 않음 (트랜잭션 제외) |
| 모든 입력은 Zod로 검증 | Controller 진입 전에 실패 |
| pino로 구조화된 로깅 | `console.log` 금지 |
| 요청 ID 추적 | 모든 로그에 requestId 포함 |
