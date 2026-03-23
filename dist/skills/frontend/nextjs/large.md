# Next.js — 대규모 프로젝트 가이드

## 개요

- **구조**: 모노레포 (Turborepo)
- **캐싱**: 고급 캐싱 전략 (ISR, On-demand Revalidation)
- **배포**: Multi-zone 또는 마이크로 프론트엔드
- **적합한 프로젝트**: 대규모 플랫폼, 엔터프라이즈 SaaS, 다중 앱

---

## 1. 프로젝트 구조

```
my-nextjs-large/
├── apps/
│   ├── web/                            # 메인 웹앱
│   │   ├── app/
│   │   │   ├── (marketing)/            # 마케팅 페이지 그룹
│   │   │   │   ├── layout.jsx
│   │   │   │   ├── page.jsx            # 랜딩
│   │   │   │   ├── pricing/
│   │   │   │   └── features/
│   │   │   ├── (app)/                  # 앱 본체 그룹
│   │   │   │   ├── layout.jsx
│   │   │   │   ├── dashboard/
│   │   │   │   │   ├── page.jsx
│   │   │   │   │   ├── loading.jsx
│   │   │   │   │   ├── @analytics/     # Parallel Route
│   │   │   │   │   │   ├── page.jsx
│   │   │   │   │   │   └── loading.jsx
│   │   │   │   │   └── @activity/      # Parallel Route
│   │   │   │   │       ├── page.jsx
│   │   │   │   │       └── loading.jsx
│   │   │   │   ├── projects/
│   │   │   │   │   ├── page.jsx
│   │   │   │   │   └── [projectId]/
│   │   │   │   │       ├── page.jsx
│   │   │   │   │       ├── settings/
│   │   │   │   │       └── members/
│   │   │   │   ├── users/
│   │   │   │   ├── billing/
│   │   │   │   └── settings/
│   │   │   ├── (admin)/               # 관리자 그룹
│   │   │   │   ├── layout.jsx
│   │   │   │   ├── admin/
│   │   │   │   │   ├── page.jsx
│   │   │   │   │   ├── system/
│   │   │   │   │   ├── audit-log/
│   │   │   │   │   └── tenants/
│   │   │   ├── api/
│   │   │   │   ├── v1/
│   │   │   │   │   ├── users/
│   │   │   │   │   │   └── route.js
│   │   │   │   │   └── projects/
│   │   │   │   │       └── route.js
│   │   │   │   ├── webhooks/
│   │   │   │   │   ├── stripe/
│   │   │   │   │   └── github/
│   │   │   │   └── internal/
│   │   │   │       └── revalidate/
│   │   │   │           └── route.js    # On-demand revalidation
│   │   │   ├── layout.jsx
│   │   │   ├── error.jsx
│   │   │   ├── not-found.jsx
│   │   │   └── globals.css
│   │   ├── features/
│   │   │   ├── auth/
│   │   │   │   ├── actions.js
│   │   │   │   ├── queries.js
│   │   │   │   ├── schemas.js
│   │   │   │   └── hooks.js
│   │   │   ├── projects/
│   │   │   │   ├── actions.js
│   │   │   │   ├── queries.js
│   │   │   │   └── schemas.js
│   │   │   ├── users/
│   │   │   ├── billing/
│   │   │   └── analytics/
│   │   ├── components/
│   │   │   ├── layout/
│   │   │   │   ├── AppSidebar.jsx
│   │   │   │   ├── AppHeader.jsx
│   │   │   │   ├── AdminSidebar.jsx
│   │   │   │   └── Breadcrumb.jsx
│   │   │   └── domain/
│   │   │       ├── ProjectCard.jsx
│   │   │       └── UserBadge.jsx
│   │   ├── lib/
│   │   │   ├── db.js
│   │   │   ├── auth.js
│   │   │   ├── redis.js              # Redis 캐싱
│   │   │   ├── queue.js              # 백그라운드 작업 큐
│   │   │   └── logger.js
│   │   ├── middleware.js
│   │   ├── next.config.js
│   │   ├── tailwind.config.js
│   │   └── package.json
│   ├── docs/                          # 문서 사이트 (별도 앱)
│   │   ├── app/
│   │   ├── next.config.js
│   │   └── package.json
│   └── storybook/                     # 스토리북
│       └── package.json
├── packages/
│   ├── ui/                            # 디자인 시스템
│   │   ├── src/
│   │   │   ├── components/
│   │   │   │   ├── Button.tsx
│   │   │   │   ├── Input.tsx
│   │   │   │   ├── Modal.tsx
│   │   │   │   ├── DataTable.tsx
│   │   │   │   ├── Toast.tsx
│   │   │   │   ├── Command.tsx        # 커맨드 팔레트
│   │   │   │   └── index.ts
│   │   │   ├── tokens/
│   │   │   │   ├── colors.css
│   │   │   │   └── typography.css
│   │   │   └── index.ts
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── db/                            # 데이터베이스 패키지
│   │   ├── prisma/
│   │   │   ├── schema.prisma
│   │   │   └── migrations/
│   │   ├── src/
│   │   │   ├── client.ts
│   │   │   └── index.ts
│   │   └── package.json
│   ├── auth/                          # 인증 패키지
│   │   ├── src/
│   │   │   ├── config.ts
│   │   │   ├── session.ts
│   │   │   └── index.ts
│   │   └── package.json
│   ├── email/                         # 이메일 패키지
│   │   ├── src/
│   │   │   ├── templates/
│   │   │   ├── send.ts
│   │   │   └── index.ts
│   │   └── package.json
│   ├── shared-utils/
│   │   └── package.json
│   ├── eslint-config/
│   │   ├── next.js
│   │   ├── react.js
│   │   └── package.json
│   └── tsconfig/
│       ├── base.json
│       ├── next.json
│       └── package.json
├── tooling/
│   ├── scripts/
│   │   ├── seed.ts                    # DB 시드
│   │   └── migrate.ts
│   └── docker/
│       ├── docker-compose.yml
│       └── Dockerfile
├── turbo.json
├── pnpm-workspace.yaml
├── package.json
└── .github/
    └── workflows/
        ├── ci.yml
        ├── deploy-web.yml
        ├── deploy-docs.yml
        └── preview.yml
```

