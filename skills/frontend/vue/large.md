# Vue 3 — 대규모 프로젝트 가이드

## 개요

- **구조**: Feature 기반 모듈 + 모노레포
- **상태 관리**: 고급 Pinia 패턴 (플러그인, 퍼시스턴스)
- **마이크로 프론트엔드**: Module Federation 또는 독립 배포
- **적합한 프로젝트**: 대규모 플랫폼, 엔터프라이즈 앱, 멀티 팀

---

## 1. 프로젝트 구조

```
my-vue-large/
├── apps/
│   ├── web/                            # 메인 웹앱 (호스트)
│   │   ├── src/
│   │   │   ├── app/
│   │   │   │   ├── App.vue
│   │   │   │   ├── router.js
│   │   │   │   ├── pinia.js            # Pinia 설정 + 플러그인
│   │   │   │   └── main.js
│   │   │   ├── modules/                # 기능 모듈 (독립 개발 단위)
│   │   │   │   ├── auth/
│   │   │   │   │   ├── components/
│   │   │   │   │   │   ├── LoginPage.vue
│   │   │   │   │   │   └── ProfilePage.vue
│   │   │   │   │   ├── composables/
│   │   │   │   │   │   └── useAuth.js
│   │   │   │   │   ├── stores/
│   │   │   │   │   │   └── authStore.js
│   │   │   │   │   ├── services/
│   │   │   │   │   │   └── authService.js
│   │   │   │   │   ├── routes.js
│   │   │   │   │   └── index.js
│   │   │   │   ├── dashboard/
│   │   │   │   │   ├── components/
│   │   │   │   │   │   ├── DashboardPage.vue
│   │   │   │   │   │   ├── StatsWidget.vue
│   │   │   │   │   │   ├── ChartWidget.vue
│   │   │   │   │   │   └── ActivityWidget.vue
│   │   │   │   │   ├── composables/
│   │   │   │   │   ├── stores/
│   │   │   │   │   ├── routes.js
│   │   │   │   │   └── index.js
│   │   │   │   ├── users/
│   │   │   │   │   └── ...
│   │   │   │   ├── orders/
│   │   │   │   │   └── ...
│   │   │   │   └── reports/
│   │   │   │       └── ...
│   │   │   ├── shared/
│   │   │   │   ├── composables/
│   │   │   │   │   ├── useApi.js
│   │   │   │   │   ├── useDebounce.js
│   │   │   │   │   ├── usePagination.js
│   │   │   │   │   └── useWebSocket.js
│   │   │   │   ├── utils/
│   │   │   │   │   ├── format.js
│   │   │   │   │   ├── validation.js
│   │   │   │   │   └── constants.js
│   │   │   │   └── lib/
│   │   │   │       └── api-client.js
│   │   │   └── layouts/
│   │   │       ├── MainLayout.vue
│   │   │       ├── AuthLayout.vue
│   │   │       └── AdminLayout.vue
│   │   ├── vite.config.js
│   │   └── package.json
│   └── admin/                          # 관리자 앱 (리모트)
│       ├── src/
│       │   ├── app/
│       │   │   ├── App.vue
│       │   │   └── main.js
│       │   ├── modules/
│       │   │   ├── system-settings/
│       │   │   ├── audit-log/
│       │   │   └── role-management/
│       │   └── shared/
│       ├── vite.config.js
│       └── package.json
├── packages/
│   ├── ui/                             # 디자인 시스템
│   │   ├── src/
│   │   │   ├── components/
│   │   │   │   ├── BaseButton.vue
│   │   │   │   ├── BaseInput.vue
│   │   │   │   ├── BaseModal.vue
│   │   │   │   ├── DataTable.vue
│   │   │   │   ├── Pagination.vue
│   │   │   │   ├── Toast.vue
│   │   │   │   └── index.js
│   │   │   ├── tokens/
│   │   │   │   ├── colors.css
│   │   │   │   ├── typography.css
│   │   │   │   └── spacing.css
│   │   │   └── index.js
│   │   ├── vite.config.js
│   │   └── package.json
│   ├── shared-utils/
│   │   ├── src/
│   │   │   ├── http.js
│   │   │   ├── format.js
│   │   │   ├── logger.js
│   │   │   └── index.js
│   │   └── package.json
│   ├── shared-stores/                  # 앱 간 공유 스토어
│   │   ├── src/
│   │   │   ├── authStore.js
│   │   │   └── index.js
│   │   └── package.json
│   └── eslint-config/
│       └── index.js
├── tools/
│   └── scripts/
│       ├── build-all.js
│       └── deploy.js
├── pnpm-workspace.yaml
├── turbo.json
├── package.json
└── .github/
    └── workflows/
        ├── ci.yml
        └── deploy.yml
```

