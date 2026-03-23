# Next.js — 중규모 프로젝트 가이드

## 개요

- **라우팅**: Route Groups, Parallel Routes
- **데이터 변경**: Server Actions
- **미들웨어**: 인증, 리다이렉트, 로깅
- **적합한 프로젝트**: SaaS 대시보드, 전자상거래, CMS

---

## 1. 프로젝트 구조

```
my-nextjs-medium/
├── app/
│   ├── (auth)/                       # Route Group: 인증 관련
│   │   ├── layout.jsx                # 인증 레이아웃
│   │   ├── login/
│   │   │   └── page.jsx
│   │   └── register/
│   │       └── page.jsx
│   ├── (dashboard)/                  # Route Group: 대시보드
│   │   ├── layout.jsx                # 대시보드 레이아웃 (사이드바)
│   │   ├── dashboard/
│   │   │   ├── page.jsx
│   │   │   ├── loading.jsx           # 스트리밍 로딩 UI
│   │   │   └── @stats/              # Parallel Route: 통계
│   │   │       ├── page.jsx
│   │   │       └── loading.jsx
│   │   ├── users/
│   │   │   ├── page.jsx
│   │   │   ├── loading.jsx
│   │   │   ├── [id]/
│   │   │   │   ├── page.jsx
│   │   │   │   └── edit/
│   │   │   │       └── page.jsx
│   │   │   └── new/
│   │   │       └── page.jsx
│   │   ├── orders/
│   │   │   ├── page.jsx
│   │   │   └── [id]/
│   │   │       └── page.jsx
│   │   └── settings/
│   │       └── page.jsx
│   ├── api/
│   │   ├── auth/
│   │   │   └── [...nextauth]/
│   │   │       └── route.js          # NextAuth.js
│   │   └── webhooks/
│   │       └── stripe/
│   │           └── route.js
│   ├── layout.jsx                    # 루트 레이아웃
│   ├── page.jsx                      # 랜딩 페이지
│   ├── not-found.jsx
│   ├── error.jsx
│   └── globals.css
├── components/
│   ├── ui/
│   │   ├── Button.jsx
│   │   ├── Input.jsx
│   │   ├── Select.jsx
│   │   ├── Modal.jsx
│   │   ├── DataTable.jsx
│   │   ├── Pagination.jsx
│   │   ├── Toast.jsx
│   │   └── Spinner.jsx
│   ├── layout/
│   │   ├── Sidebar.jsx
│   │   ├── Header.jsx
│   │   └── Breadcrumb.jsx
│   └── forms/
│       ├── UserForm.jsx
│       └── OrderForm.jsx
├── features/
│   ├── auth/
│   │   ├── actions.js                # Server Actions
│   │   ├── auth-config.js            # NextAuth 설정
│   │   └── hooks.js
│   ├── users/
│   │   ├── actions.js                # Server Actions (CRUD)
│   │   ├── queries.js                # 데이터 조회 함수
│   │   └── schemas.js                # Zod 스키마
│   └── orders/
│       ├── actions.js
│       ├── queries.js
│       └── schemas.js
├── lib/
│   ├── db.js                         # 데이터베이스 클라이언트
│   ├── auth.js                       # 인증 헬퍼
│   ├── utils.js
│   └── constants.js
├── middleware.js                      # Next.js 미들웨어
├── next.config.js
├── tailwind.config.js
├── package.json
└── .env.local
```

## 2. 상태 관리

### Server Actions 기반 상태 변경

