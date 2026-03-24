# Node.js / Express - 대규모 프로젝트 가이드

> 엔드포인트 100개 이상, 모듈 간 통신이 복잡한 서비스

---

## 핵심 원칙

**중규모와 레이어 구조는 동일하다. 대규모는 Facade + Event + CQRS만 추가된다.**

- **4-Layer 도메인 모듈**: `api → application → domain ← infrastructure` (중규모와 동일)
- **Facade**: 모듈의 공개 API — 다른 모듈은 반드시 Facade를 통해서만 접근
- **Domain Event Bus**: 모듈 간 비동기 통신 — 직접 호출 금지
- **CQRS**: Command/Query UseCase 분리
- **tsyringe 또는 InversifyJS**: DI 컨테이너
- **Zod**: 입력 검증
- **Prisma**: ORM (도메인 모델은 Prisma 타입 기반으로 실용적으로 유지)
- **pino**: 구조화된 JSON 로깅
- **Vitest**: 테스트
- **neverthrow** (선택): 예상 가능한 실패에 `Result<T, E>` 패턴

---

## 의존 방향

```
api → application → domain ← infrastructure
```

- `domain`은 어디에도 의존하지 않는다 (순수 TypeScript).
- `infrastructure`는 `domain`의 인터페이스를 구현한다.
- `application`은 `domain` 인터페이스에만 의존하고, DI로 구현체를 주입받는다.
- `api`는 `application`의 UseCase를 호출한다.

**중규모와 완전히 동일하다.** 대규모에서 추가되는 것은 모듈 경계를 강제하는 Facade, Event, CQRS뿐이다.

---

## 디렉토리 구조

```
project/
├── src/
│   ├── index.ts
│   ├── app.ts
│   ├── container.ts
│   │
│   ├── global/
│   │   ├── exception/
│   │   │   ├── app-error.ts
│   │   │   ├── not-found.error.ts
│   │   │   └── conflict.error.ts
│   │   ├── config/
│   │   │   └── config.ts
│   │   ├── middleware/
│   │   │   ├── error-handler.ts
│   │   │   ├── request-logger.ts
│   │   │   └── auth.ts
│   │   ├── lib/
│   │   │   ├── prisma.ts
│   │   │   └── logger.ts
│   │   └── domain/
│   │       ├── domain-event.ts              # 이벤트 인터페이스
│   │       └── event-bus.ts                 # EventBus 인터페이스 + 구현체
│   │
│   ├── order/
│   │   ├── order.facade.ts                  # ★ 모듈 공개 API
│   │   ├── order-created.event.ts           # ★ 모듈 공개 이벤트
│   │   │
│   │   ├── api/
│   │   │   ├── order.controller.ts
│   │   │   └── dto/
│   │   │       ├── create-order.request.ts
│   │   │       └── order.response.ts
│   │   │
│   │   ├── application/
│   │   │   ├── command/                     # ★ CQRS - Command
│   │   │   │   ├── create-order.usecase.ts
│   │   │   │   └── cancel-order.usecase.ts
│   │   │   ├── query/                       # ★ CQRS - Query
│   │   │   │   └── get-order.usecase.ts
│   │   │   ├── event/                       # ★ 이벤트 핸들러
│   │   │   │   └── payment-completed.handler.ts
│   │   │   └── order.mapper.ts
│   │   │
│   │   ├── domain/
│   │   │   ├── model/
│   │   │   │   ├── order.model.ts
│   │   │   │   └── order-status.ts
│   │   │   ├── vo/
│   │   │   │   └── money.vo.ts
│   │   │   ├── order.repository.ts          # interface
│   │   │   └── order.errors.ts
│   │   │
│   │   └── infrastructure/
│   │       ├── persistence/
│   │       │   └── prisma-order.repository.ts
│   │       ├── client/
│   │       │   └── payment.client.ts
│   │       └── messaging/
│   │           └── order-kafka.producer.ts
│   │
│   ├── inventory/
│   │   ├── inventory.facade.ts
│   │   ├── stock-decreased.event.ts
│   │   └── ...
│   │
│   └── payment/
│       ├── payment.facade.ts
│       ├── payment-completed.event.ts
│       └── ...
│
├── prisma/
├── tests/
├── package.json
└── tsconfig.json
```