## 2. 상태 관리 — 고급 Pinia 패턴

### Pinia 플러그인

```javascript
// apps/web/src/app/pinia.js
import { createPinia } from 'pinia';

const pinia = createPinia();

/**
 * 로깅 플러그인 — 모든 상태 변경을 추적
 */
pinia.use(({ store }) => {
  store.$subscribe((mutation, state) => {
    if (import.meta.env.DEV) {
      console.groupCollapsed(`[Pinia] ${store.$id}: ${mutation.type}`);
      console.log('이벤트:', mutation.events);
      console.log('상태:', JSON.parse(JSON.stringify(state)));
      console.groupEnd();
    }
  });
});

/**
 * 퍼시스턴스 플러그인 — 지정된 스토어를 localStorage에 영속화
 */
pinia.use(({ store, options }) => {
  if (options.persist) {
    const key = `pinia-${store.$id}`;
    const config = typeof options.persist === 'object' ? options.persist : {};
    const paths = config.paths || null;
    const storage = config.storage || localStorage;

    // 저장된 상태 복원
    const saved = storage.getItem(key);
    if (saved) {
      try {
        const parsed = JSON.parse(saved);
        store.$patch(parsed);
      } catch {}
    }

    // 상태 변경 시 저장
    store.$subscribe((_, state) => {
      const toSave = paths
        ? paths.reduce((obj, path) => {
            obj[path] = state[path];
            return obj;
          }, {})
        : state;
      storage.setItem(key, JSON.stringify(toSave));
    });
  }
});

/**
 * 에러 핸들링 플러그인
 */
pinia.use(({ store }) => {
  store.$onAction(({ name, onError }) => {
    onError((error) => {
      console.error(`[Pinia Action Error] ${store.$id}.${name}:`, error);
      // Sentry 등 에러 리포팅
    });
  });
});

export { pinia };
```

### 스토어 간 통신

```javascript
// apps/web/src/modules/auth/stores/authStore.js
import { defineStore } from 'pinia';
import { ref, computed } from 'vue';
import { authService } from '../services/authService';

export const useAuthStore = defineStore('auth', () => {
  const user = ref(null);
  const token = ref(null);
  const permissions = ref([]);
  const loading = ref(false);

  const isAuthenticated = computed(() => !!token.value);
  const hasPermission = (perm) => permissions.value.includes(perm);
  const isAdmin = computed(() => user.value?.role === 'admin');

  async function login(credentials) {
    loading.value = true;
    try {
      const result = await authService.login(credentials);
      user.value = result.user;
      token.value = result.token;
      permissions.value = result.permissions;
    } finally {
      loading.value = false;
    }
  }

  function logout() {
    user.value = null;
    token.value = null;
    permissions.value = [];
    // 다른 스토어 리셋
    const { useUserStore } = require('../../../modules/users/stores/userStore');
    useUserStore().$reset();
  }

  async function refreshToken() {
    if (!token.value) return;
    try {
      const result = await authService.refresh(token.value);
      token.value = result.token;
    } catch {
      logout();
    }
  }

  return {
    user, token, permissions, loading,
    isAuthenticated, isAdmin, hasPermission,
    login, logout, refreshToken,
  };
}, {
  // 퍼시스턴스 설정
  persist: {
    paths: ['token'],
    storage: localStorage,
  },
});
```

