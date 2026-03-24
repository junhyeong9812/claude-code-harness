# Node.js / Express - 소규모 프로젝트 가이드

> 엔드포인트 50개 이하, MVP/내부 툴/단일 마이크로서비스

---

## 핵심 원칙

- **TypeScript 필수**: 런타임 에러를 컴파일 타임에 잡는다
- **Express 5.x 또는 Fastify**: 성숙도 우선이면 Express, 성능 우선이면 Fastify
- **도메인 폴더 + 플랫 파일**: 도메인별 폴더 안에 controller, service, schema를 같은 레벨로 배치
- **Controller → Service → Prisma**: 요청 처리, 비즈니스 로직, 데이터 접근을 분리
- **Prisma ORM**: 타입 안전 쿼리, 마이그레이션 내장
- **Zod 검증**: 런타임 입력 검증 + TypeScript 타입 추론

---

## 디렉토리 구조

```
project/
├── src/
│   ├── index.ts                 # 서버 시작
│   ├── app.ts                   # Express 앱 설정
│   │
│   ├── user/
│   │   ├── user.controller.ts   # Router + 요청 처리
│   │   ├── user.service.ts      # 비즈니스 로직
│   │   ├── user.schema.ts       # Zod 스키마
│   │   └── user.types.ts        # DTO 타입
│   │
│   ├── order/
│   │   ├── order.controller.ts
│   │   ├── order.service.ts
│   │   ├── order.schema.ts
│   │   └── order.types.ts
│   │
│   └── common/
│       ├── prisma.ts            # Prisma 클라이언트 싱글톤
│       ├── config.ts            # 환경 설정
│       ├── error-handler.ts     # 글로벌 에러 핸들러
│       └── validate.ts          # Zod 검증 미들웨어
│
├── prisma/
├── tests/
├── package.json
├── tsconfig.json
└── .env
```

---

## 환경 설정

```typescript
// src/common/config.ts
import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
  PORT: z.coerce.number().default(3000),
  DATABASE_URL: z.string().url(),
  JWT_SECRET: z.string().min(32),
  CORS_ORIGIN: z.string().default("http://localhost:5173"),
});

export const config = envSchema.parse(process.env);
export type Config = z.infer<typeof envSchema>;
```

---

## Prisma 설정

```prisma
// prisma/schema.prisma
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id        Int      @id @default(autoincrement())
  email     String   @unique
  name      String
  password  String
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt @map("updated_at")

  orders Order[]

  @@map("users")
}

model Order {
  id        Int      @id @default(autoincrement())
  userId    Int      @map("user_id")
  status    String   @default("pending")
  total     Int
  createdAt DateTime @default(now()) @map("created_at")
  updatedAt DateTime @updatedAt @map("updated_at")

  user User @relation(fields: [userId], references: [id])

  @@map("orders")
}
```

```typescript
// src/common/prisma.ts
import { PrismaClient } from "@prisma/client";

export const prisma = new PrismaClient({
  log: process.env.NODE_ENV === "development" ? ["query"] : [],
});
```

---

## Zod 스키마 + 검증 미들웨어

```typescript
// src/user/user.schema.ts
import { z } from "zod";

export const createUserSchema = z.object({
  body: z.object({
    email: z.string().email("유효한 이메일을 입력하세요"),
    name: z.string().min(1, "이름은 필수입니다").max(100),
    password: z.string().min(8, "비밀번호는 8자 이상이어야 합니다"),
  }),
});

export const getUserParamsSchema = z.object({
  params: z.object({
    id: z.coerce.number().int().positive(),
  }),
});

export type CreateUserInput = z.infer<typeof createUserSchema>["body"];
```

```typescript
// src/user/user.types.ts
export interface UserResponse {
  id: number;
  email: string;
  name: string;
  createdAt: Date;
}
```

```typescript
// src/common/validate.ts
import { Request, Response, NextFunction } from "express";
import { AnyZodObject, ZodError } from "zod";

export const validate =
  (schema: AnyZodObject) =>
  (req: Request, res: Response, next: NextFunction) => {
    try {
      schema.parse({
        body: req.body,
        query: req.query,
        params: req.params,
      });
      next();
    } catch (error) {
      if (error instanceof ZodError) {
        res.status(422).json({
          type: "https://api.example.com/errors/validation",
          title: "입력값 검증 실패",
          status: 422,
          errors: error.errors.map((e) => ({
            field: e.path.join("."),
            message: e.message,
          })),
        });
        return;
      }
      next(error);
    }
  };
```

---

## Service 레이어

Service는 비즈니스 로직을 담당한다. Controller는 요청/응답만 처리하고, 실제 로직은 Service에 위임한다.