### 중규모 대비 추가된 것

| 추가 요소 | 파일 위치 | 역할 |
|-----------|-----------|------|
| **Facade** | `order/order.facade.ts` | 모듈의 유일한 공개 API |
| **공개 이벤트** | `order/order-created.event.ts` | 다른 모듈이 구독할 이벤트 |
| **EventBus** | `global/domain/event-bus.ts` | 이벤트 발행/구독 인프라 |
| **command/** | `application/command/` | 쓰기 UseCase |
| **query/** | `application/query/` | 읽기 UseCase |
| **event/** | `application/event/` | 외부 이벤트 핸들러 |
| **messaging/** | `infrastructure/messaging/` | Kafka 등 메시징 인프라 |

---

## 모듈 간 통신 규칙

### 금지: 다른 모듈 내부 직접 접근

```typescript
// ❌ 금지 — inventory가 order 내부 레이어를 직접 참조
import { PrismaOrderRepository } from "../order/infrastructure/persistence/prisma-order.repository";
import { CreateOrderUseCase } from "../order/application/command/create-order.usecase";
import { Order } from "../order/domain/model/order.model";
```

### 허용: Facade를 통한 동기 호출

```typescript
// ✅ 허용 — Facade만 import
import { OrderFacade } from "../order/order.facade";

class InventoryService {
  constructor(private orderFacade: OrderFacade) {}

  async checkOrderTotal(orderId: string): Promise<number> {
    // Facade의 공개 메서드만 사용
    const summary = await this.orderFacade.getOrderSummary(orderId);
    return summary.totalAmount;
  }
}
```

### 권장: 이벤트를 통한 비동기 통신

```typescript
// ✅ 권장 — 이벤트 기반 느슨한 결합
import { OrderCreatedEvent } from "../order/order-created.event";

// inventory 모듈의 이벤트 핸들러
class OrderCreatedHandler {
  constructor(private inventoryRepo: InventoryRepository) {}

  async handle(event: OrderCreatedEvent): Promise<void> {
    for (const item of event.items) {
      await this.inventoryRepo.decreaseStock(item.productId, item.quantity);
    }
  }
}
```

### 규칙 요약

| 방식 | 상황 | 예시 |
|------|------|------|
| **금지** | 다른 모듈 내부 직접 import | `import { Order } from "../order/domain/..."` |
| **허용** | 동기 조회가 필요할 때 Facade 사용 | `orderFacade.getOrderSummary(id)` |
| **권장** | 모듈 간 사이드이펙트 | 이벤트 발행 → 구독 모듈에서 처리 |

---

## Domain Event

```typescript
// src/global/domain/domain-event.ts
export interface DomainEvent {
  readonly eventName: string;
  readonly occurredAt: Date;
  readonly aggregateId: string;
}
```

```typescript
// src/global/domain/event-bus.ts
import { DomainEvent } from "./domain-event";
import { logger } from "../lib/logger";

export interface EventBus {
  publish(event: DomainEvent): Promise<void>;
  subscribe(eventName: string, handler: (event: DomainEvent) => Promise<void>): void;
}

type Handler = (event: DomainEvent) => Promise<void>;

export class InMemoryEventBus implements EventBus {
  private handlers = new Map<string, Handler[]>();

  subscribe(eventName: string, handler: Handler): void {
    const existing = this.handlers.get(eventName) ?? [];
    existing.push(handler);
    this.handlers.set(eventName, existing);
  }

  async publish(event: DomainEvent): Promise<void> {
    const handlers = this.handlers.get(event.eventName) ?? [];
    logger.info({ event: event.eventName, aggregateId: event.aggregateId }, "이벤트 발행");

    for (const handler of handlers) {
      try {
        await handler(event);
      } catch (error) {
        logger.error({ err: error, event: event.eventName }, "이벤트 핸들러 실패");
      }
    }
  }
}
```

```typescript
// src/order/order-created.event.ts
// 모듈 루트에 위치 — 다른 모듈이 import 가능한 공개 이벤트
import { DomainEvent } from "../global/domain/domain-event";

export class OrderCreatedEvent implements DomainEvent {
  readonly eventName = "OrderCreated";
  readonly occurredAt = new Date();

  constructor(
    readonly aggregateId: string,
    readonly customerId: string,
    readonly items: { productId: string; quantity: number }[],
    readonly totalAmount: number,
  ) {}
}
```

---

## Facade

```typescript
// src/order/order.facade.ts
import { injectable, inject } from "tsyringe";
import { CreateOrderUseCase } from "./application/command/create-order.usecase";
import { CancelOrderUseCase } from "./application/command/cancel-order.usecase";
import { GetOrderUseCase, OrderSummary } from "./application/query/get-order.usecase";

/** 주문 모듈의 유일한 공개 API */
export interface CreateOrderInput {
  customerId: string;
  items: { productId: string; quantity: number; unitPrice: number }[];
}

