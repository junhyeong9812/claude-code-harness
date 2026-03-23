# Vanilla JavaScript — 대규모 프로젝트 가이드

## 개요

- **구조**: Feature 기반 모듈 + 독립 배포
- **컴포넌트**: Web Components (Custom Elements + Shadow DOM)
- **상태 관리**: 커스텀 프레임워크 패턴 (Redux-like)
- **적합한 프로젝트**: 대규모 플랫폼, 마이크로 프론트엔드, 디자인 시스템

---

## 1. 프로젝트 구조

```
my-vanilla-large/
├── packages/                        # 모노레포 패키지
│   ├── core/                        # 프레임워크 코어
│   │   ├── src/
│   │   │   ├── component.js         # 베이스 컴포넌트
│   │   │   ├── store.js             # Redux-like 스토어
│   │   │   ├── router.js            # 라우터
│   │   │   ├── di.js                # 의존성 주입 컨테이너
│   │   │   ├── scheduler.js         # 렌더링 스케줄러
│   │   │   └── index.js
│   │   ├── tests/
│   │   └── package.json
│   ├── ui/                          # 디자인 시스템
│   │   ├── src/
│   │   │   ├── tokens/
│   │   │   │   ├── colors.css
│   │   │   │   ├── typography.css
│   │   │   │   └── spacing.css
│   │   │   ├── elements/
│   │   │   │   ├── Button.js
│   │   │   │   ├── Input.js
│   │   │   │   ├── Modal.js
│   │   │   │   ├── DataGrid.js
│   │   │   │   └── index.js
│   │   │   └── index.js
│   │   ├── storybook/
│   │   ├── tests/
│   │   └── package.json
│   └── utils/                       # 공유 유틸리티
│       ├── src/
│       │   ├── http.js
│       │   ├── validation.js
│       │   ├── format.js
│       │   ├── logger.js
│       │   └── index.js
│       ├── tests/
│       └── package.json
├── apps/                            # 애플리케이션
│   ├── main/                        # 메인 앱 (호스트)
│   │   ├── src/
│   │   │   ├── bootstrap.js         # 앱 부트스트랩
│   │   │   ├── registry.js          # 모듈 레지스트리
│   │   │   ├── shell.js             # 앱 셸
│   │   │   ├── routes.js
│   │   │   └── main.js
│   │   ├── public/
│   │   ├── vite.config.js
│   │   └── package.json
│   └── admin/                       # 관리자 앱
│       ├── src/
│       └── package.json
├── modules/                         # 독립 기능 모듈
│   ├── auth/
│   │   ├── src/
│   │   │   ├── components/
│   │   │   │   ├── LoginPage.js
│   │   │   │   ├── RegisterPage.js
│   │   │   │   └── ProfileCard.js
│   │   │   ├── services/
│   │   │   │   └── authService.js
│   │   │   ├── store/
│   │   │   │   ├── actions.js
│   │   │   │   ├── reducers.js
│   │   │   │   └── selectors.js
│   │   │   ├── routes.js
│   │   │   ├── manifest.js          # 모듈 메타데이터
│   │   │   └── index.js             # 모듈 진입점
│   │   ├── tests/
│   │   └── package.json
│   ├── dashboard/
│   │   ├── src/
│   │   │   ├── components/
│   │   │   │   ├── DashboardPage.js
│   │   │   │   ├── StatsWidget.js
│   │   │   │   ├── ChartWidget.js
│   │   │   │   └── ActivityFeed.js
│   │   │   ├── services/
│   │   │   ├── store/
│   │   │   ├── routes.js
│   │   │   ├── manifest.js
│   │   │   └── index.js
│   │   ├── tests/
│   │   └── package.json
│   ├── users/
│   │   └── ...
│   └── reports/
│       └── ...
├── tools/
│   ├── eslint-config/               # 공유 ESLint 설정
│   ├── tsconfig/                    # 공유 TypeScript 설정
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

## 2. 상태 관리 — Redux-like Store

```javascript
// packages/core/src/store.js
/**
 * Redux-like 상태 관리 시스템
 * - 예측 가능한 상태 변경 (순수 리듀서)
 * - 미들웨어 파이프라인
 * - DevTools 통합
 * - 모듈별 슬라이스 동적 등록
 */

// ─── 액션 타입 헬퍼 ───
export function createActionType(module, action) {
  return `[${module}] ${action}`;
}

// ─── 스토어 클래스 ───
class Store {
  #state = {};
  #reducers = {};
  #subscribers = new Map();
  #middlewares = [];
  #devtools = null;

  constructor() {
    this.#connectDevTools();
  }

  /** 리듀서 슬라이스 등록 (동적) */
  registerSlice(name, reducer, initialState = {}) {
    this.#reducers[name] = reducer;
    this.#state[name] = initialState;
    return this;
  }

  /** 리듀서 슬라이스 제거 */
  unregisterSlice(name) {
    delete this.#reducers[name];
    delete this.#state[name];
    this.#subscribers.delete(name);
  }

