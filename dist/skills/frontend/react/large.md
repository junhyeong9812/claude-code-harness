# React — 대규모 프로젝트 가이드

## 개요

- **아키텍처**: Feature-Sliced Design (FSD)
- **모듈화**: Module Federation (Webpack 5) 또는 독립 빌드
- **상태 관리**: Zustand Slices 또는 Jotai
- **적합한 프로젝트**: 대규모 플랫폼, 엔터프라이즈 앱, 멀티 팀

---

## 1. 프로젝트 구조 — Feature-Sliced Design

```
my-react-large/
├── apps/                              # 애플리케이션 (모노레포)
│   ├── web/                           # 메인 웹앱
│   │   ├── src/
│   │   │   ├── app/                   # [Layer 1] 앱 레이어
│   │   │   │   ├── providers/
│   │   │   │   │   ├── QueryProvider.jsx
│   │   │   │   │   ├── AuthProvider.jsx
│   │   │   │   │   └── index.jsx
│   │   │   │   ├── routes/
│   │   │   │   │   ├── index.jsx
│   │   │   │   │   └── guards.jsx
│   │   │   │   ├── styles/
│   │   │   │   │   └── global.css
│   │   │   │   └── App.jsx
│   │   │   ├── pages/                 # [Layer 2] 페이지 레이어
│   │   │   │   ├── dashboard/
│   │   │   │   │   ├── DashboardPage.jsx
│   │   │   │   │   └── index.js
│   │   │   │   ├── users/
│   │   │   │   │   ├── UserListPage.jsx
│   │   │   │   │   ├── UserDetailPage.jsx
│   │   │   │   │   └── index.js
│   │   │   │   └── orders/
│   │   │   │       ├── OrderListPage.jsx
│   │   │   │       └── index.js
│   │   │   ├── widgets/               # [Layer 3] 위젯 레이어
│   │   │   │   ├── header/
│   │   │   │   │   ├── Header.jsx
│   │   │   │   │   └── index.js
│   │   │   │   ├── sidebar/
│   │   │   │   │   ├── Sidebar.jsx
│   │   │   │   │   └── index.js
│   │   │   │   └── user-table/
│   │   │   │       ├── UserTable.jsx
│   │   │   │       └── index.js
│   │   │   ├── features/              # [Layer 4] 기능 레이어
│   │   │   │   ├── auth/
│   │   │   │   │   ├── ui/
│   │   │   │   │   │   ├── LoginForm.jsx
│   │   │   │   │   │   └── LogoutButton.jsx
│   │   │   │   │   ├── model/
│   │   │   │   │   │   ├── authStore.js
│   │   │   │   │   │   └── authSelectors.js
│   │   │   │   │   ├── api/
│   │   │   │   │   │   └── authApi.js
│   │   │   │   │   ├── lib/
│   │   │   │   │   │   └── tokenManager.js
│   │   │   │   │   └── index.js
│   │   │   │   ├── create-user/
│   │   │   │   │   ├── ui/
│   │   │   │   │   │   └── CreateUserForm.jsx
│   │   │   │   │   ├── model/
│   │   │   │   │   │   └── useCreateUser.js
│   │   │   │   │   └── index.js
│   │   │   │   └── filter-users/
│   │   │   │       ├── ui/
│   │   │   │       │   └── UserFilter.jsx
│   │   │   │       ├── model/
│   │   │   │       │   └── filterStore.js
│   │   │   │       └── index.js
│   │   │   ├── entities/              # [Layer 5] 엔티티 레이어
│   │   │   │   ├── user/
│   │   │   │   │   ├── ui/
│   │   │   │   │   │   ├── UserCard.jsx
│   │   │   │   │   │   └── UserAvatar.jsx
│   │   │   │   │   ├── model/
│   │   │   │   │   │   ├── types.js
│   │   │   │   │   │   └── userStore.js
│   │   │   │   │   ├── api/
│   │   │   │   │   │   └── userApi.js
│   │   │   │   │   └── index.js
│   │   │   │   ├── order/
│   │   │   │   │   └── ...
│   │   │   │   └── product/
│   │   │   │       └── ...
│   │   │   └── shared/                # [Layer 6] 공유 레이어
│   │   │       ├── ui/
│   │   │       │   ├── Button.jsx
│   │   │       │   ├── Input.jsx
│   │   │       │   ├── Modal.jsx
│   │   │       │   ├── DataTable.jsx
│   │   │       │   └── index.js
│   │   │       ├── api/
│   │   │       │   ├── apiClient.js
│   │   │       │   └── queryClient.js
│   │   │       ├── lib/
│   │   │       │   ├── cn.js
│   │   │       │   ├── format.js
│   │   │       │   └── validation.js
│   │   │       ├── config/
│   │   │       │   └── env.js
│   │   │       └── hooks/
│   │   │           ├── useDebounce.js
│   │   │           └── useMediaQuery.js
│   │   └── main.jsx
│   ├── admin/                         # 관리자 앱 (별도 빌드)
│   │   └── ...
│   └── mobile-web/                    # 모바일 웹앱
│       └── ...
├── packages/                          # 공유 패키지
│   ├── ui/                            # 디자인 시스템
│   │   ├── src/
│   │   │   ├── components/
│   │   │   ├── tokens/
│   │   │   └── index.js
│   │   ├── package.json
│   │   └── tsconfig.json
│   ├── shared-utils/                  # 공유 유틸리티
│   │   └── ...
│   └── eslint-config/                 # 공유 린트 설정
│       └── ...
├── turbo.json
├── pnpm-workspace.yaml
├── package.json
└── .github/
    └── workflows/
        ├── ci.yml
        └── deploy.yml
```

