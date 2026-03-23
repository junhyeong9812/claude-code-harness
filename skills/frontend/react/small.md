# React — 소규모 프로젝트 가이드

## 개요

- **도구**: Vite + React 18+
- **구조**: 단순 컴포넌트 구조
- **상태 관리**: useState / useEffect
- **적합한 프로젝트**: 랜딩 페이지, 프로토타입, 소규모 웹앱

---

## 1. 프로젝트 구조

```
my-react-app/
├── public/
│   └── favicon.ico
├── src/
│   ├── components/
│   │   ├── Header.jsx
│   │   ├── Hero.jsx
│   │   ├── ContactForm.jsx
│   │   ├── Footer.jsx
│   │   └── ui/
│   │       ├── Button.jsx
│   │       ├── Input.jsx
│   │       └── Spinner.jsx
│   ├── hooks/
│   │   ├── useForm.js
│   │   └── useLocalStorage.js
│   ├── utils/
│   │   ├── api.js
│   │   └── validation.js
│   ├── styles/
│   │   ├── global.css
│   │   └── variables.css
│   ├── App.jsx
│   └── main.jsx
├── index.html
├── vite.config.js
├── package.json
├── .eslintrc.cjs
└── jsconfig.json
```

## 2. 상태 관리

소규모 프로젝트에서는 React 내장 훅으로 충분합니다.

```jsx
// src/components/ContactForm.jsx
import { useState } from 'react';
import { Button } from './ui/Button';
import { Input } from './ui/Input';
import { validateEmail } from '../utils/validation';

export function ContactForm({ onSubmit }) {
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    message: '',
  });
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    // 입력 시 해당 필드 에러 초기화
    if (errors[name]) {
      setErrors((prev) => ({ ...prev, [name]: '' }));
    }
  };

  const validate = () => {
    const newErrors = {};
    if (!formData.name.trim()) newErrors.name = '이름을 입력해주세요.';
    if (!validateEmail(formData.email)) newErrors.email = '올바른 이메일을 입력해주세요.';
    if (!formData.message.trim()) newErrors.message = '메시지를 입력해주세요.';
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;

    setSubmitting(true);
    try {
      await onSubmit(formData);
      setSubmitted(true);
      setFormData({ name: '', email: '', message: '' });
    } catch {
      setErrors({ form: '전송에 실패했습니다. 다시 시도해주세요.' });
    } finally {
      setSubmitting(false);
    }
  };

  if (submitted) {
    return (
      <div className="success-message">
        <h3>감사합니다!</h3>
        <p>메시지가 성공적으로 전송되었습니다.</p>
        <Button onClick={() => setSubmitted(false)}>다시 보내기</Button>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} className="contact-form" noValidate>
      <Input
        label="이름"
        name="name"
        value={formData.name}
        onChange={handleChange}
        error={errors.name}
        required
      />
      <Input
        label="이메일"
        name="email"
        type="email"
        value={formData.email}
        onChange={handleChange}
        error={errors.email}
        required
      />
      <Input
        label="메시지"
        name="message"
        as="textarea"
        rows={4}
        value={formData.message}
        onChange={handleChange}
        error={errors.message}
        required
      />
      {errors.form && <p className="error-text">{errors.form}</p>}
      <Button type="submit" disabled={submitting}>
        {submitting ? '전송 중...' : '보내기'}
      </Button>
    </form>
  );
}
```

### 커스텀 훅으로 로직 분리