  /** 액션 디스패치 */
  dispatch(action) {
    if (typeof action === 'function') {
      // 썽크 (비동기 액션)
      return action(this.dispatch.bind(this), () => this.#state);
    }

    // 미들웨어 파이프라인
    const chain = this.#middlewares.map(mw => mw({
      getState: () => this.#state,
      dispatch: this.dispatch.bind(this),
    }));

    const dispatchWithMiddleware = chain.reduceRight(
      (next, middleware) => middleware(next),
      (action) => this.#reduce(action)
    );

    return dispatchWithMiddleware(action);
  }

  #reduce(action) {
    const prevState = this.#state;
    const nextState = {};
    let changed = false;

    for (const [name, reducer] of Object.entries(this.#reducers)) {
      const prevSlice = prevState[name];
      const nextSlice = reducer(prevSlice, action);
      nextState[name] = nextSlice;
      if (nextSlice !== prevSlice) changed = true;
    }

    if (changed) {
      this.#state = Object.freeze(nextState);
      this.#notify(prevState);
      this.#devtools?.send(action, this.#state);
    }

    return action;
  }

  /** 상태 조회 */
  getState(slice) {
    return slice ? this.#state[slice] : this.#state;
  }

  /** 셀렉터 기반 구독 (메모이제이션) */
  select(selector, listener) {
    let prevResult = selector(this.#state);

    const unsubscribe = this.subscribe('*', () => {
      const nextResult = selector(this.#state);
      if (!this.#shallowEqual(prevResult, nextResult)) {
        const prev = prevResult;
        prevResult = nextResult;
        listener(nextResult, prev);
      }
    });

    return unsubscribe;
  }

  /** 슬라이스 구독 */
  subscribe(slice, listener) {
    if (!this.#subscribers.has(slice)) {
      this.#subscribers.set(slice, new Set());
    }
    this.#subscribers.get(slice).add(listener);
    return () => this.#subscribers.get(slice)?.delete(listener);
  }

  /** 미들웨어 등록 */
  use(middleware) {
    this.#middlewares.push(middleware);
    return this;
  }

  #notify(prevState) {
    // 변경된 슬라이스의 구독자 알림
    for (const name of Object.keys(this.#reducers)) {
      if (this.#state[name] !== prevState[name]) {
        const listeners = this.#subscribers.get(name);
        listeners?.forEach(fn => fn(this.#state[name], prevState[name]));
      }
    }
    // 전역 구독자
    this.#subscribers.get('*')?.forEach(fn => fn(this.#state, prevState));
  }

  #shallowEqual(a, b) {
    if (a === b) return true;
    if (!a || !b) return false;
    const keysA = Object.keys(a);
    const keysB = Object.keys(b);
    if (keysA.length !== keysB.length) return false;
    return keysA.every(key => a[key] === b[key]);
  }

  #connectDevTools() {
    if (typeof window !== 'undefined' && window.__REDUX_DEVTOOLS_EXTENSION__) {
      this.#devtools = window.__REDUX_DEVTOOLS_EXTENSION__.connect({
        name: 'Vanilla Store',
      });
    }
  }
}

export const store = new Store();

// ─── 내장 미들웨어 ───

/** 로깅 미들웨어 */
export const loggerMiddleware = (storeApi) => (next) => (action) => {
  console.groupCollapsed(`[Action] ${action.type}`);
  console.log('Payload:', action.payload);
  const result = next(action);
  console.log('Next State:', storeApi.getState());
  console.groupEnd();
  return result;
};

/** 비동기 미들웨어 (Thunk) */
export const thunkMiddleware = (storeApi) => (next) => (action) => {
  if (typeof action === 'function') {
    return action(storeApi.dispatch, storeApi.getState);
  }
  return next(action);
};
```

```javascript
// modules/auth/src/store/actions.js
import { createActionType } from '@packages/core';

export const AUTH = {
  LOGIN_REQUEST: createActionType('auth', 'LOGIN_REQUEST'),
  LOGIN_SUCCESS: createActionType('auth', 'LOGIN_SUCCESS'),
  LOGIN_FAILURE: createActionType('auth', 'LOGIN_FAILURE'),
  LOGOUT: createActionType('auth', 'LOGOUT'),
  SET_USER: createActionType('auth', 'SET_USER'),
};

/** 비동기 로그인 액션 (thunk) */
export function login(credentials) {
  return async (dispatch) => {
    dispatch({ type: AUTH.LOGIN_REQUEST });

    try {
      const { user, token } = await authService.login(credentials);
      localStorage.setItem('token', token);
      dispatch({ type: AUTH.LOGIN_SUCCESS, payload: { user, token } });
    } catch (error) {
      dispatch({ type: AUTH.LOGIN_FAILURE, payload: error.message });
      throw error;
    }
  };
}

export function logout() {
  return (dispatch) => {
    localStorage.removeItem('token');
    dispatch({ type: AUTH.LOGOUT });
  };
}
```

```javascript
// modules/auth/src/store/reducers.js
import { AUTH } from './actions.js';

const initialState = {
  user: null,
  token: localStorage.getItem('token'),
  isAuthenticated: false,
  loading: false,
  error: null,
};