### FSD 레이어 규칙

```
의존성 방향 (상위 → 하위만 허용):
app → pages → widgets → features → entities → shared

금지:
- entities가 features를 참조
- shared가 다른 레이어를 참조
- 같은 레이어 내 슬라이스 간 직접 참조 (cross-import)
```

## 2. 상태 관리 — Zustand Slices + Jotai

### Zustand 슬라이스 패턴

```javascript
// src/shared/lib/createSlice.js
/**
 * Zustand 슬라이스 생성 헬퍼
 * - 타입 안전한 슬라이스 결합
 */
export function createSlice(name, initialState, actions) {
  return (set, get) => ({
    ...initialState,
    ...actions(
      // 슬라이스 범위 set
      (updater) => set(
        typeof updater === 'function'
          ? (state) => updater(state)
          : updater,
        false,
        `${name}/${Object.keys(updater || {})[0] || 'update'}`
      ),
      get
    ),
  });
}
```

```javascript
// src/features/auth/model/authStore.js
import { createSlice } from '@/shared/lib/createSlice';

export const createAuthSlice = createSlice('auth', {
  user: null,
  token: null,
  isAuthenticated: false,
  loading: false,
}, (set, get) => ({
  login: async (credentials) => {
    set({ loading: true });
    try {
      const { user, token } = await authApi.login(credentials);
      set({ user, token, isAuthenticated: true, loading: false });
    } catch (error) {
      set({ loading: false });
      throw error;
    }
  },

  logout: () => {
    set({ user: null, token: null, isAuthenticated: false });
  },

  refreshToken: async () => {
    const currentToken = get().token;
    if (!currentToken) return;
    const { token } = await authApi.refresh(currentToken);
    set({ token });
  },
}));
```

```javascript
// src/app/store.js
import { create } from 'zustand';
import { devtools, subscribeWithSelector } from 'zustand/middleware';
import { createAuthSlice } from '@/features/auth/model/authStore';
import { createUISlice } from '@/shared/model/uiStore';

/**
 * 루트 스토어 — 슬라이스 결합
 */
export const useStore = create(
  devtools(
    subscribeWithSelector((...args) => ({
      ...createAuthSlice(...args),
      ...createUISlice(...args),
    })),
    { name: 'AppStore' }
  )
);

// 슬라이스별 셀렉터 훅
export const useAuth = () => useStore((s) => ({
  user: s.user,
  isAuthenticated: s.isAuthenticated,
  loading: s.loading,
  login: s.login,
  logout: s.logout,
}));
```

### Jotai를 활용한 원자적 상태 (대안)

