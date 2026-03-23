# Vanilla JavaScript — 중규모 프로젝트 가이드

## 개요

- **구조**: 모듈(Module) 기반
- **라우팅**: 커스텀 라우터 (History API)
- **상태 관리**: Pub/Sub 패턴
- **스타일링**: CSS Modules (Vite 지원)
- **적합한 프로젝트**: 관리자 대시보드, 중규모 SPA, 내부 도구

---

## 1. 프로젝트 구조

```
my-vanilla-medium/
├── public/
│   └── assets/
│       ├── images/
│       └── icons/
├── src/
│   ├── core/
│   │   ├── router.js              # History API 라우터
│   │   ├── store.js               # Pub/Sub 상태 관리
│   │   ├── component.js           # 베이스 컴포넌트 클래스
│   │   ├── eventBus.js            # 전역 이벤트 버스
│   │   └── http.js                # HTTP 클라이언트
│   ├── features/
│   │   ├── auth/
│   │   │   ├── components/
│   │   │   │   ├── LoginForm.js
│   │   │   │   └── RegisterForm.js
│   │   │   ├── services/
│   │   │   │   └── authService.js
│   │   │   ├── auth.store.js
│   │   │   ├── auth.routes.js
│   │   │   └── index.js
│   │   ├── dashboard/
│   │   │   ├── components/
│   │   │   │   ├── StatsCard.js
│   │   │   │   ├── Chart.js
│   │   │   │   └── RecentActivity.js
│   │   │   ├── services/
│   │   │   │   └── dashboardService.js
│   │   │   ├── dashboard.store.js
│   │   │   ├── dashboard.routes.js
│   │   │   └── index.js
│   │   └── users/
│   │       ├── components/
│   │       │   ├── UserList.js
│   │       │   ├── UserDetail.js
│   │       │   └── UserForm.js
│   │       ├── services/
│   │       │   └── userService.js
│   │       ├── users.store.js
│   │       ├── users.routes.js
│   │       └── index.js
│   ├── shared/
│   │   ├── components/
│   │   │   ├── Button.js
│   │   │   ├── Modal.js
│   │   │   ├── Table.js
│   │   │   ├── Pagination.js
│   │   │   ├── Toast.js
│   │   │   └── Spinner.js
│   │   ├── utils/
│   │   │   ├── dom.js
│   │   │   ├── format.js
│   │   │   ├── validation.js
│   │   │   └── debounce.js
│   │   └── constants.js
│   ├── layouts/
│   │   ├── MainLayout.js
│   │   ├── AuthLayout.js
│   │   └── Sidebar.js
│   ├── styles/
│   │   ├── variables.css
│   │   ├── reset.css
│   │   ├── global.css
│   │   └── modules/
│   │       ├── button.module.css
│   │       ├── table.module.css
│   │       └── modal.module.css
│   ├── app.js
│   └── main.js
├── tests/
│   ├── unit/
│   │   ├── core/
│   │   │   ├── router.test.js
│   │   │   └── store.test.js
│   │   └── features/
│   │       └── auth/
│   │           └── authService.test.js
│   └── e2e/
│       └── auth.spec.js
├── index.html
├── vite.config.js
├── vitest.config.js
├── package.json
└── .eslintrc.json
```

## 2. 상태 관리 — Pub/Sub Store

```javascript
// src/core/store.js
/**
 * Pub/Sub 기반 상태 관리 시스템
 * - 슬라이스(slice) 단위로 상태를 분리
 * - 미들웨어 지원 (로깅, 디버깅 등)
 */
class Store {
  #state = {};
  #subscribers = new Map();
  #middlewares = [];

  constructor(initialState = {}) {
    this.#state = this.#deepFreeze({ ...initialState });
  }

  getState(slice) {
    if (slice) {
      return this.#state[slice];
    }
    return this.#state;
  }

  setState(slice, updater) {
    const currentSlice = this.#state[slice] || {};
    const newSlice = typeof updater === 'function'
      ? updater(currentSlice)
      : updater;

    const prevState = this.#state;
    this.#state = this.#deepFreeze({
      ...this.#state,
      [slice]: { ...currentSlice, ...newSlice },
    });

    // 미들웨어 실행
    this.#middlewares.forEach(mw => mw(prevState, this.#state, slice));

    // 해당 슬라이스 구독자 알림
    const listeners = this.#subscribers.get(slice) || new Set();
    listeners.forEach(fn => fn(this.#state[slice], prevState[slice]));

    // 전역 구독자 알림
    const globalListeners = this.#subscribers.get('*') || new Set();
    globalListeners.forEach(fn => fn(this.#state, prevState));
  }

  subscribe(slice, listener) {
    if (!this.#subscribers.has(slice)) {
      this.#subscribers.set(slice, new Set());
    }
    this.#subscribers.get(slice).add(listener);

    // 구독 해제 함수 반환
    return () => {
      this.#subscribers.get(slice)?.delete(listener);
    };
  }

  use(middleware) {
    this.#middlewares.push(middleware);
  }

  #deepFreeze(obj) {
    if (typeof obj !== 'object' || obj === null) return obj;
    Object.freeze(obj);
    Object.values(obj).forEach(val => this.#deepFreeze(val));
    return obj;
  }
}

// 싱글턴 인스턴스
export const store = new Store();

// 디버그 미들웨어 (개발 환경)
if (import.meta.env.DEV) {
  store.use((prev, next, slice) => {
    console.groupCollapsed(`[Store] ${slice}`);
    console.log('이전:', prev[slice]);
    console.log('이후:', next[slice]);
    console.groupEnd();
  });
}
```