export function authReducer(state = initialState, action) {
  switch (action.type) {
    case AUTH.LOGIN_REQUEST:
      return { ...state, loading: true, error: null };

    case AUTH.LOGIN_SUCCESS:
      return {
        ...state,
        user: action.payload.user,
        token: action.payload.token,
        isAuthenticated: true,
        loading: false,
        error: null,
      };

    case AUTH.LOGIN_FAILURE:
      return {
        ...state,
        loading: false,
        error: action.payload,
      };

    case AUTH.LOGOUT:
      return { ...initialState, token: null };

    case AUTH.SET_USER:
      return { ...state, user: action.payload };

    default:
      return state;
  }
}
```

```javascript
// modules/auth/src/store/selectors.js
/** 메모이제이션된 셀렉터 */
export const authSelectors = {
  isAuthenticated: (state) => state.auth?.isAuthenticated ?? false,
  currentUser: (state) => state.auth?.user,
  isLoading: (state) => state.auth?.loading ?? false,
  error: (state) => state.auth?.error,
  token: (state) => state.auth?.token,
};
```

## 3. 라우팅 — 모듈 연합 라우터

```javascript
// packages/core/src/router.js
/**
 * 모듈 연합 라우터
 * - 각 모듈이 독립적으로 라우트 등록
 * - 중첩 라우트 지원
 * - 비동기 모듈 로딩
 * - 라우트 가드 체인
 */
class ModularRouter {
  #routes = new Map();
  #guards = [];
  #outlet = null;
  #currentModule = null;
  #errorHandler = null;

  constructor() {
    window.addEventListener('popstate', () => this.#resolve());
    document.addEventListener('click', (e) => {
      const link = e.target.closest('a[data-link]');
      if (link) {
        e.preventDefault();
        this.navigate(link.href);
      }
    });
  }

  setOutlet(selector) {
    this.#outlet = document.querySelector(selector);
    return this;
  }

  setErrorHandler(handler) {
    this.#errorHandler = handler;
    return this;
  }

  /** 모듈 라우트 일괄 등록 */
  registerModule(moduleName, routes) {
    for (const route of routes) {
      const fullPath = route.path;
      const paramNames = [];
      const regexStr = fullPath.replace(/:(\w+)/g, (_, name) => {
        paramNames.push(name);
        return '([^/]+)';
      });

      this.#routes.set(fullPath, {
        ...route,
        module: moduleName,
        regex: new RegExp(`^${regexStr}$`),
        paramNames,
      });
    }
    return this;
  }

  /** 모듈 라우트 제거 */
  unregisterModule(moduleName) {
    for (const [path, route] of this.#routes) {
      if (route.module === moduleName) {
        this.#routes.delete(path);
      }
    }
  }

  /** 전역 가드 등록 */
  addGuard(guard) {
    this.#guards.push(guard);
    return this;
  }

  navigate(path, options = {}) {
    const url = new URL(path, window.location.origin);
    if (options.replace) {
      history.replaceState(options.state || null, '', url.pathname + url.search);
    } else {
      history.pushState(options.state || null, '', url.pathname + url.search);
    }
    this.#resolve();
  }

  async #resolve() {
    const pathname = window.location.pathname;
    const query = Object.fromEntries(new URLSearchParams(window.location.search));

    for (const [, route] of this.#routes) {
      const match = pathname.match(route.regex);
      if (!match) continue;

      const params = {};
      route.paramNames.forEach((name, i) => {
        params[name] = decodeURIComponent(match[i + 1]);
      });

      const context = { path: pathname, params, query, route, state: history.state };

      try {
        // 전역 가드 순차 실행
        for (const guard of this.#guards) {
          const result = await guard(context);
          if (result === false) return;
          if (typeof result === 'string') {
            this.navigate(result, { replace: true });
            return;
          }
        }

        // 라우트 가드
        if (route.guard) {
          const result = await route.guard(context);
          if (result === false) return;
          if (typeof result === 'string') {
            this.navigate(result, { replace: true });
            return;
          }
        }

        // 모듈 변경 시 이전 모듈 정리
        if (this.#currentModule !== route.module) {
          this.#currentModule = route.module;
        }

        // 컴포넌트 렌더링
        document.title = route.title || document.title;
        const component = await route.component(context);
        this.#mount(component, route.layout);
        return;
      } catch (error) {
        if (this.#errorHandler) {
          this.#errorHandler(error, context);
        } else {
          console.error('라우팅 에러:', error);
        }
        return;
      }
    }

    // 404
    this.#mount('<h1>404 — 페이지를 찾을 수 없습니다</h1>');
  }

  #mount(content, Layout) {
    if (!this.#outlet) return;
    this.#outlet.innerHTML = '';

    if (Layout) {
      const layout = new Layout();
      const el = layout.render();
      const slot = el.querySelector('[data-outlet]') || el;

      if (content instanceof HTMLElement) {
        slot.appendChild(content);
      } else {
        slot.innerHTML = content;
      }
      this.#outlet.appendChild(el);
    } else if (content instanceof HTMLElement) {
      this.#outlet.appendChild(content);
    } else {
      this.#outlet.innerHTML = content;
    }
  }

  start() {
    this.#resolve();
    return this;
  }
}