@injectable()
export class OrderFacade {
  constructor(
    @inject("CreateOrderUseCase") private createOrder: CreateOrderUseCase,
    @inject("CancelOrderUseCase") private cancelOrder: CancelOrderUseCase,
    @inject("GetOrderUseCase") private getOrder: GetOrderUseCase,
  ) {}

  /** 주문 생성 — Command */
  async create(input: CreateOrderInput): Promise<string> {
    return this.createOrder.execute(input);
  }

  /** 주문 취소 — Command */
  async cancel(orderId: string, reason: string): Promise<void> {
    return this.cancelOrder.execute(orderId, reason);
  }

  /** 주문 요약 조회 — Query */
  async getOrderSummary(orderId: string): Promise<OrderSummary> {
    return this.getOrder.execute(orderId);
  }
}
```

Facade는 모듈 내부 UseCase를 조합하는 얇은 위임 레이어다. 비즈니스 로직을 담지 않는다.

---

## CQRS — Command UseCase

```typescript
// src/order/application/command/create-order.usecase.ts
import { injectable, inject } from "tsyringe";
import type { OrderRepository } from "../../domain/order.repository";
import type { EventBus } from "../../../global/domain/event-bus";
import { Order, calculateTotalAmount } from "../../domain/model/order.model";
import { OrderCreatedEvent } from "../../order-created.event";
import { BusinessValidationError } from "../../../global/exception/business-validation.error";
import { logger } from "../../../global/lib/logger";
import { randomUUID } from "crypto";

interface CreateOrderInput {
  customerId: string;
  items: { productId: string; quantity: number; unitPrice: number }[];
}

@injectable()
export class CreateOrderUseCase {
  constructor(
    @inject("OrderRepository") private orderRepo: OrderRepository,
    @inject("EventBus") private eventBus: EventBus,
  ) {}

  async execute(input: CreateOrderInput): Promise<string> {
    if (input.items.length === 0) {
      throw new BusinessValidationError("주문 항목이 비어있습니다");
    }

    const totalAmount = calculateTotalAmount(input.items);
    if (totalAmount <= 0) {
      throw new BusinessValidationError("주문 총액은 0보다 커야 합니다");
    }

    const orderId = randomUUID();
    const order = await this.orderRepo.create({
      id: orderId,
      customerId: input.customerId,
      status: "PENDING",
      totalAmount,
      items: input.items,
    });

    // 도메인 이벤트 발행
    await this.eventBus.publish(
      new OrderCreatedEvent(
        order.id,
        order.customerId,
        input.items.map((i) => ({ productId: i.productId, quantity: i.quantity })),
        totalAmount,
      ),
    );

    logger.info({ orderId: order.id, customerId: input.customerId }, "주문 생성");
    return order.id;
  }
}
```

```typescript
// src/order/application/command/cancel-order.usecase.ts
import { injectable, inject } from "tsyringe";
import type { OrderRepository } from "../../domain/order.repository";
import { NotFoundError } from "../../../global/exception/not-found.error";
import { BusinessValidationError } from "../../../global/exception/business-validation.error";
import { canTransition } from "../../domain/model/order-status";