```javascript
// features/users/actions.js
'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { z } from 'zod';
import { db } from '@/lib/db';
import { getSession } from '@/lib/auth';

const userSchema = z.object({
  name: z.string().min(2, '이름은 2자 이상이어야 합니다.'),
  email: z.string().email('올바른 이메일을 입력해주세요.'),
  role: z.enum(['admin', 'user', 'viewer']),
  department: z.string().optional(),
});

/**
 * 사용자 생성 Server Action
 * - 서버에서 실행, 클라이언트 JS 번들에 포함되지 않음
 * - 자동 폼 검증, DB 작업, 캐시 무효화
 */
export async function createUser(prevState, formData) {
  const session = await getSession();
  if (!session || session.user.role !== 'admin') {
    return { error: '권한이 없습니다.' };
  }

  const rawData = {
    name: formData.get('name'),
    email: formData.get('email'),
    role: formData.get('role'),
    department: formData.get('department'),
  };

  const result = userSchema.safeParse(rawData);
  if (!result.success) {
    return {
      errors: result.error.flatten().fieldErrors,
    };
  }

  try {
    await db.user.create({ data: result.data });
  } catch (error) {
    if (error.code === 'P2002') {
      return { error: '이미 존재하는 이메일입니다.' };
    }
    return { error: '사용자 생성에 실패했습니다.' };
  }

  revalidatePath('/dashboard/users');
  redirect('/dashboard/users');
}

/**
 * 사용자 수정 Server Action
 */
export async function updateUser(id, prevState, formData) {
  const session = await getSession();
  if (!session) return { error: '인증이 필요합니다.' };

  const rawData = Object.fromEntries(formData);
  const result = userSchema.safeParse(rawData);

  if (!result.success) {
    return { errors: result.error.flatten().fieldErrors };
  }

  try {
    await db.user.update({ where: { id }, data: result.data });
  } catch {
    return { error: '수정에 실패했습니다.' };
  }

  revalidatePath('/dashboard/users');
  revalidatePath(`/dashboard/users/${id}`);
  redirect(`/dashboard/users/${id}`);
}

/**
 * 사용자 삭제 Server Action
 */
export async function deleteUser(id) {
  const session = await getSession();
  if (!session || session.user.role !== 'admin') {
    throw new Error('권한이 없습니다.');
  }

  await db.user.delete({ where: { id } });
  revalidatePath('/dashboard/users');
}
```

### useFormState / useFormStatus 활용

```jsx
// components/forms/UserForm.jsx
'use client';

import { useFormState, useFormStatus } from 'react-dom';
import { createUser, updateUser } from '@/features/users/actions';
import { Input } from '@/components/ui/Input';
import { Select } from '@/components/ui/Select';
import { Button } from '@/components/ui/Button';

function SubmitButton({ children }) {
  const { pending } = useFormStatus();
  return (
    <Button type="submit" disabled={pending}>
      {pending ? '처리 중...' : children}
    </Button>
  );
}

export function UserForm({ user }) {
  const action = user
    ? updateUser.bind(null, user.id)
    : createUser;

  const [state, formAction] = useFormState(action, {});

  return (
    <form action={formAction} className="space-y-4 max-w-lg">
      {state.error && (
        <div className="bg-red-50 text-red-600 p-3 rounded-lg text-sm">
          {state.error}
        </div>
      )}

      <Input
        label="이름"
        name="name"
        defaultValue={user?.name}
        error={state.errors?.name?.[0]}
        required
      />
      <Input
        label="이메일"
        name="email"
        type="email"
        defaultValue={user?.email}
        error={state.errors?.email?.[0]}
        required
      />
      <Select
        label="역할"
        name="role"
        defaultValue={user?.role || 'user'}
        error={state.errors?.role?.[0]}
        options={[
          { value: 'admin', label: '관리자' },
          { value: 'user', label: '사용자' },
          { value: 'viewer', label: '뷰어' },
        ]}
      />
      <Input
        label="부서"
        name="department"
        defaultValue={user?.department}
      />

      <div className="flex gap-3">
        <SubmitButton>{user ? '수정' : '생성'}</SubmitButton>
      </div>
    </form>
  );
}
```

## 3. 라우팅 — Route Groups & Parallel Routes

### Route Groups

```jsx
// app/(auth)/layout.jsx — 인증 전용 레이아웃
export default function AuthLayout({ children }) {
  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50">
      <div className="max-w-md w-full bg-white rounded-xl shadow-lg p-8">
        {children}
      </div>
    </div>
  );
}

// app/(dashboard)/layout.jsx — 대시보드 레이아웃
import { Sidebar } from '@/components/layout/Sidebar';
import { Header } from '@/components/layout/Header';
import { getSession } from '@/lib/auth';
import { redirect } from 'next/navigation';

export default async function DashboardLayout({ children, stats }) {
  const session = await getSession();
  if (!session) redirect('/login');

  return (
    <div className="flex min-h-screen">
      <Sidebar user={session.user} />
      <div className="flex-1">
        <Header user={session.user} />
        <main className="p-6">
          {stats}  {/* Parallel Route: 통계 위젯 */}
          {children}
        </main>
      </div>
    </div>
  );
}
```