```javascript
// src/hooks/useForm.js
import { useState, useCallback } from 'react';

/**
 * 폼 관리 커스텀 훅
 * - 값 관리, 검증, 제출 처리를 캡슐화
 */
export function useForm({ initialValues, validate, onSubmit }) {
  const [values, setValues] = useState(initialValues);
  const [errors, setErrors] = useState({});
  const [submitting, setSubmitting] = useState(false);

  const handleChange = useCallback((e) => {
    const { name, value, type, checked } = e.target;
    setValues((prev) => ({
      ...prev,
      [name]: type === 'checkbox' ? checked : value,
    }));
  }, []);

  const handleSubmit = useCallback(async (e) => {
    e.preventDefault();
    const validationErrors = validate?.(values) || {};
    setErrors(validationErrors);

    if (Object.keys(validationErrors).length > 0) return;

    setSubmitting(true);
    try {
      await onSubmit(values);
    } catch (error) {
      setErrors({ _form: error.message });
    } finally {
      setSubmitting(false);
    }
  }, [values, validate, onSubmit]);

  const reset = useCallback(() => {
    setValues(initialValues);
    setErrors({});
  }, [initialValues]);

  return { values, errors, submitting, handleChange, handleSubmit, reset, setValues };
}
```

```javascript
// src/hooks/useLocalStorage.js
import { useState, useEffect } from 'react';

export function useLocalStorage(key, initialValue) {
  const [value, setValue] = useState(() => {
    try {
      const stored = localStorage.getItem(key);
      return stored ? JSON.parse(stored) : initialValue;
    } catch {
      return initialValue;
    }
  });

  useEffect(() => {
    try {
      localStorage.setItem(key, JSON.stringify(value));
    } catch {
      // 저장 실패 무시 (private 모드 등)
    }
  }, [key, value]);

  return [value, setValue];
}
```

## 3. 라우팅

소규모 프로젝트에서는 React Router의 간단한 설정으로 충분합니다.

```jsx
// src/App.jsx
import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { Header } from './components/Header';
import { Footer } from './components/Footer';
import { Home } from './pages/Home';
import { About } from './pages/About';
import { NotFound } from './pages/NotFound';

export default function App() {
  return (
    <BrowserRouter>
      <div className="app">
        <Header />
        <main>
          <Routes>
            <Route path="/" element={<Home />} />
            <Route path="/about" element={<About />} />
            <Route path="*" element={<NotFound />} />
          </Routes>
        </main>
        <Footer />
      </div>
    </BrowserRouter>
  );
}
```

## 4. 스타일링

```css
/* src/styles/variables.css */
:root {
  --color-primary: #2563eb;
  --color-primary-hover: #1d4ed8;
  --color-bg: #ffffff;
  --color-bg-secondary: #f8fafc;
  --color-text: #1e293b;
  --color-text-muted: #64748b;
  --color-border: #e2e8f0;
  --color-error: #dc2626;
  --color-success: #16a34a;

  --font-sans: 'Pretendard', -apple-system, system-ui, sans-serif;
  --radius-md: 0.5rem;
  --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
  --transition-fast: 150ms ease;
}

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

```jsx
// src/components/ui/Button.jsx
/**
 * 재사용 가능한 버튼 컴포넌트
 */