### 동적 모듈 등록

```javascript
// apps/web/src/app/module-registry.js
import { router } from './router';
import { pinia } from './pinia';

/**
 * 모듈 레지스트리
 * - 동적으로 모듈(라우트 + 스토어)을 등록/해제
 */
class ModuleRegistry {
  #modules = new Map();

  async register(name, moduleLoader) {
    if (this.#modules.has(name)) return;

    const mod = await moduleLoader();

    // 라우트 등록
    if (mod.routes) {
      mod.routes.forEach((route) => {
        router.addRoute('main', route);
      });
    }

    this.#modules.set(name, mod);
    console.log(`[ModuleRegistry] "${name}" 등록 완료`);
  }

  unregister(name) {
    const mod = this.#modules.get(name);
    if (!mod) return;

    // 라우트 제거
    if (mod.routes) {
      mod.routes.forEach((route) => {
        if (route.name) router.removeRoute(route.name);
      });
    }

    this.#modules.delete(name);
  }

  isLoaded(name) {
    return this.#modules.has(name);
  }
}

export const moduleRegistry = new ModuleRegistry();

// 사용: 권한에 따라 모듈 동적 로딩
export async function loadModulesForUser(permissions) {
  const moduleMap = {
    'users.read': () => import('../modules/users'),
    'orders.read': () => import('../modules/orders'),
    'reports.read': () => import('../modules/reports'),
  };

  const loaders = permissions
    .filter((perm) => moduleMap[perm])
    .map((perm) => moduleRegistry.register(perm.split('.')[0], moduleMap[perm]));

  await Promise.all(loaders);
}
```

## 3. 라우팅

```javascript
// apps/web/src/app/router.js
import { createRouter, createWebHistory } from 'vue-router';
import { useAuthStore } from '../modules/auth/stores/authStore';
import { loadModulesForUser } from './module-registry';

const router = createRouter({
  history: createWebHistory(),
  routes: [
    // 인증 라우트
    {
      path: '/login',
      component: () => import('../modules/auth/components/LoginPage.vue'),
      meta: { public: true },
    },
    // 메인 레이아웃 (자식 라우트가 동적으로 추가됨)
    {
      path: '/',
      name: 'main',
      component: () => import('../layouts/MainLayout.vue'),
      redirect: '/dashboard',
      children: [
        // 기본 라우트
        {
          path: 'dashboard',
          name: 'dashboard',
          component: () => import('../modules/dashboard/components/DashboardPage.vue'),
          meta: { title: '대시보드' },
        },
      ],
    },
    // 404
    {
      path: '/:pathMatch(.*)*',
      component: () => import('../shared/components/NotFound.vue'),
    },
  ],
});

// 전역 가드
router.beforeEach(async (to) => {
  const authStore = useAuthStore();

  if (to.meta.public) return true;

  if (!authStore.isAuthenticated) {
    if (authStore.token) {
      try {
        await authStore.fetchUser();
        // 권한에 따라 모듈 동적 로딩
        await loadModulesForUser(authStore.permissions);
      } catch {
        return { path: '/login', query: { redirect: to.fullPath } };
      }
    } else {
      return { path: '/login', query: { redirect: to.fullPath } };
    }
  }

  // 권한 체크
  if (to.meta.permission && !authStore.hasPermission(to.meta.permission)) {
    return { path: '/forbidden' };
  }

  return true;
});

export { router };
```

## 4. 스타일링 — 디자인 시스템 패키지