```javascript
// src/features/auth/auth.store.js
import { store } from '../../core/store.js';

// 슬라이스 초기화
store.setState('auth', {
  user: null,
  token: localStorage.getItem('token'),
  isAuthenticated: false,
  loading: false,
  error: null,
});

// 액션 함수들
export const authActions = {
  setLoading(loading) {
    store.setState('auth', { loading, error: null });
  },

  loginSuccess(user, token) {
    localStorage.setItem('token', token);
    store.setState('auth', {
      user,
      token,
      isAuthenticated: true,
      loading: false,
      error: null,
    });
  },

  loginFailure(error) {
    store.setState('auth', {
      loading: false,
      error,
    });
  },

  logout() {
    localStorage.removeItem('token');
    store.setState('auth', {
      user: null,
      token: null,
      isAuthenticated: false,
    });
  },
};

// 셀렉터
export const authSelectors = {
  isAuthenticated: () => store.getState('auth')?.isAuthenticated ?? false,
  currentUser: () => store.getState('auth')?.user,
  isLoading: () => store.getState('auth')?.loading ?? false,
};
```

## 3. 라우팅 — History API 커스텀 라우터

```javascript
// src/core/router.js
/**
 * History API 기반 클라이언트 사이드 라우터
 * - 경로 매개변수 지원 (/users/:id)
 * - 라우트 가드 (인증 체크)
 * - 레이아웃 시스템
 * - 코드 스플리팅 (동적 임포트)
 */
class Router {
  #routes = [];
  #currentRoute = null;
  #beforeEach = null;
  #outlet = null;

  constructor(outletSelector = '#app') {
    this.#outlet = document.querySelector(outletSelector);
    window.addEventListener('popstate', () => this.#resolve());
    // 링크 인터셉트
    document.addEventListener('click', (e) => {
      const link = e.target.closest('a[data-link]');
      if (link) {
        e.preventDefault();
        this.navigate(link.getAttribute('href'));
      }
    });
  }

  addRoute(path, handler, options = {}) {
    const paramNames = [];
    const regexPath = path.replace(/:(\w+)/g, (_, name) => {
      paramNames.push(name);
      return '([^/]+)';
    });

    this.#routes.push({
      path,
      regex: new RegExp(`^${regexPath}$`),
      paramNames,
      handler,
      ...options, // layout, guard, title
    });
    return this;
  }

  beforeEach(guard) {
    this.#beforeEach = guard;
    return this;
  }

  navigate(path, { replace = false } = {}) {
    if (replace) {
      history.replaceState(null, '', path);
    } else {
      history.pushState(null, '', path);
    }
    this.#resolve();
  }

  async #resolve() {
    const path = window.location.pathname;

    for (const route of this.#routes) {
      const match = path.match(route.regex);
      if (!match) continue;

      // 매개변수 추출
      const params = {};
      route.paramNames.forEach((name, i) => {
        params[name] = match[i + 1];
      });

      // 쿼리 파라미터 파싱
      const query = Object.fromEntries(
        new URLSearchParams(window.location.search)
      );

      const context = { path, params, query, route };

      // 전역 가드 실행
      if (this.#beforeEach) {
        const result = await this.#beforeEach(context);
        if (result === false) return;
        if (typeof result === 'string') {
          this.navigate(result, { replace: true });
          return;
        }
      }

      // 라우트별 가드
      if (route.guard) {
        const result = await route.guard(context);
        if (result === false) return;
        if (typeof result === 'string') {
          this.navigate(result, { replace: true });
          return;
        }
      }

      // 페이지 제목 업데이트
      if (route.title) {
        document.title = typeof route.title === 'function'
          ? route.title(context)
          : route.title;
      }

      // 핸들러 실행 (동적 임포트 지원)
      this.#currentRoute = context;
      const component = typeof route.handler === 'function'
        ? await route.handler(context)
        : route.handler;

      // 레이아웃 적용
      this.#render(component, route.layout);
      return;
    }

    // 404 처리
    this.#outlet.innerHTML = '<h1>404 — 페이지를 찾을 수 없습니다</h1>';
  }

  #render(content, Layout) {
    this.#outlet.innerHTML = '';

    if (Layout) {
      const layout = new Layout();
      const layoutEl = layout.render();
      const slot = layoutEl.querySelector('[data-slot="content"]') || layoutEl;
      if (typeof content === 'string') {
        slot.innerHTML = content;
      } else if (content instanceof HTMLElement) {
        slot.appendChild(content);
      }
      this.#outlet.appendChild(layoutEl);
    } else {
      if (typeof content === 'string') {
        this.#outlet.innerHTML = content;
      } else if (content instanceof HTMLElement) {
        this.#outlet.appendChild(content);
      }
    }
  }

  start() {
    this.#resolve();
    return this;
  }
}

export const router = new Router('#app');
```