### Parallel Routes

```jsx
// app/(dashboard)/dashboard/@stats/page.jsx
// 독립적으로 로딩/에러 처리되는 병렬 라우트
import { getDashboardStats } from '@/features/dashboard/queries';

export default async function StatsSection() {
  const stats = await getDashboardStats();

  return (
    <div className="grid grid-cols-4 gap-4 mb-6">
      {stats.map((stat) => (
        <div key={stat.label} className="bg-white rounded-lg shadow p-4">
          <p className="text-sm text-gray-500">{stat.label}</p>
          <p className="text-2xl font-bold">{stat.value}</p>
          <p className={`text-sm ${stat.change > 0 ? 'text-green-600' : 'text-red-600'}`}>
            {stat.change > 0 ? '+' : ''}{stat.change}%
          </p>
        </div>
      ))}
    </div>
  );
}

// app/(dashboard)/dashboard/@stats/loading.jsx
export default function StatsLoading() {
  return (
    <div className="grid grid-cols-4 gap-4 mb-6">
      {[...Array(4)].map((_, i) => (
        <div key={i} className="bg-white rounded-lg shadow p-4 animate-pulse">
          <div className="h-4 bg-gray-200 rounded w-20 mb-2" />
          <div className="h-8 bg-gray-200 rounded w-16" />
        </div>
      ))}
    </div>
  );
}
```

## 4. 미들웨어

```javascript
// middleware.js
import { NextResponse } from 'next/server';
import { getToken } from 'next-auth/jwt';

const PUBLIC_PATHS = ['/login', '/register', '/api/auth'];

export async function middleware(request) {
  const { pathname } = request.nextUrl;

  // 공개 경로는 패스
  if (PUBLIC_PATHS.some((path) => pathname.startsWith(path))) {
    return NextResponse.next();
  }

  // 정적 파일, API 웹훅은 패스
  if (pathname.startsWith('/_next') || pathname.startsWith('/api/webhooks')) {
    return NextResponse.next();
  }

  // 인증 체크
  const token = await getToken({ req: request });

  if (!token) {
    const loginUrl = new URL('/login', request.url);
    loginUrl.searchParams.set('redirect', pathname);
    return NextResponse.redirect(loginUrl);
  }

  // 역할 기반 접근 제어
  if (pathname.startsWith('/dashboard/settings') && token.role !== 'admin') {
    return NextResponse.redirect(new URL('/dashboard', request.url));
  }

  // 보안 헤더 추가
  const response = NextResponse.next();
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('X-Frame-Options', 'DENY');

  return response;
}

export const config = {
  matcher: [
    // 정적 파일 제외
    '/((?!_next/static|_next/image|favicon.ico).*)',
  ],
};
```

## 5. 컴포넌트 설계 패턴

### Streaming + Suspense

```jsx
// app/(dashboard)/dashboard/page.jsx
import { Suspense } from 'react';
import { RecentOrders } from './RecentOrders';
import { RevenueChart } from './RevenueChart';
import { Skeleton } from '@/components/ui/Skeleton';

export const metadata = { title: '대시보드' };

export default function DashboardPage() {
  return (
    <div className="space-y-6">
      <h1 className="text-2xl font-bold">대시보드</h1>

      <div className="grid grid-cols-2 gap-6">
        {/* 각 섹션이 독립적으로 스트리밍 */}
        <Suspense fallback={<Skeleton className="h-80" />}>
          <RevenueChart />
        </Suspense>

        <Suspense fallback={<Skeleton className="h-80" />}>
          <RecentOrders />
        </Suspense>
      </div>
    </div>
  );
}
```

```jsx
// app/(dashboard)/dashboard/RevenueChart.jsx
// 서버 컴포넌트 — 느린 API도 스트리밍으로 점진적 렌더링
import { getRevenueData } from '@/features/dashboard/queries';

export async function RevenueChart() {
  const data = await getRevenueData(); // 2초 걸리는 API

  return (
    <div className="bg-white rounded-lg shadow p-6">
      <h2 className="font-semibold mb-4">매출 현황</h2>
      {/* 차트 렌더링 */}
      <div className="h-64">
        {/* 클라이언트 차트 컴포넌트에 데이터 전달 */}
        <ChartClient data={data} />
      </div>
    </div>
  );
}
```