```css
/* packages/ui/src/tokens/colors.css */
:root {
  --ds-primary-50: #ecfdf5;
  --ds-primary-100: #d1fae5;
  --ds-primary-500: #10b981;
  --ds-primary-600: #059669;
  --ds-primary-700: #047857;

  --ds-neutral-50: #f8fafc;
  --ds-neutral-100: #f1f5f9;
  --ds-neutral-200: #e2e8f0;
  --ds-neutral-500: #64748b;
  --ds-neutral-700: #334155;
  --ds-neutral-900: #0f172a;

  --ds-error: #dc2626;
  --ds-warning: #d97706;
  --ds-success: #16a34a;

  --ds-bg-page: #ffffff;
  --ds-bg-surface: var(--ds-neutral-50);
  --ds-text-primary: var(--ds-neutral-900);
  --ds-text-secondary: var(--ds-neutral-500);
  --ds-border: var(--ds-neutral-200);
}

[data-theme="dark"] {
  --ds-bg-page: var(--ds-neutral-900);
  --ds-bg-surface: var(--ds-neutral-700);
  --ds-text-primary: var(--ds-neutral-50);
  --ds-text-secondary: var(--ds-neutral-200);
  --ds-border: var(--ds-neutral-500);
}
```

```vue
<!-- packages/ui/src/components/DataTable.vue -->
<script setup>
import { computed } from 'vue';

const props = defineProps({
  columns: { type: Array, required: true },
  data: { type: Array, required: true },
  loading: { type: Boolean, default: false },
  selectable: { type: Boolean, default: false },
  selected: { type: Set, default: () => new Set() },
  sortKey: { type: String, default: null },
  sortDir: { type: String, default: 'asc' },
  stickyHeader: { type: Boolean, default: false },
});

const emit = defineEmits(['sort', 'select', 'select-all']);

const allSelected = computed(() =>
  props.data.length > 0 && props.selected.size === props.data.length
);

function handleSort(col) {
  if (!col.sortable) return;
  emit('sort', col.key);
}
</script>

<template>
  <div class="ds-table-wrapper">
    <div v-if="$slots.toolbar" class="ds-table-toolbar">
      <slot name="toolbar" :selected-count="selected.size" />
    </div>
    <div class="ds-table-scroll">
      <table class="ds-table">
        <thead :class="{ 'ds-table--sticky': stickyHeader }">
          <tr>
            <th v-if="selectable" class="ds-table__check">
              <input
                type="checkbox"
                :checked="allSelected"
                @change="emit('select-all', !allSelected)"
              />
            </th>
            <th
              v-for="col in columns"
              :key="col.key"
              :class="{ 'ds-table__sortable': col.sortable }"
              :style="col.width ? { width: col.width } : {}"
              @click="handleSort(col)"
            >
              {{ col.label }}
              <span v-if="sortKey === col.key" class="ds-table__sort-icon">
                {{ sortDir === 'asc' ? '▲' : '▼' }}
              </span>
            </th>
          </tr>
        </thead>
        <tbody>
          <tr v-if="loading">
            <td :colspan="columns.length + (selectable ? 1 : 0)" class="ds-table__loading">
              <slot name="loading">로딩 중...</slot>
            </td>
          </tr>
          <tr v-else-if="data.length === 0">
            <td :colspan="columns.length + (selectable ? 1 : 0)" class="ds-table__empty">
              <slot name="empty">데이터가 없습니다.</slot>
            </td>
          </tr>
          <template v-else>
            <tr
              v-for="row in data"
              :key="row.id"
              :class="{ 'ds-table__row--selected': selected.has(row.id) }"
            >
              <td v-if="selectable" class="ds-table__check">
                <input
                  type="checkbox"
                  :checked="selected.has(row.id)"
                  @change="emit('select', row.id)"
                />
              </td>
              <td v-for="col in columns" :key="col.key">
                <slot :name="`cell-${col.key}`" :row="row" :value="row[col.key]">
                  {{ col.format ? col.format(row[col.key], row) : row[col.key] }}
                </slot>
              </td>
            </tr>
          </template>
        </tbody>
      </table>
    </div>
    <div v-if="$slots.footer" class="ds-table-footer">
      <slot name="footer" />
    </div>
  </div>
</template>

<style scoped>
.ds-table-wrapper {
  border: 1px solid var(--ds-border);
  border-radius: 8px;
  overflow: hidden;
}
.ds-table-toolbar {
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--ds-border);
  background: var(--ds-bg-surface);
}
.ds-table-scroll { overflow-x: auto; }
.ds-table {
  width: 100%;
  border-collapse: collapse;
}
.ds-table th, .ds-table td {
  padding: 0.75rem 1rem;
  text-align: left;
  border-bottom: 1px solid var(--ds-border);
}
.ds-table th {
  background: var(--ds-bg-surface);
  font-weight: 600;
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.05em;
  color: var(--ds-text-secondary);
}
.ds-table--sticky {
  position: sticky;
  top: 0;
  z-index: 1;
}
.ds-table__sortable { cursor: pointer; user-select: none; }
.ds-table__sortable:hover { color: var(--ds-primary-600); }
.ds-table__sort-icon { margin-left: 0.25rem; font-size: 0.625rem; }
.ds-table__check { width: 40px; text-align: center; }
.ds-table__row--selected td { background: var(--ds-primary-50); }
.ds-table__loading, .ds-table__empty {
  text-align: center;
  padding: 2rem;
  color: var(--ds-text-secondary);
}
.ds-table tr:hover td { background: var(--ds-bg-surface); }
.ds-table-footer {
  padding: 0.75rem 1rem;
  border-top: 1px solid var(--ds-border);
}
</style>
```