```javascript
// src/features/auth/auth.routes.js
import { router } from '../../core/router.js';
import { AuthLayout } from '../../layouts/AuthLayout.js';

export function registerAuthRoutes() {
  router
    .addRoute('/login', async () => {
      const { LoginForm } = await import('./components/LoginForm.js');
      return new LoginForm().render();
    }, {
      layout: AuthLayout,
      title: '로그인',
    })
    .addRoute('/register', async () => {
      const { RegisterForm } = await import('./components/RegisterForm.js');
      return new RegisterForm().render();
    }, {
      layout: AuthLayout,
      title: '회원가입',
    });
}
```

```javascript
// src/features/users/users.routes.js
import { router } from '../../core/router.js';
import { MainLayout } from '../../layouts/MainLayout.js';
import { authSelectors } from '../auth/auth.store.js';

const requireAuth = () => {
  if (!authSelectors.isAuthenticated()) return '/login';
  return true;
};

export function registerUserRoutes() {
  router
    .addRoute('/users', async () => {
      const { UserList } = await import('./components/UserList.js');
      return new UserList().render();
    }, {
      layout: MainLayout,
      guard: requireAuth,
      title: '사용자 목록',
    })
    .addRoute('/users/:id', async ({ params }) => {
      const { UserDetail } = await import('./components/UserDetail.js');
      return new UserDetail(params.id).render();
    }, {
      layout: MainLayout,
      guard: requireAuth,
      title: (ctx) => `사용자 #${ctx.params.id}`,
    });
}
```

## 4. 스타일링 — CSS Modules

```css
/* src/styles/modules/button.module.css */
.button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  border: none;
  border-radius: var(--radius-md);
  font-size: var(--font-size-base);
  font-weight: 500;
  cursor: pointer;
  transition: all var(--transition-fast);
  text-decoration: none;
}

.button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.primary {
  background: var(--color-primary);
  color: white;
}

.primary:hover:not(:disabled) {
  background: var(--color-primary-hover);
}

.secondary {
  background: transparent;
  color: var(--color-text);
  border: 1px solid var(--color-border);
}

.secondary:hover:not(:disabled) {
  background: var(--color-bg-secondary);
}

.danger {
  background: var(--color-error);
  color: white;
}

.danger:hover:not(:disabled) {
  background: #b91c1c;
}

.small {
  padding: 0.25rem 0.75rem;
  font-size: var(--font-size-sm);
}

.large {
  padding: 0.75rem 1.5rem;
  font-size: var(--font-size-lg);
}
```

```javascript
// src/shared/components/Button.js
import styles from '../../styles/modules/button.module.css';

/**
 * 재사용 가능한 버튼 컴포넌트
 */
