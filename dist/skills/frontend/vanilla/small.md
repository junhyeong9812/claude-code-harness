# Vanilla JavaScript — 소규모 프로젝트 가이드

## 개요

- **도구**: Vite
- **구조**: 플랫(flat) 구조
- **스타일링**: CSS Custom Properties
- **컴포넌트**: Web Components (선택)
- **적합한 프로젝트**: 랜딩 페이지, 단일 기능 도구, 프로토타입, 위젯

---

## 1. 프로젝트 구조

```
my-vanilla-app/
├── public/
│   ├── favicon.ico
│   └── images/
│       └── logo.svg
├── src/
│   ├── components/
│   │   ├── header.js          # 헤더 컴포넌트
│   │   ├── hero.js            # 히어로 섹션
│   │   └── contact-form.js    # 연락처 폼
│   ├── utils/
│   │   ├── dom.js             # DOM 유틸리티
│   │   └── validation.js      # 폼 검증
│   ├── styles/
│   │   ├── reset.css          # CSS 리셋
│   │   ├── variables.css      # CSS Custom Properties
│   │   ├── global.css         # 전역 스타일
│   │   └── components/
│   │       ├── header.css
│   │       ├── hero.css
│   │       └── contact-form.css
│   ├── app.js                 # 앱 초기화
│   └── main.js                # 진입점
├── index.html
├── vite.config.js
├── package.json
└── .eslintrc.json
```

## 2. 상태 관리

소규모 프로젝트에서는 별도 라이브러리 없이 간단한 상태 객체를 사용합니다.

```javascript
// src/utils/state.js
/**
 * 간단한 반응형 상태 관리
 * - 소규모 프로젝트에 적합한 최소 구현
 */
export function createState(initialState) {
  let state = { ...initialState };
  const listeners = new Set();

  return {
    getState() {
      return Object.freeze({ ...state });
    },

    setState(updater) {
      const newState = typeof updater === 'function'
        ? updater(state)
        : updater;
      state = { ...state, ...newState };
      listeners.forEach(listener => listener(state));
    },

    subscribe(listener) {
      listeners.add(listener);
      return () => listeners.delete(listener);
    }
  };
}

// 사용 예시
// src/app.js
import { createState } from './utils/state.js';

const appState = createState({
  menuOpen: false,
  formData: { name: '', email: '', message: '' },
  formSubmitted: false,
});

// 상태 변경 구독
appState.subscribe((state) => {
  document.querySelector('.menu').classList.toggle('open', state.menuOpen);
});

// 상태 업데이트
document.querySelector('.menu-toggle').addEventListener('click', () => {
  appState.setState(prev => ({ menuOpen: !prev.menuOpen }));
});
```

## 3. 라우팅

소규모 프로젝트에서는 단일 페이지이거나 해시 기반 간단한 라우팅으로 충분합니다.

```javascript
// src/utils/router.js
/**
 * 해시 기반 간단한 라우터
 */
export function createRouter(routes) {
  function navigate() {
    const hash = window.location.hash.slice(1) || '/';
    const route = routes[hash];

    if (route) {
      const container = document.querySelector('#app');
      container.innerHTML = '';
      route(container);
    }
  }

  window.addEventListener('hashchange', navigate);
  // 초기 로드
  navigate();

  return { navigate };
}

// 사용 예시
import { createRouter } from './utils/router.js';
import { renderHome } from './components/home.js';
import { renderAbout } from './components/about.js';

createRouter({
  '/': renderHome,
  '/about': renderAbout,
});
```

## 4. 스타일링

CSS Custom Properties를 활용한 디자인 토큰 기반 스타일링입니다.