## 5. 컴포넌트 설계 — 고급 패턴

### Renderless Component (헤드리스)

```vue
<!-- packages/ui/src/components/Autocomplete.vue -->
<script setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import { useDebounce } from '../composables/useDebounce';

const props = defineProps({
  modelValue: { type: String, default: '' },
  items: { type: Array, default: () => [] },
  searchFn: { type: Function, default: null },
  displayKey: { type: String, default: 'label' },
  minChars: { type: Number, default: 2 },
});

const emit = defineEmits(['update:modelValue', 'select']);

const query = ref(props.modelValue);
const results = ref([]);
const loading = ref(false);
const isOpen = ref(false);
const highlightIndex = ref(-1);

const debouncedQuery = useDebounce(query, 300);

watch(debouncedQuery, async (val) => {
  if (val.length < props.minChars) {
    results.value = [];
    isOpen.value = false;
    return;
  }

  loading.value = true;
  try {
    results.value = props.searchFn
      ? await props.searchFn(val)
      : props.items.filter((item) =>
          item[props.displayKey].toLowerCase().includes(val.toLowerCase())
        );
    isOpen.value = results.value.length > 0;
    highlightIndex.value = -1;
  } finally {
    loading.value = false;
  }
});

function select(item) {
  query.value = item[props.displayKey];
  emit('update:modelValue', query.value);
  emit('select', item);
  isOpen.value = false;
}

function handleKeydown(e) {
  if (!isOpen.value) return;
  if (e.key === 'ArrowDown') {
    e.preventDefault();
    highlightIndex.value = Math.min(highlightIndex.value + 1, results.value.length - 1);
  } else if (e.key === 'ArrowUp') {
    e.preventDefault();
    highlightIndex.value = Math.max(highlightIndex.value - 1, 0);
  } else if (e.key === 'Enter' && highlightIndex.value >= 0) {
    e.preventDefault();
    select(results.value[highlightIndex.value]);
  } else if (e.key === 'Escape') {
    isOpen.value = false;
  }
}

// Renderless — 슬롯으로 UI 위임
</script>

<template>
  <slot
    :query="query"
    :results="results"
    :loading="loading"
    :is-open="isOpen"
    :highlight-index="highlightIndex"
    :on-input="(val) => { query = val; emit('update:modelValue', val); }"
    :on-select="select"
    :on-keydown="handleKeydown"
    :on-blur="() => setTimeout(() => (isOpen = false), 200)"
  />
</template>
```

### 사용 예시

