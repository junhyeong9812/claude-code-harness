# Vue 3 — 중규모 프로젝트 가이드

## 개요

- **구조**: Feature 폴더 기반
- **상태 관리**: Pinia
- **라우팅**: Vue Router (네비게이션 가드)
- **데이터 페칭**: Composables + VueUse
- **적합한 프로젝트**: 관리자 대시보드, B2B SaaS, 중규모 서비스

---

## 1. 프로젝트 구조

```
my-vue-medium/
├── public/
│   └── assets/
├── src/
│   ├── app/
│   │   ├── App.vue
│   │   ├── router.js                # 라우트 정의
│   │   └── main.js                  # 진입점
│   ├── features/
│   │   ├── auth/
│   │   │   ├── components/
│   │   │   │   ├── LoginForm.vue
│   │   │   │   ├── RegisterForm.vue
│   │   │   │   └── AuthGuard.vue
│   │   │   ├── composables/
│   │   │   │   ├── useAuth.js
│   │   │   │   └── useLogin.js
│   │   │   ├── services/
│   │   │   │   └── authService.js
│   │   │   ├── stores/
│   │   │   │   └── authStore.js
│   │   │   ├── routes.js
│   │   │   └── index.js             # 배럴 파일
│   │   ├── dashboard/
│   │   │   ├── components/
│   │   │   │   ├── DashboardPage.vue
│   │   │   │   ├── StatsGrid.vue
│   │   │   │   ├── RevenueChart.vue
│   │   │   │   └── RecentActivity.vue
│   │   │   ├── composables/
│   │   │   │   └── useDashboardStats.js
│   │   │   ├── services/
│   │   │   │   └── dashboardService.js
│   │   │   ├── routes.js
│   │   │   └── index.js
│   │   └── users/
│   │       ├── components/
│   │       │   ├── UserListPage.vue
│   │       │   ├── UserDetailPage.vue
│   │       │   ├── UserForm.vue
│   │       │   └── UserTable.vue
│   │       ├── composables/
│   │       │   ├── useUsers.js
│   │       │   └── useUserForm.js
│   │       ├── services/
│   │       │   └── userService.js
│   │       ├── stores/
│   │       │   └── userStore.js
│   │       ├── routes.js
│   │       └── index.js
│   ├── shared/
│   │   ├── components/
│   │   │   ├── ui/
│   │   │   │   ├── BaseButton.vue
│   │   │   │   ├── BaseInput.vue
│   │   │   │   ├── BaseSelect.vue
│   │   │   │   ├── BaseModal.vue
│   │   │   │   ├── BaseTable.vue
│   │   │   │   ├── BasePagination.vue
│   │   │   │   ├── BaseToast.vue
│   │   │   │   └── BaseSpinner.vue
│   │   │   └── layout/
│   │   │       ├── MainLayout.vue
│   │   │       ├── AuthLayout.vue
│   │   │       ├── TheSidebar.vue
│   │   │       └── TheHeader.vue
│   │   ├── composables/
│   │   │   ├── useDebounce.js
│   │   │   ├── usePagination.js
│   │   │   └── useNotification.js
│   │   ├── utils/
│   │   │   ├── format.js
│   │   │   ├── validation.js
│   │   │   └── constants.js
│   │   └── lib/
│   │       └── api-client.js
│   ├── plugins/
│   │   ├── pinia.js
│   │   └── toast.js
│   └── assets/
│       └── styles/
│           ├── variables.css
│           └── global.css
├── tests/
│   ├── setup.js
│   └── helpers.js
├── vite.config.js
├── vitest.config.js
├── package.json
└── .eslintrc.cjs
```

## 2. 상태 관리 — Pinia