export function Button({
  children,
  variant = 'primary',
  size = 'md',
  disabled = false,
  type = 'button',
  onClick,
  className = '',
  ...props
}) {
  return (
    <button
      type={type}
      disabled={disabled}
      onClick={onClick}
      className={`btn btn--${variant} btn--${size} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
}
```

```jsx
// src/components/ui/Input.jsx
export function Input({
  label,
  name,
  error,
  as: Component = 'input',
  className = '',
  ...props
}) {
  const id = `field-${name}`;
  return (
    <div className={`form-group ${error ? 'form-group--error' : ''} ${className}`}>
      {label && <label htmlFor={id}>{label}</label>}
      <Component
        id={id}
        name={name}
        className="form-control"
        aria-invalid={!!error}
        aria-describedby={error ? `${id}-error` : undefined}
        {...props}
      />
      {error && (
        <p id={`${id}-error`} className="error-text" role="alert">
          {error}
        </p>
      )}
    </div>
  );
}
```

## 5. 컴포넌트 설계 패턴

### 합성(Composition) 패턴

```jsx
// src/components/Hero.jsx
export function Hero({ children }) {
  return <section className="hero">{children}</section>;
}

Hero.Title = function HeroTitle({ children }) {
  return <h1 className="hero__title">{children}</h1>;
};

Hero.Subtitle = function HeroSubtitle({ children }) {
  return <p className="hero__subtitle">{children}</p>;
};

Hero.Actions = function HeroActions({ children }) {
  return <div className="hero__actions">{children}</div>;
};

// 사용
<Hero>
  <Hero.Title>환영합니다</Hero.Title>
  <Hero.Subtitle>React로 만든 간단한 프로젝트</Hero.Subtitle>
  <Hero.Actions>
    <Button>시작하기</Button>
  </Hero.Actions>
</Hero>
```

### 조건부 렌더링 헬퍼

```jsx
// src/components/ui/Spinner.jsx
export function Spinner({ size = 24 }) {
  return (
    <svg
      className="spinner"
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      aria-label="로딩 중"
    >
      <circle
        cx="12" cy="12" r="10"
        stroke="currentColor"
        strokeWidth="3"
        strokeLinecap="round"
        strokeDasharray="60"
        strokeDashoffset="20"
      />
    </svg>
  );
}

// 로딩 래퍼
export function LoadingWrapper({ loading, children, fallback }) {
  if (loading) return fallback || <Spinner />;
  return children;
}
```

## 6. 데이터 페칭

```javascript
// src/utils/api.js
const BASE_URL = import.meta.env.VITE_API_URL || '/api';

async function request(endpoint, options = {}) {
  const response = await fetch(`${BASE_URL}${endpoint}`, {
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
    ...options,
  });

  if (!response.ok) {
    const error = new Error('API 요청 실패');
    error.status = response.status;
    try {
      error.data = await response.json();
    } catch {}
    throw error;
  }

  return response.json();
}

export const api = {
  get: (endpoint) => request(endpoint),
  post: (endpoint, data) => request(endpoint, {
    method: 'POST',
    body: JSON.stringify(data),
  }),
};
```

```jsx
// 데이터 페칭 커스텀 훅
// src/hooks/useFetch.js
import { useState, useEffect } from 'react';
import { api } from '../utils/api';

export function useFetch(endpoint) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;

    async function fetchData() {
      try {
        setLoading(true);
        const result = await api.get(endpoint);
        if (!cancelled) setData(result);
      } catch (err) {
        if (!cancelled) setError(err);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    fetchData();

    return () => { cancelled = true; };
  }, [endpoint]);

  return { data, loading, error };
}

// 사용 예시
function UserProfile({ userId }) {
  const { data: user, loading, error } = useFetch(`/users/${userId}`);

  if (loading) return <Spinner />;
  if (error) return <p>사용자 정보를 불러올 수 없습니다.</p>;

  return (
    <div>
      <h2>{user.name}</h2>
      <p>{user.email}</p>
    </div>
  );
}
```

## 7. 테스트 전략

```jsx
// src/components/__tests__/ContactForm.test.jsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { ContactForm } from '../ContactForm';

describe('ContactForm', () => {
  it('모든 필드를 렌더링한다', () => {
    render(<ContactForm onSubmit={vi.fn()} />);

    expect(screen.getByLabelText('이름')).toBeInTheDocument();
    expect(screen.getByLabelText('이메일')).toBeInTheDocument();
    expect(screen.getByLabelText('메시지')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: '보내기' })).toBeInTheDocument();
  });

  it('빈 폼 제출 시 에러를 표시한다', async () => {
    const user = userEvent.setup();
    render(<ContactForm onSubmit={vi.fn()} />);

    await user.click(screen.getByRole('button', { name: '보내기' }));

    expect(screen.getByText('이름을 입력해주세요.')).toBeInTheDocument();
    expect(screen.getByText('올바른 이메일을 입력해주세요.')).toBeInTheDocument();
  });

  it('유효한 데이터로 제출한다', async () => {
    const user = userEvent.setup();
    const handleSubmit = vi.fn().mockResolvedValue(undefined);
    render(<ContactForm onSubmit={handleSubmit} />);

    await user.type(screen.getByLabelText('이름'), '홍길동');
    await user.type(screen.getByLabelText('이메일'), 'hong@example.com');
    await user.type(screen.getByLabelText('메시지'), '안녕하세요');
    await user.click(screen.getByRole('button', { name: '보내기' }));

    await waitFor(() => {
      expect(handleSubmit).toHaveBeenCalledWith({
        name: '홍길동',
        email: 'hong@example.com',
        message: '안녕하세요',
      });
    });
  });

  it('제출 성공 후 성공 메시지를 표시한다', async () => {
    const user = userEvent.setup();
    const handleSubmit = vi.fn().mockResolvedValue(undefined);
    render(<ContactForm onSubmit={handleSubmit} />);

    await user.type(screen.getByLabelText('이름'), '홍길동');
    await user.type(screen.getByLabelText('이메일'), 'hong@example.com');
    await user.type(screen.getByLabelText('메시지'), '안녕하세요');
    await user.click(screen.getByRole('button', { name: '보내기' }));

    await waitFor(() => {
      expect(screen.getByText('감사합니다!')).toBeInTheDocument();
    });
  });
});
```

```javascript
// vite.config.js
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    setupFiles: './src/test-setup.js',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
    },
  },
});
```

```javascript
// src/test-setup.js
import '@testing-library/jest-dom';
```

## 8. 성능 최적화

### React.lazy를 활용한 코드 스플리팅

```jsx
import { lazy, Suspense } from 'react';
import { Spinner } from './components/ui/Spinner';

// 페이지 단위 지연 로딩
const About = lazy(() => import('./pages/About'));

function App() {
  return (
    <Suspense fallback={<Spinner />}>
      <Routes>
        <Route path="/" element={<Home />} />
        <Route path="/about" element={<About />} />
      </Routes>
    </Suspense>
  );
}
```

### 이미지 최적화

```jsx
// src/components/OptimizedImage.jsx
export function OptimizedImage({ src, alt, width, height, ...props }) {
  return (
    <img
      src={src}
      alt={alt}
      width={width}
      height={height}
      loading="lazy"
      decoding="async"
      {...props}
    />
  );
}
```

### useCallback / useMemo 적절한 활용

```jsx
import { useState, useMemo, useCallback } from 'react';

function FilteredList({ items }) {
  const [filter, setFilter] = useState('');

  // 필터링 결과 메모이제이션 (items나 filter 변경 시만 재계산)
  const filteredItems = useMemo(
    () => items.filter((item) => item.name.includes(filter)),
    [items, filter]
  );

  // 이벤트 핸들러 안정화 (자식 리렌더링 방지)
  const handleFilterChange = useCallback((e) => {
    setFilter(e.target.value);
  }, []);

  return (
    <div>
      <input value={filter} onChange={handleFilterChange} placeholder="검색..." />
      <ul>
        {filteredItems.map((item) => (
          <li key={item.id}>{item.name}</li>
        ))}
      </ul>
    </div>
  );
}
```

## 9. 보안

### XSS 방지

```jsx
// React는 기본적으로 JSX 내 값을 이스케이프합니다.
// 아래는 안전합니다:
<p>{userInput}</p>

// 위험: dangerouslySetInnerHTML 사용 시 반드시 새니타이즈
import DOMPurify from 'dompurify';

function SafeHtml({ html }) {
  return (
    <div
      dangerouslySetInnerHTML={{
        __html: DOMPurify.sanitize(html),
      }}
    />
  );
}

// 위험: href에 사용자 입력 직접 사용
function SafeLink({ url, children }) {
  const isValid = /^https?:\/\//i.test(url);
  return isValid ? <a href={url}>{children}</a> : <span>{children}</span>;
}
```

### 환경변수

```bash
# .env
VITE_API_URL=https://api.example.com
# 주의: VITE_ 접두사만 클라이언트에 노출
# SECRET_KEY=비밀   ← 클라이언트 접근 불가 (안전)
```

### CSP 설정

```html
<!-- index.html -->
<meta http-equiv="Content-Security-Policy" content="
  default-src 'self';
  script-src 'self';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https:;
  connect-src 'self' https://api.example.com;
"/>
```

## 10. 전체 진입점 예시

```jsx
// src/main.jsx
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './styles/variables.css';
import './styles/global.css';

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
```
