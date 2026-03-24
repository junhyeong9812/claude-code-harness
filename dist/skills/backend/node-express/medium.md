# Node.js / Express - 중규모 프로젝트 가이드

> 엔드포인트 50~100개, 성장하는 서비스

---

## 핵심 원칙

- **4-Layer 도메인 모듈**: `api → application → domain ← infrastructure`
- **global/**: 횡단 관심사 + 공유 도메인 객체 (별도 `core/` 없음)
- **tsyringe DI**: 인터페이스 기반 의존성 주입으로 레이어 분리
- **커스텀 에러 계층**: HTTP와 분리된 비즈니스 예외
- **Prisma 트랜잭션**: `$transaction`으로 데이터 일관성 보장
- **구조화된 로깅**: pino로 JSON 로깅
- **파일 수 규칙**: 4개 이상 → 하위 폴더, 3개 이하 → flat

---

## 의존 방향

```
api → application → domain ← infrastructure
```

- `domain`은 어디에도 의존하지 않는다 (순수 TypeScript).
- `infrastructure`는 `domain`의 인터페이스를 구현한다.
- `application`은 `domain` 인터페이스에만 의존하고, DI로 구현체를 주입받는다.
- `api`는 `application`의 UseCase를 호출한다.

---

## 디렉토리 구조

```
project/
├── src/
│   ├── index.ts                        # 서버 시작
│   ├── app.ts                          # Express 앱 설정
│   ├── container.ts                    # tsyringe DI 등록
│   │
│   ├── global/                         # 횡단 관심사 + 공유 도메인 객체
│   │   ├── exception/
│   │   │   ├── app-error.ts
│   │   │   ├── not-found.error.ts
│   │   │   └── conflict.error.ts
│   │   ├── config/
│   │   │   └── config.ts
│   │   ├── middleware/
│   │   │   ├── error-handler.ts
│   │   │   ├── request-logger.ts
│   │   │   ├── validate.ts
│   │   │   └── auth.ts
│   │   ├── lib/
│   │   │   ├── prisma.ts
│   │   │   └── logger.ts              # pino 설정
│   │   └── domain/
│   │       └── base.types.ts          # 공유 타입 (ID, Timestamp 등)
│   │
│   ├── order/                          # 복잡한 도메인 → 4-Layer
│   │   ├── api/
│   │   │   ├── order.controller.ts
│   │   │   └── dto/                   # DTO 4개 이상 → 하위 폴더
│   │   │       ├── create-order.request.ts
│   │   │       └── order.response.ts
│   │   ├── application/
│   │   │   ├── create-order.usecase.ts
│   │   │   ├── cancel-order.usecase.ts
│   │   │   └── order.mapper.ts
│   │   ├── domain/
│   │   │   ├── order.model.ts
│   │   │   ├── order-item.model.ts
│   │   │   └── order.repository.ts    # interface
│   │   └── infrastructure/
│   │       ├── prisma-order.repository.ts
│   │       └── payment.client.ts
│   │
│   ├── user/                           # 일반 도메인 → 4-Layer (flat DTO)
│   │   ├── api/
│   │   │   ├── user.controller.ts
│   │   │   ├── user-create.request.ts # DTO 3개 이하 → flat
│   │   │   └── user.response.ts
│   │   ├── application/
│   │   │   ├── create-user.usecase.ts
│   │   │   └── user.mapper.ts
│   │   ├── domain/
│   │   │   ├── user.model.ts
│   │   │   └── user.repository.ts
│   │   └── infrastructure/
│   │       └── prisma-user.repository.ts
│   │
│   └── notification/                   # 단순 CRUD → flat 유지
│       ├── notification.controller.ts
│       ├── notification.service.ts
│       └── notification.schema.ts
│
├── prisma/
│   ├── schema.prisma
│   └── migrations/
├── tests/
│   ├── order/
│   │   └── create-order.usecase.test.ts
│   ├── user/
│   │   └── create-user.usecase.test.ts
│   └── helpers/
│       └── test-client.ts
├── package.json
└── tsconfig.json
```

### 파일 수 규칙

| 조건 | 구조 | 예시 |
|------|------|------|
| 한 레이어에 파일 4개 이상 | 하위 폴더로 분리 | `api/dto/create-order.request.ts` |
| 한 레이어에 파일 3개 이하 | flat으로 유지 | `api/user-create.request.ts` |
| 단순 CRUD 도메인 | 4-Layer 없이 flat | `notification/notification.controller.ts` |

---

## 커스텀 에러 계층

```typescript
// src/global/exception/app-error.ts
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
// src/global/exception/not-found.error.ts
import { AppError } from "./app-error";

export class NotFoundError extends AppError {
  readonly statusCode = 404;
  readonly code = "NOT_FOUND";

  constructor(resource: string, id?: string | number) {
    super(
      id
        ? `${resource}(${id})을(를) 찾을 수 없습니다`
        : `${resource}을(를) 찾을 수 없습니다`,
    );
  }
}
```

```typescript
// src/global/exception/conflict.error.ts
import { AppError } from "./app-error";

export class ConflictError extends AppError {
  readonly statusCode = 409;
  readonly code = "CONFLICT";
}
```

```typescript
// src/global/exception/business-validation.error.ts
import { AppError } from "./app-error";

export class BusinessValidationError extends AppError {
  readonly statusCode = 422;
  readonly code = "BUSINESS_VALIDATION";
}
```

---

## 에러 핸들러 미들웨어

```typescript
// src/global/middleware/error-handler.ts
import { Request, Response, NextFunction } from "express";
import { AppError } from "../exception/app-error";
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
// src/global/lib/logger.ts
import pino from "pino";
import { config } from "../config/config";

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
// src/global/middleware/request-logger.ts
import { Request, Response, NextFunction } from "express";
import { randomUUID } from "crypto";
import { logger } from "../lib/logger";

export function requestLogger(
  req: Request,
  res: Response,
  next: NextFunction,
) {
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

## 공유 타입

```typescript
// src/global/domain/base.types.ts

/** 모든 엔티티의 공통 필드 */
export interface BaseEntity {
  readonly id: number;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

/** 페이지네이션 파라미터 */
export interface PaginationParams {
  skip: number;
  take: number;
}

/** 페이지네이션 결과 */
export interface PaginatedResult<T> {
  data: T[];
  total: number;
  skip: number;
  take: number;
}
```

---

## Domain 모델

```typescript
// src/order/domain/order.model.ts
import type { OrderItem } from "./order-item.model";

export type OrderStatus = "PENDING" | "CONFIRMED" | "CANCELLED" | "SHIPPED";

export interface Order {
  readonly id: number;
  readonly customerId: number;
  readonly status: OrderStatus;
  readonly items: OrderItem[];
  readonly totalAmount: number;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

/** 주문 생성에 필요한 데이터 (ID, 타임스탬프 제외) */
export interface CreateOrderData {
  customerId: number;
  items: {
    productId: number;
    quantity: number;
    unitPrice: number;
  }[];
}

/** 도메인 로직: 총액 계산 */
export function calculateTotalAmount(
  items: { quantity: number; unitPrice: number }[],
): number {
  return items.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);
}
```

```typescript
// src/order/domain/order-item.model.ts
export interface OrderItem {
  readonly id: number;
  readonly orderId: number;
  readonly productId: number;
  readonly quantity: number;
  readonly unitPrice: number;
}
```

---

## Repository 인터페이스 (domain) + 구현 (infrastructure)

```typescript
// src/order/domain/order.repository.ts
import type { Order, CreateOrderData } from "./order.model";

/**
 * domain 레이어에 인터페이스만 정의한다.
 * infrastructure 레이어에서 구현체를 제공하고, DI로 주입한다.
 */
export interface OrderRepository {
  findById(id: number): Promise<Order | null>;
  findByCustomerId(customerId: number): Promise<Order[]>;
  create(data: CreateOrderData): Promise<Order>;
  updateStatus(id: number, status: Order["status"]): Promise<Order>;
}
```

```typescript
// src/order/infrastructure/prisma-order.repository.ts
import { injectable, inject } from "tsyringe";
import { PrismaClient } from "@prisma/client";
import type { OrderRepository } from "../domain/order.repository";
import type { Order, CreateOrderData } from "../domain/order.model";
import { calculateTotalAmount } from "../domain/order.model";

@injectable()
export class PrismaOrderRepository implements OrderRepository {
  constructor(@inject("PrismaClient") private prisma: PrismaClient) {}