```javascript
// src/features/auth/stores/authStore.js
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { authService } from '../services/authService';

/**
 * 인증 스토어 (Setup Store 문법)
 * - Composition API와 일관된 패턴
 * - TypeScript 추론 우수
 */
export const useAuthStore = defineStore('auth', () => {
  // ─── 상태 ───
  const user = ref(null);
  const token = ref(localStorage.getItem('token'));
  const loading = ref(false);
  const error = ref(null);

  // ─── Getters ───
  const isAuthenticated = computed(() => !!token.value && !!user.value);
  const isAdmin = computed(() => user.value?.role === 'admin');
  const displayName = computed(() => user.value?.name || '게스트');

  // ─── Actions ───
  async function login(credentials) {
    loading.value = true;
    error.value = null;
    try {
      const response = await authService.login(credentials);
      user.value = response.user;
      token.value = response.token;
      localStorage.setItem('token', response.token);
    } catch (err) {
      error.value = err.message;
      throw err;
    } finally {
      loading.value = false;
    }
  }

  async function fetchUser() {
    if (!token.value) return;
    try {
      user.value = await authService.getMe();
    } catch {
      logout();
    }
  }

  function logout() {
    user.value = null;
    token.value = null;
    localStorage.removeItem('token');
  }

  return {
    user, token, loading, error,
    isAuthenticated, isAdmin, displayName,
    login, fetchUser, logout,
  };
});
```

```javascript
// src/features/users/stores/userStore.js
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';

export const useUserStore = defineStore('users', () => {
  const filters = ref({
    search: '',
    role: 'all',
    page: 1,
    pageSize: 20,
  });

  const selectedIds = ref(new Set());

  // Getters
  const activeFiltersCount = computed(() => {
    let count = 0;
    if (filters.value.search) count++;
    if (filters.value.role !== 'all') count++;
    return count;
  });

  const hasSelection = computed(() => selectedIds.value.size > 0);

  // Actions
  function setFilter(key, value) {
    filters.value[key] = value;
    if (key !== 'page') filters.value.page = 1; // 필터 변경 시 첫 페이지로
  }

  function resetFilters() {
    filters.value = { search: '', role: 'all', page: 1, pageSize: 20 };
  }

  function toggleSelection(id) {
    const next = new Set(selectedIds.value);
    next.has(id) ? next.delete(id) : next.add(id);
    selectedIds.value = next;
  }

  function clearSelection() {
    selectedIds.value = new Set();
  }

  return {
    filters, selectedIds,
    activeFiltersCount, hasSelection,
    setFilter, resetFilters, toggleSelection, clearSelection,
  };
});
```

## 3. 라우팅 — Vue Router

```javascript
// src/app/router.js
import { createRouter, createWebHistory } from 'vue-router';
import { useAuthStore } from '../features/auth/stores/authStore';
import { authRoutes } from '../features/auth/routes';
import { dashboardRoutes } from '../features/dashboard/routes';
import { userRoutes } from '../features/users/routes';

const router = createRouter({
  history: createWebHistory(),
  routes: [
    // 인증 라우트
    {
      path: '/',
      component: () => import('../shared/components/layout/AuthLayout.vue'),
      children: authRoutes,
    },
    // 메인 라우트 (인증 필요)
    {
      path: '/',
      component: () => import('../shared/components/layout/MainLayout.vue'),
      meta: { requiresAuth: true },
      children: [
        { path: '', redirect: '/dashboard' },
        ...dashboardRoutes,
        ...userRoutes,
      ],
    },
    // 404
    {
      path: '/:pathMatch(.*)*',
      component: () => import('../shared/components/NotFound.vue'),
    },
  ],
  scrollBehavior(to, from, savedPosition) {
    return savedPosition || { top: 0 };
  },
});

// 전역 네비게이션 가드
router.beforeEach(async (to, from) => {
  const authStore = useAuthStore();

  // 인증이 필요한 라우트
  if (to.meta.requiresAuth && !authStore.isAuthenticated) {
    // 토큰은 있지만 유저 정보가 없으면 조회 시도
    if (authStore.token) {
      try {
        await authStore.fetchUser();
        if (authStore.isAuthenticated) return true;
      } catch {
        // 토큰 무효
      }
    }
    return { path: '/login', query: { redirect: to.fullPath } };
  }

  // 이미 로그인 상태에서 로그인/회원가입 접근
  if ((to.path === '/login' || to.path === '/register') && authStore.isAuthenticated) {
    return { path: '/dashboard' };
  }

  return true;
});

// 페이지 제목 업데이트
router.afterEach((to) => {
  const title = to.meta.title;
  if (title) {
    document.title = `${title} | MyApp`;
  }
});

export { router };
```

```javascript
// src/features/users/routes.js
export const userRoutes = [
  {
    path: '/users',
    name: 'users',
    component: () => import('./components/UserListPage.vue'),
    meta: { title: '사용자 관리', requiresAuth: true },
  },
  {
    path: '/users/:id',
    name: 'user-detail',
    component: () => import('./components/UserDetailPage.vue'),
    meta: { title: '사용자 상세', requiresAuth: true },
    props: true,
  },
];
```