```typescript
// src/user/user.service.ts
import { prisma } from "../common/prisma";
import { CreateUserInput, UserResponse } from "./user.types";
import bcrypt from "bcryptjs";

const USER_SELECT = {
  id: true,
  email: true,
  name: true,
  createdAt: true,
} as const;

export async function createUser(input: CreateUserInput): Promise<UserResponse> {
  const existing = await prisma.user.findUnique({
    where: { email: input.email },
  });

  if (existing) {
    throw new ConflictError("이미 등록된 이메일입니다");
  }

  const hashedPassword = await bcrypt.hash(input.password, 12);

  return prisma.user.create({
    data: { email: input.email, name: input.name, password: hashedPassword },
    select: USER_SELECT,
  });
}

export async function getUserById(id: number): Promise<UserResponse | null> {
  return prisma.user.findUnique({
    where: { id },
    select: USER_SELECT,
  });
}

export async function listUsers(skip: number, take: number): Promise<UserResponse[]> {
  return prisma.user.findMany({
    skip,
    take,
    select: USER_SELECT,
    orderBy: { createdAt: "desc" },
  });
}

// 도메인 에러
export class ConflictError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "ConflictError";
  }
}
```

---

## Controller (라우터)

Controller는 HTTP 요청을 받아 Service를 호출하고 응답을 반환한다.

```typescript
// src/user/user.controller.ts
import { Router, Request, Response } from "express";
import { validate } from "../common/validate";
import { createUserSchema, getUserParamsSchema, CreateUserInput } from "./user.schema";
import * as userService from "./user.service";
import { ConflictError } from "./user.service";

const router = Router();

// 사용자 생성
router.post("/", validate(createUserSchema), async (req: Request, res: Response) => {
  try {
    const user = await userService.createUser(req.body as CreateUserInput);
    res.status(201).json(user);
  } catch (error) {
    if (error instanceof ConflictError) {
      res.status(409).json({
        type: "https://api.example.com/errors/conflict",
        title: error.message,
        status: 409,
      });
      return;
    }
    throw error;
  }
});

// 사용자 조회
router.get("/:id", validate(getUserParamsSchema), async (req: Request, res: Response) => {
  const id = Number(req.params.id);
  const user = await userService.getUserById(id);

  if (!user) {
    res.status(404).json({
      type: "https://api.example.com/errors/not-found",
      title: "사용자를 찾을 수 없습니다",
      status: 404,
    });
    return;
  }

  res.json(user);
});

// 사용자 목록
router.get("/", async (req: Request, res: Response) => {
  const skip = Number(req.query.skip) || 0;
  const take = Math.min(Number(req.query.limit) || 20, 100);

  const users = await userService.listUsers(skip, take);
  res.json(users);
});

export default router;
```

```typescript
// src/order/order.schema.ts
import { z } from "zod";

export const createOrderSchema = z.object({
  body: z.object({
    userId: z.number().int().positive(),
    total: z.number().int().positive("금액은 양수여야 합니다"),
  }),
});

export const getOrderParamsSchema = z.object({
  params: z.object({
    id: z.coerce.number().int().positive(),
  }),
});

export type CreateOrderInput = z.infer<typeof createOrderSchema>["body"];
```

```typescript
// src/order/order.service.ts
import { prisma } from "../common/prisma";
import { CreateOrderInput } from "./order.schema";

const ORDER_SELECT = {
  id: true,
  userId: true,
  status: true,
  total: true,
  createdAt: true,
} as const;

export async function createOrder(input: CreateOrderInput) {
  return prisma.order.create({
    data: input,
    select: ORDER_SELECT,
  });
}

export async function getOrderById(id: number) {
  return prisma.order.findUnique({
    where: { id },
    select: ORDER_SELECT,
  });
}

export async function listOrdersByUser(userId: number) {
  return prisma.order.findMany({
    where: { userId },
    select: ORDER_SELECT,
    orderBy: { createdAt: "desc" },
  });
}
```

```typescript
// src/order/order.controller.ts
import { Router, Request, Response } from "express";
import { validate } from "../common/validate";
import { createOrderSchema, getOrderParamsSchema, CreateOrderInput } from "./order.schema";
import * as orderService from "./order.service";

const router = Router();

router.post("/", validate(createOrderSchema), async (req: Request, res: Response) => {
  const order = await orderService.createOrder(req.body as CreateOrderInput);
  res.status(201).json(order);
});

router.get("/:id", validate(getOrderParamsSchema), async (req: Request, res: Response) => {
  const id = Number(req.params.id);
  const order = await orderService.getOrderById(id);

  if (!order) {
    res.status(404).json({
      type: "https://api.example.com/errors/not-found",
      title: "주문을 찾을 수 없습니다",
      status: 404,
    });
    return;
  }

  res.json(order);
});

export default router;
```

---

## 앱 설정

