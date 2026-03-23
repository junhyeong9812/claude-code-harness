# React — 중규모 프로젝트 가이드

## 개요

- **구조**: Feature 폴더 기반
- **데이터 페칭**: TanStack Query (React Query)
- **상태 관리**: Zustand
- **폼**: React Hook Form + Zod
- **적합한 프로젝트**: 관리자 대시보드, B2B SaaS, 중규모 서비스

---

## 1. 프로젝트 구조

```
my-react-medium/
├── public/
│   └── assets/
├── src/
│   ├── app/
│   │   ├── App.jsx
│   │   ├── routes.jsx              # 라우트 정의
│   │   ├── providers.jsx           # 글로벌 프로바이더
│   │   └── error-boundary.jsx
│   ├── features/
│   │   ├── auth/
│   │   │   ├── components/
│   │   │   │   ├── LoginForm.jsx
│   │   │   │   ├── RegisterForm.jsx
│   │   │   │   └── ProtectedRoute.jsx
│   │   │   ├── hooks/
│   │   │   │   ├── useAuth.js
│   │   │   │   └── useLogin.js
│   │   │   ├── services/
│   │   │   │   └── authService.js
│   │   │   ├── store/
│   │   │   │   └── authStore.js
│   │   │   ├── schemas/
│   │   │   │   └── authSchema.js
│   │   │   └── index.js            # 공개 API (배럴 파일)
│   │   ├── dashboard/
│   │   │   ├── components/
│   │   │   │   ├── DashboardPage.jsx
│   │   │   │   ├── StatsGrid.jsx
│   │   │   │   ├── RevenueChart.jsx
│   │   │   │   └── RecentOrders.jsx
│   │   │   ├── hooks/
│   │   │   │   └── useDashboardData.js
│   │   │   ├── services/
│   │   │   │   └── dashboardService.js
│   │   │   └── index.js
│   │   └── users/
│   │       ├── components/
│   │       │   ├── UserListPage.jsx
│   │       │   ├── UserDetailPage.jsx
│   │       │   ├── UserForm.jsx
│   │       │   └── UserTable.jsx
│   │       ├── hooks/
│   │       │   ├── useUsers.js
│   │       │   └── useUserMutation.js
│   │       ├── services/
│   │       │   └── userService.js
│   │       ├── schemas/
│   │       │   └── userSchema.js
│   │       └── index.js
│   ├── shared/
│   │   ├── components/
│   │   │   ├── ui/
│   │   │   │   ├── Button.jsx
│   │   │   │   ├── Input.jsx
│   │   │   │   ├── Select.jsx
│   │   │   │   ├── Modal.jsx
│   │   │   │   ├── Table.jsx
│   │   │   │   ├── Pagination.jsx
│   │   │   │   ├── Toast.jsx
│   │   │   │   └── Spinner.jsx
│   │   │   └── layout/
│   │   │       ├── MainLayout.jsx
│   │   │       ├── AuthLayout.jsx
│   │   │       ├── Sidebar.jsx
│   │   │       └── Header.jsx
│   │   ├── hooks/
│   │   │   ├── useDebounce.js
│   │   │   ├── useMediaQuery.js
│   │   │   └── useClickOutside.js
│   │   ├── utils/
│   │   │   ├── format.js
│   │   │   ├── cn.js               # className 헬퍼
│   │   │   └── constants.js
│   │   └── lib/
│   │       ├── api-client.js       # Axios/fetch 래퍼
│   │       └── query-client.js     # TanStack Query 설정
│   ├── styles/
│   │   ├── global.css
│   │   └── variables.css
│   └── main.jsx
├── tests/
│   ├── setup.js
│   └── utils.jsx                   # 테스트 유틸 (커스텀 render)
├── vite.config.js
├── vitest.config.js
├── tailwind.config.js              # (선택) Tailwind CSS
├── package.json
└── .eslintrc.cjs
```

## 2. 상태 관리 — Zustand