```javascript
// src/entities/user/model/userAtoms.js
import { atom } from 'jotai';
import { atomWithQuery } from 'jotai-tanstack-query';

/** 사용자 필터 atom */
export const userFilterAtom = atom({
  search: '',
  role: 'all',
  page: 1,
  pageSize: 20,
});

/** 사용자 목록 쿼리 atom (TanStack Query 연동) */
export const usersQueryAtom = atomWithQuery((get) => ({
  queryKey: ['users', get(userFilterAtom)],
  queryFn: async ({ queryKey }) => {
    const [, params] = queryKey;
    const response = await apiClient.get('/users', { params });
    return response.data;
  },
}));

/** 선택된 사용자 atom */
export const selectedUserAtom = atom(null);

/** 파생 atom: 필터링된 사용자 수 */
export const filteredUserCountAtom = atom((get) => {
  const query = get(usersQueryAtom);
  return query.data?.total ?? 0;
});
```

```jsx
// Jotai 사용 예시
import { useAtom, useAtomValue, useSetAtom } from 'jotai';
import { userFilterAtom, usersQueryAtom } from '@/entities/user/model/userAtoms';

function UserFilter() {
  const [filter, setFilter] = useAtom(userFilterAtom);

  return (
    <input
      value={filter.search}
      onChange={(e) => setFilter((prev) => ({ ...prev, search: e.target.value, page: 1 }))}
      placeholder="검색..."
    />
  );
}

function UserList() {
  const { data, isLoading } = useAtomValue(usersQueryAtom);
  // ...
}
```

## 3. 라우팅

```jsx
// src/app/routes/index.jsx
import { createBrowserRouter, Navigate } from 'react-router-dom';
import { lazy, Suspense } from 'react';
import { AuthGuard, RoleGuard } from './guards';
import { MainLayout } from '@/widgets/layout';
import { PageSkeleton } from '@/shared/ui';

// 마이크로 프론트엔드 리모트 (Module Federation)
const RemoteAdminModule = lazy(() => import('admin/AdminRoutes'));

const DashboardPage = lazy(() => import('@/pages/dashboard'));
const UserListPage = lazy(() => import('@/pages/users/UserListPage'));
const UserDetailPage = lazy(() => import('@/pages/users/UserDetailPage'));
const OrderListPage = lazy(() => import('@/pages/orders/OrderListPage'));

function Lazy({ children }) {
  return <Suspense fallback={<PageSkeleton />}>{children}</Suspense>;
}

export const router = createBrowserRouter([
  {
    path: '/',
    element: <AuthGuard />,
    children: [
      {
        element: <MainLayout />,
        children: [
          { index: true, element: <Navigate to="/dashboard" replace /> },
          {
            path: 'dashboard',
            element: <Lazy><DashboardPage /></Lazy>,
          },
          {
            path: 'users',
            children: [
              { index: true, element: <Lazy><UserListPage /></Lazy> },
              { path: ':id', element: <Lazy><UserDetailPage /></Lazy> },
            ],
          },
          {
            path: 'orders',
            element: <Lazy><OrderListPage /></Lazy>,
          },
          // Module Federation 리모트
          {
            path: 'admin/*',
            element: (
              <RoleGuard roles={['admin']}>
                <Lazy><RemoteAdminModule /></Lazy>
              </RoleGuard>
            ),
          },
        ],
      },
    ],
  },
]);
```

### Module Federation 설정

```javascript
// apps/web/vite.config.js
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import federation from '@originjs/vite-plugin-federation';

export default defineConfig({
  plugins: [
    react(),
    federation({
      name: 'host',
      remotes: {
        admin: 'http://localhost:3001/assets/remoteEntry.js',
      },
      shared: ['react', 'react-dom', 'zustand', '@tanstack/react-query'],
    }),
  ],
  build: {
    target: 'esnext',
    minify: false,
    cssCodeSplit: false,
  },
});
```

```javascript
// apps/admin/vite.config.js
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import federation from '@originjs/vite-plugin-federation';

export default defineConfig({
  plugins: [
    react(),
    federation({
      name: 'admin',
      filename: 'remoteEntry.js',
      exposes: {
        './AdminRoutes': './src/routes.jsx',
      },
      shared: ['react', 'react-dom', 'zustand', '@tanstack/react-query'],
    }),
  ],
});
```