### 검색 + URL 상태 동기화

```jsx
// app/(dashboard)/users/page.jsx
import { getUsers } from '@/features/users/queries';
import { UserTable } from './UserTable';
import { SearchBar } from './SearchBar';
import { Pagination } from '@/components/ui/Pagination';

export default async function UserListPage({ searchParams }) {
  const page = Number(searchParams?.page) || 1;
  const search = searchParams?.search || '';
  const role = searchParams?.role || '';

  const { data: users, total } = await getUsers({ page, search, role, limit: 20 });
  const totalPages = Math.ceil(total / 20);

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h1 className="text-2xl font-bold">사용자 관리</h1>
        <a href="/dashboard/users/new" className="btn btn-primary">
          + 새 사용자
        </a>
      </div>

      {/* 클라이언트 컴포넌트: URL 쿼리 파라미터 업데이트 */}
      <SearchBar defaultSearch={search} defaultRole={role} />

      <UserTable users={users} />
      <Pagination currentPage={page} totalPages={totalPages} />
    </div>
  );
}
```

```jsx
// app/(dashboard)/users/SearchBar.jsx
'use client';

import { useRouter, useSearchParams, usePathname } from 'next/navigation';
import { useCallback, useTransition } from 'react';
import { useDebouncedCallback } from 'use-debounce';

export function SearchBar({ defaultSearch, defaultRole }) {
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [isPending, startTransition] = useTransition();

  const updateParams = useCallback((key, value) => {
    const params = new URLSearchParams(searchParams.toString());
    if (value) {
      params.set(key, value);
    } else {
      params.delete(key);
    }
    params.delete('page'); // 필터 변경 시 첫 페이지로
    startTransition(() => {
      router.push(`${pathname}?${params.toString()}`);
    });
  }, [router, pathname, searchParams]);

  const handleSearch = useDebouncedCallback((value) => {
    updateParams('search', value);
  }, 300);

  return (
    <div className="flex gap-4">
      <input
        type="search"
        defaultValue={defaultSearch}
        onChange={(e) => handleSearch(e.target.value)}
        placeholder="이름 또는 이메일 검색..."
        className="flex-1 px-3 py-2 border rounded-lg"
      />
      <select
        defaultValue={defaultRole}
        onChange={(e) => updateParams('role', e.target.value)}
        className="px-3 py-2 border rounded-lg"
      >
        <option value="">전체 역할</option>
        <option value="admin">관리자</option>
        <option value="user">사용자</option>
        <option value="viewer">뷰어</option>
      </select>
      {isPending && <span className="text-sm text-gray-500">검색 중...</span>}
    </div>
  );
}
```

## 6. 데이터 페칭

### 쿼리 함수

```javascript
// features/users/queries.js
import { db } from '@/lib/db';
import { cache } from 'react';
import { unstable_cache } from 'next/cache';

/**
 * React cache로 요청 내 중복 제거
 */
export const getUser = cache(async (id) => {
  return db.user.findUnique({
    where: { id },
    include: { department: true },
  });
});

/**
 * Next.js unstable_cache로 요청 간 캐시
 */
export const getUsers = unstable_cache(
  async ({ page = 1, limit = 20, search = '', role = '' }) => {
    const where = {};
    if (search) {
      where.OR = [
        { name: { contains: search, mode: 'insensitive' } },
        { email: { contains: search, mode: 'insensitive' } },
      ];
    }
    if (role) {
      where.role = role;
    }

    const [data, total] = await Promise.all([
      db.user.findMany({
        where,
        skip: (page - 1) * limit,
        take: limit,
        orderBy: { createdAt: 'desc' },
      }),
      db.user.count({ where }),
    ]);

    return { data, total };
  },
  ['users-list'],
  {
    revalidate: 60, // 60초 캐시
    tags: ['users'],
  }
);
```

### 삭제 with 낙관적 UI