export const router = new ModularRouter();
```

```javascript
// modules/dashboard/src/routes.js
export const dashboardRoutes = [
  {
    path: '/dashboard',
    component: async () => {
      const { DashboardPage } = await import('./components/DashboardPage.js');
      return new DashboardPage().render();
    },
    title: '대시보드',
    guard: ({ getState }) => {
      return getState().auth?.isAuthenticated ? true : '/login';
    },
  },
  {
    path: '/dashboard/analytics',
    component: async () => {
      const { AnalyticsPage } = await import('./components/AnalyticsPage.js');
      return new AnalyticsPage().render();
    },
    title: '분석',
  },
];
```

## 4. 스타일링 — 디자인 시스템

```css
/* packages/ui/src/tokens/colors.css */
:root {
  /* 시맨틱 컬러 (라이트) */
  --ds-color-primary-50: #eff6ff;
  --ds-color-primary-100: #dbeafe;
  --ds-color-primary-500: #3b82f6;
  --ds-color-primary-600: #2563eb;
  --ds-color-primary-700: #1d4ed8;

  --ds-color-neutral-50: #f8fafc;
  --ds-color-neutral-100: #f1f5f9;
  --ds-color-neutral-200: #e2e8f0;
  --ds-color-neutral-500: #64748b;
  --ds-color-neutral-700: #334155;
  --ds-color-neutral-900: #0f172a;

  --ds-color-success: #16a34a;
  --ds-color-warning: #d97706;
  --ds-color-error: #dc2626;

  /* 시맨틱 별칭 */
  --ds-bg-primary: var(--ds-color-primary-600);
  --ds-bg-page: #ffffff;
  --ds-bg-surface: var(--ds-color-neutral-50);
  --ds-text-primary: var(--ds-color-neutral-900);
  --ds-text-secondary: var(--ds-color-neutral-500);
  --ds-border-default: var(--ds-color-neutral-200);
}

[data-theme="dark"] {
  --ds-bg-page: var(--ds-color-neutral-900);
  --ds-bg-surface: var(--ds-color-neutral-700);
  --ds-text-primary: var(--ds-color-neutral-50);
  --ds-text-secondary: var(--ds-color-neutral-200);
  --ds-border-default: var(--ds-color-neutral-500);
}
```

```css
/* packages/ui/src/tokens/typography.css */
:root {
  --ds-font-family: 'Pretendard Variable', 'Pretendard', sans-serif;
  --ds-font-mono: 'JetBrains Mono', monospace;

  --ds-text-xs: 0.75rem;    /* 12px */
  --ds-text-sm: 0.875rem;   /* 14px */
  --ds-text-base: 1rem;     /* 16px */
  --ds-text-lg: 1.125rem;   /* 18px */
  --ds-text-xl: 1.25rem;    /* 20px */
  --ds-text-2xl: 1.5rem;    /* 24px */
  --ds-text-3xl: 1.875rem;  /* 30px */
  --ds-text-4xl: 2.25rem;   /* 36px */

  --ds-leading-tight: 1.25;
  --ds-leading-normal: 1.5;
  --ds-leading-relaxed: 1.75;

  --ds-weight-normal: 400;
  --ds-weight-medium: 500;
  --ds-weight-semibold: 600;
  --ds-weight-bold: 700;
}
```

## 5. 컴포넌트 설계 — Web Components 기반

```javascript
// packages/core/src/component.js
import { store } from './store.js';

/**
 * Web Component 베이스 클래스
 * - Shadow DOM 캡슐화
 * - 반응형 속성 (observed attributes)
 * - 스토어 연동
 * - 렌더링 스케줄링 (배치 업데이트)
 */
export class BaseComponent extends HTMLElement {
  static observedAttributes = [];

  #subscriptions = [];
  #renderScheduled = false;
  #mounted = false;

  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
    this._state = {};
  }

  /** 반응형 내부 상태 */
  get state() {
    return this._state;
  }

  set state(newState) {
    this._state = { ...this._state, ...newState };
    this.#scheduleRender();
  }

  connectedCallback() {
    this.setup();
    this.#doRender();
    this.#mounted = true;
    this.mounted();
  }

  disconnectedCallback() {
    this.unmounted();
    this.#subscriptions.forEach(unsub => unsub());
    this.#subscriptions = [];
  }

  attributeChangedCallback(name, oldVal, newVal) {
    if (oldVal !== newVal) {
      this.attributeChanged(name, oldVal, newVal);
      this.#scheduleRender();
    }
  }

  // ─── 라이프사이클 훅 (오버라이드용) ───
  setup() {}
  mounted() {}
  unmounted() {}
  attributeChanged(name, oldVal, newVal) {}

  /** 오버라이드: 스타일 문자열 반환 */
  styles() { return ''; }

  /** 오버라이드: HTML 문자열 반환 */
  template() { return ''; }

  /** 스토어 구독 (자동 정리) */
  watch(selector, callback) {
    const unsub = store.select(selector, callback);
    this.#subscriptions.push(unsub);
    return unsub;
  }

  /** 디스패치 헬퍼 */
  dispatch(action) {
    return store.dispatch(action);
  }

  /** Shadow DOM 내 쿼리 */
  $(selector) {
    return this.shadowRoot.querySelector(selector);
  }

  $$(selector) {
    return this.shadowRoot.querySelectorAll(selector);
  }

  /** 이벤트 발행 */
  emit(name, detail) {
    this.dispatchEvent(new CustomEvent(name, {
      detail,
      bubbles: true,
      composed: true,
    }));
  }

  #scheduleRender() {
    if (this.#renderScheduled || !this.#mounted) return;
    this.#renderScheduled = true;
    requestAnimationFrame(() => {
      this.#doRender();
      this.#renderScheduled = false;
    });
  }

  #doRender() {
    const styles = this.styles();
    const template = this.template();
    this.shadowRoot.innerHTML = `
      ${styles ? `<style>${styles}</style>` : ''}
      ${template}
    `;
    // 렌더 후 이벤트 바인딩
    queueMicrotask(() => this.afterRender());
  }

  /** 오버라이드: 렌더 후 이벤트 바인딩 */
  afterRender() {}
}