```javascript
// src/features/auth/store/authStore.js
import { create } from 'zustand';
import { devtools, persist } from 'zustand/middleware';

/**
 * 인증 상태 스토어
 * - devtools: Redux DevTools 연동
 * - persist: localStorage 영속화
 */
export const useAuthStore = create(
  devtools(
    persist(
      (set, get) => ({
        // 상태
        user: null,
        token: null,
        isAuthenticated: false,

        // 액션
        setAuth: (user, token) =>
          set(
            { user, token, isAuthenticated: true },
            false,
            'auth/setAuth'
          ),

        logout: () =>
          set(
            { user: null, token: null, isAuthenticated: false },
            false,
            'auth/logout'
          ),

        updateUser: (updates) =>
          set(
            (state) => ({
              user: state.user ? { ...state.user, ...updates } : null,
            }),
            false,
            'auth/updateUser'
          ),

        // 파생 상태 (getter)
        isAdmin: () => get().user?.role === 'admin',
      }),
      {
        name: 'auth-storage',
        partialize: (state) => ({
          token: state.token,
          user: state.user,
          isAuthenticated: state.isAuthenticated,
        }),
      }
    ),
    { name: 'AuthStore' }
  )
);
```

```javascript
// src/shared/stores/uiStore.js
import { create } from 'zustand';

/**
 * UI 상태 스토어 (사이드바, 모달, 토스트 등)
 */
export const useUIStore = create((set) => ({
  sidebarOpen: true,
  toggleSidebar: () => set((state) => ({ sidebarOpen: !state.sidebarOpen })),

  // 토스트 관리
  toasts: [],
  addToast: (toast) =>
    set((state) => ({
      toasts: [...state.toasts, { id: Date.now(), ...toast }],
    })),
  removeToast: (id) =>
    set((state) => ({
      toasts: state.toasts.filter((t) => t.id !== id),
    })),

  // 모달 관리
  modal: null,
  openModal: (modal) => set({ modal }),
  closeModal: () => set({ modal: null }),
}));
```

## 3. 라우팅

```jsx
// src/app/routes.jsx
import { createBrowserRouter, Navigate } from 'react-router-dom';
import { lazy, Suspense } from 'react';
import { MainLayout } from '../shared/components/layout/MainLayout';
import { AuthLayout } from '../shared/components/layout/AuthLayout';
import { ProtectedRoute } from '../features/auth';
import { Spinner } from '../shared/components/ui/Spinner';
import { ErrorBoundary } from './error-boundary';

// 코드 스플리팅: 페이지 단위 지연 로딩
const LoginPage = lazy(() => import('../features/auth/components/LoginForm'));
const RegisterPage = lazy(() => import('../features/auth/components/RegisterForm'));
const DashboardPage = lazy(() => import('../features/dashboard/components/DashboardPage'));
const UserListPage = lazy(() => import('../features/users/components/UserListPage'));
const UserDetailPage = lazy(() => import('../features/users/components/UserDetailPage'));

function SuspenseWrapper({ children }) {
  return <Suspense fallback={<Spinner fullScreen />}>{children}</Suspense>;
}

export const router = createBrowserRouter([
  {
    path: '/',
    errorElement: <ErrorBoundary />,
    children: [
      // 인증 라우트 (비로그인)
      {
        element: <AuthLayout />,
        children: [
          { path: 'login', element: <SuspenseWrapper><LoginPage /></SuspenseWrapper> },
          { path: 'register', element: <SuspenseWrapper><RegisterPage /></SuspenseWrapper> },
        ],
      },
      // 보호된 라우트 (로그인 필요)
      {
        element: <ProtectedRoute />,
        children: [
          {
            element: <MainLayout />,
            children: [
              { index: true, element: <Navigate to="/dashboard" replace /> },
              {
                path: 'dashboard',
                element: <SuspenseWrapper><DashboardPage /></SuspenseWrapper>,
              },
              {
                path: 'users',
                children: [
                  { index: true, element: <SuspenseWrapper><UserListPage /></SuspenseWrapper> },
                  { path: ':id', element: <SuspenseWrapper><UserDetailPage /></SuspenseWrapper> },
                ],
              },
            ],
          },
        ],
      },
    ],
  },
]);
```

```jsx
// src/features/auth/components/ProtectedRoute.jsx
import { Navigate, Outlet, useLocation } from 'react-router-dom';
import { useAuthStore } from '../store/authStore';

export function ProtectedRoute() {
  const isAuthenticated = useAuthStore((state) => state.isAuthenticated);
  const location = useLocation();

  if (!isAuthenticated) {
    return <Navigate to="/login" state={{ from: location }} replace />;
  }

  return <Outlet />;
}
```

## 4. 스타일링

CSS Modules 또는 Tailwind CSS를 사용합니다.