## 4. 스타일링 — 디자인 시스템 패키지

```jsx
// packages/ui/src/components/Button.jsx
import { forwardRef } from 'react';
import { cva } from 'class-variance-authority';
import { cn } from '../lib/cn';

const buttonVariants = cva(
  'inline-flex items-center justify-center rounded-md font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 disabled:pointer-events-none disabled:opacity-50',
  {
    variants: {
      variant: {
        primary: 'bg-primary-600 text-white hover:bg-primary-700',
        secondary: 'bg-transparent border border-neutral-200 hover:bg-neutral-50',
        destructive: 'bg-error text-white hover:bg-red-700',
        ghost: 'hover:bg-neutral-100',
      },
      size: {
        sm: 'h-8 px-3 text-sm',
        md: 'h-10 px-4 text-sm',
        lg: 'h-12 px-6 text-base',
        icon: 'h-10 w-10',
      },
    },
    defaultVariants: {
      variant: 'primary',
      size: 'md',
    },
  }
);

export const Button = forwardRef(
  ({ className, variant, size, ...props }, ref) => (
    <button
      ref={ref}
      className={cn(buttonVariants({ variant, size }), className)}
      {...props}
    />
  )
);
Button.displayName = 'Button';
```

## 5. 컴포넌트 설계 패턴

### Compound Components (복합 컴포넌트)

```jsx
// packages/ui/src/components/DataTable.jsx
import { createContext, useContext, useState, useMemo } from 'react';

const TableContext = createContext(null);

export function DataTable({ data, children, defaultSort }) {
  const [sort, setSort] = useState(defaultSort || { key: null, dir: 'asc' });
  const [selected, setSelected] = useState(new Set());

  const sortedData = useMemo(() => {
    if (!sort.key) return data;
    return [...data].sort((a, b) => {
      const cmp = a[sort.key] < b[sort.key] ? -1 : a[sort.key] > b[sort.key] ? 1 : 0;
      return sort.dir === 'asc' ? cmp : -cmp;
    });
  }, [data, sort]);

  const ctx = {
    data: sortedData,
    sort, setSort,
    selected, setSelected,
    toggleSelect: (id) => setSelected((prev) => {
      const next = new Set(prev);
      next.has(id) ? next.delete(id) : next.add(id);
      return next;
    }),
    selectAll: () => setSelected(new Set(data.map((d) => d.id))),
    deselectAll: () => setSelected(new Set()),
  };

  return (
    <TableContext.Provider value={ctx}>
      <div className="data-table">{children}</div>
    </TableContext.Provider>
  );
}

DataTable.Head = function Head({ columns }) {
  const { sort, setSort, selected, data, selectAll, deselectAll } = useContext(TableContext);
  const allSelected = selected.size === data.length && data.length > 0;

  return (
    <thead>
      <tr>
        <th>
          <input
            type="checkbox"
            checked={allSelected}
            onChange={allSelected ? deselectAll : selectAll}
          />
        </th>
        {columns.map((col) => (
          <th
            key={col.key}
            onClick={() => col.sortable && setSort({
              key: col.key,
              dir: sort.key === col.key && sort.dir === 'asc' ? 'desc' : 'asc',
            })}
            style={{ cursor: col.sortable ? 'pointer' : 'default' }}
          >
            {col.label}
            {sort.key === col.key && (sort.dir === 'asc' ? ' ▲' : ' ▼')}
          </th>
        ))}
      </tr>
    </thead>
  );
};

DataTable.Body = function Body({ columns, renderRow }) {
  const { data, selected, toggleSelect } = useContext(TableContext);

  return (
    <tbody>
      {data.map((row) => (
        <tr key={row.id} className={selected.has(row.id) ? 'selected' : ''}>
          <td>
            <input
              type="checkbox"
              checked={selected.has(row.id)}
              onChange={() => toggleSelect(row.id)}
            />
          </td>
          {renderRow
            ? renderRow(row, columns)
            : columns.map((col) => (
                <td key={col.key}>
                  {col.render ? col.render(row[col.key], row) : row[col.key]}
                </td>
              ))}
        </tr>
      ))}
    </tbody>
  );
};

DataTable.Actions = function Actions({ children }) {
  const { selected } = useContext(TableContext);
  if (selected.size === 0) return null;
  return (
    <div className="data-table__actions">
      <span>{selected.size}개 선택됨</span>
      {children(selected)}
    </div>
  );
};

// 사용 예시
<DataTable data={users}>
  <DataTable.Actions>
    {(selected) => (
      <Button variant="destructive" onClick={() => bulkDelete([...selected])}>
        일괄 삭제
      </Button>
    )}
  </DataTable.Actions>
  <table>
    <DataTable.Head columns={columns} />
    <DataTable.Body columns={columns} />
  </table>
</DataTable>
```