/**
 * 컴포넌트 등록 헬퍼
 */
export function defineComponent(tag, ComponentClass) {
  if (!customElements.get(tag)) {
    customElements.define(tag, ComponentClass);
  }
}
```

```javascript
// packages/ui/src/elements/DataGrid.js
import { BaseComponent, defineComponent } from '@packages/core';

/**
 * 고성능 데이터 그리드 Web Component
 * - 가상 스크롤
 * - 정렬/필터
 * - 컬럼 리사이즈
 */
class DataGrid extends BaseComponent {
  static observedAttributes = ['page-size'];

  setup() {
    this._state = {
      data: [],
      columns: [],
      sortKey: null,
      sortDir: 'asc',
      page: 1,
      pageSize: parseInt(this.getAttribute('page-size') || '50'),
    };
  }

  /** 외부에서 데이터 설정 */
  setData(data, columns) {
    this.state = { data, columns };
  }

  styles() {
    return `
      :host {
        display: block;
        border: 1px solid var(--ds-border-default, #e2e8f0);
        border-radius: 8px;
        overflow: hidden;
      }
      .grid-wrapper { overflow-x: auto; }
      table { width: 100%; border-collapse: collapse; }
      th, td {
        padding: 0.75rem 1rem;
        text-align: left;
        border-bottom: 1px solid var(--ds-border-default, #e2e8f0);
      }
      th {
        background: var(--ds-bg-surface, #f8fafc);
        font-weight: 600;
        font-size: 0.75rem;
        text-transform: uppercase;
        letter-spacing: 0.05em;
        cursor: pointer;
        user-select: none;
      }
      th:hover { background: #e2e8f0; }
      tr:hover td { background: var(--ds-bg-surface, #f8fafc); }
      .sort-icon { margin-left: 0.25rem; }
      .pagination {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 0.75rem 1rem;
        border-top: 1px solid var(--ds-border-default, #e2e8f0);
      }
      .pagination button {
        padding: 0.25rem 0.75rem;
        border: 1px solid var(--ds-border-default);
        background: white;
        border-radius: 4px;
        cursor: pointer;
      }
      .pagination button:disabled { opacity: 0.5; cursor: default; }
    `;
  }