```vue
<Autocomplete
  v-model="search"
  :search-fn="searchUsers"
  display-key="name"
  @select="handleSelect"
  v-slot="{ query, results, loading, isOpen, highlightIndex, onInput, onSelect, onKeydown, onBlur }"
>
  <div class="autocomplete">
    <BaseInput
      :model-value="query"
      @update:model-value="onInput"
      @keydown="onKeydown"
      @blur="onBlur"
      placeholder="사용자 검색..."
      name="search"
    />
    <ul v-if="isOpen" class="autocomplete__results">
      <li v-if="loading" class="autocomplete__loading">검색 중...</li>
      <li
        v-else
        v-for="(item, i) in results"
        :key="item.id"
        :class="{ highlighted: i === highlightIndex }"
        @click="onSelect(item)"
      >
        {{ item.name }} ({{ item.email }})
      </li>
    </ul>
  </div>
</Autocomplete>
```

## 6. 데이터 페칭 — 고급 패턴

### WebSocket 통합

```javascript
// apps/web/src/shared/composables/useWebSocket.js
import { ref, onUnmounted } from 'vue';

/**
 * WebSocket composable — 실시간 데이터 수신
 */
export function useWebSocket(url) {
  const data = ref(null);
  const status = ref('CLOSED');
  const error = ref(null);
  let ws = null;
  let reconnectTimer = null;
  let reconnectAttempts = 0;
  const MAX_RECONNECTS = 5;

  function connect() {
    ws = new WebSocket(url);
    status.value = 'CONNECTING';

    ws.onopen = () => {
      status.value = 'OPEN';
      reconnectAttempts = 0;
    };

    ws.onmessage = (event) => {
      try {
        data.value = JSON.parse(event.data);
      } catch {
        data.value = event.data;
      }
    };

    ws.onclose = () => {
      status.value = 'CLOSED';
      if (reconnectAttempts < MAX_RECONNECTS) {
        const delay = Math.min(1000 * 2 ** reconnectAttempts, 30000);
        reconnectTimer = setTimeout(() => {
          reconnectAttempts++;
          connect();
        }, delay);
      }
    };

    ws.onerror = (e) => {
      error.value = e;
      status.value = 'ERROR';
    };
  }

  function send(payload) {
    if (ws?.readyState === WebSocket.OPEN) {
      ws.send(typeof payload === 'string' ? payload : JSON.stringify(payload));
    }
  }

  function close() {
    clearTimeout(reconnectTimer);
    reconnectAttempts = MAX_RECONNECTS; // 재연결 방지
    ws?.close();
  }

  connect();

  onUnmounted(close);

  return { data, status, error, send, close };
}
```

### 캐싱 레이어

```javascript
// apps/web/src/shared/lib/cache.js
/**
 * 메모리 + IndexedDB 2계층 캐시
 */
class CacheLayer {
  #memory = new Map();
  #dbName = 'app-cache';
  #storeName = 'responses';

  async get(key, ttl = 300000) {
    // 1. 메모리 캐시 확인
    const memCached = this.#memory.get(key);
    if (memCached && Date.now() - memCached.ts < ttl) {
      return memCached.data;
    }

    // 2. IndexedDB 확인
    try {
      const db = await this.#openDB();
      const tx = db.transaction(this.#storeName, 'readonly');
      const store = tx.objectStore(this.#storeName);
      const result = await this.#promisify(store.get(key));

      if (result && Date.now() - result.ts < ttl) {
        // 메모리에도 저장
        this.#memory.set(key, result);
        return result.data;
      }
    } catch {}

    return null;
  }

  async set(key, data) {
    const entry = { data, ts: Date.now() };
    this.#memory.set(key, entry);

    try {
      const db = await this.#openDB();
      const tx = db.transaction(this.#storeName, 'readwrite');
      tx.objectStore(this.#storeName).put({ ...entry, key });
    } catch {}
  }

  invalidate(pattern) {
    for (const key of this.#memory.keys()) {
      if (key.includes(pattern)) this.#memory.delete(key);
    }
  }

  #openDB() {
    return new Promise((resolve, reject) => {
      const req = indexedDB.open(this.#dbName, 1);
      req.onupgradeneeded = () => {
        req.result.createObjectStore(this.#storeName, { keyPath: 'key' });
      };
      req.onsuccess = () => resolve(req.result);
      req.onerror = () => reject(req.error);
    });
  }

  #promisify(request) {
    return new Promise((resolve, reject) => {
      request.onsuccess = () => resolve(request.result);
      request.onerror = () => reject(request.error);
    });
  }
}

export const cache = new CacheLayer();
```