## 2. 상태 관리

### Server-first 상태 관리

```jsx
// 대부분의 상태는 서버에서 관리 (URL params + Server Components)
// app/(app)/projects/page.jsx
import { getProjects } from '@/features/projects/queries';
import { ProjectList } from './ProjectList';

export default async function ProjectsPage({ searchParams }) {
  const { page = 1, sort = 'updated', search = '' } = searchParams;

  // 서버에서 데이터 조회 — 클라이언트 상태 불필요
  const { projects, total } = await getProjects({ page, sort, search });

  return <ProjectList projects={projects} total={total} />;
}
```

### 클라이언트 상태가 필요한 경우 (Zustand)

```javascript
// features/app/stores/appStore.js
'use client';

import { create } from 'zustand';

/**
 * 앱 UI 상태만 클라이언트에서 관리
 * - 사이드바 토글, 모달, 토스트 등
 */
export const useAppStore = create((set) => ({
  sidebarOpen: true,
  toggleSidebar: () => set((s) => ({ sidebarOpen: !s.sidebarOpen })),

  commandOpen: false,
  openCommand: () => set({ commandOpen: true }),
  closeCommand: () => set({ commandOpen: false }),

  toasts: [],
  addToast: (toast) =>
    set((s) => ({ toasts: [...s.toasts, { id: Date.now(), ...toast }] })),
  removeToast: (id) =>
    set((s) => ({ toasts: s.toasts.filter((t) => t.id !== id) })),
}));
```

## 3. 라우팅 — Multi-zone

### Multi-zone 설정 (별도 앱 결합)

```javascript
// apps/web/next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  // 다른 Next.js 앱으로 라우팅
  async rewrites() {
    return {
      beforeFiles: [
        // /docs/* 요청을 docs 앱으로 프록시
        {
          source: '/docs/:path*',
          destination: `${process.env.DOCS_URL}/docs/:path*`,
        },
      ],
    };
  },

  // 앱 간 공유되는 basePath 설정 (docs 앱)
  // apps/docs/next.config.js: basePath: '/docs'

  transpilePackages: ['@packages/ui', '@packages/shared-utils'],

  experimental: {
    // Partial Prerendering
    ppr: true,
  },
};

module.exports = nextConfig;
```