  template() {
    const { data, columns, sortKey, sortDir, page, pageSize } = this._state;
    const sorted = this.#getSortedData(data);
    const start = (page - 1) * pageSize;
    const pageData = sorted.slice(start, start + pageSize);
    const totalPages = Math.ceil(sorted.length / pageSize);

    return `
      <div class="grid-wrapper">
        <table>
          <thead>
            <tr>
              ${columns.map(col => `
                <th data-key="${col.key}">
                  ${col.label}
                  ${sortKey === col.key
                    ? `<span class="sort-icon">${sortDir === 'asc' ? '▲' : '▼'}</span>`
                    : ''}
                </th>
              `).join('')}
            </tr>
          </thead>
          <tbody>
            ${pageData.map(row => `
              <tr>
                ${columns.map(col => `
                  <td>${col.render ? col.render(row[col.key], row) : this.#escape(row[col.key])}</td>
                `).join('')}
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
      <div class="pagination">
        <span>${sorted.length}건 중 ${start + 1}-${Math.min(start + pageSize, sorted.length)}</span>
        <div>
          <button data-action="prev" ${page <= 1 ? 'disabled' : ''}>이전</button>
          <span>${page} / ${totalPages}</span>
          <button data-action="next" ${page >= totalPages ? 'disabled' : ''}>다음</button>
        </div>
      </div>
    `;
  }

  afterRender() {
    this.$$('th').forEach(th => {
      th.addEventListener('click', () => {
        const key = th.dataset.key;
        this.state = {
          sortKey: key,
          sortDir: this._state.sortKey === key && this._state.sortDir === 'asc' ? 'desc' : 'asc',
          page: 1,
        };
      });
    });

    this.$('[data-action="prev"]')?.addEventListener('click', () => {
      if (this._state.page > 1) this.state = { page: this._state.page - 1 };
    });

    this.$('[data-action="next"]')?.addEventListener('click', () => {
      const totalPages = Math.ceil(this._state.data.length / this._state.pageSize);
      if (this._state.page < totalPages) this.state = { page: this._state.page + 1 };
    });
  }

  #getSortedData(data) {
    const { sortKey, sortDir } = this._state;
    if (!sortKey) return data;
    return [...data].sort((a, b) => {
      const aVal = a[sortKey], bVal = b[sortKey];
      const cmp = aVal < bVal ? -1 : aVal > bVal ? 1 : 0;
      return sortDir === 'asc' ? cmp : -cmp;
    });
  }

  #escape(val) {
    if (val == null) return '';
    const el = document.createElement('span');
    el.textContent = String(val);
    return el.innerHTML;
  }
}

defineComponent('ds-data-grid', DataGrid);
export { DataGrid };
```

## 6. 데이터 페칭 — 캐싱 레이어

```javascript
// packages/utils/src/http.js
/**
 * HTTP 클라이언트 (캐싱, 재시도, 취소 지원)
 */
class HttpClient {
  #baseURL;
  #cache = new Map();
  #inflightRequests = new Map();
  #interceptors = { request: [], response: [] };

  constructor(baseURL) {
    this.#baseURL = baseURL;
  }

  /** 캐시를 활용한 GET 요청 */
  async get(endpoint, { cache = false, ttl = 60000, signal } = {}) {
    const cacheKey = `GET:${endpoint}`;

    // 캐시 확인
    if (cache && this.#cache.has(cacheKey)) {
      const cached = this.#cache.get(cacheKey);
      if (Date.now() - cached.timestamp < ttl) {
        return cached.data;
      }
      this.#cache.delete(cacheKey);
    }

    // 동일 요청 중복 방지 (deduplication)
    if (this.#inflightRequests.has(cacheKey)) {
      return this.#inflightRequests.get(cacheKey);
    }

    const promise = this.#request(endpoint, { method: 'GET', signal })
      .then(data => {
        if (cache) {
          this.#cache.set(cacheKey, { data, timestamp: Date.now() });
        }
        this.#inflightRequests.delete(cacheKey);
        return data;
      })
      .catch(err => {
        this.#inflightRequests.delete(cacheKey);
        throw err;
      });

    this.#inflightRequests.set(cacheKey, promise);
    return promise;
  }

  async post(endpoint, data, options) {
    return this.#request(endpoint, { method: 'POST', body: JSON.stringify(data), ...options });
  }

  async put(endpoint, data, options) {
    return this.#request(endpoint, { method: 'PUT', body: JSON.stringify(data), ...options });
  }

  async delete(endpoint, options) {
    return this.#request(endpoint, { method: 'DELETE', ...options });
  }

  /** 캐시 무효화 */
  invalidateCache(pattern) {
    if (!pattern) {
      this.#cache.clear();
      return;
    }
    for (const key of this.#cache.keys()) {
      if (key.includes(pattern)) {
        this.#cache.delete(key);
      }
    }
  }

  async #request(endpoint, options = {}) {
    let config = {
      headers: { 'Content-Type': 'application/json' },
      ...options,
    };

    // 요청 인터셉터
    for (const interceptor of this.#interceptors.request) {
      config = await interceptor(config);
    }

    const response = await fetch(`${this.#baseURL}${endpoint}`, config);

    let result = {
      status: response.status,
      ok: response.ok,
      data: await response.json().catch(() => null),
    };

    // 응답 인터셉터
    for (const interceptor of this.#interceptors.response) {
      result = await interceptor(result);
    }

    if (!response.ok) {
      throw new HttpError(response.status, result.data?.message || 'Request failed');
    }

    return result.data;
  }

  onRequest(interceptor) { this.#interceptors.request.push(interceptor); }
  onResponse(interceptor) { this.#interceptors.response.push(interceptor); }
}

class HttpError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
    this.name = 'HttpError';
  }
}

export const http = new HttpClient(import.meta.env.VITE_API_URL || '/api');
```

## 7. 테스트 전략

```javascript
// packages/core/tests/store.test.js
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { Store, thunkMiddleware } from '../src/store.js';

describe('Store', () => {
  let store;

  beforeEach(() => {
    store = new Store();
    store.use(thunkMiddleware);
  });

  describe('리듀서 등록', () => {
    it('슬라이스를 등록하고 초기 상태를 설정한다', () => {
      const reducer = (state = { count: 0 }, action) => {
        if (action.type === 'INCREMENT') return { ...state, count: state.count + 1 };
        return state;
      };
      store.registerSlice('counter', reducer, { count: 0 });

      expect(store.getState('counter')).toEqual({ count: 0 });
    });
  });

  describe('dispatch', () => {
    it('액션으로 상태를 변경한다', () => {
      const reducer = (state = { count: 0 }, action) => {
        if (action.type === 'INCREMENT') return { count: state.count + 1 };
        return state;
      };
      store.registerSlice('counter', reducer, { count: 0 });

      store.dispatch({ type: 'INCREMENT' });
      expect(store.getState('counter').count).toBe(1);
    });

    it('thunk 액션을 처리한다', async () => {
      const reducer = (state = { data: null }, action) => {
        if (action.type === 'SET_DATA') return { data: action.payload };
        return state;
      };
      store.registerSlice('test', reducer, { data: null });

      await store.dispatch(async (dispatch) => {
        const data = { message: 'hello' };
        dispatch({ type: 'SET_DATA', payload: data });
      });

      expect(store.getState('test').data).toEqual({ message: 'hello' });
    });
  });

  describe('select', () => {
    it('셀렉터 결과 변경 시 콜백을 실행한다', () => {
      const reducer = (state = { count: 0 }, action) => {
        if (action.type === 'INCREMENT') return { count: state.count + 1 };
        return state;
      };
      store.registerSlice('counter', reducer, { count: 0 });

      const listener = vi.fn();
      store.select(
        (state) => state.counter?.count,
        listener
      );

      store.dispatch({ type: 'INCREMENT' });
      expect(listener).toHaveBeenCalledWith(1, 0);
    });
  });
});
```

```javascript
// packages/ui/tests/DataGrid.test.js
import { describe, it, expect, beforeEach } from 'vitest';
import '../src/elements/DataGrid.js';

describe('ds-data-grid', () => {
  let grid;

  beforeEach(() => {
    document.body.innerHTML = '<ds-data-grid page-size="10"></ds-data-grid>';
    grid = document.querySelector('ds-data-grid');
    grid.setData(
      Array.from({ length: 25 }, (_, i) => ({ id: i + 1, name: `User ${i + 1}` })),
      [
        { key: 'id', label: 'ID' },
        { key: 'name', label: '이름' },
      ]
    );
  });

  it('올바른 수의 행을 렌더링한다', () => {
    const rows = grid.shadowRoot.querySelectorAll('tbody tr');
    expect(rows.length).toBe(10); // pageSize = 10
  });

  it('페이지네이션 정보를 표시한다', () => {
    const pagination = grid.shadowRoot.querySelector('.pagination');
    expect(pagination.textContent).toContain('25건');
    expect(pagination.textContent).toContain('1 / 3');
  });
});
```

## 8. 성능 최적화

### 모듈 레지스트리 (동적 로딩)

```javascript
// apps/main/src/registry.js
/**
 * 모듈 레지스트리
 * - 모듈 지연 로딩
 * - 의존성 해석
 * - 모듈 라이프사이클 관리
 */
class ModuleRegistry {
  #modules = new Map();
  #loaded = new Map();