```jsx
// src/shared/utils/cn.js
/**
 * className 결합 유틸리티 (clsx 대안)
 */
export function cn(...args) {
  return args
    .flat()
    .filter((x) => typeof x === 'string' && x.trim())
    .join(' ');
}

// 조건부 클래스:
// cn('btn', variant === 'primary' && 'btn--primary', disabled && 'btn--disabled')
```

```jsx
// src/shared/components/ui/Table.jsx (CSS Modules 예시)
import styles from './Table.module.css';
import { cn } from '../../utils/cn';

export function Table({ columns, data, onSort, sortKey, sortDir }) {
  return (
    <div className={styles.wrapper}>
      <table className={styles.table}>
        <thead>
          <tr>
            {columns.map((col) => (
              <th
                key={col.key}
                className={cn(styles.th, col.sortable && styles.sortable)}
                onClick={() => col.sortable && onSort?.(col.key)}
              >
                {col.label}
                {sortKey === col.key && (
                  <span className={styles.sortIcon}>
                    {sortDir === 'asc' ? '▲' : '▼'}
                  </span>
                )}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>
          {data.map((row, i) => (
            <tr key={row.id || i}>
              {columns.map((col) => (
                <td key={col.key} className={styles.td}>
                  {col.render ? col.render(row[col.key], row) : row[col.key]}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

## 5. 컴포넌트 설계 패턴

### 배럴 파일 (Feature 공개 API)

```javascript
// src/features/auth/index.js
// 외부에서 접근 가능한 것만 내보냄
export { ProtectedRoute } from './components/ProtectedRoute';
export { useAuth } from './hooks/useAuth';
export { useAuthStore } from './store/authStore';
```

### Error Boundary

```jsx
// src/app/error-boundary.jsx
import { Component } from 'react';
import { useRouteError, isRouteErrorResponse } from 'react-router-dom';

export function ErrorBoundary() {
  const error = useRouteError();

  if (isRouteErrorResponse(error)) {
    return (
      <div className="error-page">
        <h1>{error.status}</h1>
        <p>{error.statusText}</p>
      </div>
    );
  }

  return (
    <div className="error-page">
      <h1>오류 발생</h1>
      <p>예기치 않은 오류가 발생했습니다.</p>
    </div>
  );
}

// 클래스 기반 Error Boundary (render 에러 포착)
export class ReactErrorBoundary extends Component {
  state = { hasError: false, error: null };

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, errorInfo) {
    console.error('React Error Boundary:', error, errorInfo);
    // Sentry 등 에러 리포팅
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback || (
        <div className="error-page">
          <h1>문제가 발생했습니다</h1>
          <button onClick={() => this.setState({ hasError: false })}>
            다시 시도
          </button>
        </div>
      );
    }
    return this.props.children;
  }
}
```

### 레이아웃 패턴

```jsx
// src/shared/components/layout/MainLayout.jsx
import { Outlet } from 'react-router-dom';
import { Sidebar } from './Sidebar';
import { Header } from './Header';
import { useUIStore } from '../../stores/uiStore';

export function MainLayout() {
  const sidebarOpen = useUIStore((state) => state.sidebarOpen);

  return (
    <div className={`layout ${sidebarOpen ? 'layout--sidebar-open' : ''}`}>
      <Sidebar />
      <div className="layout__content">
        <Header />
        <main className="layout__main">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
```

## 6. 데이터 페칭 — TanStack Query

```javascript
// src/shared/lib/api-client.js
const BASE_URL = import.meta.env.VITE_API_URL || '/api';

class ApiClient {
  async request(endpoint, options = {}) {
    const token = useAuthStore.getState().token;

    const config = {
      headers: {
        'Content-Type': 'application/json',
        ...(token && { Authorization: `Bearer ${token}` }),
        ...options.headers,
      },
      ...options,
    };

    const response = await fetch(`${BASE_URL}${endpoint}`, config);

    if (response.status === 401) {
      useAuthStore.getState().logout();
      window.location.href = '/login';
      throw new Error('인증 만료');
    }

    if (!response.ok) {
      const error = new Error('API 오류');
      error.status = response.status;
      error.data = await response.json().catch(() => null);
      throw error;
    }

    return response.json();
  }

  get(endpoint, options) { return this.request(endpoint, options); }

  post(endpoint, data, options) {
    return this.request(endpoint, {
      method: 'POST',
      body: JSON.stringify(data),
      ...options,
    });
  }

  put(endpoint, data, options) {
    return this.request(endpoint, {
      method: 'PUT',
      body: JSON.stringify(data),
      ...options,
    });
  }

  delete(endpoint, options) {
    return this.request(endpoint, { method: 'DELETE', ...options });
  }
}

export const apiClient = new ApiClient();
```

```javascript
// src/shared/lib/query-client.js
import { QueryClient } from '@tanstack/react-query';

export const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 5 * 60 * 1000,      // 5분
      gcTime: 10 * 60 * 1000,         // 10분 (구 cacheTime)
      retry: 1,
      refetchOnWindowFocus: false,
    },
    mutations: {
      retry: 0,
    },
  },
});
```

```javascript
// src/features/users/services/userService.js
import { apiClient } from '../../../shared/lib/api-client';