### Intercepting Routes (모달 라우트)

```
app/(app)/projects/
├── page.jsx                    # /projects
├── [projectId]/
│   ├── page.jsx                # /projects/123
│   └── edit/
│       └── page.jsx            # /projects/123/edit (전체 페이지)
└── @modal/
    └── (.)[projectId]/
        └── edit/
            └── page.jsx        # 모달로 열리는 편집
```

```jsx
// app/(app)/projects/@modal/(.)[projectId]/edit/page.jsx
import { Modal } from '@packages/ui';
import { getProject } from '@/features/projects/queries';
import { ProjectEditForm } from '@/components/domain/ProjectEditForm';

export default async function ProjectEditModal({ params }) {
  const project = await getProject(params.projectId);

  return (
    <Modal title="프로젝트 수정">
      <ProjectEditForm project={project} />
    </Modal>
  );
}
```

## 4. 스타일링 — 디자인 시스템 패키지

```tsx
// packages/ui/src/components/DataTable.tsx
'use client';

import { useState, useMemo, useCallback } from 'react';

interface Column<T> {
  key: keyof T;
  label: string;
  sortable?: boolean;
  width?: string;
  render?: (value: any, row: T) => React.ReactNode;
}

interface DataTableProps<T> {
  columns: Column<T>[];
  data: T[];
  selectable?: boolean;
  onSelectionChange?: (ids: Set<string>) => void;
  onSort?: (key: string, dir: 'asc' | 'desc') => void;
  sortKey?: string;
  sortDir?: 'asc' | 'desc';
  loading?: boolean;
  emptyMessage?: string;
}

export function DataTable<T extends { id: string }>({
  columns,
  data,
  selectable,
  onSelectionChange,
  onSort,
  sortKey,
  sortDir,
  loading,
  emptyMessage = '데이터가 없습니다.',
}: DataTableProps<T>) {
  const [selected, setSelected] = useState<Set<string>>(new Set());

  const toggleSelect = useCallback((id: string) => {
    setSelected((prev) => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      onSelectionChange?.(next);
      return next;
    });
  }, [onSelectionChange]);

  const toggleAll = useCallback(() => {
    setSelected((prev) => {
      const next = prev.size === data.length
        ? new Set<string>()
        : new Set(data.map((d) => d.id));
      onSelectionChange?.(next);
      return next;
    });
  }, [data, onSelectionChange]);

  return (
    <div className="border rounded-lg overflow-hidden">
      {selected.size > 0 && (
        <div className="bg-blue-50 px-4 py-2 text-sm text-blue-700 flex items-center gap-2">
          {selected.size}개 선택됨
          <button onClick={() => { setSelected(new Set()); onSelectionChange?.(new Set()); }}
            className="underline">
            선택 해제
          </button>
        </div>
      )}
      <div className="overflow-x-auto">
        <table className="w-full">
          <thead className="bg-gray-50">
            <tr>
              {selectable && (
                <th className="w-10 px-4 py-3">
                  <input
                    type="checkbox"
                    checked={selected.size === data.length && data.length > 0}
                    onChange={toggleAll}
                  />
                </th>
              )}
              {columns.map((col) => (
                <th
                  key={String(col.key)}
                  className={`px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider ${
                    col.sortable ? 'cursor-pointer hover:text-gray-700' : ''
                  }`}
                  style={col.width ? { width: col.width } : undefined}
                  onClick={() => col.sortable && onSort?.(
                    String(col.key),
                    sortKey === col.key && sortDir === 'asc' ? 'desc' : 'asc'
                  )}
                >
                  {col.label}
                  {sortKey === col.key && (
                    <span className="ml-1">{sortDir === 'asc' ? '▲' : '▼'}</span>
                  )}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y">
            {loading ? (
              <tr>
                <td colSpan={columns.length + (selectable ? 1 : 0)} className="px-4 py-8 text-center text-gray-500">
                  로딩 중...
                </td>
              </tr>
            ) : data.length === 0 ? (
              <tr>
                <td colSpan={columns.length + (selectable ? 1 : 0)} className="px-4 py-8 text-center text-gray-500">
                  {emptyMessage}
                </td>
              </tr>
            ) : (
              data.map((row) => (
                <tr key={row.id} className={`hover:bg-gray-50 ${selected.has(row.id) ? 'bg-blue-50' : ''}`}>
                  {selectable && (
                    <td className="px-4 py-3">
                      <input
                        type="checkbox"
                        checked={selected.has(row.id)}
                        onChange={() => toggleSelect(row.id)}
                      />
                    </td>
                  )}
                  {columns.map((col) => (
                    <td key={String(col.key)} className="px-4 py-3 text-sm">
                      {col.render ? col.render(row[col.key], row) : String(row[col.key] ?? '')}
                    </td>
                  ))}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
```