## 4. 스타일링

```vue
<!-- src/shared/components/ui/BaseTable.vue -->
<script setup>
const props = defineProps({
  columns: { type: Array, required: true },
  data: { type: Array, required: true },
  sortKey: { type: String, default: null },
  sortDir: { type: String, default: 'asc' },
  loading: { type: Boolean, default: false },
});

const emit = defineEmits(['sort']);

function handleSort(column) {
  if (!column.sortable) return;
  emit('sort', column.key);
}
</script>

<template>
  <div class="table-wrapper">
    <table class="table">
      <thead>
        <tr>
          <th
            v-for="col in columns"
            :key="col.key"
            :class="{ sortable: col.sortable }"
            @click="handleSort(col)"
          >
            {{ col.label }}
            <span v-if="sortKey === col.key" class="sort-icon">
              {{ sortDir === 'asc' ? '▲' : '▼' }}
            </span>
          </th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="loading">
          <td :colspan="columns.length" class="loading-cell">
            <BaseSpinner /> 로딩 중...
          </td>
        </tr>
        <tr v-else-if="data.length === 0">
          <td :colspan="columns.length" class="empty-cell">
            데이터가 없습니다.
          </td>
        </tr>
        <tr v-else v-for="row in data" :key="row.id">
          <td v-for="col in columns" :key="col.key">
            <slot :name="`cell-${col.key}`" :row="row" :value="row[col.key]">
              {{ row[col.key] }}
            </slot>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.table-wrapper {
  overflow-x: auto;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.table {
  width: 100%;
  border-collapse: collapse;
}

.table th,
.table td {
  padding: 0.75rem 1rem;
  text-align: left;
  border-bottom: 1px solid var(--color-border);
}

.table th {
  background: var(--color-bg-secondary);
  font-weight: 600;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--color-text-muted);
}

.sortable {
  cursor: pointer;
  user-select: none;
}
.sortable:hover { color: var(--color-primary); }

.sort-icon { margin-left: 0.25rem; font-size: 0.625rem; }

.loading-cell,
.empty-cell {
  text-align: center;
  padding: 2rem;
  color: var(--color-text-muted);
}

.table tr:hover td { background: var(--color-bg-secondary); }
.table tr:last-child td { border-bottom: none; }
</style>
```

## 5. 컴포넌트 설계 패턴

### Provide/Inject로 컨텍스트 전달

```vue
<!-- src/shared/components/layout/MainLayout.vue -->
<script setup>
import { provide, ref } from 'vue';
import { useRouter } from 'vue-router';
import TheSidebar from './TheSidebar.vue';
import TheHeader from './TheHeader.vue';

const sidebarOpen = ref(true);
function toggleSidebar() { sidebarOpen.value = !sidebarOpen.value; }

// 하위 컴포넌트에 레이아웃 컨텍스트 제공
provide('layout', {
  sidebarOpen,
  toggleSidebar,
});
</script>

<template>
  <div :class="['layout', { 'layout--sidebar-collapsed': !sidebarOpen }]">
    <TheSidebar :collapsed="!sidebarOpen" />
    <div class="layout__content">
      <TheHeader @toggle-sidebar="toggleSidebar" />
      <main class="layout__main">
        <RouterView v-slot="{ Component }">
          <Transition name="page" mode="out-in">
            <component :is="Component" />
          </Transition>
        </RouterView>
      </main>
    </div>
  </div>
</template>

<style scoped>
.layout {
  display: grid;
  grid-template-columns: 240px 1fr;
  min-height: 100vh;
  transition: grid-template-columns 0.2s ease;
}
.layout--sidebar-collapsed {
  grid-template-columns: 60px 1fr;
}
.layout__main {
  padding: 1.5rem;
  overflow-y: auto;
}

/* 페이지 전환 애니메이션 */
.page-enter-active,
.page-leave-active {
  transition: opacity 0.15s ease;
}
.page-enter-from,
.page-leave-to {
  opacity: 0;
}
</style>
```

### Composable 기반 비즈니스 로직 분리