  /** 모듈 등록 (메타데이터만) */
  register(manifest) {
    this.#modules.set(manifest.name, {
      ...manifest,
      status: 'registered',
    });
  }

  /** 모듈 로드 (필요 시) */
  async load(name) {
    if (this.#loaded.has(name)) {
      return this.#loaded.get(name);
    }

    const manifest = this.#modules.get(name);
    if (!manifest) throw new Error(`모듈 "${name}"을 찾을 수 없습니다.`);

    // 의존성 먼저 로드
    if (manifest.dependencies) {
      await Promise.all(
        manifest.dependencies.map(dep => this.load(dep))
      );
    }

    manifest.status = 'loading';

    try {
      const module = await manifest.loader();
      await module.init?.();
      this.#loaded.set(name, module);
      manifest.status = 'loaded';
      return module;
    } catch (error) {
      manifest.status = 'error';
      throw new Error(`모듈 "${name}" 로드 실패: ${error.message}`);
    }
  }

  /** 모듈 언로드 */
  async unload(name) {
    const module = this.#loaded.get(name);
    if (module) {
      await module.destroy?.();
      this.#loaded.delete(name);
      this.#modules.get(name).status = 'registered';
    }
  }

  getStatus(name) {
    return this.#modules.get(name)?.status || 'unknown';
  }
}

export const registry = new ModuleRegistry();

// 모듈 매니페스트 등록
registry.register({
  name: 'auth',
  version: '1.0.0',
  loader: () => import('../../modules/auth/src/index.js'),
  dependencies: [],
});

registry.register({
  name: 'dashboard',
  version: '1.0.0',
  loader: () => import('../../modules/dashboard/src/index.js'),
  dependencies: ['auth'],
});

registry.register({
  name: 'users',
  version: '1.0.0',
  loader: () => import('../../modules/users/src/index.js'),
  dependencies: ['auth'],
});
```

### Web Worker 활용

```javascript
// packages/utils/src/worker-pool.js
/**
 * Web Worker 풀
 * - 무거운 연산을 워커에 위임
 * - 풀 기반 워커 재사용
 */
export class WorkerPool {
  #workers = [];
  #queue = [];
  #maxWorkers;

  constructor(workerScript, maxWorkers = navigator.hardwareConcurrency || 4) {
    this.#maxWorkers = maxWorkers;
    for (let i = 0; i < maxWorkers; i++) {
      this.#workers.push({
        worker: new Worker(workerScript, { type: 'module' }),
        busy: false,
      });
    }
  }

  async exec(taskData) {
    return new Promise((resolve, reject) => {
      const available = this.#workers.find(w => !w.busy);

      const task = { data: taskData, resolve, reject };

      if (available) {
        this.#run(available, task);
      } else {
        this.#queue.push(task);
      }
    });
  }

  #run(worker, task) {
    worker.busy = true;

    const handler = (e) => {
      worker.worker.removeEventListener('message', handler);
      worker.busy = false;

      task.resolve(e.data);

      // 대기열 처리
      if (this.#queue.length > 0) {
        this.#run(worker, this.#queue.shift());
      }
    };

    worker.worker.addEventListener('message', handler);
    worker.worker.postMessage(task.data);
  }

  terminate() {
    this.#workers.forEach(w => w.worker.terminate());
  }
}
```

### Service Worker (오프라인 지원)

```javascript
// apps/main/public/sw.js
const CACHE_NAME = 'app-v1';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/src/main.js',
];

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(STATIC_ASSETS))
  );
});