export function createButton({
  text,
  variant = 'primary',
  size = '',
  disabled = false,
  onClick,
  type = 'button',
  icon = '',
} = {}) {
  const button = document.createElement('button');
  button.type = type;
  button.disabled = disabled;
  button.className = [
    styles.button,
    styles[variant],
    size && styles[size],
  ].filter(Boolean).join(' ');

  button.innerHTML = icon ? `${icon}<span>${text}</span>` : text;

  if (onClick) {
    button.addEventListener('click', onClick);
  }

  return button;
}
```

```css
/* src/styles/modules/table.module.css */
.wrapper {
  overflow-x: auto;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}

.table {
  width: 100%;
  border-collapse: collapse;
  font-size: var(--font-size-sm);
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
  color: var(--color-text-muted);
  text-transform: uppercase;
  font-size: 0.75rem;
  letter-spacing: 0.05em;
}

.table tr:hover td {
  background: var(--color-bg-secondary);
}

.table tr:last-child td {
  border-bottom: none;
}

.sortable {
  cursor: pointer;
  user-select: none;
}

.sortable:hover {
  color: var(--color-primary);
}
```

## 5. 컴포넌트 설계 패턴 — 베이스 클래스

```javascript
// src/core/component.js
import { store } from './store.js';

/**
 * 컴포넌트 베이스 클래스
 * - 라이프사이클: setup → render → mounted → destroyed
 * - 스토어 구독 자동 관리
 * - 이벤트 리스너 자동 정리
 */
export class Component {
  #element = null;
  #unsubscribers = [];
  #eventCleanups = [];

  constructor(props = {}) {
    this.props = props;
    this.state = {};
    this.setup();
  }

  /** 오버라이드: 초기 설정 */
  setup() {}

  /** 오버라이드: HTML 문자열 또는 Element 반환 */
  template() {
    return '';
  }

  /** 오버라이드: DOM 렌더링 후 호출 */
  mounted() {}

  /** 오버라이드: 파괴 전 정리 */
  beforeDestroy() {}

  render() {
    this.#element = document.createElement('div');
    const tmpl = this.template();

    if (typeof tmpl === 'string') {
      this.#element.innerHTML = tmpl;
    } else if (tmpl instanceof HTMLElement) {
      this.#element.appendChild(tmpl);
    }

    // mounted 콜백을 마이크로태스크로 예약
    queueMicrotask(() => this.mounted());

    return this.#element;
  }

  /** 상태 업데이트 후 리렌더링 */
  setState(newState) {
    this.state = { ...this.state, ...newState };
    this.#rerender();
  }

  /** 스토어 슬라이스 구독 (자동 정리) */
  watch(slice, callback) {
    const unsub = store.subscribe(slice, callback);
    this.#unsubscribers.push(unsub);
    return unsub;
  }

  /** 이벤트 리스너 등록 (자동 정리) */
  on(selector, event, handler) {
    const el = this.#element?.querySelector(selector);
    if (el) {
      el.addEventListener(event, handler);
      this.#eventCleanups.push(() => el.removeEventListener(event, handler));
    }
  }

  /** DOM 쿼리 헬퍼 */
  $(selector) {
    return this.#element?.querySelector(selector);
  }

  $$(selector) {
    return this.#element?.querySelectorAll(selector) || [];
  }

  /** 컴포넌트 파괴 */
  destroy() {
    this.beforeDestroy();
    this.#unsubscribers.forEach(unsub => unsub());
    this.#eventCleanups.forEach(cleanup => cleanup());
    this.#element?.remove();
  }

  #rerender() {
    const parent = this.#element?.parentNode;
    if (!parent) return;

    this.#eventCleanups.forEach(cleanup => cleanup());
    this.#eventCleanups = [];

    const newElement = document.createElement('div');
    const tmpl = this.template();
    if (typeof tmpl === 'string') {
      newElement.innerHTML = tmpl;
    }

    parent.replaceChild(newElement, this.#element);
    this.#element = newElement;
    this.mounted();
  }
}
```

```javascript
// src/features/users/components/UserList.js
import { Component } from '../../../core/component.js';
import { store } from '../../../core/store.js';
import { userService } from '../services/userService.js';
import { router } from '../../../core/router.js';
import tableStyles from '../../../styles/modules/table.module.css';

export class UserList extends Component {
  setup() {
    this.state = {
      users: [],
      loading: true,
      page: 1,
      totalPages: 1,
      search: '',
    };
  }