```javascript
// src/features/users/composables/useUsers.js
import { computed, watch } from 'vue';
import { useUserStore } from '../stores/userStore';
import { userService } from '../services/userService';
import { useFetch } from '../../../shared/composables/useFetch';
import { useDebounce } from '../../../shared/composables/useDebounce';

export function useUsers() {
  const store = useUserStore();
  const debouncedSearch = useDebounce(
    computed(() => store.filters.search),
    300
  );

  const queryParams = computed(() => ({
    ...store.filters,
    search: debouncedSearch.value,
  }));

  const { data, loading, error, refetch } = useFetch(
    () => `/users?${new URLSearchParams(queryParams.value)}`
  );

  const users = computed(() => data.value?.data || []);
  const total = computed(() => data.value?.total || 0);
  const totalPages = computed(() =>
    Math.ceil(total.value / store.filters.pageSize)
  );

  async function deleteUser(id) {
    if (!confirm('정말 삭제하시겠습니까?')) return;
    await userService.deleteUser(id);
    refetch();
  }

  return {
    users,
    total,
    totalPages,
    loading,
    error,
    filters: store.filters,
    setFilter: store.setFilter,
    resetFilters: store.resetFilters,
    deleteUser,
    refetch,
  };
}
```

```vue
<!-- src/features/users/components/UserListPage.vue -->
<script setup>
import { useUsers } from '../composables/useUsers';
import { useRouter } from 'vue-router';
import BaseTable from '../../../shared/components/ui/BaseTable.vue';
import BasePagination from '../../../shared/components/ui/BasePagination.vue';
import BaseInput from '../../../shared/components/ui/BaseInput.vue';
import BaseButton from '../../../shared/components/ui/BaseButton.vue';

const router = useRouter();
const {
  users,
  total,
  totalPages,
  loading,
  filters,
  setFilter,
  resetFilters,
  deleteUser,
} = useUsers();

const columns = [
  { key: 'name', label: '이름', sortable: true },
  { key: 'email', label: '이메일', sortable: true },
  { key: 'role', label: '역할' },
  { key: 'createdAt', label: '가입일', sortable: true },
  { key: 'actions', label: '액션' },
];

function goToDetail(id) {
  router.push({ name: 'user-detail', params: { id } });
}
</script>

<template>
  <div class="user-list-page">
    <div class="page-header">
      <h1>사용자 관리</h1>
      <BaseButton @click="router.push('/users/new')">
        + 새 사용자
      </BaseButton>
    </div>

    <!-- 필터 -->
    <div class="filter-bar">
      <BaseInput
        :model-value="filters.search"
        @update:model-value="(v) => setFilter('search', v)"
        placeholder="이름 또는 이메일로 검색..."
        name="search"
      />
      <select
        :value="filters.role"
        @change="(e) => setFilter('role', e.target.value)"
      >
        <option value="all">전체 역할</option>
        <option value="admin">관리자</option>
        <option value="user">사용자</option>
        <option value="viewer">뷰어</option>
      </select>
    </div>

    <!-- 테이블 -->
    <BaseTable
      :columns="columns"
      :data="users"
      :loading="loading"
    >
      <template #cell-role="{ value }">
        <span :class="['badge', `badge--${value}`]">{{ value }}</span>
      </template>
      <template #cell-createdAt="{ value }">
        {{ new Date(value).toLocaleDateString('ko-KR') }}
      </template>
      <template #cell-actions="{ row }">
        <BaseButton size="sm" variant="secondary" @click="goToDetail(row.id)">
          보기
        </BaseButton>
        <BaseButton size="sm" variant="danger" @click="deleteUser(row.id)">
          삭제
        </BaseButton>
      </template>
    </BaseTable>

    <!-- 페이지네이션 -->
    <BasePagination
      :current-page="filters.page"
      :total-pages="totalPages"
      :total="total"
      @change="(page) => setFilter('page', page)"
    />
  </div>
</template>

<style scoped>
.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1.5rem;
}

.filter-bar {
  display: flex;
  gap: 1rem;
  margin-bottom: 1rem;
}

.badge {
  padding: 0.125rem 0.5rem;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
}
.badge--admin { background: #dbeafe; color: #1e40af; }
.badge--user { background: #dcfce7; color: #166534; }
.badge--viewer { background: #f1f5f9; color: #475569; }
</style>
```

## 6. 데이터 페칭 — Composables

