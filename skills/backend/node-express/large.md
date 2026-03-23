# Node.js / Express - 대규모 프로젝트 가이드

> 팀 8명 이상, 엔드포인트 100개 이상, 헥사고날/클린 아키텍처 + DDD

---

## 핵심 원칙

- **헥사고날 아키텍처**: Domain ← Application ← Infrastructure
- **DDD**: Bounded Context, Aggregate Root, Value Object, Domain Event
- **CQRS**: Command/Query 분리
- **InversifyJS**: IoC 컨테이너
- **neverthrow Result 패턴**: 예외 대신 `Result<T, E>` 반환
- **Domain Event Bus**: Bounded Context 간 비동기 통신

---

## 디렉토리 구조

```
project/
├── src/
│   ├── index.ts                          # 서버 시작
│   ├── app.ts                            # Express 설정
│   ├── container.ts                      # InversifyJS 바인딩
│   ├── TYPES.ts                          # 의존성 토큰 상수
│   │
│   ├── shared/
│   │   ├── domain/
│   │   │   ├── entity.ts                 # 기본 Entity 클래스
│   │   │   ├── aggregate-root.ts         # Aggregate Root (이벤트 수집)
│   │   │   ├── value-object.ts           # Value Object 기본 클래스
│   │   │   └── domain-event.ts           # 이벤트 인터페이스
│   │   ├── application/
│   │   │   └── event-bus.ts              # EventBus 인터페이스
│   │   └── infrastructure/
│   │       ├── prisma.ts
│   │       ├── logger.ts
│   │       └── in-memory-event-bus.ts    # EventBus 구현체
│   │
│   ├── order/                            # Bounded Context: 주문
│   │   ├── domain/
│   │   │   ├── order.aggregate.ts        # Aggregate Root
│   │   │   ├── order-item.entity.ts
│   │   │   ├── value-objects/
│   │   │   │   ├── money.vo.ts
│   │   │   │   ├── order-status.vo.ts
│   │   │   │   └── address.vo.ts
│   │   │   ├── events/
│   │   │   │   ├── order-created.event.ts
│   │   │   │   └── order-cancelled.event.ts
│   │   │   ├── errors/
│   │   │   │   ├── order.errors.ts
│   │   │   │   └── index.ts
│   │   │   └── ports/
│   │   │       └── order.repository.ts   # Port (인터페이스)
│   │   │
│   │   ├── application/
│   │   │   ├── commands/
│   │   │   │   ├── create-order.command.ts
│   │   │   │   ├── create-order.handler.ts
│   │   │   │   ├── cancel-order.command.ts
│   │   │   │   └── cancel-order.handler.ts
│   │   │   ├── queries/
│   │   │   │   ├── get-order.query.ts
│   │   │   │   └── get-order.handler.ts
│   │   │   └── event-handlers/
│   │   │       └── on-order-created.ts
│   │   │
│   │   └── infrastructure/
│   │       ├── adapters/
│   │       │   └── prisma-order.repository.ts  # Adapter (구현체)
│   │       └── http/
│   │           ├── order.controller.ts
│   │           ├── order.schemas.ts
│   │           └── order.mapper.ts       # Domain → HTTP 변환
│   │
│   └── user/                             # Bounded Context: 사용자
│       ├── domain/
│       ├── application/
│       └── infrastructure/
│
├── prisma/
├── tests/
│   ├── unit/
│   │   └── order/
│   │       ├── order.aggregate.test.ts
│   │       └── create-order.handler.test.ts
│   └── integration/
├── package.json
└── tsconfig.json
```

---

## 공유 도메인 기본 클래스

```typescript
// src/shared/domain/value-object.ts
export abstract class ValueObject<T> {
  protected readonly props: T;

  constructor(props: T) {
    this.props = Object.freeze(props);
  }

  equals(other: ValueObject<T>): boolean {
    return JSON.stringify(this.props) === JSON.stringify(other.props);
  }
}
```

```typescript
// src/shared/domain/domain-event.ts
export interface DomainEvent {
  readonly eventName: string;
  readonly occurredAt: Date;
  readonly aggregateId: string;
}
```

```typescript
// src/shared/domain/aggregate-root.ts
import { DomainEvent } from "./domain-event";

export abstract class AggregateRoot {
  private _domainEvents: DomainEvent[] = [];

  get id(): string {
    return this._id;
  }

  constructor(protected readonly _id: string) {}

  protected addDomainEvent(event: DomainEvent): void {
    this._domainEvents.push(event);
  }

  collectEvents(): DomainEvent[] {
    const events = [...this._domainEvents];
    this._domainEvents = [];
    return events;
  }
}
```

---

## Value Objects