## 7. 테스트 전략

```javascript
// apps/web/tests/helpers.js
import { mount } from '@vue/test-utils';
import { createTestingPinia } from '@pinia/testing';
import { createRouter, createMemoryHistory } from 'vue-router';
import { vi } from 'vitest';

export function createTestRouter(routes = []) {
  return createRouter({
    history: createMemoryHistory(),
    routes: [
      { path: '/', component: { template: '<div />' } },
      ...routes,
    ],
  });
}

export function mountWithAll(component, options = {}) {
  const router = options.router || createTestRouter(options.routes);
  const pinia = createTestingPinia({
    createSpy: vi.fn,
    initialState: options.initialState,
    stubActions: options.stubActions ?? true,
  });

  return mount(component, {
    global: {
      plugins: [pinia, router],
      stubs: {
        Teleport: true,
        Transition: false,
        ...options.stubs,
      },
    },
    props: options.props,
    slots: options.slots,
  });
}
```

```javascript
// packages/ui/tests/DataTable.test.js
import { describe, it, expect, vi } from 'vitest';
import { mount } from '@vue/test-utils';
import DataTable from '../src/components/DataTable.vue';

const columns = [
  { key: 'name', label: '이름', sortable: true },
  { key: 'email', label: '이메일' },
];

const data = [
  { id: 1, name: '홍길동', email: 'hong@test.com' },
  { id: 2, name: '김철수', email: 'kim@test.com' },
];

describe('DataTable', () => {
  it('데이터를 올바르게 렌더링한다', () => {
    const wrapper = mount(DataTable, {
      props: { columns, data },
    });

    expect(wrapper.findAll('tbody tr')).toHaveLength(2);
    expect(wrapper.text()).toContain('홍길동');
    expect(wrapper.text()).toContain('kim@test.com');
  });

  it('정렬 클릭 시 이벤트를 발행한다', async () => {
    const wrapper = mount(DataTable, {
      props: { columns, data },
    });

    await wrapper.find('th').trigger('click'); // 이름 컬럼
    expect(wrapper.emitted('sort')).toBeTruthy();
    expect(wrapper.emitted('sort')[0]).toEqual(['name']);
  });

  it('선택 기능이 동작한다', async () => {
    const wrapper = mount(DataTable, {
      props: { columns, data, selectable: true, selected: new Set() },
    });

    const checkboxes = wrapper.findAll('input[type="checkbox"]');
    expect(checkboxes).toHaveLength(3); // 전체 선택 + 2개 행
  });

  it('데이터가 없을 때 빈 상태를 표시한다', () => {
    const wrapper = mount(DataTable, {
      props: { columns, data: [] },
    });

    expect(wrapper.text()).toContain('데이터가 없습니다.');
  });
});
```

## 8. 성능 최적화

### Module Federation 설정

```javascript
// apps/web/vite.config.js (호스트)
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import federation from '@originjs/vite-plugin-federation';

export default defineConfig({
  plugins: [
    vue(),
    federation({
      name: 'host',
      remotes: {
        adminApp: 'http://localhost:3001/assets/remoteEntry.js',
      },
      shared: ['vue', 'pinia', 'vue-router'],
    }),
  ],
  build: {
    target: 'esnext',
  },
});
```