### Render Props + Hook 패턴

```jsx
// src/features/filter-users/ui/UserFilter.jsx
import { useFilterStore } from '../model/filterStore';

export function UserFilter({ renderFilters }) {
  const { filters, setFilter, resetFilters, activeCount } = useFilterStore();

  return (
    <div className="filter-bar">
      {renderFilters({ filters, setFilter })}
      {activeCount > 0 && (
        <button onClick={resetFilters} className="filter-reset">
          필터 초기화 ({activeCount})
        </button>
      )}
    </div>
  );
}

// 사용
<UserFilter
  renderFilters={({ filters, setFilter }) => (
    <>
      <Input
        placeholder="검색..."
        value={filters.search}
        onChange={(e) => setFilter('search', e.target.value)}
      />
      <Select
        value={filters.role}
        onChange={(e) => setFilter('role', e.target.value)}
        options={roleOptions}
      />
    </>
  )}
/>
```

## 6. 데이터 페칭 — 고급 TanStack Query 패턴

```javascript
// src/shared/api/queryClient.js
import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,
      gcTime: 30 * 60 * 1000,
      retry: (failureCount, error) => {
        // 4xx 에러는 재시도하지 않음
        if (error?.status >= 400 && error?.status < 500) return false;
        return failureCount < 3;
      },
      refetchOnWindowFocus: import.meta.env.PROD,
    },
  },
});

// 전역 에러 핸들러
queryClient.getQueryCache().config.onError = (error, query) => {
  if (error.status === 401) {
    useStore.getState().logout();
  }
  // Sentry 리포트
  console.error(`Query failed [${query.queryKey}]:`, error);
};
```

```javascript
// src/entities/user/api/userApi.js
import { apiClient } from '@/shared/api/apiClient';

export const userApi = {
  getUsers: (params) => apiClient.get('/users', { params }),
  getUser: (id) => apiClient.get(`/users/${id}`),
  createUser: (data) => apiClient.post('/users', data),
  updateUser: (id, data) => apiClient.put(`/users/${id}`, data),
  deleteUser: (id) => apiClient.delete(`/users/${id}`),
};

// 쿼리 키 팩토리
export const userQueryKeys = {
  all: ['users'] as const,
  lists: () => [...userQueryKeys.all, 'list'] as const,
  list: (params) => [...userQueryKeys.lists(), params] as const,
  details: () => [...userQueryKeys.all, 'detail'] as const,
  detail: (id) => [...userQueryKeys.details(), id] as const,
};
```

### Infinite Query (무한 스크롤)

```javascript
// src/features/feed/hooks/useFeed.js
import { useInfiniteQuery } from '@tanstack/react-query';

export function useFeed() {
  return useInfiniteQuery({
    queryKey: ['feed'],
    queryFn: ({ pageParam = 1 }) => apiClient.get(`/feed?page=${pageParam}`),
    getNextPageParam: (lastPage) =>
      lastPage.hasMore ? lastPage.page + 1 : undefined,
    staleTime: 60 * 1000,
  });
}

// 컴포넌트에서 사용
function FeedList() {
  const { data, fetchNextPage, hasNextPage, isFetchingNextPage } = useFeed();

  const observerRef = useIntersectionObserver(() => {
    if (hasNextPage && !isFetchingNextPage) fetchNextPage();
  });

  return (
    <div>
      {data?.pages.map((page) =>
        page.items.map((item) => <FeedItem key={item.id} item={item} />)
      )}
      <div ref={observerRef}>
        {isFetchingNextPage && <Spinner />}
      </div>
    </div>
  );
}
```

## 7. 테스트 전략