  async findById(id: number): Promise<Order | null> {
    return this.prisma.order.findUnique({
      where: { id },
      include: { items: true },
    });
  }

  async findByCustomerId(customerId: number): Promise<Order[]> {
    return this.prisma.order.findMany({
      where: { customerId },
      include: { items: true },
      orderBy: { createdAt: "desc" },
    });
  }

  async create(data: CreateOrderData): Promise<Order> {
    const totalAmount = calculateTotalAmount(data.items);

    return this.prisma.order.create({
      data: {
        customerId: data.customerId,
        status: "PENDING",
        totalAmount,
        items: {
          create: data.items.map((item) => ({
            productId: item.productId,
            quantity: item.quantity,
            unitPrice: item.unitPrice,
          })),
        },
      },
      include: { items: true },
    });
  }

  async updateStatus(id: number, status: Order["status"]): Promise<Order> {
    return this.prisma.order.update({
      where: { id },
      data: { status },
      include: { items: true },
    });
  }
}
```

---

## UseCase (application 레이어)

```typescript
// src/order/application/create-order.usecase.ts
import { injectable, inject } from "tsyringe";
import type { OrderRepository } from "../domain/order.repository";
import type { Order, CreateOrderData } from "../domain/order.model";
import { calculateTotalAmount } from "../domain/order.model";
import { BusinessValidationError } from "../../global/exception/business-validation.error";
import { logger } from "../../global/lib/logger";

@injectable()
export class CreateOrderUseCase {
  constructor(
    @inject("OrderRepository") private orderRepo: OrderRepository,
  ) {}