```typescript
// src/order/domain/value-objects/money.vo.ts
import { ValueObject } from "../../../shared/domain/value-object";

interface MoneyProps {
  amount: number;
  currency: string;
}

export class Money extends ValueObject<MoneyProps> {
  get amount(): number {
    return this.props.amount;
  }
  get currency(): string {
    return this.props.currency;
  }

  static create(amount: number, currency = "KRW"): Money {
    if (amount < 0) throw new Error("금액은 0 이상이어야 합니다");
    return new Money({ amount, currency });
  }

  add(other: Money): Money {
    if (this.currency !== other.currency) throw new Error("통화가 다릅니다");
    return Money.create(this.amount + other.amount, this.currency);
  }

  multiply(quantity: number): Money {
    return Money.create(this.amount * quantity, this.currency);
  }
}
```

```typescript
// src/order/domain/value-objects/order-status.vo.ts
const TRANSITIONS: Record<string, string[]> = {
  PENDING: ["CONFIRMED", "CANCELLED"],
  CONFIRMED: ["SHIPPED", "CANCELLED"],
  SHIPPED: ["DELIVERED"],
  DELIVERED: [],
  CANCELLED: [],
};

export class OrderStatus {
  private constructor(private readonly value: string) {}

  static PENDING = new OrderStatus("PENDING");
  static CONFIRMED = new OrderStatus("CONFIRMED");
  static SHIPPED = new OrderStatus("SHIPPED");
  static DELIVERED = new OrderStatus("DELIVERED");
  static CANCELLED = new OrderStatus("CANCELLED");

  canTransitionTo(target: OrderStatus): boolean {
    return (TRANSITIONS[this.value] ?? []).includes(target.value);
  }

  toString(): string {
    return this.value;
  }

  static from(value: string): OrderStatus {
    const status = (OrderStatus as any)[value];
    if (!status) throw new Error(`유효하지 않은 주문 상태: ${value}`);
    return status;
  }
}
```

---

## Aggregate Root

```typescript
// src/order/domain/order.aggregate.ts
import { AggregateRoot } from "../../shared/domain/aggregate-root";
import { Money } from "./value-objects/money.vo";
import { OrderStatus } from "./value-objects/order-status.vo";
import { OrderCreatedEvent } from "./events/order-created.event";
import { OrderCancelledEvent } from "./events/order-cancelled.event";
import { InvalidTransitionError, EmptyOrderError } from "./errors/order.errors";

export interface OrderItem {
  productId: string;
  productName: string;
  unitPrice: Money;
  quantity: number;
}

export class Order extends AggregateRoot {
  private _customerId: string;
  private _items: OrderItem[] = [];
  private _status: OrderStatus = OrderStatus.PENDING;
  private _createdAt: Date = new Date();

  get customerId(): string { return this._customerId; }
  get items(): ReadonlyArray<OrderItem> { return this._items; }
  get status(): OrderStatus { return this._status; }
  get createdAt(): Date { return this._createdAt; }

  get total(): Money {
    return this._items.reduce(
      (sum, item) => sum.add(item.unitPrice.multiply(item.quantity)),
      Money.create(0),
    );
  }

  private constructor(id: string, customerId: string) {
    super(id);
    this._customerId = customerId;
  }

  static create(id: string, customerId: string): Order {
    return new Order(id, customerId);
  }

  static reconstitute(
    id: string,
    customerId: string,
    items: OrderItem[],
    status: string,
    createdAt: Date,
  ): Order {
    const order = new Order(id, customerId);
    order._items = items;
    order._status = OrderStatus.from(status);
    order._createdAt = createdAt;
    return order;
  }

  addItem(productId: string, name: string, price: Money, qty: number): void {
    if (this._status !== OrderStatus.PENDING) {
      throw new InvalidTransitionError("확정된 주문에 상품을 추가할 수 없습니다");
    }
    this._items.push({ productId, productName: name, unitPrice: price, quantity: qty });
  }

  confirm(): void {
    if (!this._status.canTransitionTo(OrderStatus.CONFIRMED)) {
      throw new InvalidTransitionError(`${this._status} → CONFIRMED 불가`);
    }
    if (this._items.length === 0) {
      throw new EmptyOrderError();
    }
    this._status = OrderStatus.CONFIRMED;
    this.addDomainEvent(new OrderCreatedEvent(this.id, this._customerId, this.total.amount));
  }

  cancel(reason: string): void {
    if (!this._status.canTransitionTo(OrderStatus.CANCELLED)) {
      throw new InvalidTransitionError(`${this._status} → CANCELLED 불가`);
    }
    this._status = OrderStatus.CANCELLED;
    this.addDomainEvent(new OrderCancelledEvent(this.id, reason));
  }
}
```

---

## neverthrow Result 패턴