```jsx
// app/(dashboard)/users/UserTable.jsx
'use client';

import { useOptimistic, useTransition } from 'react';
import { deleteUser } from '@/features/users/actions';
import { useRouter } from 'next/navigation';

export function UserTable({ users: initialUsers }) {
  const router = useRouter();
  const [isPending, startTransition] = useTransition();
  const [optimisticUsers, removeOptimistic] = useOptimistic(
    initialUsers,
    (state, deletedId) => state.filter((u) => u.id !== deletedId)
  );

  async function handleDelete(id) {
    if (!confirm('정말 삭제하시겠습니까?')) return;

    startTransition(async () => {
      removeOptimistic(id);  // 즉시 UI 업데이트
      await deleteUser(id);  // 서버 삭제
      router.refresh();      // 서버 데이터 갱신
    });
  }

  return (
    <table className="w-full">
      <thead>
        <tr className="border-b text-left text-sm text-gray-500">
          <th className="pb-3">이름</th>
          <th className="pb-3">이메일</th>
          <th className="pb-3">역할</th>
          <th className="pb-3">액션</th>
        </tr>
      </thead>
      <tbody>
        {optimisticUsers.map((user) => (
          <tr key={user.id} className="border-b hover:bg-gray-50">
            <td className="py-3">
              <a href={`/dashboard/users/${user.id}`} className="text-blue-600 hover:underline">
                {user.name}
              </a>
            </td>
            <td className="py-3">{user.email}</td>
            <td className="py-3">
              <span className="px-2 py-0.5 rounded-full text-xs bg-gray-100">
                {user.role}
              </span>
            </td>
            <td className="py-3">
              <button
                onClick={() => handleDelete(user.id)}
                disabled={isPending}
                className="text-red-600 hover:underline text-sm"
              >
                삭제
              </button>
            </td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
```

## 7. 테스트 전략

```jsx
// __tests__/features/users/actions.test.js
import { describe, it, expect, vi, beforeEach } from 'vitest';

// Server Action 테스트
vi.mock('@/lib/db', () => ({
  db: {
    user: {
      create: vi.fn(),
      update: vi.fn(),
      delete: vi.fn(),
    },
  },
}));

vi.mock('@/lib/auth', () => ({
  getSession: vi.fn(),
}));

vi.mock('next/cache', () => ({
  revalidatePath: vi.fn(),
}));

vi.mock('next/navigation', () => ({
  redirect: vi.fn(),
}));

describe('createUser', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('유효한 데이터로 사용자를 생성한다', async () => {
    const { getSession } = await import('@/lib/auth');
    getSession.mockResolvedValue({ user: { role: 'admin' } });

    const { db } = await import('@/lib/db');
    db.user.create.mockResolvedValue({ id: 1 });

    const { createUser } = await import('@/features/users/actions');
    const formData = new FormData();
    formData.set('name', '홍길동');
    formData.set('email', 'hong@example.com');
    formData.set('role', 'user');

    await createUser({}, formData);

    expect(db.user.create).toHaveBeenCalledWith({
      data: expect.objectContaining({ name: '홍길동' }),
    });
  });

  it('권한 없는 사용자의 요청을 거부한다', async () => {
    const { getSession } = await import('@/lib/auth');
    getSession.mockResolvedValue({ user: { role: 'user' } });

    const { createUser } = await import('@/features/users/actions');
    const result = await createUser({}, new FormData());

    expect(result.error).toBe('권한이 없습니다.');
  });
});
```

### E2E 테스트

```javascript
// e2e/users.spec.js
import { test, expect } from '@playwright/test';

test.describe('사용자 관리', () => {
  test.beforeEach(async ({ page }) => {
    // 로그인
    await page.goto('/login');
    await page.fill('[name="email"]', 'admin@test.com');
    await page.fill('[name="password"]', 'password');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL('/dashboard');
  });

  test('사용자 생성 플로우', async ({ page }) => {
    await page.goto('/dashboard/users/new');

    await page.fill('[name="name"]', '새 사용자');
    await page.fill('[name="email"]', 'new@test.com');
    await page.selectOption('[name="role"]', 'user');
    await page.click('button[type="submit"]');

    await expect(page).toHaveURL('/dashboard/users');
    await expect(page.locator('table')).toContainText('새 사용자');
  });
});
```

## 8. 성능 최적화

### 스트리밍 SSR

```jsx
// app/(dashboard)/dashboard/page.jsx
import { Suspense } from 'react';

// 각 섹션이 준비되는 대로 점진적으로 렌더링
export default function DashboardPage() {
  return (
    <>
      {/* 즉시 렌더링 */}
      <h1>대시보드</h1>

      {/* 1초 후 렌더링 */}
      <Suspense fallback={<StatsSkeleton />}>
        <StatsSection />
      </Suspense>

      {/* 2초 후 렌더링 */}
      <Suspense fallback={<ChartSkeleton />}>
        <RevenueChart />
      </Suspense>
    </>
  );
}
```