```css
/* src/styles/variables.css */
:root {
  /* 색상 */
  --color-primary: #2563eb;
  --color-primary-hover: #1d4ed8;
  --color-secondary: #64748b;
  --color-bg: #ffffff;
  --color-bg-secondary: #f8fafc;
  --color-text: #1e293b;
  --color-text-muted: #64748b;
  --color-border: #e2e8f0;
  --color-error: #dc2626;
  --color-success: #16a34a;

  /* 타이포그래피 */
  --font-sans: 'Pretendard', -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
  --font-mono: 'JetBrains Mono', 'Fira Code', monospace;
  --font-size-sm: 0.875rem;
  --font-size-base: 1rem;
  --font-size-lg: 1.125rem;
  --font-size-xl: 1.25rem;
  --font-size-2xl: 1.5rem;
  --font-size-3xl: 2rem;

  /* 간격 */
  --spacing-xs: 0.25rem;
  --spacing-sm: 0.5rem;
  --spacing-md: 1rem;
  --spacing-lg: 1.5rem;
  --spacing-xl: 2rem;
  --spacing-2xl: 3rem;

  /* 기타 */
  --radius-sm: 0.25rem;
  --radius-md: 0.5rem;
  --radius-lg: 1rem;
  --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
  --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.07);
  --transition-fast: 150ms ease;
  --transition-base: 250ms ease;
}

/* 다크 모드 */
@media (prefers-color-scheme: dark) {
  :root {
    --color-bg: #0f172a;
    --color-bg-secondary: #1e293b;
    --color-text: #f1f5f9;
    --color-text-muted: #94a3b8;
    --color-border: #334155;
  }
}
```

```css
/* src/styles/components/header.css */
.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: var(--spacing-md) var(--spacing-xl);
  background: var(--color-bg);
  border-bottom: 1px solid var(--color-border);
  box-shadow: var(--shadow-sm);
}

.header__logo {
  font-size: var(--font-size-xl);
  font-weight: 700;
  color: var(--color-primary);
  text-decoration: none;
}

.header__nav a {
  color: var(--color-text);
  text-decoration: none;
  padding: var(--spacing-sm) var(--spacing-md);
  border-radius: var(--radius-sm);
  transition: background var(--transition-fast);
}

.header__nav a:hover {
  background: var(--color-bg-secondary);
}
```

## 5. 컴포넌트 설계 패턴

### 함수 기반 컴포넌트

```javascript
// src/components/hero.js
/**
 * 히어로 섹션 컴포넌트
 * - DOM을 직접 생성하여 반환하는 패턴
 */
export function createHero({ title, subtitle, ctaText, onCtaClick }) {
  const section = document.createElement('section');
  section.className = 'hero';
  section.innerHTML = `
    <div class="hero__content">
      <h1 class="hero__title">${escapeHtml(title)}</h1>
      <p class="hero__subtitle">${escapeHtml(subtitle)}</p>
      <button class="hero__cta btn btn--primary">${escapeHtml(ctaText)}</button>
    </div>
  `;

  section.querySelector('.hero__cta').addEventListener('click', onCtaClick);

  return section;
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str;
  return div.innerHTML;
}
```

### Web Components 활용