export const userService = {
  getUsers: (params) => apiClient.get(`/users?${new URLSearchParams(params)}`),
  getUserById: (id) => apiClient.get(`/users/${id}`),
  createUser: (data) => apiClient.post('/users', data),
  updateUser: (id, data) => apiClient.put(`/users/${id}`, data),
  deleteUser: (id) => apiClient.delete(`/users/${id}`),
};
```

```javascript
// src/features/users/hooks/useUsers.js
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { userService } from '../services/userService';
import { useUIStore } from '../../../shared/stores/uiStore';

/** 쿼리 키 팩토리 */
export const userKeys = {
  all: ['users'],
  lists: () => [...userKeys.all, 'list'],
  list: (params) => [...userKeys.lists(), params],
  details: () => [...userKeys.all, 'detail'],
  detail: (id) => [...userKeys.details(), id],
};

/** 사용자 목록 조회 */
export function useUsers(params = {}) {
  return useQuery({
    queryKey: userKeys.list(params),
    queryFn: () => userService.getUsers(params),
    placeholderData: (previousData) => previousData, // 페이지네이션 시 이전 데이터 유지
  });
}

/** 사용자 상세 조회 */
export function useUser(id) {
  return useQuery({
    queryKey: userKeys.detail(id),
    queryFn: () => userService.getUserById(id),
    enabled: !!id,
  });
}
```

```javascript
// src/features/users/hooks/useUserMutation.js
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { userService } from '../services/userService';
import { userKeys } from './useUsers';
import { useUIStore } from '../../../shared/stores/uiStore';

/** 사용자 생성 */
export function useCreateUser() {
  const queryClient = useQueryClient();
  const addToast = useUIStore((s) => s.addToast);

  return useMutation({
    mutationFn: userService.createUser,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: userKeys.lists() });
      addToast({ type: 'success', message: '사용자가 생성되었습니다.' });
    },
    onError: (error) => {
      addToast({ type: 'error', message: error.data?.message || '생성에 실패했습니다.' });
    },
  });
}

/** 사용자 수정 (낙관적 업데이트) */
export function useUpdateUser(id) {
  const queryClient = useQueryClient();
  const addToast = useUIStore((s) => s.addToast);

  return useMutation({
    mutationFn: (data) => userService.updateUser(id, data),
    // 낙관적 업데이트
    onMutate: async (newData) => {
      await queryClient.cancelQueries({ queryKey: userKeys.detail(id) });
      const previousUser = queryClient.getQueryData(userKeys.detail(id));
      queryClient.setQueryData(userKeys.detail(id), (old) => ({
        ...old,
        ...newData,
      }));
      return { previousUser };
    },
    onError: (err, _, context) => {
      // 롤백
      queryClient.setQueryData(userKeys.detail(id), context.previousUser);
      addToast({ type: 'error', message: '수정에 실패했습니다.' });
    },
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: userKeys.detail(id) });
      queryClient.invalidateQueries({ queryKey: userKeys.lists() });
    },
    onSuccess: () => {
      addToast({ type: 'success', message: '수정되었습니다.' });
    },
  });
}

/** 사용자 삭제 */
export function useDeleteUser() {
  const queryClient = useQueryClient();
  const addToast = useUIStore((s) => s.addToast);

  return useMutation({
    mutationFn: userService.deleteUser,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: userKeys.lists() });
      addToast({ type: 'success', message: '삭제되었습니다.' });
    },
    onError: () => {
      addToast({ type: 'error', message: '삭제에 실패했습니다.' });
    },
  });
}
```

## 7. 폼 관리 — React Hook Form + Zod

```javascript
// src/features/users/schemas/userSchema.js
import { z } from 'zod';