### 캐싱 전략

```javascript
// next.config.js
module.exports = {
  // 이미지 최적화
  images: {
    remotePatterns: [
      { protocol: 'https', hostname: 'images.example.com' },
    ],
    formats: ['image/avif', 'image/webp'],
  },

  // 실험적 기능
  experimental: {
    // Partial Prerendering (PPR)
    ppr: true,
  },
};
```

### 동적/정적 렌더링 제어

```javascript
// 정적 렌더링 강제
export const dynamic = 'force-static';
export const revalidate = 3600; // 1시간

// 동적 렌더링 강제
export const dynamic = 'force-dynamic';

// 특정 시간마다 재검증 (ISR)
export const revalidate = 60; // 60초
```

## 9. 보안

### Server Actions 보안

```javascript
// features/users/actions.js
'use server';

import { getSession } from '@/lib/auth';
import { z } from 'zod';
import { headers } from 'next/headers';

// 1. 항상 서버사이드 검증 수행
// 2. 세션/권한 확인
// 3. Rate Limiting

const rateLimitMap = new Map();

function rateLimit(ip, limit = 10, windowMs = 60000) {
  const now = Date.now();
  const requests = rateLimitMap.get(ip) || [];
  const recent = requests.filter((t) => now - t < windowMs);

  if (recent.length >= limit) {
    throw new Error('요청이 너무 많습니다. 잠시 후 다시 시도해주세요.');
  }

  recent.push(now);
  rateLimitMap.set(ip, recent);
}

export async function createUser(prevState, formData) {
  // Rate Limiting
  const headersList = headers();
  const ip = headersList.get('x-forwarded-for') || 'unknown';
  try {
    rateLimit(ip);
  } catch (error) {
    return { error: error.message };
  }

  // 인증 + 권한
  const session = await getSession();
  if (!session?.user || session.user.role !== 'admin') {
    return { error: '권한이 없습니다.' };
  }

  // 서버사이드 검증 (클라이언트 검증을 신뢰하지 않음)
  const result = userSchema.safeParse(Object.fromEntries(formData));
  if (!result.success) {
    return { errors: result.error.flatten().fieldErrors };
  }

  // ...DB 작업
}
```

### 보안 헤더

```javascript
// next.config.js
const securityHeaders = [
  { key: 'X-DNS-Prefetch-Control', value: 'on' },
  { key: 'Strict-Transport-Security', value: 'max-age=63072000; includeSubDomains; preload' },
  { key: 'X-Content-Type-Options', value: 'nosniff' },
  { key: 'X-Frame-Options', value: 'DENY' },
  { key: 'X-XSS-Protection', value: '1; mode=block' },
  { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
  { key: 'Permissions-Policy', value: 'camera=(), microphone=(), geolocation=()' },
];

module.exports = {
  async headers() {
    return [{ source: '/(.*)', headers: securityHeaders }];
  },
};
```

## 10. 에러 처리

```jsx
// app/error.jsx
'use client';

import { useEffect } from 'react';
import { Button } from '@/components/ui/Button';

export default function Error({ error, reset }) {
  useEffect(() => {
    // 에러 리포팅
    console.error('앱 에러:', error);
  }, [error]);

  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="text-center">
        <h2 className="text-2xl font-bold mb-4">문제가 발생했습니다</h2>
        <p className="text-gray-600 mb-6">{error.message || '예기치 않은 오류'}</p>
        <Button onClick={reset}>다시 시도</Button>
      </div>
    </div>
  );
}
```

```jsx
// app/(dashboard)/users/loading.jsx
export default function UsersLoading() {
  return (
    <div className="space-y-4">
      <div className="h-8 w-48 bg-gray-200 rounded animate-pulse" />
      <div className="bg-white rounded-lg shadow">
        {[...Array(5)].map((_, i) => (
          <div key={i} className="flex gap-4 p-4 border-b animate-pulse">
            <div className="h-4 w-32 bg-gray-200 rounded" />
            <div className="h-4 w-48 bg-gray-200 rounded" />
            <div className="h-4 w-16 bg-gray-200 rounded" />
          </div>
        ))}
      </div>
    </div>
  );
}
```