@injectable()
export class CancelOrderUseCase {
  constructor(
    @inject("OrderRepository") private orderRepo: OrderRepository,
  ) {}

  async execute(orderId: string, reason: string): Promise<void> {
    const order = await this.orderRepo.findById(orderId);
    if (!order) throw new NotFoundError("주문", orderId);

    if (!canTransition(order.status, "CANCELLED")) {
      throw new BusinessValidationError(
        `${order.status} 상태의 주문은 취소할 수 없습니다`,
      );
    }

    await this.orderRepo.updateStatus(orderId, "CANCELLED");
  }
}
```

---

## CQRS — Query UseCase

```typescript
// src/order/application/query/get-order.usecase.ts
import { injectable, inject } from "tsyringe";
import type { OrderRepository } from "../../domain/order.repository";
import { NotFoundError } from "../../../global/exception/not-found.error";

export interface OrderSummary {
  id: string;
  customerId: string;
  status: string;
  totalAmount: number;
  itemCount: number;
  createdAt: Date;
}

@injectable()
export class GetOrderUseCase {
  constructor(
    @inject("OrderRepository") private orderRepo: OrderRepository,
  ) {}

  async execute(orderId: string): Promise<OrderSummary> {
    const order = await this.orderRepo.findById(orderId);
    if (!order) throw new NotFoundError("주문", orderId);

    return {
      id: order.id,
      customerId: order.customerId,
      status: order.status,
      totalAmount: order.totalAmount,
      itemCount: order.items.length,
      createdAt: order.createdAt,
    };
  }
}
```

Command는 상태를 변경하고 ID만 반환한다. Query는 읽기 전용 DTO를 반환한다. 같은 Repository를 사용하더라도 UseCase를 분리하면 향후 읽기/쓰기 저장소 분리가 용이하다.

---

## Domain 모델

도메인 모델은 Prisma 타입 기반으로 실용적으로 유지한다. 별도의 Aggregate Root 클래스를 만들지 않는다.

```typescript
// src/order/domain/model/order.model.ts

export type OrderStatus = "PENDING" | "CONFIRMED" | "CANCELLED" | "SHIPPED" | "DELIVERED";

export interface Order {
  readonly id: string;
  readonly customerId: string;
  readonly status: OrderStatus;
  readonly items: OrderItem[];
  readonly totalAmount: number;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface OrderItem {
  readonly id: string;
  readonly orderId: string;
  readonly productId: string;
  readonly quantity: number;
  readonly unitPrice: number;
}

export interface CreateOrderData {
  id: string;
  customerId: string;
  status: OrderStatus;
  totalAmount: number;
  items: { productId: string; quantity: number; unitPrice: number }[];
}

/** 도메인 로직: 총액 계산 */
export function calculateTotalAmount(
  items: { quantity: number; unitPrice: number }[],
): number {
  return items.reduce((sum, item) => sum + item.quantity * item.unitPrice, 0);
}

/** 도메인 로직: 취소 가능 여부 */
export function isCancellable(order: Order): boolean {
  return order.status === "PENDING" || order.status === "CONFIRMED";
}
```

```typescript
// src/order/domain/model/order-status.ts

export type OrderStatus = "PENDING" | "CONFIRMED" | "CANCELLED" | "SHIPPED" | "DELIVERED";

const TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  PENDING: ["CONFIRMED", "CANCELLED"],
  CONFIRMED: ["SHIPPED", "CANCELLED"],
  SHIPPED: ["DELIVERED"],
  DELIVERED: [],
  CANCELLED: [],
};