### 단위 테스트 (스토어)

```javascript
// src/features/auth/model/__tests__/authStore.test.js
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { useStore } from '@/app/store';

describe('authStore', () => {
  beforeEach(() => {
    useStore.setState({
      user: null,
      token: null,
      isAuthenticated: false,
      loading: false,
    });
  });

  it('login 후 인증 상태가 변경된다', async () => {
    vi.spyOn(authApi, 'login').mockResolvedValue({
      user: { id: 1, name: '홍길동' },
      token: 'mock-token',
    });

    await useStore.getState().login({ email: 'test@test.com', password: '1234' });

    const state = useStore.getState();
    expect(state.isAuthenticated).toBe(true);
    expect(state.user.name).toBe('홍길동');
    expect(state.token).toBe('mock-token');
  });

  it('logout 후 상태가 초기화된다', () => {
    useStore.setState({ user: { id: 1 }, token: 'token', isAuthenticated: true });
    useStore.getState().logout();

    expect(useStore.getState().isAuthenticated).toBe(false);
    expect(useStore.getState().user).toBeNull();
  });
});
```

### 통합 테스트 (페이지)

```jsx
// src/pages/users/__tests__/UserListPage.test.jsx
import { screen, within, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { HttpResponse, http } from 'msw';
import { setupServer } from 'msw/node';
import { renderWithProviders } from '@/test/utils';
import { UserListPage } from '../UserListPage';

const mockUsers = [
  { id: 1, name: '홍길동', email: 'hong@test.com', role: 'admin' },
  { id: 2, name: '김철수', email: 'kim@test.com', role: 'user' },
];

const server = setupServer(
  http.get('/api/users', () => {
    return HttpResponse.json({ data: mockUsers, total: 2 });
  })
);

beforeAll(() => server.listen());
afterEach(() => server.resetHandlers());
afterAll(() => server.close());

describe('UserListPage', () => {
  it('사용자 목록을 표시한다', async () => {
    renderWithProviders(<UserListPage />, { route: '/users' });

    await waitFor(() => {
      expect(screen.getByText('홍길동')).toBeInTheDocument();
      expect(screen.getByText('김철수')).toBeInTheDocument();
    });
  });

  it('검색 시 결과를 필터링한다', async () => {
    const user = userEvent.setup();
    renderWithProviders(<UserListPage />, { route: '/users' });

    await waitFor(() => expect(screen.getByText('홍길동')).toBeInTheDocument());

    server.use(
      http.get('/api/users', ({ request }) => {
        const url = new URL(request.url);
        const search = url.searchParams.get('search');
        const filtered = mockUsers.filter((u) => u.name.includes(search));
        return HttpResponse.json({ data: filtered, total: filtered.length });
      })
    );

    await user.type(screen.getByPlaceholderText('검색...'), '홍');

    await waitFor(() => {
      expect(screen.getByText('홍길동')).toBeInTheDocument();
      expect(screen.queryByText('김철수')).not.toBeInTheDocument();
    });
  });
});
```

### E2E 테스트 (Playwright)

```javascript
// e2e/users.spec.js
import { test, expect } from '@playwright/test';

test.describe('사용자 관리', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/login');
    await page.fill('[name="email"]', 'admin@test.com');
    await page.fill('[name="password"]', 'password');
    await page.click('button[type="submit"]');
    await expect(page).toHaveURL('/dashboard');
  });

  test('사용자 목록 → 상세 → 수정 플로우', async ({ page }) => {
    await page.goto('/users');
    await expect(page.locator('table tbody tr')).toHaveCount(10);

    await page.click('text=홍길동');
    await expect(page).toHaveURL(/\/users\/\d+/);

    await page.click('button:text("수정")');
    await page.fill('[name="name"]', '홍길동 수정');
    await page.click('button:text("저장")');

    await expect(page.locator('.toast')).toContainText('수정되었습니다');
  });
});
```

## 8. 성능 최적화

### React.lazy + Prefetch