```typescript
// src/order/domain/errors/order.errors.ts
export class InvalidTransitionError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "InvalidTransitionError";
  }
}

export class EmptyOrderError extends Error {
  constructor() {
    super("상품이 없는 주문은 확정할 수 없습니다");
    this.name = "EmptyOrderError";
  }
}

export class OrderNotFoundError extends Error {
  constructor(id: string) {
    super(`주문(${id})을 찾을 수 없습니다`);
    this.name = "OrderNotFoundError";
  }
}
```

```typescript
// src/order/application/commands/create-order.handler.ts
import { injectable, inject } from "inversify";
import { Result, ok, err } from "neverthrow";
import { TYPES } from "../../../TYPES";
import type { OrderRepository } from "../../domain/ports/order.repository";
import type { EventBus } from "../../../shared/application/event-bus";
import { Order } from "../../domain/order.aggregate";
import { Money } from "../../domain/value-objects/money.vo";
import { CreateOrderCommand } from "./create-order.command";
import { randomUUID } from "crypto";

type CreateOrderError = "EMPTY_ITEMS" | "INVALID_ITEM";

@injectable()
export class CreateOrderHandler {
  constructor(
    @inject(TYPES.OrderRepository) private repo: OrderRepository,
    @inject(TYPES.EventBus) private eventBus: EventBus,
  ) {}

  async handle(cmd: CreateOrderCommand): Promise<Result<string, CreateOrderError>> {
    if (cmd.items.length === 0) {
      return err("EMPTY_ITEMS");
    }

    const order = Order.create(randomUUID(), cmd.customerId);

    for (const item of cmd.items) {
      order.addItem(item.productId, item.name, Money.create(item.price), item.quantity);
    }

    order.confirm();
    await this.repo.save(order);

    // 도메인 이벤트 발행
    for (const event of order.collectEvents()) {
      await this.eventBus.publish(event);
    }

    return ok(order.id);
  }
}
```

---

## Port (Repository 인터페이스)

```typescript
// src/order/domain/ports/order.repository.ts
import { Order } from "../order.aggregate";

export interface OrderRepository {
  findById(id: string): Promise<Order | null>;
  findByCustomerId(customerId: string): Promise<Order[]>;
  save(order: Order): Promise<void>;
  delete(id: string): Promise<void>;
}
```

---

## Adapter (Prisma 구현체)

```typescript
// src/order/infrastructure/adapters/prisma-order.repository.ts
import { injectable, inject } from "inversify";
import { PrismaClient } from "@prisma/client";
import { TYPES } from "../../../TYPES";
import type { OrderRepository } from "../../domain/ports/order.repository";
import { Order } from "../../domain/order.aggregate";
import { Money } from "../../domain/value-objects/money.vo";

@injectable()
export class PrismaOrderRepository implements OrderRepository {
  constructor(@inject(TYPES.PrismaClient) private prisma: PrismaClient) {}

  async findById(id: string): Promise<Order | null> {
    const row = await this.prisma.order.findUnique({
      where: { id },
      include: { items: true },
    });
    if (!row) return null;

    return Order.reconstitute(
      row.id,
      row.customerId,
      row.items.map((i) => ({
        productId: i.productId,
        productName: i.productName,
        unitPrice: Money.create(Number(i.unitPrice)),
        quantity: i.quantity,
      })),
      row.status,
      row.createdAt,
    );
  }

  async findByCustomerId(customerId: string): Promise<Order[]> {
    const rows = await this.prisma.order.findMany({
      where: { customerId },
      include: { items: true },
    });
    return rows.map((row) =>
      Order.reconstitute(
        row.id,
        row.customerId,
        row.items.map((i) => ({
          productId: i.productId,
          productName: i.productName,
          unitPrice: Money.create(Number(i.unitPrice)),
          quantity: i.quantity,
        })),
        row.status,
        row.createdAt,
      ),
    );
  }

  async save(order: Order): Promise<void> {
    await this.prisma.order.upsert({
      where: { id: order.id },
      create: {
        id: order.id,
        customerId: order.customerId,
        status: order.status.toString(),
        items: {
          create: order.items.map((i) => ({
            productId: i.productId,
            productName: i.productName,
            unitPrice: i.unitPrice.amount,
            quantity: i.quantity,
          })),
        },
      },
      update: {
        status: order.status.toString(),
      },
    });
  }

  async delete(id: string): Promise<void> {
    await this.prisma.order.delete({ where: { id } });
  }
}
```

---

## Event Bus

```typescript
// src/shared/application/event-bus.ts
import { DomainEvent } from "../domain/domain-event";

export interface EventBus {
  publish(event: DomainEvent): Promise<void>;
  subscribe(eventName: string, handler: (event: DomainEvent) => Promise<void>): void;
}
```