```javascript
// src/shared/lib/api-client.js
import { useAuthStore } from '../../features/auth/stores/authStore';

const BASE_URL = import.meta.env.VITE_API_URL || '/api';

class ApiClient {
  async request(endpoint, options = {}) {
    const authStore = useAuthStore();
    const headers = {
      'Content-Type': 'application/json',
      ...(authStore.token && { Authorization: `Bearer ${authStore.token}` }),
      ...options.headers,
    };

    const response = await fetch(`${BASE_URL}${endpoint}`, {
      ...options,
      headers,
    });

    if (response.status === 401) {
      authStore.logout();
      throw new Error('인증 만료');
    }

    if (!response.ok) {
      const data = await response.json().catch(() => null);
      const error = new Error(data?.message || '요청 실패');
      error.status = response.status;
      error.data = data;
      throw error;
    }

    return response.json();
  }

  get(endpoint) { return this.request(endpoint); }
  post(endpoint, data) {
    return this.request(endpoint, { method: 'POST', body: JSON.stringify(data) });
  }
  put(endpoint, data) {
    return this.request(endpoint, { method: 'PUT', body: JSON.stringify(data) });
  }
  delete(endpoint) {
    return this.request(endpoint, { method: 'DELETE' });
  }
}

export const apiClient = new ApiClient();
```

```javascript
// src/shared/composables/useFetch.js
import { ref, watchEffect, onUnmounted, isRef, unref } from 'vue';
import { apiClient } from '../lib/api-client';

/**
 * 반응형 데이터 페칭 composable
 * - endpoint가 ref 또는 함수일 경우 자동 재요청
 */
export function useFetch(endpoint, options = {}) {
  const data = ref(null);
  const loading = ref(false);
  const error = ref(null);
  let controller;

  function execute() {
    const url = typeof endpoint === 'function' ? endpoint() : unref(endpoint);
    if (!url) return;

    controller?.abort();
    controller = new AbortController();
    loading.value = true;
    error.value = null;

    apiClient.get(url)
      .then((result) => { data.value = result; })
      .catch((err) => {
        if (err.name !== 'AbortError') error.value = err;
      })
      .finally(() => { loading.value = false; });
  }

  if (options.immediate !== false) {
    watchEffect(execute);
  }

  onUnmounted(() => controller?.abort());

  return { data, loading, error, refetch: execute };
}

/**
 * 뮤테이션 composable (생성/수정/삭제)
 */
export function useMutation(mutationFn) {
  const loading = ref(false);
  const error = ref(null);
  const data = ref(null);

  async function mutate(...args) {
    loading.value = true;
    error.value = null;
    try {
      data.value = await mutationFn(...args);
      return data.value;
    } catch (err) {
      error.value = err;
      throw err;
    } finally {
      loading.value = false;
    }
  }

  return { mutate, loading, error, data };
}
```

## 7. 테스트 전략

```javascript
// tests/helpers.js
import { createTestingPinia } from '@pinia/testing';
import { mount } from '@vue/test-utils';
import { createRouter, createMemoryHistory } from 'vue-router';

/**
 * 테스트용 마운트 헬퍼
 */
export function mountWithPlugins(component, options = {}) {
  const pinia = createTestingPinia({
    createSpy: vi.fn,
    initialState: options.initialState,
  });

  const router = createRouter({
    history: createMemoryHistory(),
    routes: options.routes || [{ path: '/', component: { template: '<div />' } }],
  });

  return mount(component, {
    global: {
      plugins: [pinia, router],
      stubs: options.stubs || {},
    },
    ...options,
  });
}
```

```javascript
// src/features/auth/stores/__tests__/authStore.test.js
import { setActivePinia, createPinia } from 'pinia';
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { useAuthStore } from '../authStore';
import { authService } from '../../services/authService';

vi.mock('../../services/authService');

describe('authStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    localStorage.clear();
  });

  it('로그인 성공 시 상태를 업데이트한다', async () => {
    authService.login.mockResolvedValue({
      user: { id: 1, name: '홍길동', role: 'admin' },
      token: 'mock-token',
    });

    const store = useAuthStore();
    await store.login({ email: 'test@test.com', password: '1234' });

    expect(store.isAuthenticated).toBe(true);
    expect(store.user.name).toBe('홍길동');
    expect(store.isAdmin).toBe(true);
    expect(localStorage.getItem('token')).toBe('mock-token');
  });

  it('로그아웃 시 상태를 초기화한다', () => {
    const store = useAuthStore();
    store.user = { id: 1, name: '홍길동' };
    store.token = 'token';

    store.logout();

    expect(store.isAuthenticated).toBe(false);
    expect(store.user).toBeNull();
    expect(localStorage.getItem('token')).toBeNull();
  });
});
```