```typescript
// src/app.ts
import express from "express";
import helmet from "helmet";
import cors from "cors";
import { config } from "./common/config";
import { errorHandler } from "./common/error-handler";
import userController from "./user/user.controller";
import orderController from "./order/order.controller";

const app = express();

// 보안 미들웨어
app.use(helmet());
app.use(cors({ origin: config.CORS_ORIGIN }));
app.use(express.json({ limit: "1mb" }));

// Health check
app.get("/health", (_, res) => {
  res.json({ status: "ok" });
});

// 도메인 라우터
app.use("/api/v1/users", userController);
app.use("/api/v1/orders", orderController);

// 글로벌 에러 핸들러 (반드시 마지막에)
app.use(errorHandler);

export default app;
```

```typescript
// src/index.ts
import app from "./app";
import { config } from "./common/config";
import { prisma } from "./common/prisma";

const server = app.listen(config.PORT, () => {
  console.log(`서버 시작: http://localhost:${config.PORT}`);
});

// Graceful shutdown
const shutdown = async () => {
  console.log("서버 종료 중...");
  server.close();
  await prisma.$disconnect();
  process.exit(0);
};

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);
```

---

## 글로벌 에러 핸들러

```typescript
// src/common/error-handler.ts
import { Request, Response, NextFunction } from "express";

export function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  _next: NextFunction,
) {
  console.error(`[ERROR] ${req.method} ${req.path}:`, err);

  // Prisma 에러 처리
  if (err.constructor.name === "PrismaClientKnownRequestError") {
    res.status(400).json({
      type: "https://api.example.com/errors/database",
      title: "데이터베이스 요청 오류",
      status: 400,
    });
    return;
  }

  res.status(500).json({
    type: "https://api.example.com/errors/internal",
    title: "서버 내부 오류가 발생했습니다",
    status: 500,
  });
}
```

---

## 테스트 (Vitest + Supertest)

```typescript
// tests/user/user.test.ts
import { describe, it, expect, beforeEach } from "vitest";
import request from "supertest";
import app from "../../src/app";
import { prisma } from "../../src/common/prisma";

describe("Users API", () => {
  beforeEach(async () => {
    await prisma.order.deleteMany();
    await prisma.user.deleteMany();
  });

  it("POST /api/v1/users - 사용자 생성", async () => {
    const res = await request(app)
      .post("/api/v1/users")
      .send({ email: "test@example.com", name: "테스트", password: "secret1234" });

    expect(res.status).toBe(201);
    expect(res.body.email).toBe("test@example.com");
    expect(res.body).not.toHaveProperty("password");
  });

  it("POST /api/v1/users - 중복 이메일 409", async () => {
    const payload = { email: "dup@example.com", name: "중복", password: "secret1234" };
    await request(app).post("/api/v1/users").send(payload);
    const res = await request(app).post("/api/v1/users").send(payload);

    expect(res.status).toBe(409);
  });

  it("GET /api/v1/users/:id - 존재하지 않는 사용자 404", async () => {
    const res = await request(app).get("/api/v1/users/9999");
    expect(res.status).toBe(404);
  });

  it("POST /api/v1/users - 검증 실패 422", async () => {
    const res = await request(app)
      .post("/api/v1/users")
      .send({ email: "invalid", name: "", password: "short" });

    expect(res.status).toBe(422);
    expect(res.body.errors).toBeDefined();
  });
});
```

---

## 필수 패키지

```json
{
  "dependencies": {
    "express": "^5.0",
    "@prisma/client": "^6.0",
    "zod": "^3.23",
    "bcryptjs": "^2.4",
    "helmet": "^8.0",
    "cors": "^2.8",
    "jsonwebtoken": "^9.0"
  },
  "devDependencies": {
    "typescript": "^5.5",
    "prisma": "^6.0",
    "vitest": "^2.0",
    "supertest": "^7.0",
    "@types/express": "^5.0",
    "@types/bcryptjs": "^2.4",
    "@types/cors": "^2.8",
    "@types/supertest": "^6.0",
    "tsx": "^4.0"
  }
}
```

---

## 소규모에서 하지 말아야 할 것

| 안티패턴 | 이유 |
|----------|------|
| 레이어별 하위 폴더 분리 (`controllers/`, `services/`, `schemas/` 등) | 도메인 폴더 안에 플랫하게 배치. 레이어별 분리는 파일 탐색만 어렵게 만든다 |
| DI 컨테이너 (tsyringe 등) | 모듈 import로 충분 |
| 도메인 모델 별도 생성 | Prisma 생성 타입 활용 |
| 모노레포 구조 | 단일 패키지로 충분 |
| GraphQL | REST로 충분한 규모 |

---

## 전환 시그널

다음 상황이 발생하면 중규모 아키텍처로 전환을 검토한다:

- **도메인 폴더 안 파일이 10개를 넘기기 시작할 때** - 도메인 내부를 하위 모듈로 분리할 시점
- **Service 하나가 200줄 이상으로 커질 때** - 책임 분리가 필요하다는 신호
- **외부 시스템 연동이 생길 때** - Adapter/Port 패턴 도입을 고려