## 5. 컴포넌트 설계 — 고급 패턴

### Partial Prerendering (PPR)

```jsx
// app/(app)/dashboard/page.jsx
import { Suspense } from 'react';
import { StatsSkeleton, ChartSkeleton, ActivitySkeleton } from '@/components/skeletons';

// PPR 활성화: 정적 셸 + 동적 콘텐츠 스트리밍
export const experimental_ppr = true;

export default function DashboardPage() {
  return (
    <div className="space-y-6">
      {/* 정적 부분: 즉시 렌더링 */}
      <h1 className="text-2xl font-bold">대시보드</h1>

      {/* 동적 부분: 스트리밍 */}
      <Suspense fallback={<StatsSkeleton />}>
        <DashboardStats />
      </Suspense>

      <div className="grid grid-cols-2 gap-6">
        <Suspense fallback={<ChartSkeleton />}>
          <RevenueChart />
        </Suspense>
        <Suspense fallback={<ActivitySkeleton />}>
          <RecentActivity />
        </Suspense>
      </div>
    </div>
  );
}

// 서버 컴포넌트 — 독립적으로 데이터 페칭
async function DashboardStats() {
  const stats = await getStats(); // 비동기 데이터
  return (
    <div className="grid grid-cols-4 gap-4">
      {stats.map((stat) => (
        <StatCard key={stat.label} {...stat} />
      ))}
    </div>
  );
}
```

### Server Action + Optimistic Updates

```jsx
// features/projects/actions.js
'use server';

import { revalidateTag } from 'next/cache';
import { z } from 'zod';
import { db } from '@packages/db';
import { getSession } from '@packages/auth';

export async function updateProjectStatus(projectId, newStatus) {
  const session = await getSession();
  if (!session) throw new Error('인증이 필요합니다.');

  // 권한 확인
  const member = await db.projectMember.findFirst({
    where: { projectId, userId: session.user.id },
  });
  if (!member) throw new Error('프로젝트에 접근할 수 없습니다.');

  await db.project.update({
    where: { id: projectId },
    data: { status: newStatus },
  });

  revalidateTag(`project-${projectId}`);
  revalidateTag('projects');
}
```

```jsx
// components/domain/ProjectCard.jsx
'use client';

import { useOptimistic, useTransition } from 'react';
import { updateProjectStatus } from '@/features/projects/actions';

export function ProjectStatusToggle({ project }) {
  const [isPending, startTransition] = useTransition();
  const [optimisticStatus, setOptimisticStatus] = useOptimistic(project.status);

  function handleToggle() {
    const newStatus = optimisticStatus === 'active' ? 'paused' : 'active';

    startTransition(async () => {
      setOptimisticStatus(newStatus);
      await updateProjectStatus(project.id, newStatus);
    });
  }

  return (
    <button
      onClick={handleToggle}
      disabled={isPending}
      className={`px-3 py-1 rounded-full text-sm ${
        optimisticStatus === 'active'
          ? 'bg-green-100 text-green-700'
          : 'bg-yellow-100 text-yellow-700'
      }`}
    >
      {optimisticStatus === 'active' ? '활성' : '일시 중지'}
    </button>
  );
}
```

## 6. 데이터 페칭 — 고급 캐싱

### On-demand Revalidation