self.addEventListener('fetch', (event) => {
  // Network First, fallback to cache
  event.respondWith(
    fetch(event.request)
      .then(response => {
        const clone = response.clone();
        caches.open(CACHE_NAME).then(cache => cache.put(event.request, clone));
        return response;
      })
      .catch(() => caches.match(event.request))
  );
});
```

## 9. 보안

### ⚠️ innerHTML 사용 주의

이 가이드의 Module Registry, Web Component, 라우터 예시에서 `innerHTML`이 사용된다. 실제 프로젝트에서는:

- **사용자 입력이 포함된 문자열을 `innerHTML`에 할당하지 않는다**
- Shadow DOM 내부 정적 템플릿은 허용되지만, 동적 데이터는 `textContent`로 삽입
- 외부 HTML은 반드시 `DOMPurify.sanitize()`를 거친다
- 상세 패턴은 `skills/security-common.md` 4절 및 `vanilla/small.md` 9절 참고

### 의존성 주입 + 보안 레이어

```javascript
// packages/core/src/di.js
/**
 * 의존성 주입 컨테이너
 * - 서비스 격리 및 교체 용이
 * - 테스트 시 모킹 간편
 */
class DIContainer {
  #services = new Map();
  #singletons = new Map();

  /** 싱글턴 등록 */
  singleton(name, factory) {
    this.#services.set(name, { factory, type: 'singleton' });
    return this;
  }

  /** 트랜지언트(매번 새로운 인스턴스) 등록 */
  transient(name, factory) {
    this.#services.set(name, { factory, type: 'transient' });
    return this;
  }

  /** 서비스 해석 */
  resolve(name) {
    const entry = this.#services.get(name);
    if (!entry) throw new Error(`서비스 "${name}" 미등록`);

    if (entry.type === 'singleton') {
      if (!this.#singletons.has(name)) {
        this.#singletons.set(name, entry.factory(this));
      }
      return this.#singletons.get(name);
    }

    return entry.factory(this);
  }
}

export const container = new DIContainer();
```

### CSP + Subresource Integrity

```html
<!-- apps/main/index.html -->
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <meta http-equiv="Content-Security-Policy" content="
    default-src 'self';
    script-src 'self' 'nonce-${NONCE}';
    style-src 'self' 'unsafe-inline';
    img-src 'self' data: https:;
    connect-src 'self' https://api.example.com;
    font-src 'self';
    object-src 'none';
    base-uri 'self';
    form-action 'self';
    frame-ancestors 'none';
  "/>
  <meta name="referrer" content="strict-origin-when-cross-origin" />
  <title>앱</title>
</head>
<body>
  <div id="app"></div>
  <script type="module" src="/src/main.js" nonce="${NONCE}"></script>
</body>
</html>
```

### 보안 유틸리티

```javascript
// packages/utils/src/security.js
/**
 * DOMPurify 대안 — 간단한 HTML 새니타이저
 */
const ALLOWED_TAGS = new Set([
  'p', 'br', 'b', 'i', 'em', 'strong', 'a', 'ul', 'ol', 'li', 'code', 'pre',
]);
const ALLOWED_ATTRS = new Set(['href', 'title', 'class']);

export function sanitizeHtml(html) {
  const template = document.createElement('template');
  template.innerHTML = html;
  const fragment = template.content;

  function clean(node) {
    const walker = document.createTreeWalker(node, NodeFilter.SHOW_ELEMENT);
    const toRemove = [];

    while (walker.nextNode()) {
      const el = walker.currentNode;
      if (!ALLOWED_TAGS.has(el.tagName.toLowerCase())) {
        toRemove.push(el);
        continue;
      }
      // 허용되지 않은 속성 제거
      for (const attr of [...el.attributes]) {
        if (!ALLOWED_ATTRS.has(attr.name)) {
          el.removeAttribute(attr.name);
        }
      }
      // href에서 javascript: 프로토콜 차단
      if (el.hasAttribute('href')) {
        const href = el.getAttribute('href');
        if (href.trim().toLowerCase().startsWith('javascript:')) {
          el.removeAttribute('href');
        }
      }
    }

    toRemove.forEach(el => {
      el.replaceWith(...el.childNodes);
    });
  }

  clean(fragment);
  const div = document.createElement('div');
  div.appendChild(fragment);
  return div.innerHTML;
}
```

## 10. 빌드 및 배포

```javascript
// turbo.json
{
  "$schema": "https://turbo.build/schema.json",
  "pipeline": {
    "build": {
      "dependsOn": ["^build"],
      "outputs": ["dist/**"]
    },
    "test": {
      "dependsOn": ["build"]
    },
    "lint": {},
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
  - 'packages/*'
  - 'apps/*'
  - 'modules/*'
  - 'tools/*'
```

```javascript
// apps/main/vite.config.js
import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
  resolve: {
    alias: {
      '@packages/core': resolve(__dirname, '../../packages/core/src'),
      '@packages/ui': resolve(__dirname, '../../packages/ui/src'),
      '@packages/utils': resolve(__dirname, '../../packages/utils/src'),
    },
  },
  build: {
    target: 'es2022',
    rollupOptions: {
      output: {
        manualChunks: {
          core: ['../../packages/core/src/index.js'],
          ui: ['../../packages/ui/src/index.js'],
        },
      },
    },
  },
});
```