```javascript
// apps/admin/vite.config.js (리모트)
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import federation from '@originjs/vite-plugin-federation';

export default defineConfig({
  plugins: [
    vue(),
    federation({
      name: 'adminApp',
      filename: 'remoteEntry.js',
      exposes: {
        './AdminRoutes': './src/routes.js',
      },
      shared: ['vue', 'pinia', 'vue-router'],
    }),
  ],
});
```

### 성능 모니터링

```javascript
// apps/web/src/shared/lib/performance.js
/**
 * Core Web Vitals 모니터링
 */
export function initPerformanceMonitoring() {
  if (typeof PerformanceObserver === 'undefined') return;

  // LCP
  new PerformanceObserver((list) => {
    const entries = list.getEntries();
    const lastEntry = entries[entries.length - 1];
    console.log('[LCP]', lastEntry.startTime);
  }).observe({ type: 'largest-contentful-paint', buffered: true });

  // FID
  new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
      console.log('[FID]', entry.processingStart - entry.startTime);
    }
  }).observe({ type: 'first-input', buffered: true });

  // CLS
  let clsValue = 0;
  new PerformanceObserver((list) => {
    for (const entry of list.getEntries()) {
      if (!entry.hadRecentInput) {
        clsValue += entry.value;
      }
    }
    console.log('[CLS]', clsValue);
  }).observe({ type: 'layout-shift', buffered: true });
}
```

## 9. 보안

### API 클라이언트 보안 레이어

```javascript
// packages/shared-utils/src/http.js
class SecureHttpClient {
  #baseURL;
  #tokenProvider;

  constructor(baseURL, tokenProvider) {
    this.#baseURL = baseURL;
    this.#tokenProvider = tokenProvider;
  }

  async request(endpoint, options = {}) {
    const token = this.#tokenProvider();
    const headers = {
      'Content-Type': 'application/json',
      ...(token && { Authorization: `Bearer ${token}` }),
    };

    // CSRF 토큰
    if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(options.method)) {
      const csrf = this.#getCsrfFromCookie();
      if (csrf) headers['X-XSRF-TOKEN'] = csrf;
    }

    const response = await fetch(`${this.#baseURL}${endpoint}`, {
      ...options,
      headers: { ...headers, ...options.headers },
      credentials: 'include',
    });

    if (response.status === 401) {
      throw new AuthError('인증이 만료되었습니다.');
    }

    if (!response.ok) {
      const data = await response.json().catch(() => null);
      throw new ApiError(response.status, data);
    }

    return response.json();
  }

  #getCsrfFromCookie() {
    return document.cookie
      .split('; ')
      .find((row) => row.startsWith('XSRF-TOKEN='))
      ?.split('=')[1];
  }
}

class AuthError extends Error { name = 'AuthError'; }
class ApiError extends Error {
  constructor(status, data) {
    super(data?.message || `HTTP ${status}`);
    this.status = status;
    this.data = data;
  }
}

export { SecureHttpClient, AuthError, ApiError };
```

### CSP 및 보안 헤더

```javascript
// 배포 서버 설정 (예: nginx 또는 CDN 헤더)
const SECURITY_HEADERS = {
  'Content-Security-Policy': [
    "default-src 'self'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data: https:",
    "connect-src 'self' https://api.example.com wss://ws.example.com",
    "font-src 'self'",
    "object-src 'none'",
    "base-uri 'self'",
    "form-action 'self'",
    "frame-ancestors 'none'",
  ].join('; '),
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'X-XSS-Protection': '1; mode=block',
  'Referrer-Policy': 'strict-origin-when-cross-origin',
  'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
  'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
};
```

## 10. CI/CD 및 모노레포

```json
// turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "test": {
      "dependsOn": ["build"],
      "outputs": ["coverage/**"]
    },
    "lint": {},
    "typecheck": {
      "dependsOn": ["^build"]
    },
    "dev": {
      "cache": false,
      "persistent": true
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
  ci:
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
      - run: pnpm turbo lint typecheck test build --filter=...[HEAD~1]
```