```javascript
// app/api/internal/revalidate/route.js
import { revalidateTag, revalidatePath } from 'next/cache';
import { NextResponse } from 'next/server';

/**
 * 외부 시스템(CMS, 웹훅)에서 호출하여 캐시 무효화
 */
export async function POST(request) {
  const secret = request.headers.get('x-revalidation-secret');
  if (secret !== process.env.REVALIDATION_SECRET) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const body = await request.json();

  if (body.tag) {
    revalidateTag(body.tag);
  }
  if (body.path) {
    revalidatePath(body.path);
  }

  return NextResponse.json({ revalidated: true, now: Date.now() });
}
```

### 다층 캐싱 전략

```javascript
// features/projects/queries.js
import { db } from '@packages/db';
import { cache } from 'react';
import { unstable_cache } from 'next/cache';
import { redis } from '@/lib/redis';

/**
 * 캐싱 계층:
 * 1. React cache: 같은 요청 내 중복 제거 (request-level)
 * 2. Next.js Data Cache: 요청 간 캐시 (ISR)
 * 3. Redis: 분산 캐시 (여러 서버 인스턴스 공유)
 */

// Layer 1: React 요청 내 메모이제이션
export const getProject = cache(async (id) => {
  return db.project.findUnique({
    where: { id },
    include: { members: { include: { user: true } } },
  });
});

// Layer 2: Next.js ISR 캐시
export const getProjects = unstable_cache(
  async ({ page = 1, limit = 20, sort = 'updated', search = '' }) => {
    const where = search ? {
      name: { contains: search, mode: 'insensitive' },
    } : {};

    const orderBy = sort === 'updated'
      ? { updatedAt: 'desc' }
      : sort === 'name'
        ? { name: 'asc' }
        : { createdAt: 'desc' };

    const [projects, total] = await Promise.all([
      db.project.findMany({
        where, orderBy,
        skip: (page - 1) * limit,
        take: limit,
        include: { _count: { select: { members: true } } },
      }),
      db.project.count({ where }),
    ]);

    return { projects, total };
  },
  ['projects'],
  { revalidate: 30, tags: ['projects'] }
);

// Layer 3: Redis 캐시 (무거운 집계 쿼리)
export async function getProjectAnalytics(projectId) {
  const cacheKey = `analytics:${projectId}`;

  // Redis에서 조회
  const cached = await redis.get(cacheKey);
  if (cached) return JSON.parse(cached);

  // DB 조회 (비용이 큰 집계)
  const analytics = await db.$queryRaw`
    SELECT
      DATE_TRUNC('day', created_at) as date,
      COUNT(*) as count,
      SUM(amount) as total
    FROM events
    WHERE project_id = ${projectId}
    AND created_at > NOW() - INTERVAL '30 days'
    GROUP BY DATE_TRUNC('day', created_at)
    ORDER BY date
  `;

  // Redis에 5분 TTL로 저장
  await redis.set(cacheKey, JSON.stringify(analytics), 'EX', 300);

  return analytics;
}
```

### Webhook에서 캐시 무효화

```javascript
// app/api/webhooks/stripe/route.js
import { headers } from 'next/headers';
import { revalidateTag } from 'next/cache';
import Stripe from 'stripe';
import { db } from '@packages/db';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);

export async function POST(request) {
  const body = await request.text();
  const sig = headers().get('stripe-signature');

  let event;
  try {
    event = stripe.webhooks.constructEvent(body, sig, process.env.STRIPE_WEBHOOK_SECRET);
  } catch (err) {
    return new Response(`Webhook Error: ${err.message}`, { status: 400 });
  }

  switch (event.type) {
    case 'invoice.paid': {
      const { customer } = event.data.object;
      await db.subscription.update({
        where: { stripeCustomerId: customer },
        data: { status: 'active', currentPeriodEnd: new Date(event.data.object.period_end * 1000) },
      });
      // 관련 캐시 무효화
      revalidateTag('billing');
      revalidateTag(`user-${customer}`);
      break;
    }
    case 'customer.subscription.deleted': {
      // ...
      revalidateTag('billing');
      break;
    }
  }

  return new Response('OK');
}
```

## 7. 테스트 전략

### Server Action 테스트