export const userSchema = z.object({
  name: z.string()
    .min(2, '이름은 2자 이상이어야 합니다.')
    .max(50, '이름은 50자 이하여야 합니다.'),
  email: z.string()
    .email('올바른 이메일을 입력해주세요.'),
  role: z.enum(['admin', 'user', 'viewer'], {
    errorMap: () => ({ message: '역할을 선택해주세요.' }),
  }),
  department: z.string().optional(),
  phone: z.string()
    .regex(/^01[016789]-?\d{3,4}-?\d{4}$/, '올바른 전화번호를 입력해주세요.')
    .optional()
    .or(z.literal('')),
});

export type UserFormData = z.infer<typeof userSchema>;
```

```jsx
// src/features/users/components/UserForm.jsx
import { useForm } from 'react-hook-form';
import { zodResolver } from '@hookform/resolvers/zod';
import { userSchema } from '../schemas/userSchema';
import { Input } from '../../../shared/components/ui/Input';
import { Select } from '../../../shared/components/ui/Select';
import { Button } from '../../../shared/components/ui/Button';

export function UserForm({ defaultValues, onSubmit, isLoading }) {
  const {
    register,
    handleSubmit,
    formState: { errors, isDirty },
    reset,
  } = useForm({
    resolver: zodResolver(userSchema),
    defaultValues: defaultValues || {
      name: '',
      email: '',
      role: 'user',
      department: '',
      phone: '',
    },
  });

  return (
    <form onSubmit={handleSubmit(onSubmit)} noValidate>
      <Input
        label="이름"
        error={errors.name?.message}
        {...register('name')}
      />
      <Input
        label="이메일"
        type="email"
        error={errors.email?.message}
        {...register('email')}
      />
      <Select
        label="역할"
        error={errors.role?.message}
        options={[
          { value: 'admin', label: '관리자' },
          { value: 'user', label: '사용자' },
          { value: 'viewer', label: '뷰어' },
        ]}
        {...register('role')}
      />
      <Input
        label="부서"
        error={errors.department?.message}
        {...register('department')}
      />
      <Input
        label="전화번호"
        error={errors.phone?.message}
        {...register('phone')}
      />

      <div className="form-actions">
        <Button
          type="button"
          variant="secondary"
          onClick={() => reset()}
          disabled={!isDirty}
        >
          초기화
        </Button>
        <Button type="submit" disabled={isLoading}>
          {isLoading ? '저장 중...' : '저장'}
        </Button>
      </div>
    </form>
  );
}
```

## 8. 테스트 전략

```jsx
// tests/utils.jsx
import { render } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';

/**
 * 테스트용 커스텀 render
 * - QueryClientProvider, Router 등을 자동 래핑
 */