```javascript
// src/shared/lib/lazyWithPreload.js
/**
 * 프리로드 지원 lazy
 * - 마우스 호버 시 미리 로드
 */
export function lazyWithPreload(factory) {
  const Component = lazy(factory);
  Component.preload = factory;
  return Component;
}

// 사용
const UserDetailPage = lazyWithPreload(() => import('@/pages/users/UserDetailPage'));

// 목록에서 호버 시 프리로드
<Link
  to={`/users/${user.id}`}
  onMouseEnter={() => UserDetailPage.preload()}
>
  {user.name}
</Link>
```

### React Compiler (React 19+)

```javascript
// vite.config.js
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [
    react({
      babel: {
        plugins: [
          ['babel-plugin-react-compiler', {}], // 자동 메모이제이션
        ],
      },
    }),
  ],
});
```

### 번들 최적화

```javascript
// vite.config.js
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks(id) {
          if (id.includes('node_modules')) {
            if (id.includes('react') || id.includes('react-dom')) return 'react-vendor';
            if (id.includes('@tanstack')) return 'query-vendor';
            if (id.includes('zustand') || id.includes('jotai')) return 'state-vendor';
            return 'vendor';
          }
        },
      },
    },
  },
});
```

## 9. 보안

### 레이어별 보안 적용

```javascript
// src/shared/api/apiClient.js
import { useStore } from '@/app/store';

class ApiClient {
  #baseURL = import.meta.env.VITE_API_URL;

  async request(endpoint, options = {}) {
    const { token } = useStore.getState();

    const headers = {
      'Content-Type': 'application/json',
      ...(token && { Authorization: `Bearer ${token}` }),
      ...options.headers,
    };

    // CSRF 토큰 (non-GET 요청)
    if (options.method && options.method !== 'GET') {
      const csrf = this.#getCsrfToken();
      if (csrf) headers['X-XSRF-TOKEN'] = csrf;
    }

    const response = await fetch(`${this.#baseURL}${endpoint}`, {
      ...options,
      headers,
      credentials: 'include', // 쿠키 전송
    });

    if (response.status === 401) {
      useStore.getState().logout();
      throw new AuthError('인증 만료');
    }

    if (!response.ok) {
      throw new ApiError(response.status, await response.json());
    }

    return response.json();
  }

  #getCsrfToken() {
    return document.cookie
      .split('; ')
      .find((row) => row.startsWith('XSRF-TOKEN='))
      ?.split('=')[1];
  }
}

class AuthError extends Error { name = 'AuthError'; }
class ApiError extends Error {
  constructor(status, data) {
    super(data?.message || 'API Error');
    this.status = status;
    this.data = data;
  }
}

export const apiClient = new ApiClient();
```

### ESLint 보안 규칙

```javascript
// packages/eslint-config/index.js
module.exports = {
  rules: {
    // dangerouslySetInnerHTML 사용 경고
    'react/no-danger': 'warn',
    // eval 금지
    'no-eval': 'error',
    // URL 스킴 제한
    'no-script-url': 'error',
  },
  overrides: [
    {
      // shared 레이어에서 features/entities 임포트 금지 (FSD 규칙)
      files: ['src/shared/**/*'],
      rules: {
        'no-restricted-imports': ['error', {
          patterns: ['@/features/*', '@/entities/*', '@/widgets/*', '@/pages/*'],
        }],
      },
    },
    {
      // entities에서 features 임포트 금지
      files: ['src/entities/**/*'],
      rules: {
        'no-restricted-imports': ['error', {
          patterns: ['@/features/*', '@/widgets/*', '@/pages/*'],
        }],
      },
    },
  ],
};
```

## 10. 모노레포 설정

```json
// turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "globalDependencies": [".env"],
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**", ".next/**"],
      "env": ["VITE_API_URL"]
    },
    "test": {
      "dependsOn": ["build"],
      "outputs": ["coverage/**"]
    },
    "lint": {
      "outputs": []
    },
    "dev": {
      "cache": false,
      "persistent": true
    },
    "typecheck": {
      "dependsOn": ["^build"],
      "outputs": []
    }
  }
}
```

```yaml
# pnpm-workspace.yaml
packages:
  - 'apps/*'
  - 'packages/*'
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
  build:
    runs-on: ubuntu-latest
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

      # Turborepo로 영향받은 패키지만 빌드/테스트
      - run: pnpm turbo lint typecheck test build --filter=...[HEAD~1]
```