```javascript
// features/projects/actions.test.js
import { describe, it, expect, vi, beforeEach } from 'vitest';

vi.mock('@packages/db');
vi.mock('@packages/auth');
vi.mock('next/cache', () => ({
  revalidateTag: vi.fn(),
  revalidatePath: vi.fn(),
}));

describe('updateProjectStatus', () => {
  beforeEach(() => vi.clearAllMocks());

  it('권한이 있는 사용자가 상태를 변경한다', async () => {
    const { getSession } = await import('@packages/auth');
    getSession.mockResolvedValue({ user: { id: 'user1' } });

    const { db } = await import('@packages/db');
    db.projectMember.findFirst.mockResolvedValue({ id: 'member1' });
    db.project.update.mockResolvedValue({});

    const { updateProjectStatus } = await import('./actions');
    await updateProjectStatus('project1', 'paused');

    expect(db.project.update).toHaveBeenCalledWith({
      where: { id: 'project1' },
      data: { status: 'paused' },
    });
  });

  it('비멤버의 요청을 거부한다', async () => {
    const { getSession } = await import('@packages/auth');
    getSession.mockResolvedValue({ user: { id: 'user2' } });

    const { db } = await import('@packages/db');
    db.projectMember.findFirst.mockResolvedValue(null);

    const { updateProjectStatus } = await import('./actions');
    await expect(updateProjectStatus('project1', 'paused'))
      .rejects.toThrow('프로젝트에 접근할 수 없습니다.');
  });
});
```

### 통합 테스트 (MSW)

```javascript
// __tests__/app/projects.test.jsx
import { render, screen, waitFor } from '@testing-library/react';
import { HttpResponse, http } from 'msw';
import { setupServer } from 'msw/node';

const server = setupServer(
  http.get('/api/v1/projects', () => {
    return HttpResponse.json({
      projects: [
        { id: '1', name: '프로젝트 A', status: 'active' },
        { id: '2', name: '프로젝트 B', status: 'paused' },
      ],
      total: 2,
    });
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());
```

### E2E 테스트

```javascript
// e2e/projects.spec.js
import { test, expect } from '@playwright/test';

test.describe('프로젝트 관리', () => {
  test.use({ storageState: '.auth/admin.json' }); // 사전 인증 상태

  test('프로젝트 생성 → 수정 → 삭제 플로우', async ({ page }) => {
    // 생성
    await page.goto('/projects');
    await page.click('button:text("새 프로젝트")');
    await page.fill('[name="name"]', 'E2E 테스트 프로젝트');
    await page.click('button:text("생성")');
    await expect(page.locator('table')).toContainText('E2E 테스트 프로젝트');

    // 수정
    await page.click('text=E2E 테스트 프로젝트');
    await page.click('button:text("수정")');
    await page.fill('[name="name"]', 'E2E 수정됨');
    await page.click('button:text("저장")');
    await expect(page.locator('h1')).toContainText('E2E 수정됨');

    // 삭제
    await page.click('button:text("삭제")');
    await page.click('button:text("확인")');
    await expect(page).toHaveURL('/projects');
  });
});
```

## 8. 성능 최적화

### ISR + 태그 기반 재검증

```javascript
// 정적 생성 + 주기적 재검증
export const revalidate = 3600; // 1시간

// 또는 태그 기반 재검증
const data = await fetch('https://api.example.com/posts', {
  next: { tags: ['posts'] },
});

// 데이터 변경 시
revalidateTag('posts'); // 해당 태그의 모든 캐시 무효화
```

### Edge Runtime

```javascript
// app/api/v1/health/route.js
export const runtime = 'edge'; // Edge에서 실행 (더 빠른 응답)

export function GET() {
  return new Response(JSON.stringify({ status: 'ok', timestamp: Date.now() }), {
    headers: { 'Content-Type': 'application/json' },
  });
}
```

### 번들 분석

```javascript
// next.config.js
const withBundleAnalyzer = require('@next/bundle-analyzer')({
  enabled: process.env.ANALYZE === 'true',
});

module.exports = withBundleAnalyzer({
  // ...config
});
```

### 이미지/폰트 최적화

```jsx
// 자동 최적화
import Image from 'next/image';
import { Inter } from 'next/font/google';

const inter = Inter({
  subsets: ['latin'],
  display: 'swap',
  variable: '--font-inter',
});
```

## 9. 보안