```javascript
// src/components/contact-form.js
/**
 * 연락처 폼 Web Component
 * - Shadow DOM으로 스타일 캡슐화
 * - 커스텀 이벤트로 외부 통신
 */
class ContactForm extends HTMLElement {
  constructor() {
    super();
    this.attachShadow({ mode: 'open' });
  }

  connectedCallback() {
    this.render();
    this.setupEvents();
  }

  render() {
    this.shadowRoot.innerHTML = `
      <style>
        :host {
          display: block;
          max-width: 480px;
          margin: 0 auto;
        }
        .form-group {
          margin-bottom: 1rem;
        }
        label {
          display: block;
          margin-bottom: 0.25rem;
          font-weight: 600;
          color: var(--color-text, #1e293b);
        }
        input, textarea {
          width: 100%;
          padding: 0.5rem 0.75rem;
          border: 1px solid var(--color-border, #e2e8f0);
          border-radius: 0.5rem;
          font-size: 1rem;
          font-family: inherit;
          box-sizing: border-box;
          transition: border-color 150ms ease;
        }
        input:focus, textarea:focus {
          outline: none;
          border-color: var(--color-primary, #2563eb);
          box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.1);
        }
        .error {
          color: var(--color-error, #dc2626);
          font-size: 0.875rem;
          margin-top: 0.25rem;
        }
        button {
          background: var(--color-primary, #2563eb);
          color: white;
          padding: 0.75rem 1.5rem;
          border: none;
          border-radius: 0.5rem;
          font-size: 1rem;
          cursor: pointer;
          transition: background 150ms ease;
        }
        button:hover {
          background: var(--color-primary-hover, #1d4ed8);
        }
      </style>
      <form>
        <div class="form-group">
          <label for="name">이름</label>
          <input type="text" id="name" name="name" required />
          <div class="error" data-error="name"></div>
        </div>
        <div class="form-group">
          <label for="email">이메일</label>
          <input type="email" id="email" name="email" required />
          <div class="error" data-error="email"></div>
        </div>
        <div class="form-group">
          <label for="message">메시지</label>
          <textarea id="message" name="message" rows="4" required></textarea>
          <div class="error" data-error="message"></div>
        </div>
        <button type="submit">보내기</button>
      </form>
    `;
  }

  setupEvents() {
    const form = this.shadowRoot.querySelector('form');
    form.addEventListener('submit', (e) => {
      e.preventDefault();
      const formData = new FormData(form);
      const data = Object.fromEntries(formData);

      if (this.validate(data)) {
        this.dispatchEvent(new CustomEvent('form-submit', {
          detail: data,
          bubbles: true,
          composed: true,
        }));
        form.reset();
      }
    });
  }

  validate(data) {
    let valid = true;
    // 에러 메시지 초기화
    this.shadowRoot.querySelectorAll('.error').forEach(el => el.textContent = '');

    if (!data.name.trim()) {
      this.showError('name', '이름을 입력해주세요.');
      valid = false;
    }
    if (!data.email.includes('@')) {
      this.showError('email', '올바른 이메일을 입력해주세요.');
      valid = false;
    }
    if (!data.message.trim()) {
      this.showError('message', '메시지를 입력해주세요.');
      valid = false;
    }
    return valid;
  }

  showError(field, message) {
    const el = this.shadowRoot.querySelector(`[data-error="${field}"]`);
    if (el) el.textContent = message;
  }
}

customElements.define('contact-form', ContactForm);
```

## 6. 데이터 페칭

```javascript
// src/utils/api.js
/**
 * 간단한 API 클라이언트
 * - fetch 래퍼로 에러 처리 통일
 */
const BASE_URL = import.meta.env.VITE_API_URL || '/api';

async function request(endpoint, options = {}) {
  const url = `${BASE_URL}${endpoint}`;

  const config = {
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
    ...options,
  };

  try {
    const response = await fetch(url, config);

    if (!response.ok) {
      throw new ApiError(response.status, await response.text());
    }

    return await response.json();
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(0, '네트워크 오류가 발생했습니다.');
  }
}

class ApiError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
    this.name = 'ApiError';
  }
}

export const api = {
  get: (endpoint) => request(endpoint),
  post: (endpoint, data) => request(endpoint, {
    method: 'POST',
    body: JSON.stringify(data),
  }),
};

// 사용 예시
import { api } from './utils/api.js';

document.querySelector('contact-form').addEventListener('form-submit', async (e) => {
  try {
    await api.post('/contact', e.detail);
    showToast('메시지가 전송되었습니다!', 'success');
  } catch (error) {
    showToast('전송에 실패했습니다. 다시 시도해주세요.', 'error');
  }
});
```

## 7. 테스트 전략

```javascript
// tests/utils/validation.test.js
import { describe, it, expect } from 'vitest';
import { validateEmail, validateRequired } from '../../src/utils/validation.js';

describe('validateEmail', () => {
  it('올바른 이메일을 통과시킨다', () => {
    expect(validateEmail('user@example.com')).toBe(true);
  });

  it('잘못된 이메일을 거부한다', () => {
    expect(validateEmail('invalid')).toBe(false);
    expect(validateEmail('user@')).toBe(false);
    expect(validateEmail('')).toBe(false);
  });
});

describe('validateRequired', () => {
  it('빈 문자열을 거부한다', () => {
    expect(validateRequired('')).toBe(false);
    expect(validateRequired('   ')).toBe(false);
  });

  it('값이 있으면 통과시킨다', () => {
    expect(validateRequired('hello')).toBe(true);
  });
});
```

```javascript
// vite.config.js
import { defineConfig } from 'vite';

export default defineConfig({
  test: {
    environment: 'jsdom',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
    },
  },
  build: {
    target: 'es2020',
    minify: 'esbuild',
  },
});
```

## 8. 성능 최적화

### 이미지 최적화

```html
<!-- 반응형 이미지 + lazy loading -->
<img
  src="/images/hero.webp"
  srcset="/images/hero-480.webp 480w,
          /images/hero-768.webp 768w,
          /images/hero-1200.webp 1200w"
  sizes="(max-width: 768px) 100vw, 1200px"
  alt="히어로 이미지"
  loading="lazy"
  decoding="async"
  width="1200"
  height="600"
/>
```

### 리소스 힌트

```html
<!-- index.html -->
<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />

  <!-- 폰트 프리로드 -->
  <link rel="preload" href="/fonts/Pretendard-Regular.woff2" as="font" type="font/woff2" crossorigin />

  <!-- 중요 CSS 인라인 -->
  <style>
    /* Critical CSS: 첫 화면에 보이는 요소만 */
    body { margin: 0; font-family: 'Pretendard', sans-serif; }
    .header { display: flex; padding: 1rem 2rem; }
  </style>

  <!-- 나머지 CSS 비동기 로드 -->
  <link rel="stylesheet" href="/src/styles/global.css" media="print" onload="this.media='all'" />

  <title>내 프로젝트</title>
</head>
<body>
  <div id="app"></div>
  <script type="module" src="/src/main.js"></script>
</body>
</html>
```

### 동적 임포트

```javascript
// 필요할 때만 모듈 로드
document.querySelector('.open-modal').addEventListener('click', async () => {
  const { createModal } = await import('./components/modal.js');
  const modal = createModal({ title: '안내', content: '...' });
  document.body.appendChild(modal);
});
```

## 9. 보안

### ⚠️ innerHTML 사용 규칙

이 가이드의 코드 예시에서 `innerHTML`이 사용된 곳이 있다. 실제 프로젝트에서는 아래 규칙을 반드시 따른다:

```
❌ element.innerHTML = userInput;           // 사용자 입력 직접 할당 금지
❌ element.innerHTML = `<p>${variable}</p>`; // 외부 데이터가 포함된 템플릿 금지

✅ element.textContent = userInput;          // 텍스트만 삽입 (HTML 파싱 없음)
✅ element.innerHTML = '';                   // 비우기는 안전
✅ shadowRoot.innerHTML = `<style>...</style><slot></slot>`;  // 정적 템플릿은 허용
```

**innerHTML이 허용되는 경우:**
- 컨텐츠가 100% 개발자가 작성한 정적 문자열일 때
- Shadow DOM 내부의 초기 템플릿 설정일 때
- `DOMPurify.sanitize()`를 거친 HTML일 때

**innerHTML 대신 사용할 패턴:**

```javascript
// ✅ createElement + textContent 조합 (가장 안전)
function createCard(title, description) {
  const card = document.createElement('div');
  card.className = 'card';

  const h3 = document.createElement('h3');
  h3.textContent = title;  // 자동 이스케이프

  const p = document.createElement('p');
  p.textContent = description;  // 자동 이스케이프

  card.append(h3, p);
  return card;
}

// ✅ <template> 태그 활용 (HTML 구조 재사용)
// HTML: <template id="card-template"><div class="card"><h3></h3><p></p></div></template>
function createCardFromTemplate(title, description) {
  const template = document.getElementById('card-template');
  const clone = template.content.cloneNode(true);
  clone.querySelector('h3').textContent = title;
  clone.querySelector('p').textContent = description;
  return clone;
}

// ✅ DOMPurify 사용 (외부 HTML 렌더링이 반드시 필요할 때)
// npm install dompurify
import DOMPurify from 'dompurify';
element.innerHTML = DOMPurify.sanitize(untrustedHtml, {
  ALLOWED_TAGS: ['b', 'i', 'em', 'strong', 'a', 'p', 'br'],
  ALLOWED_ATTR: ['href', 'target'],
});
```

### XSS 방지 유틸리티

```javascript
// src/utils/dom.js
/**
 * 안전한 텍스트 삽입 — innerHTML 대신 사용
 */
export function setText(selector, text) {
  const el = document.querySelector(selector);
  if (el) el.textContent = text; // textContent는 HTML을 파싱하지 않음
}

/**
 * 안전한 HTML 이스케이프 — innerHTML을 써야만 할 때 필수 적용
 */
export function escapeHtml(unsafe) {
  return unsafe
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

/**
 * URL 검증 — 사용자 입력 URL 사용 전 반드시 확인
 */
export function isValidUrl(string) {
  try {
    const url = new URL(string);
    return ['http:', 'https:'].includes(url.protocol);
  } catch {
    return false;
  }
}
```

### CSP 헤더 설정

```javascript
// vite.config.js — 개발 서버 CSP
export default defineConfig({
  server: {
    headers: {
      'Content-Security-Policy': [
        "default-src 'self'",
        "script-src 'self'",
        "style-src 'self' 'nonce-{RANDOM}'",  // unsafe-inline 대신 nonce 사용 권장
        "img-src 'self' data: https:",
        "font-src 'self'",
        "connect-src 'self' https://api.example.com",
      ].join('; '),
    },
  },
});
```

### 환경변수 보호

```bash
# .env (gitignore에 추가)
VITE_API_URL=https://api.example.com

# 주의: VITE_ 접두사가 붙은 변수만 클라이언트에 노출됨
# 비밀키는 절대 VITE_ 접두사를 붙이지 말 것
# SECRET_KEY=do-not-expose  ← 클라이언트에서 접근 불가 (안전)
```

## 10. 전체 예제: 메인 진입점

```javascript
// src/main.js
import './styles/reset.css';
import './styles/variables.css';
import './styles/global.css';
import './styles/components/header.css';
import './styles/components/hero.css';
import './styles/components/contact-form.css';

import { initApp } from './app.js';

// DOM 준비 후 앱 초기화
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initApp);
} else {
  initApp();
}
```

```javascript
// src/app.js
import { createHero } from './components/hero.js';
import './components/contact-form.js'; // Web Component 등록
import { createState } from './utils/state.js';

export function initApp() {
  const app = document.querySelector('#app');
  const state = createState({ submitted: false });

  // 헤더
  app.innerHTML = `
    <header class="header">
      <a href="#/" class="header__logo">MyApp</a>
      <nav class="header__nav">
        <a href="#/">홈</a>
        <a href="#/about">소개</a>
      </nav>
    </header>
    <main id="content"></main>
  `;

  // 히어로 섹션
  const content = app.querySelector('#content');
  const hero = createHero({
    title: '환영합니다',
    subtitle: '간단하고 빠른 Vanilla JS 프로젝트입니다.',
    ctaText: '시작하기',
    onCtaClick: () => {
      document.querySelector('contact-form')?.scrollIntoView({
        behavior: 'smooth',
      });
    },
  });
  content.appendChild(hero);

  // 연락처 폼
  const form = document.createElement('contact-form');
  content.appendChild(form);

  form.addEventListener('form-submit', (e) => {
    console.log('폼 데이터:', e.detail);
    state.setState({ submitted: true });
  });
}
```