  template() {
    const { users, loading, search } = this.state;

    if (loading) {
      return '<div class="spinner">로딩 중...</div>';
    }

    return `
      <div class="user-list">
        <div class="user-list__header">
          <h2>사용자 목록</h2>
          <input
            type="search"
            class="search-input"
            placeholder="이름으로 검색..."
            value="${this.#escapeAttr(search)}"
          />
        </div>
        <div class="${tableStyles.wrapper}">
          <table class="${tableStyles.table}">
            <thead>
              <tr>
                <th class="${tableStyles.sortable}" data-sort="name">이름</th>
                <th>이메일</th>
                <th>역할</th>
                <th>가입일</th>
                <th>액션</th>
              </tr>
            </thead>
            <tbody>
              ${users.map(user => `
                <tr data-id="${user.id}">
                  <td>${this.#escape(user.name)}</td>
                  <td>${this.#escape(user.email)}</td>
                  <td><span class="badge badge--${user.role}">${this.#escape(user.role)}</span></td>
                  <td>${this.#formatDate(user.createdAt)}</td>
                  <td>
                    <button class="btn-view" data-id="${user.id}">보기</button>
                    <button class="btn-delete" data-id="${user.id}">삭제</button>
                  </td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        </div>
      </div>
    `;
  }

  async mounted() {
    // 데이터 로드
    if (this.state.loading) {
      await this.#loadUsers();
    }

    // 이벤트 바인딩
    this.on('.search-input', 'input', this.#debounce((e) => {
      this.setState({ search: e.target.value });
      this.#loadUsers();
    }, 300));

    this.$$('.btn-view').forEach(btn => {
      btn.addEventListener('click', () => {
        router.navigate(`/users/${btn.dataset.id}`);
      });
    });

    this.$$('.btn-delete').forEach(btn => {
      btn.addEventListener('click', () => this.#deleteUser(btn.dataset.id));
    });
  }

  async #loadUsers() {
    try {
      const { data, totalPages } = await userService.getUsers({
        page: this.state.page,
        search: this.state.search,
      });
      this.setState({ users: data, totalPages, loading: false });
    } catch (error) {
      console.error('사용자 목록 로드 실패:', error);
      this.setState({ loading: false });
    }
  }

  async #deleteUser(id) {
    if (!confirm('정말 삭제하시겠습니까?')) return;
    try {
      await userService.deleteUser(id);
      this.setState({
        users: this.state.users.filter(u => u.id !== id),
      });
    } catch (error) {
      alert('삭제에 실패했습니다.');
    }
  }

  #escape(str) {
    const el = document.createElement('span');
    el.textContent = str;
    return el.innerHTML;
  }

  #escapeAttr(str) {
    return str.replace(/"/g, '&quot;');
  }

  #formatDate(dateStr) {
    return new Date(dateStr).toLocaleDateString('ko-KR');
  }

  #debounce(fn, delay) {
    let timer;
    return (...args) => {
      clearTimeout(timer);
      timer = setTimeout(() => fn(...args), delay);
    };
  }
}
```

## 6. 데이터 페칭 — HTTP 클라이언트

```javascript
// src/core/http.js
/**
 * HTTP 클라이언트
 * - 인터셉터 패턴
 * - 자동 토큰 주입
 * - 요청 재시도
 * - 요청 취소 (AbortController)
 */
class HttpClient {
  #baseURL;
  #interceptors = {
    request: [],
    response: [],
  };

  constructor(baseURL = '') {
    this.#baseURL = baseURL;
  }

  /** 요청 인터셉터 등록 */
  useRequestInterceptor(fulfilled, rejected) {
    this.#interceptors.request.push({ fulfilled, rejected });
  }

  /** 응답 인터셉터 등록 */
  useResponseInterceptor(fulfilled, rejected) {
    this.#interceptors.response.push({ fulfilled, rejected });
  }

  async #request(endpoint, options = {}) {
    let config = {
      url: `${this.#baseURL}${endpoint}`,
      headers: {
        'Content-Type': 'application/json',
        ...options.headers,
      },
      ...options,
    };

    // 요청 인터셉터 실행
    for (const interceptor of this.#interceptors.request) {
      try {
        config = await interceptor.fulfilled(config);
      } catch (error) {
        if (interceptor.rejected) interceptor.rejected(error);
        throw error;
      }
    }

    const { url, ...fetchOptions } = config;
    let response;

    try {
      response = await fetch(url, fetchOptions);
    } catch (error) {
      throw new HttpError(0, '네트워크 오류', error);
    }

    let result = {
      status: response.status,
      ok: response.ok,
      headers: response.headers,
      data: null,
    };

    const contentType = response.headers.get('content-type');
    if (contentType?.includes('application/json')) {
      result.data = await response.json();
    } else {
      result.data = await response.text();
    }

    // 응답 인터셉터 실행
    for (const interceptor of this.#interceptors.response) {
      try {
        result = await interceptor.fulfilled(result);
      } catch (error) {
        if (interceptor.rejected) result = await interceptor.rejected(error);
        else throw error;
      }
    }

    if (!response.ok) {
      throw new HttpError(response.status, result.data?.message || '요청 실패', result);
    }

    return result.data;
  }

  get(endpoint, options) {
    return this.#request(endpoint, { ...options, method: 'GET' });
  }

  post(endpoint, data, options) {
    return this.#request(endpoint, {
      ...options,
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  put(endpoint, data, options) {
    return this.#request(endpoint, {
      ...options,
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  delete(endpoint, options) {
    return this.#request(endpoint, { ...options, method: 'DELETE' });
  }
}

class HttpError extends Error {
  constructor(status, message, response) {
    super(message);
    this.status = status;
    this.response = response;
    this.name = 'HttpError';
  }
}

// 인스턴스 생성 및 인터셉터 설정
export const http = new HttpClient(import.meta.env.VITE_API_URL || '/api');

// 인증 토큰 자동 주입
http.useRequestInterceptor((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// 401 응답 시 로그아웃 처리
http.useResponseInterceptor(
  (response) => response,
  (error) => {
    if (error.status === 401) {
      localStorage.removeItem('token');
      window.location.href = '/login';
    }
    throw error;
  }
);
```

```javascript
// src/features/users/services/userService.js
import { http } from '../../../core/http.js';

export const userService = {
  async getUsers({ page = 1, limit = 20, search = '' } = {}) {
    const params = new URLSearchParams({ page, limit, search });
    return http.get(`/users?${params}`);
  },

  async getUserById(id) {
    return http.get(`/users/${id}`);
  },

  async createUser(userData) {
    return http.post('/users', userData);
  },

  async updateUser(id, userData) {
    return http.put(`/users/${id}`, userData);
  },

  async deleteUser(id) {
    return http.delete(`/users/${id}`);
  },
};
```

## 7. 테스트 전략

```javascript
// tests/unit/core/store.test.js
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Store } from '../../../src/core/store.js';

describe('Store', () => {
  let store;

  beforeEach(() => {
    store = new Store();
  });

  it('슬라이스 상태를 설정하고 조회한다', () => {
    store.setState('auth', { user: 'john' });
    expect(store.getState('auth')).toEqual({ user: 'john' });
  });

  it('함수형 업데이터를 지원한다', () => {
    store.setState('counter', { count: 0 });
    store.setState('counter', (prev) => ({ count: prev.count + 1 }));
    expect(store.getState('counter').count).toBe(1);
  });

  it('슬라이스 변경 시 구독자에게 알린다', () => {
    const listener = vi.fn();
    store.subscribe('auth', listener);

    store.setState('auth', { user: 'john' });
    expect(listener).toHaveBeenCalledWith(
      { user: 'john' },
      undefined
    );
  });

  it('구독 해제가 동작한다', () => {
    const listener = vi.fn();
    const unsub = store.subscribe('auth', listener);

    unsub();
    store.setState('auth', { user: 'john' });
    expect(listener).not.toHaveBeenCalled();
  });

  it('상태가 불변(frozen)이다', () => {
    store.setState('auth', { user: 'john' });
    const state = store.getState('auth');
    expect(() => { state.user = 'changed'; }).toThrow();
  });
});
```

```javascript
// tests/unit/core/router.test.js
import { describe, it, expect, vi, beforeEach } from 'vitest';

describe('Router', () => {
  let container;

  beforeEach(() => {
    document.body.innerHTML = '<div id="app"></div>';
    container = document.querySelector('#app');
    // History API 모킹
    vi.spyOn(window, 'addEventListener');
  });

  it('경로 매개변수를 추출한다', () => {
    const paramRegex = /^\/users\/([^/]+)$/;
    const match = '/users/123'.match(paramRegex);
    expect(match[1]).toBe('123');
  });

  it('쿼리 파라미터를 파싱한다', () => {
    const params = Object.fromEntries(
      new URLSearchParams('?page=1&search=test')
    );
    expect(params).toEqual({ page: '1', search: 'test' });
  });
});
```

```javascript
// tests/e2e/auth.spec.js (Playwright)
import { test, expect } from '@playwright/test';

test.describe('인증 흐름', () => {
  test('로그인 후 대시보드로 이동한다', async ({ page }) => {
    await page.goto('/login');

    await page.fill('[name="email"]', 'admin@example.com');
    await page.fill('[name="password"]', 'password123');
    await page.click('button[type="submit"]');

    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('h1')).toContainText('대시보드');
  });

  test('잘못된 자격 증명으로 에러를 표시한다', async ({ page }) => {
    await page.goto('/login');

    await page.fill('[name="email"]', 'wrong@example.com');
    await page.fill('[name="password"]', 'wrong');
    await page.click('button[type="submit"]');

    await expect(page.locator('.error-message')).toBeVisible();
  });
});
```

## 8. 성능 최적화

### 가상 스크롤 (대량 리스트)

```javascript
// src/shared/components/VirtualList.js
/**
 * 가상 스크롤 컴포넌트
 * - 수천 개의 항목도 부드럽게 렌더링
 */
export class VirtualList {
  #container;
  #items;
  #itemHeight;
  #renderItem;
  #visibleCount;

  constructor({ container, items, itemHeight, renderItem }) {
    this.#container = container;
    this.#items = items;
    this.#itemHeight = itemHeight;
    this.#renderItem = renderItem;
    this.#visibleCount = Math.ceil(container.clientHeight / itemHeight) + 5;

    this.#setup();
  }

  #setup() {
    this.#container.style.overflow = 'auto';
    this.#container.style.position = 'relative';

    // 전체 높이를 차지하는 스페이서
    const spacer = document.createElement('div');
    spacer.style.height = `${this.#items.length * this.#itemHeight}px`;
    this.#container.appendChild(spacer);

    // 콘텐츠 래퍼
    const content = document.createElement('div');
    content.style.position = 'absolute';
    content.style.top = '0';
    content.style.left = '0';
    content.style.right = '0';
    content.dataset.role = 'virtual-content';
    this.#container.appendChild(content);

    this.#container.addEventListener('scroll', () => {
      requestAnimationFrame(() => this.#update());
    });

    this.#update();
  }

  #update() {
    const scrollTop = this.#container.scrollTop;
    const startIndex = Math.floor(scrollTop / this.#itemHeight);
    const endIndex = Math.min(startIndex + this.#visibleCount, this.#items.length);

    const content = this.#container.querySelector('[data-role="virtual-content"]');
    content.style.transform = `translateY(${startIndex * this.#itemHeight}px)`;
    content.innerHTML = '';

    for (let i = startIndex; i < endIndex; i++) {
      const el = this.#renderItem(this.#items[i], i);
      el.style.height = `${this.#itemHeight}px`;
      content.appendChild(el);
    }
  }

  updateItems(newItems) {
    this.#items = newItems;
    this.#container.querySelector('div').style.height =
      `${newItems.length * this.#itemHeight}px`;
    this.#update();
  }
}
```

### 지연 로딩 및 디바운싱

```javascript
// src/shared/utils/debounce.js
export function debounce(fn, delay = 300) {
  let timeoutId;
  return function (...args) {
    clearTimeout(timeoutId);
    timeoutId = setTimeout(() => fn.apply(this, args), delay);
  };
}

export function throttle(fn, limit = 100) {
  let inThrottle = false;
  return function (...args) {
    if (!inThrottle) {
      fn.apply(this, args);
      inThrottle = true;
      setTimeout(() => (inThrottle = false), limit);
    }
  };
}

// IntersectionObserver 기반 지연 로딩
export function lazyLoad(selector, loadCallback) {
  const observer = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        loadCallback(entry.target);
        observer.unobserve(entry.target);
      }
    });
  }, { rootMargin: '200px' });