### 미들웨어 보안 레이어

```javascript
// middleware.js
import { NextResponse } from 'next/server';
import { getToken } from 'next-auth/jwt';

// Rate limiting (Edge에서 동작)
const rateLimitMap = new Map();

function rateLimit(ip) {
  const now = Date.now();
  const window = 60000; // 1분
  const limit = 100;

  const requests = rateLimitMap.get(ip) || [];
  const recent = requests.filter((t) => now - t < window);

  if (recent.length >= limit) {
    return false;
  }

  recent.push(now);
  rateLimitMap.set(ip, recent);
  return true;
}

export async function middleware(request) {
  const ip = request.headers.get('x-forwarded-for') || 'unknown';

  // Rate limiting
  if (!rateLimit(ip)) {
    return new NextResponse('Too Many Requests', { status: 429 });
  }

  // API 요청 보안
  if (request.nextUrl.pathname.startsWith('/api/v1')) {
    const token = await getToken({ req: request });
    if (!token) {
      return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
    }
  }

  // 보안 헤더
  const response = NextResponse.next();
  response.headers.set('X-Content-Type-Options', 'nosniff');
  response.headers.set('X-Frame-Options', 'DENY');
  response.headers.set('X-XSS-Protection', '1; mode=block');
  response.headers.set('Referrer-Policy', 'strict-origin-when-cross-origin');
  response.headers.set('Permissions-Policy', 'camera=(), microphone=()');

  return response;
}
```

### Server Action 보안

```javascript
// lib/auth.js
import { getServerSession } from 'next-auth';
import { authConfig } from '@packages/auth';

/**
 * Server Action/Route Handler에서 세션 검증
 */
export async function getSession() {
  return getServerSession(authConfig);
}

export async function requireAuth() {
  const session = await getSession();
  if (!session) throw new Error('인증이 필요합니다.');
  return session;
}

export async function requireRole(role) {
  const session = await requireAuth();
  if (session.user.role !== role) {
    throw new Error('권한이 없습니다.');
  }
  return session;
}
```

## 10. CI/CD 및 배포

```json
// turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": [".env"],
  "globalEnv": ["DATABASE_URL", "NEXTAUTH_SECRET"],
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": [".next/**", "dist/**"],
      "env": [
        "NEXT_PUBLIC_API_URL",
        "DATABASE_URL"
      ]
    },
    "test": {
      "dependsOn": ["build"],
      "outputs": ["coverage/**"]
    },
    "test:e2e": {
      "dependsOn": ["build"],
      "outputs": ["playwright-report/**"]
    },
    "lint": {},
    "typecheck": {
      "dependsOn": ["^build"]
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "db:push": {
      "cache": false
    },
    "db:seed": {
      "cache": false
    }
  }
}
```

```yaml
# .github/workflows/ci.yml
name: CI
on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  ci:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: testdb
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
        ports: ['5432:5432']

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - uses: pnpm/action-setup@v2
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm

      - run: pnpm install --frozen-lockfile

      # Turborepo 원격 캐시
      - run: pnpm turbo lint typecheck --filter=...[HEAD~1]
      - run: pnpm turbo test --filter=...[HEAD~1]
      - run: pnpm turbo build --filter=...[HEAD~1]

  e2e:
    needs: ci
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v2
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm
      - run: pnpm install --frozen-lockfile
      - run: pnpm turbo build --filter=web
      - run: npx playwright install --with-deps
      - run: pnpm --filter web test:e2e
```

```yaml
# .github/workflows/deploy-web.yml
name: Deploy Web
on:
  push:
    branches: [main]
    paths:
      - 'apps/web/**'
      - 'packages/**'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: pnpm/action-setup@v2
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: pnpm

      - run: pnpm install --frozen-lockfile
      - run: pnpm turbo build --filter=web

      # Vercel 배포 (또는 다른 플랫폼)
      - uses: amondnet/vercel-action@v25
        with:
          vercel-token: ${{ secrets.VERCEL_TOKEN }}
          vercel-org-id: ${{ secrets.VERCEL_ORG_ID }}
          vercel-project-id: ${{ secrets.VERCEL_PROJECT_ID }}
          vercel-args: '--prod'
          working-directory: apps/web
```
