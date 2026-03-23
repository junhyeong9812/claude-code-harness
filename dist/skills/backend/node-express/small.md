# Node.js / Express - 소규모 프로젝트 가이드

> 팀 1~3명, 엔드포인트 20개 이하, MVP/내부 툴/단일 마이크로서비스

---

## 핵심 원칙

- **TypeScript 필수**: 런타임 에러를 컴파일 타임에 잡는다
- **Express 5.x 또는 Fastify**: 성숙도 우선이면 Express, 성능 우선이면 Fastify
- **Flat 구조**: 폴더 중첩 최소화, 파일명으로 역할 구분
- **Prisma ORM**: 타입 안전 쿼리, 마이그레이션 내장
- **Zod 검증**: 런타임 입력 검증 + TypeScript 타입 추론

---

## 디렉토리 구조

```
project/
├── src/
│   ├── index.ts              # 앱 진입점, 서버 시작
│   ├── app.ts                # Express 앱 설정, 미들웨어, 라우터 등록
│   ├── routes/
│   │   ├── users.ts          # /users 라우터
│   │   └── health.ts         # /health
│   ├── schemas/
│   │   └── user.schema.ts    # Zod 스키마
│   ├── middleware/
│   │   ├── error-handler.ts  # 글로벌 에러 핸들러
│   │   └── validate.ts       # Zod 검증 미들웨어
│   ├── lib/
│   │   ├── prisma.ts         # Prisma 클라이언트 싱글톤
│   │   └── config.ts         # 환경 설정
│   └── types/
│       └── index.ts          # 공통 타입 정의
├── prisma/
│   ├── schema.prisma
│   └── migrations/
├── tests/
│   ├── routes/
│   │   └── users.test.ts
│   └── setup.ts
├── package.json
├── tsconfig.json
└── .env
```

---

## 환경 설정

```typescript
// src/lib/config.ts
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

  @@map("users")
}
```

```typescript
// src/lib/prisma.ts
import { PrismaClient } from "@prisma/client";

export const prisma = new PrismaClient({
  log: process.env.NODE_ENV === "development" ? ["query"] : [],
});
```

---

## Zod 스키마 + 검증 미들웨어

```typescript
// src/schemas/user.schema.ts
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
// src/middleware/validate.ts
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

## 라우터

```typescript
// src/routes/users.ts
import { Router, Request, Response } from "express";
import { prisma } from "../lib/prisma";
import { validate } from "../middleware/validate";
import { createUserSchema, getUserParamsSchema, CreateUserInput } from "../schemas/user.schema";
import bcrypt from "bcryptjs";

const router = Router();

// 사용자 생성
router.post("/", validate(createUserSchema), async (req: Request, res: Response) => {
  const { email, name, password } = req.body as CreateUserInput;

  const existing = await prisma.user.findUnique({ where: { email } });
  if (existing) {
    res.status(409).json({
      type: "https://api.example.com/errors/conflict",
      title: "이미 등록된 이메일입니다",
      status: 409,
    });
    return;
  }

  const hashedPassword = await bcrypt.hash(password, 12);
  const user = await prisma.user.create({
    data: { email, name, password: hashedPassword },
    select: { id: true, email: true, name: true, createdAt: true },
  });

  res.status(201).json(user);
});

// 사용자 조회
router.get("/:id", validate(getUserParamsSchema), async (req: Request, res: Response) => {
  const id = Number(req.params.id);
  const user = await prisma.user.findUnique({
    where: { id },
    select: { id: true, email: true, name: true, createdAt: true },
  });

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

  const users = await prisma.user.findMany({
    skip,
    take,
    select: { id: true, email: true, name: true, createdAt: true },
    orderBy: { createdAt: "desc" },
  });

  res.json(users);
});

export default router;
```

```typescript
// src/routes/health.ts
import { Router } from "express";

const router = Router();

router.get("/", (_, res) => {
  res.json({ status: "ok" });
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
import { config } from "./lib/config";
import { errorHandler } from "./middleware/error-handler";
import usersRouter from "./routes/users";
import healthRouter from "./routes/health";

const app = express();

// 보안 미들웨어
app.use(helmet());
app.use(cors({ origin: config.CORS_ORIGIN }));
app.use(express.json({ limit: "1mb" }));

// 라우터
app.use("/health", healthRouter);
app.use("/api/v1/users", usersRouter);

// 글로벌 에러 핸들러 (반드시 마지막에)
app.use(errorHandler);

export default app;
```

```typescript
// src/index.ts
import app from "./app";
import { config } from "./lib/config";
import { prisma } from "./lib/prisma";

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
// src/middleware/error-handler.ts
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
// tests/routes/users.test.ts
import { describe, it, expect, beforeEach } from "vitest";
import request from "supertest";
import app from "../../src/app";
import { prisma } from "../../src/lib/prisma";

describe("Users API", () => {
  beforeEach(async () => {
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
| Service/Repository 클래스 | Prisma가 이미 Repository. 라우터에서 직접 호출 |
| DI 컨테이너 (tsyringe 등) | 모듈 import로 충분 |
| 도메인 모델 별도 생성 | Prisma 생성 타입 활용 |
| 모노레포 구조 | 단일 패키지로 충분 |
| GraphQL | REST로 충분한 규모 |