  document.querySelectorAll(selector).forEach(el => observer.observe(el));

  return observer;
}
```

## 9. 보안

### ⚠️ innerHTML 사용 주의

이 가이드의 라우터, 컴포넌트 예시에서 `innerHTML`이 사용된다. 실제 프로젝트에서는:

- **사용자 입력이 포함된 문자열을 `innerHTML`에 할당하지 않는다**
- `textContent`, `createElement()`, `<template>` 태그를 우선 사용한다
- 외부 HTML 렌더링이 필요하면 반드시 `DOMPurify.sanitize()`를 거친다
- 상세 패턴은 `skills/security-common.md` 4절 및 `vanilla/small.md` 9절 참고

### XSS 방지 — 템플릿 엔진

```javascript
// src/shared/utils/template.js
/**
 * 안전한 템플릿 엔진
 * - 기본적으로 모든 값을 이스케이프
 * - raw() 함수로 명시적으로 HTML 삽입 가능
 */
const ESCAPE_MAP = {
  '&': '&amp;',
  '<': '&lt;',
  '>': '&gt;',
  '"': '&quot;',
  "'": '&#39;',
};

function escape(str) {
  return String(str).replace(/[&<>"']/g, (char) => ESCAPE_MAP[char]);
}

/** 이스케이프하지 않을 값을 표시 */
export function raw(html) {
  return { __raw: true, value: html };
}

/**
 * 태그 템플릿 리터럴로 안전한 HTML 생성
 *
 * 사용법:
 * html`<div>${userInput}</div>`    // 자동 이스케이프
 * html`<div>${raw(trustedHtml)}</div>` // 이스케이프 안 함
 */
export function html(strings, ...values) {
  return strings.reduce((result, str, i) => {
    const value = values[i];
    if (value === undefined || value === null) {
      return result + str;
    }
    if (value.__raw) {
      return result + str + value.value;
    }
    if (Array.isArray(value)) {
      return result + str + value.map(v => v?.__raw ? v.value : escape(v)).join('');
    }
    return result + str + escape(value);
  }, '');
}
```

### CSRF 보호

```javascript
// src/core/http.js 에 추가
http.useRequestInterceptor((config) => {
  // CSRF 토큰 자동 주입 (쿠키에서 읽기)
  if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(config.method)) {
    const csrfToken = document.cookie
      .split('; ')
      .find(row => row.startsWith('XSRF-TOKEN='))
      ?.split('=')[1];

    if (csrfToken) {
      config.headers['X-XSRF-TOKEN'] = decodeURIComponent(csrfToken);
    }
  }
  return config;
});
```

### 입력 검증 유틸리티

```javascript
// src/shared/utils/validation.js
export const validators = {
  required: (value) => ({
    valid: value != null && String(value).trim() !== '',
    message: '필수 입력 항목입니다.',
  }),

  email: (value) => ({
    valid: /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value),
    message: '올바른 이메일 형식이 아닙니다.',
  }),

  minLength: (min) => (value) => ({
    valid: String(value).length >= min,
    message: `최소 ${min}자 이상 입력해주세요.`,
  }),

  maxLength: (max) => (value) => ({
    valid: String(value).length <= max,
    message: `최대 ${max}자까지 입력 가능합니다.`,
  }),

  pattern: (regex, msg) => (value) => ({
    valid: regex.test(value),
    message: msg,
  }),

  /** URL 검증 (XSS 방지) */
  safeUrl: (value) => {
    try {
      const url = new URL(value);
      return {
        valid: ['http:', 'https:'].includes(url.protocol),
        message: 'http 또는 https URL만 허용됩니다.',
      };
    } catch {
      return { valid: false, message: '올바른 URL이 아닙니다.' };
    }
  },
};