export function canTransition(from: OrderStatus, to: OrderStatus): boolean {
  return TRANSITIONS[from].includes(to);
}
```

```typescript
// src/order/domain/vo/money.vo.ts

/** Value Object — 불변 객체로 금액을 표현 */
export interface Money {
  readonly amount: number;
  readonly currency: string;
}

export function createMoney(amount: number, currency = "KRW"): Money {
  if (amount < 0) throw new Error("금액은 0 이상이어야 합니다");
  return Object.freeze({ amount, currency });
}

export function addMoney(a: Money, b: Money): Money {
  if (a.currency !== b.currency) throw new Error("통화가 다릅니다");
  return createMoney(a.amount + b.amount, a.currency);
}

export function multiplyMoney(money: Money, quantity: number): Money {
  return createMoney(money.amount * quantity, money.currency);
}
```

Prisma가 반환하는 객체를 그대로 도메인 모델로 사용한다. 비즈니스 로직은 순수 함수로 분리한다. 별도의 도메인 클래스로 감싸는 것은 Node.js/Prisma 환경에서 불필요한 복잡도를 추가한다.

---

## Domain 에러

```typescript
// src/order/domain/order.errors.ts
import { AppError } from "../../global/exception/app-error";

export class InvalidOrderTransitionError extends AppError {
  readonly statusCode = 422;
  readonly code = "INVALID_ORDER_TRANSITION";

  constructor(from: string, to: string) {
    super(`${from} → ${to} 전환은 허용되지 않습니다`);
  }
}

export class EmptyOrderError extends AppError {
  readonly statusCode = 422;
  readonly code = "EMPTY_ORDER";

  constructor() {
    super("상품이 없는 주문은 생성할 수 없습니다");
  }
}
```

---

## Repository 인터페이스 + 구현체

```typescript
// src/order/domain/order.repository.ts
import type { Order, CreateOrderData, OrderStatus } from "./model/order.model";

export interface OrderRepository {
  findById(id: string): Promise<Order | null>;
  findByCustomerId(customerId: string): Promise<Order[]>;
  create(data: CreateOrderData): Promise<Order>;
  updateStatus(id: string, status: OrderStatus): Promise<Order>;
}
```

```typescript
// src/order/infrastructure/persistence/prisma-order.repository.ts
import { injectable, inject } from "tsyringe";
import { PrismaClient } from "@prisma/client";
import type { OrderRepository } from "../../domain/order.repository";
import type { Order, CreateOrderData, OrderStatus } from "../../domain/model/order.model";

@injectable()
export class PrismaOrderRepository implements OrderRepository {
  constructor(@inject("PrismaClient") private prisma: PrismaClient) {}

  async findById(id: string): Promise<Order | null> {
    return this.prisma.order.findUnique({
      where: { id },
      include: { items: true },
    });
  }

  async findByCustomerId(customerId: string): Promise<Order[]> {
    return this.prisma.order.findMany({
      where: { customerId },
      include: { items: true },
      orderBy: { createdAt: "desc" },
    });
  }