export function renderWithProviders(ui, {
  queryClient = new QueryClient({
    defaultOptions: { queries: { retry: false } },
  }),
  route = '/',
  ...options
} = {}) {
  function Wrapper({ children }) {
    return (
      <QueryClientProvider client={queryClient}>
        <MemoryRouter initialEntries={[route]}>
          {children}
        </MemoryRouter>
      </QueryClientProvider>
    );
  }

  return {
    ...render(ui, { wrapper: Wrapper, ...options }),
    queryClient,
  };
}
```

```jsx
// src/features/users/components/__tests__/UserForm.test.jsx
import { screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { renderWithProviders } from '../../../../../tests/utils';
import { UserForm } from '../UserForm';

describe('UserForm', () => {
  it('유효하지 않은 데이터로 제출 시 에러를 표시한다', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn();
    renderWithProviders(<UserForm onSubmit={onSubmit} />);

    await user.click(screen.getByRole('button', { name: '저장' }));

    await waitFor(() => {
      expect(screen.getByText('이름은 2자 이상이어야 합니다.')).toBeInTheDocument();
      expect(screen.getByText('올바른 이메일을 입력해주세요.')).toBeInTheDocument();
    });
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('유효한 데이터로 제출한다', async () => {
    const user = userEvent.setup();
    const onSubmit = vi.fn();
    renderWithProviders(<UserForm onSubmit={onSubmit} />);

    await user.type(screen.getByLabelText('이름'), '홍길동');
    await user.type(screen.getByLabelText('이메일'), 'hong@example.com');
    await user.click(screen.getByRole('button', { name: '저장' }));

    await waitFor(() => {
      expect(onSubmit).toHaveBeenCalledWith(
        expect.objectContaining({
          name: '홍길동',
          email: 'hong@example.com',
          role: 'user',
        }),
        expect.anything()
      );
    });
  });
});
```

```javascript
// src/features/users/hooks/__tests__/useUsers.test.js
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { describe, it, expect, vi } from 'vitest';
import { useUsers } from '../useUsers';
import { userService } from '../../services/userService';

vi.mock('../../services/userService');

describe('useUsers', () => {
  const createWrapper = () => {
    const queryClient = new QueryClient({
      defaultOptions: { queries: { retry: false } },
    });
    return ({ children }) => (
      <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>
    );
  };

  it('사용자 목록을 가져온다', async () => {
    const mockUsers = [
      { id: 1, name: '홍길동', email: 'hong@example.com' },
    ];
    userService.getUsers.mockResolvedValue({ data: mockUsers, total: 1 });

    const { result } = renderHook(() => useUsers(), {
      wrapper: createWrapper(),
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
    expect(result.current.data.data).toEqual(mockUsers);
  });
});
```

## 9. 성능 최적화

### React.memo를 활용한 리렌더링 방지

```jsx
import { memo, useCallback } from 'react';

const UserRow = memo(function UserRow({ user, onEdit, onDelete }) {
  return (
    <tr>
      <td>{user.name}</td>
      <td>{user.email}</td>
      <td>
        <button onClick={() => onEdit(user.id)}>수정</button>
        <button onClick={() => onDelete(user.id)}>삭제</button>
      </td>
    </tr>
  );
});

function UserTable({ users }) {
  const handleEdit = useCallback((id) => {
    // 수정 로직
  }, []);

  const handleDelete = useCallback((id) => {
    // 삭제 로직
  }, []);

  return (
    <table>
      <tbody>
        {users.map((user) => (
          <UserRow
            key={user.id}
            user={user}
            onEdit={handleEdit}
            onDelete={handleDelete}
          />
        ))}
      </tbody>
    </table>
  );
}
```

### 번들 분석 및 최적화

```javascript
// vite.config.js
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@': '/src',
      '@features': '/src/features',
      '@shared': '/src/shared',
    },
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          vendor: ['react', 'react-dom'],
          router: ['react-router-dom'],
          query: ['@tanstack/react-query'],
        },
      },
    },
  },
});
```

## 10. 보안

### API 클라이언트 보안

```javascript
// src/shared/lib/api-client.js 에 추가
// 요청 시 CSRF 토큰 자동 주입
function getCsrfToken() {
  return document.cookie
    .split('; ')
    .find((row) => row.startsWith('XSRF-TOKEN='))
    ?.split('=')[1];
}

// fetch 인터셉트에서:
if (['POST', 'PUT', 'DELETE'].includes(method)) {
  const csrf = getCsrfToken();
  if (csrf) headers['X-XSRF-TOKEN'] = decodeURIComponent(csrf);
}
```

### 입력 새니타이즈

```jsx
// dangerouslySetInnerHTML 사용이 불가피한 경우
import DOMPurify from 'dompurify';

function RichContent({ html }) {
  const clean = DOMPurify.sanitize(html, {
    ALLOWED_TAGS: ['p', 'br', 'b', 'i', 'em', 'strong', 'a', 'ul', 'ol', 'li'],
    ALLOWED_ATTR: ['href', 'title'],
  });

  return <div dangerouslySetInnerHTML={{ __html: clean }} />;
}
```

### Zustand에서 민감 데이터 관리

```javascript
// persist 미들웨어에서 토큰만 저장, 사용자 전체 정보는 저장하지 않음
persist(
  (set) => ({ /* ... */ }),
  {
    name: 'auth-storage',
    partialize: (state) => ({
      token: state.token, // 토큰만 영속화
    }),
    storage: {
      getItem: (name) => {
        const str = sessionStorage.getItem(name); // localStorage 대신 sessionStorage
        return str ? JSON.parse(str) : null;
      },
      setItem: (name, value) => sessionStorage.setItem(name, JSON.stringify(value)),
      removeItem: (name) => sessionStorage.removeItem(name),
    },
  }
)
```