/**
 * 폼 검증 실행
 * @param {Object} data - 검증할 데이터
 * @param {Object} rules - { fieldName: [validator1, validator2] }
 */
export function validateForm(data, rules) {
  const errors = {};
  let isValid = true;

  for (const [field, fieldValidators] of Object.entries(rules)) {
    for (const validator of fieldValidators) {
      const result = validator(data[field]);
      if (!result.valid) {
        errors[field] = result.message;
        isValid = false;
        break;
      }
    }
  }

  return { isValid, errors };
}
```

## 10. 앱 초기화 예시

```javascript
// src/app.js
import { router } from './core/router.js';
import { store } from './core/store.js';
import { authSelectors } from './features/auth/auth.store.js';
import { registerAuthRoutes } from './features/auth/auth.routes.js';
import { registerUserRoutes } from './features/users/users.routes.js';

export function initApp() {
  // 전역 라우트 가드
  router.beforeEach((context) => {
    const publicPaths = ['/login', '/register'];
    if (!publicPaths.includes(context.path) && !authSelectors.isAuthenticated()) {
      return '/login';
    }
    return true;
  });

  // 기능별 라우트 등록
  registerAuthRoutes();
  registerUserRoutes();

  // 대시보드 라우트
  router.addRoute('/', async () => {
    const { Dashboard } = await import('./features/dashboard/index.js');
    return new Dashboard().render();
  }, {
    title: '대시보드',
  });

  // 라우터 시작
  router.start();
}
```

```javascript
// src/main.js
import './styles/reset.css';
import './styles/variables.css';
import './styles/global.css';
import { initApp } from './app.js';

initApp();
```