```typescript
// src/shared/infrastructure/in-memory-event-bus.ts
import { injectable } from "inversify";
import { DomainEvent } from "../domain/domain-event";
import { EventBus } from "../application/event-bus";
import { logger } from "./logger";

type Handler = (event: DomainEvent) => Promise<void>;

@injectable()
export class InMemoryEventBus implements EventBus {
  private handlers = new Map<string, Handler[]>();

  subscribe(eventName: string, handler: Handler): void {
    const existing = this.handlers.get(eventName) ?? [];
    existing.push(handler);
    this.handlers.set(eventName, existing);
  }

  async publish(event: DomainEvent): Promise<void> {
    const handlers = this.handlers.get(event.eventName) ?? [];
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

---

## InversifyJS 컨테이너

```typescript
// src/TYPES.ts
export const TYPES = {
  PrismaClient: Symbol.for("PrismaClient"),
  EventBus: Symbol.for("EventBus"),
  OrderRepository: Symbol.for("OrderRepository"),
  CreateOrderHandler: Symbol.for("CreateOrderHandler"),
  CancelOrderHandler: Symbol.for("CancelOrderHandler"),
  GetOrderHandler: Symbol.for("GetOrderHandler"),
} as const;
```

```typescript
// src/container.ts
import "reflect-metadata";
import { Container } from "inversify";
import { PrismaClient } from "@prisma/client";
import { TYPES } from "./TYPES";

import { InMemoryEventBus } from "./shared/infrastructure/in-memory-event-bus";
import { PrismaOrderRepository } from "./order/infrastructure/adapters/prisma-order.repository";
import { CreateOrderHandler } from "./order/application/commands/create-order.handler";
import { CancelOrderHandler } from "./order/application/commands/cancel-order.handler";
import { GetOrderHandler } from "./order/application/queries/get-order.handler";

const container = new Container();

container.bind(TYPES.PrismaClient).toConstantValue(new PrismaClient());
container.bind(TYPES.EventBus).to(InMemoryEventBus).inSingletonScope();
container.bind(TYPES.OrderRepository).to(PrismaOrderRepository);
container.bind(TYPES.CreateOrderHandler).to(CreateOrderHandler);
container.bind(TYPES.CancelOrderHandler).to(CancelOrderHandler);
container.bind(TYPES.GetOrderHandler).to(GetOrderHandler);

export { container };
```

---

## 도메인 단위 테스트

```typescript
// tests/unit/order/order.aggregate.test.ts
import { describe, it, expect } from "vitest";
import { Order } from "../../../src/order/domain/order.aggregate";
import { Money } from "../../../src/order/domain/value-objects/money.vo";
import { InvalidTransitionError, EmptyOrderError } from "../../../src/order/domain/errors/order.errors";

describe("Order Aggregate", () => {
  const createOrder = () => Order.create("order-1", "customer-1");

  it("상품 추가 후 확정하면 이벤트가 발생한다", () => {
    const order = createOrder();
    order.addItem("p1", "상품A", Money.create(10000), 2);
    order.confirm();

    expect(order.status.toString()).toBe("CONFIRMED");
    expect(order.total.amount).toBe(20000);

    const events = order.collectEvents();
    expect(events).toHaveLength(1);
    expect(events[0].eventName).toBe("OrderCreated");
  });

  it("빈 주문은 확정할 수 없다", () => {
    const order = createOrder();
    expect(() => order.confirm()).toThrow(EmptyOrderError);
  });

  it("확정된 주문에 상품을 추가할 수 없다", () => {
    const order = createOrder();
    order.addItem("p1", "상품A", Money.create(10000), 1);
    order.confirm();

    expect(() => order.addItem("p2", "상품B", Money.create(5000), 1))
      .toThrow(InvalidTransitionError);
  });

  it("배송 완료된 주문은 취소할 수 없다", () => {
    const order = Order.reconstitute("o1", "c1", [], "DELIVERED", new Date());
    expect(() => order.cancel("변심")).toThrow(InvalidTransitionError);
  });
});
```

---

## 의존성 규칙

```
Domain (순수 TypeScript)
  ↑
Application (Domain 의존)
  ↑
Infrastructure (Domain + Application 의존, 외부 라이브러리 사용)
```

| 레이어 | 허용 | 금지 |
|--------|------|------|
| Domain | 표준 라이브러리, 자체 Value Object | Prisma, Express, inversify |
| Application | Domain, neverthrow | Prisma, Express |
| Infrastructure | 모든 것 | - |

---

## 대규모에서 반드시 지켜야 할 것

| 규칙 | 설명 |
|------|------|
| Aggregate 간 ID 참조 | 다른 Aggregate를 직접 참조하지 않음 |
| 이벤트로 Context 간 통신 | Order → Inventory 직접 호출 금지 |
| `reconstitute` 팩토리 | DB에서 읽을 때는 검증 없이 복원 |
| Result 패턴 | 예상 가능한 실패는 예외 대신 `Result` |
| 불변 Value Object | `Object.freeze`로 불변성 보장 |