  async create(data: CreateOrderData): Promise<Order> {
    return this.prisma.order.create({
      data: {
        id: data.id,
        customerId: data.customerId,
        status: data.status,
        totalAmount: data.totalAmount,
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

  async updateStatus(id: string, status: OrderStatus): Promise<Order> {
    return this.prisma.order.update({
      where: { id },
      data: { status },
      include: { items: true },
    });
  }
}
```

---

## 이벤트 핸들러

```typescript
// src/order/application/event/payment-completed.handler.ts
import { injectable, inject } from "tsyringe";
import type { OrderRepository } from "../../domain/order.repository";
import { PaymentCompletedEvent } from "../../payment/payment-completed.event";
import { logger } from "../../../global/lib/logger";

@injectable()
export class PaymentCompletedHandler {
  constructor(
    @inject("OrderRepository") private orderRepo: OrderRepository,
  ) {}

  async handle(event: PaymentCompletedEvent): Promise<void> {
    const order = await this.orderRepo.findById(event.orderId);
    if (!order) {
      logger.warn({ orderId: event.orderId }, "결제 완료 이벤트 수신했으나 주문을 찾을 수 없음");
      return;
    }

    await this.orderRepo.updateStatus(order.id, "CONFIRMED");
    logger.info({ orderId: order.id }, "결제 완료 → 주문 확정");
  }
}
```

---

## DI 컨테이너

```typescript
// src/container.ts
import "reflect-metadata";
import { container } from "tsyringe";
import { PrismaClient } from "@prisma/client";

// Infrastructure
import { InMemoryEventBus } from "./global/domain/event-bus";
import { PrismaOrderRepository } from "./order/infrastructure/persistence/prisma-order.repository";

// Application - Command
import { CreateOrderUseCase } from "./order/application/command/create-order.usecase";
import { CancelOrderUseCase } from "./order/application/command/cancel-order.usecase";
import { GetOrderUseCase } from "./order/application/query/get-order.usecase";

// Application - Event Handlers
import { PaymentCompletedHandler } from "./order/application/event/payment-completed.handler";

// Facade
import { OrderFacade } from "./order/order.facade";

// --- 싱글톤 ---
container.registerInstance("PrismaClient", new PrismaClient());

const eventBus = new InMemoryEventBus();
container.registerInstance("EventBus", eventBus);

// --- Repository ---
container.register("OrderRepository", { useClass: PrismaOrderRepository });

// --- UseCase ---
container.register("CreateOrderUseCase", { useClass: CreateOrderUseCase });
container.register("CancelOrderUseCase", { useClass: CancelOrderUseCase });
container.register("GetOrderUseCase", { useClass: GetOrderUseCase });

// --- Facade ---
container.register("OrderFacade", { useClass: OrderFacade });

// --- 이벤트 구독 등록 ---
const paymentHandler = container.resolve(PaymentCompletedHandler);
eventBus.subscribe("PaymentCompleted", (event) => paymentHandler.handle(event as any));

export { container };
```

---

## 단위 테스트 (Vitest)

```typescript
// tests/order/create-order.usecase.test.ts
import { describe, it, expect, vi, beforeEach } from "vitest";
import { CreateOrderUseCase } from "../../src/order/application/command/create-order.usecase";
import type { OrderRepository } from "../../src/order/domain/order.repository";
import type { EventBus } from "../../src/global/domain/event-bus";
import { BusinessValidationError } from "../../src/global/exception/business-validation.error";

describe("CreateOrderUseCase", () => {
  let useCase: CreateOrderUseCase;
  let mockOrderRepo: Record<keyof OrderRepository, ReturnType<typeof vi.fn>>;
  let mockEventBus: Record<keyof EventBus, ReturnType<typeof vi.fn>>;

  beforeEach(() => {
    mockOrderRepo = {
      findById: vi.fn(),
      findByCustomerId: vi.fn(),
      create: vi.fn(),
      updateStatus: vi.fn(),
    };
    mockEventBus = {
      publish: vi.fn(),
      subscribe: vi.fn(),
    };

    useCase = new CreateOrderUseCase(mockOrderRepo, mockEventBus);
  });

  it("유효한 주문을 생성하고 이벤트를 발행한다", async () => {
    mockOrderRepo.create.mockResolvedValue({
      id: "order-1",
      customerId: "customer-1",
      status: "PENDING",
      totalAmount: 30000,
      items: [{ productId: "p1", quantity: 2, unitPrice: 15000 }],
      createdAt: new Date(),
      updatedAt: new Date(),
    });

    const orderId = await useCase.execute({
      customerId: "customer-1",
      items: [{ productId: "p1", quantity: 2, unitPrice: 15000 }],
    });

    expect(orderId).toBe("order-1");
    expect(mockOrderRepo.create).toHaveBeenCalledOnce();
    expect(mockEventBus.publish).toHaveBeenCalledWith(
      expect.objectContaining({ eventName: "OrderCreated" }),
    );
  });

  it("주문 항목이 비어있으면 BusinessValidationError를 던진다", async () => {
    await expect(
      useCase.execute({ customerId: "c1", items: [] }),
    ).rejects.toThrow(BusinessValidationError);

    expect(mockOrderRepo.create).not.toHaveBeenCalled();
    expect(mockEventBus.publish).not.toHaveBeenCalled();
  });

  it("총액이 0 이하이면 BusinessValidationError를 던진다", async () => {
    await expect(
      useCase.execute({
        customerId: "c1",
        items: [{ productId: "p1", quantity: 0, unitPrice: 15000 }],
      }),
    ).rejects.toThrow(BusinessValidationError);

    expect(mockOrderRepo.create).not.toHaveBeenCalled();
  });
});
```

---

## 대규모에서 지켜야 할 규칙

| 규칙 | 설명 |
|------|------|
| **Facade로만 접근** | 다른 모듈의 내부 레이어를 직접 import 금지 |
| **이벤트로 모듈 간 통신** | Order → Inventory 직접 호출 금지, 이벤트로 전달 |
| **Command/Query 분리** | 쓰기는 command/, 읽기는 query/ 폴더에 |
| **공개 이벤트는 모듈 루트에** | `order/order-created.event.ts` — 다른 모듈이 import 가능 |
| **domain은 순수하게** | Prisma, Express 등 외부 라이브러리 의존 금지 |
| **Controller는 얇게** | 검증과 응답 변환만, 비즈니스 로직은 UseCase |
| **도메인 모델은 실용적으로** | Prisma 타입 기반 인터페이스 + 순수 함수 |

---

## 헥사고날은 언제 쓰는가

이 가이드의 기본 구조는 4-Layer 모듈 구조다. 헥사고날(포트/어댑터) 아키텍처는 다음 조건을 **모두** 충족할 때만 검토한다:

| 조건 | 설명 |
|------|------|
| **인프라 교체가 현실적** | DB를 PostgreSQL → DynamoDB로, 메시징을 Kafka → SQS로 바꿀 계획이 실제로 있다 |
| **도메인 로직이 매우 복잡** | 상태 전이, 불변식, 복잡한 계산 규칙이 많아 순수 도메인 모델 격리가 필수적이다 |
| **팀이 패턴을 이해** | Port, Adapter, Application Service 등의 개념을 팀 전체가 이해하고 합의한 상태다 |

헥사고날을 적용하면:
- `domain/ports/` — 인터페이스(Port) 정의
- `infrastructure/adapters/` — Port의 구현체(Adapter)
- 도메인 모델이 별도의 클래스(Aggregate Root, Entity, Value Object)로 분리됨
- Prisma 타입과 도메인 타입 간 매핑 레이어가 추가됨

**대부분의 Node.js 프로젝트에서는 4-Layer + Facade + Event + CQRS로 충분하다.** 헥사고날은 복잡도 대비 이득이 명확할 때만 도입한다.

---

## 전환 시그널 (중규모 → 대규모)

다음 상황이 발생하면 대규모 아키텍처(Facade + Event + CQRS)를 도입한다:

| 시그널 | 설명 |
|--------|------|
| **모듈 간 직접 호출 복잡** | 모듈끼리 서로의 UseCase를 직접 호출하며 의존이 얽히기 시작할 때 → Facade 도입 |
| **사이드이펙트 전파** | 주문 생성 시 재고 차감, 알림 발송 등 연쇄 작업이 늘어날 때 → Event 도입 |
| **읽기/쓰기 최적화 필요** | 조회 성능과 쓰기 로직을 독립적으로 최적화해야 할 때 → CQRS 도입 |