```javascript
// src/features/users/components/__tests__/UserListPage.test.js
import { describe, it, expect, vi } from 'vitest';
import { mountWithPlugins } from '../../../../../tests/helpers';
import UserListPage from '../UserListPage.vue';

describe('UserListPage', () => {
  it('사용자 목록을 렌더링한다', async () => {
    const wrapper = mountWithPlugins(UserListPage, {
      initialState: {
        users: {
          filters: { search: '', role: 'all', page: 1, pageSize: 20 },
        },
      },
    });

    expect(wrapper.find('h1').text()).toBe('사용자 관리');
    expect(wrapper.find('.filter-bar').exists()).toBe(true);
  });
});
```

## 8. 성능 최적화

### 컴포넌트 지연 로딩

```javascript
// src/app/router.js
// 라우트에서 동적 임포트 = 자동 코드 스플리팅
{
  path: '/users',
  component: () => import('../features/users/components/UserListPage.vue'),
}
```

### KeepAlive로 컴포넌트 상태 유지

```vue
<!-- 탭 전환 시 상태 유지 -->
<RouterView v-slot="{ Component, route }">
  <KeepAlive :include="['DashboardPage', 'UserListPage']">
    <component :is="Component" :key="route.path" />
  </KeepAlive>
</RouterView>
```

### 가상 스크롤

```vue
<!-- 대량 리스트에 vue-virtual-scroller 사용 -->
<script setup>
import { RecycleScroller } from 'vue-virtual-scroller';
import 'vue-virtual-scroller/dist/vue-virtual-scroller.css';
</script>

<template>
  <RecycleScroller
    :items="users"
    :item-size="48"
    key-field="id"
    v-slot="{ item }"
  >
    <div class="user-row">
      {{ item.name }} — {{ item.email }}
    </div>
  </RecycleScroller>
</template>
```

### 이미지 최적화

```vue
<template>
  <img
    :src="src"
    :alt="alt"
    loading="lazy"
    decoding="async"
    :width="width"
    :height="height"
  />
</template>
```

## 9. 보안

### XSS 방지

```vue
<!-- Vue의 {{ }}는 자동 이스케이프 -->
<p>{{ userInput }}</p>  <!-- 안전 -->

<!-- v-html은 반드시 새니타이즈 -->
<script setup>
import DOMPurify from 'dompurify';
import { computed } from 'vue';

const props = defineProps({ rawHtml: String });
const safeHtml = computed(() => DOMPurify.sanitize(props.rawHtml));
</script>

<template>
  <div v-html="safeHtml" />
</template>
```

### API 보안

```javascript
// src/shared/lib/api-client.js 에서 CSRF 토큰 처리
async request(endpoint, options = {}) {
  const headers = { ...options.headers };

  // non-GET 요청에 CSRF 토큰 추가
  if (options.method && options.method !== 'GET') {
    const csrfToken = document.cookie
      .split('; ')
      .find(row => row.startsWith('XSRF-TOKEN='))
      ?.split('=')[1];
    if (csrfToken) {
      headers['X-XSRF-TOKEN'] = decodeURIComponent(csrfToken);
    }
  }
  // ...
}
```

### 라우트 가드로 권한 제어

```javascript
// src/app/router.js
router.beforeEach((to) => {
  const authStore = useAuthStore();

  // 역할 기반 접근 제어
  if (to.meta.roles && !to.meta.roles.includes(authStore.user?.role)) {
    return { path: '/forbidden' };
  }

  return true;
});

// 라우트 정의
{
  path: '/admin',
  component: AdminPage,
  meta: { requiresAuth: true, roles: ['admin'] },
}
```

## 10. 앱 초기화

```javascript
// src/app/main.js
import { createApp } from 'vue';
import { createPinia } from 'pinia';
import App from './App.vue';
import { router } from './router';
import '../assets/styles/variables.css';
import '../assets/styles/global.css';

const app = createApp(App);

// Pinia (상태 관리)
app.use(createPinia());

// Router
app.use(router);

// 전역 에러 핸들러
app.config.errorHandler = (err, instance, info) => {
  console.error('전역 에러:', err, info);
  // Sentry 등 에러 리포팅
};

app.mount('#app');
```