  async execute(data: CreateOrderData): Promise<Order> {
    // 비즈니스 검증
    if (data.items.length === 0) {
      throw new BusinessValidationError("주문 항목이 비어있습니다");
    }

    const totalAmount = calculateTotalAmount(data.items);
    if (totalAmount <= 0) {
      throw new BusinessValidationError("주문 총액은 0보다 커야 합니다");
    }

    const order = await this.orderRepo.create(data);

    logger.info(
      { orderId: order.id, customerId: data.customerId, totalAmount },
      "주문이 생성되었습니다",
    );

    return order;
  }
}
```

```typescript
// src/order/application/order.mapper.ts
import type { Order } from "../domain/order.model";

/** API 응답용 DTO 변환 */
export interface OrderResponseDto {
  id: number;
  customerId: number;
  status: string;
  totalAmount: number;
  items: {
    productId: number;
    quantity: number;
    unitPrice: number;
  }[];
  createdAt: string;
}

export function toOrderResponse(order: Order): OrderResponseDto {
  return {
    id: order.id,
    customerId: order.customerId,
    status: order.status,
    totalAmount: order.totalAmount,
    items: order.items.map((item) => ({
      productId: item.productId,
      quantity: item.quantity,
      unitPrice: item.unitPrice,
    })),
    createdAt: order.createdAt.toISOString(),
  };
}
```

---

## Controller (api 레이어)

```typescript
// src/order/api/order.controller.ts
import { Router, Request, Response } from "express";
import { container } from "../../container";
import { CreateOrderUseCase } from "../application/create-order.usecase";
import { CancelOrderUseCase } from "../application/cancel-order.usecase";
import { toOrderResponse } from "../application/order.mapper";
import { validate } from "../../global/middleware/validate";
import { createOrderRequestSchema } from "./dto/create-order.request";

const router = Router();

router.post(
  "/",
  validate(createOrderRequestSchema),
  async (req: Request, res: Response) => {
    const useCase = container.resolve(CreateOrderUseCase);
    const order = await useCase.execute(req.body);
    res.status(201).json(toOrderResponse(order));
  },
);

router.post(
  "/:id/cancel",
  async (req: Request, res: Response) => {
    const useCase = container.resolve(CancelOrderUseCase);
    const order = await useCase.execute(Number(req.params.id));
    res.json(toOrderResponse(order));
  },
);

export default router;
```

```typescript
// src/order/api/dto/create-order.request.ts
import { z } from "zod";

export const createOrderRequestSchema = z.object({
  body: z.object({
    customerId: z.number().int().positive(),
    items: z
      .array(
        z.object({
          productId: z.number().int().positive(),
          quantity: z.number().int().min(1),
          unitPrice: z.number().positive(),
        }),
      )
      .min(1, "최소 1개 이상의 주문 항목이 필요합니다"),
  }),
});

export type CreateOrderRequest = z.infer<
  typeof createOrderRequestSchema
>["body"];
```

---

## Zod 검증 미들웨어

```typescript
// src/global/middleware/validate.ts
import { Request, Response, NextFunction } from "express";
import { AnyZodObject, ZodError } from "zod";

export function validate(schema: AnyZodObject) {
  return (req: Request, res: Response, next: NextFunction) => {
    try {
      schema.parse({
        body: req.body,
        query: req.query,
        params: req.params,
      });
      next();
    } catch (err) {
      if (err instanceof ZodError) {
        res.status(400).json({
          type: "https://api.example.com/errors/validation",
          title: "요청 데이터가 유효하지 않습니다",
          status: 400,
          errors: err.errors.map((e) => ({
            path: e.path.join("."),
            message: e.message,
          })),
        });
        return;
      }
      next(err);
    }
  };
}
```

---

## DI 컨테이너 (tsyringe)

```typescript
// src/container.ts
import "reflect-metadata";
import { container } from "tsyringe";
import { PrismaClient } from "@prisma/client";

// Infrastructure
import { PrismaOrderRepository } from "./order/infrastructure/prisma-order.repository";
import { PrismaUserRepository } from "./user/infrastructure/prisma-user.repository";

// Prisma 싱글톤
container.registerInstance("PrismaClient", new PrismaClient());

// Repository: domain 인터페이스 토큰 → infrastructure 구현체
container.register("OrderRepository", { useClass: PrismaOrderRepository });
container.register("UserRepository", { useClass: PrismaUserRepository });

export { container };
```

---

## Prisma 트랜잭션 예시

```typescript
// src/order/infrastructure/prisma-order.repository.ts (트랜잭션 메서드 추가)

/**
 * 트랜잭션이 필요한 경우: infrastructure 레이어에서 처리한다.
 * Repository 인터페이스에 트랜잭션용 메서드를 정의하고,
 * Prisma 구현체에서 $transaction을 사용한다.
 */
async createWithStockDeduction(data: CreateOrderData): Promise<Order> {
  return this.prisma.$transaction(async (tx) => {
    // 재고 확인 및 차감
    for (const item of data.items) {
      const product = await tx.product.findUnique({
        where: { id: item.productId },
      });
      if (!product || product.stock < item.quantity) {
        throw new BusinessValidationError(
          `상품(${item.productId}) 재고가 부족합니다`,
        );
      }
      await tx.product.update({
        where: { id: item.productId },
        data: { stock: { decrement: item.quantity } },
      });
    }

    // 주문 생성
    const totalAmount = calculateTotalAmount(data.items);
    const order = await tx.order.create({
      data: {
        customerId: data.customerId,
        status: "CONFIRMED",
        totalAmount,
        items: {
          create: data.items.map((i) => ({
            productId: i.productId,
            quantity: i.quantity,
            unitPrice: i.unitPrice,
          })),
        },
      },
      include: { items: true },
    });

    return order;
  });
}
```

---

## UseCase 단위 테스트 (Vitest)

```typescript
// tests/order/create-order.usecase.test.ts
import { describe, it, expect, vi, beforeEach } from "vitest";
import { CreateOrderUseCase } from "../../src/order/application/create-order.usecase";
import type { OrderRepository } from "../../src/order/domain/order.repository";
import type { Order } from "../../src/order/domain/order.model";
import { BusinessValidationError } from "../../src/global/exception/business-validation.error";

describe("CreateOrderUseCase", () => {
  let useCase: CreateOrderUseCase;
  let mockOrderRepo: Record<keyof OrderRepository, ReturnType<typeof vi.fn>>;

  const mockOrder: Order = {
    id: 1,
    customerId: 100,
    status: "PENDING",
    totalAmount: 30000,
    items: [
      { id: 1, orderId: 1, productId: 10, quantity: 2, unitPrice: 15000 },
    ],
    createdAt: new Date("2026-01-01"),
    updatedAt: new Date("2026-01-01"),
  };

  beforeEach(() => {
    mockOrderRepo = {
      findById: vi.fn(),
      findByCustomerId: vi.fn(),
      create: vi.fn(),
      updateStatus: vi.fn(),
    };
    // interface 기반 mock → infrastructure 의존 없이 테스트
    useCase = new CreateOrderUseCase(mockOrderRepo);
  });

  it("유효한 주문을 생성한다", async () => {
    mockOrderRepo.create.mockResolvedValue(mockOrder);

    const result = await useCase.execute({
      customerId: 100,
      items: [{ productId: 10, quantity: 2, unitPrice: 15000 }],
    });

    expect(result.id).toBe(1);
    expect(result.status).toBe("PENDING");
    expect(result.totalAmount).toBe(30000);
    expect(mockOrderRepo.create).toHaveBeenCalledOnce();
  });

  it("주문 항목이 비어있으면 BusinessValidationError를 던진다", async () => {
    await expect(
      useCase.execute({ customerId: 100, items: [] }),
    ).rejects.toThrow(BusinessValidationError);

    expect(mockOrderRepo.create).not.toHaveBeenCalled();
  });

  it("총액이 0 이하이면 BusinessValidationError를 던진다", async () => {
    await expect(
      useCase.execute({
        customerId: 100,
        items: [{ productId: 10, quantity: 0, unitPrice: 15000 }],
      }),
    ).rejects.toThrow(BusinessValidationError);

    expect(mockOrderRepo.create).not.toHaveBeenCalled();
  });
});
```

---

## 중규모에서 지켜야 할 규칙

| 규칙 | 설명 |
|------|------|
| domain은 순수하게 | 외부 라이브러리(Prisma, Express 등) 의존 금지 |
| UseCase는 하나의 행위 | `CreateOrderUseCase`, `CancelOrderUseCase`처럼 단일 책임 |
| Controller는 얇게 | 검증과 응답 변환만, 비즈니스 로직은 UseCase |
| Repository 인터페이스는 domain에 | 구현체는 infrastructure에, DI로 연결 |
| 단순 CRUD는 flat | 모든 도메인에 4-Layer를 강제하지 않음 |
| 모든 입력은 Zod로 검증 | Controller 진입 전에 실패 |
| pino로 구조화된 로깅 | `console.log` 금지 |
| 요청 ID 추적 | 모든 로그에 requestId 포함 |

---

## 전환 시그널 (→ 대규모)

다음 상황이 발생하면 대규모 아키텍처로 전환을 검토한다:

| 시그널 | 설명 |
|--------|------|
| **모듈 간 의존 복잡** | 모듈 간 직접 호출이 복잡하게 얽히기 시작할 때 (이벤트 기반 통신, 메시지 큐 도입 검토) |
| **팀 규모 15명 이상** | 모듈 경계를 코드 레벨에서 강제해야 할 때 (모노레포, 워크스페이스 분리 검토) |
| **사이드이펙트 전파** | 한 모듈의 변경이 다른 모듈에 예상치 못한 영향을 줄 때 (계약 테스트, API 버저닝 검토) |
