# Next.js — 소규모 프로젝트 가이드

## 개요

- **라우팅**: App Router
- **렌더링**: Server Components 기본
- **구조**: 단순 페이지 구조
- **적합한 프로젝트**: 랜딩 페이지, 블로그, 포트폴리오, 소규모 마케팅 사이트

---

## 1. 프로젝트 구조

```
my-nextjs-app/
├── app/
│   ├── layout.jsx              # 루트 레이아웃
│   ├── page.jsx                # 홈 페이지
│   ├── globals.css
│   ├── about/
│   │   └── page.jsx
│   ├── contact/
│   │   └── page.jsx
│   ├── blog/
│   │   ├── page.jsx            # 블로그 목록
│   │   └── [slug]/
│   │       └── page.jsx        # 블로그 상세
│   ├── not-found.jsx           # 404 페이지
│   └── error.jsx               # 에러 페이지
├── components/
│   ├── Header.jsx
│   ├── Footer.jsx
│   ├── Hero.jsx
│   ├── ContactForm.jsx         # 클라이언트 컴포넌트
│   └── ui/
│       ├── Button.jsx
│       └── Input.jsx
├── lib/
│   ├── api.js                  # API 유틸리티
│   └── utils.js
├── public/
│   ├── images/
│   └── favicon.ico
├── next.config.js
├── package.json
├── jsconfig.json
└── .env.local
```

## 2. 상태 관리

Server Components에서는 상태가 불필요합니다. 클라이언트 컴포넌트에서만 useState를 사용합니다.

```jsx
// components/ContactForm.jsx
'use client';

import { useState } from 'react';
import { Button } from './ui/Button';
import { Input } from './ui/Input';

export function ContactForm() {
  const [formData, setFormData] = useState({
    name: '',
    email: '',
    message: '',
  });
  const [status, setStatus] = useState('idle'); // idle | submitting | success | error
  const [errors, setErrors] = useState({});

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
    if (errors[name]) setErrors((prev) => ({ ...prev, [name]: '' }));
  };

  const validate = () => {
    const newErrors = {};
    if (!formData.name.trim()) newErrors.name = '이름을 입력해주세요.';
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(formData.email))
      newErrors.email = '올바른 이메일을 입력해주세요.';
    if (!formData.message.trim()) newErrors.message = '메시지를 입력해주세요.';
    setErrors(newErrors);
    return Object.keys(newErrors).length === 0;
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    if (!validate()) return;

    setStatus('submitting');
    try {
      const res = await fetch('/api/contact', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(formData),
      });
      if (!res.ok) throw new Error('전송 실패');
      setStatus('success');
      setFormData({ name: '', email: '', message: '' });
    } catch {
      setStatus('error');
    }
  };

  if (status === 'success') {
    return (
      <div className="text-center py-8">
        <h3 className="text-xl font-bold">감사합니다!</h3>
        <p className="text-gray-600 mt-2">메시지가 전송되었습니다.</p>
        <Button onClick={() => setStatus('idle')} className="mt-4">
          다시 보내기
        </Button>
      </div>
    );
  }

  return (
    <form onSubmit={handleSubmit} noValidate className="space-y-4 max-w-md mx-auto">
      <Input
        label="이름"
        name="name"
        value={formData.name}
        onChange={handleChange}
        error={errors.name}
      />
      <Input
        label="이메일"
        name="email"
        type="email"
        value={formData.email}
        onChange={handleChange}
        error={errors.email}
      />
      <Input
        label="메시지"
        name="message"
        as="textarea"
        rows={4}
        value={formData.message}
        onChange={handleChange}
        error={errors.message}
      />
      {status === 'error' && (
        <p className="text-red-600 text-sm">전송에 실패했습니다. 다시 시도해주세요.</p>
      )}
      <Button type="submit" disabled={status === 'submitting'}>
        {status === 'submitting' ? '전송 중...' : '보내기'}
      </Button>
    </form>
  );
}
```

### Server Component에서 데이터 직접 조회

```jsx
// app/blog/page.jsx — 서버 컴포넌트 (기본)
import Link from 'next/link';
import { getAllPosts } from '@/lib/api';

// 메타데이터
export const metadata = {
  title: '블로그',
  description: '최신 블로그 글 목록',
};

export default async function BlogPage() {
  // 서버에서 직접 데이터 조회 — useState 불필요
  const posts = await getAllPosts();

  return (
    <section className="py-12">
      <h1 className="text-3xl font-bold mb-8">블로그</h1>
      <div className="grid gap-6 md:grid-cols-2">
        {posts.map((post) => (
          <article key={post.slug} className="border rounded-lg p-6 hover:shadow-md transition-shadow">
            <time className="text-sm text-gray-500">
              {new Date(post.date).toLocaleDateString('ko-KR')}
            </time>
            <h2 className="text-xl font-semibold mt-2">
              <Link href={`/blog/${post.slug}`} className="hover:text-blue-600">
                {post.title}
              </Link>
            </h2>
            <p className="text-gray-600 mt-2">{post.excerpt}</p>
          </article>
        ))}
      </div>
    </section>
  );
}
```

## 3. 라우팅

Next.js App Router는 파일 시스템 기반 라우팅을 사용합니다.

```
app/
├── page.jsx                → /
├── about/page.jsx          → /about
├── contact/page.jsx        → /contact
├── blog/
│   ├── page.jsx            → /blog
│   └── [slug]/
│       └── page.jsx        → /blog/:slug
└── not-found.jsx           → 404
```

### 동적 라우트

```jsx
// app/blog/[slug]/page.jsx
import { notFound } from 'next/navigation';
import { getPostBySlug, getAllPosts } from '@/lib/api';

// 정적 생성할 경로 미리 지정 (SSG)
export async function generateStaticParams() {
  const posts = await getAllPosts();
  return posts.map((post) => ({ slug: post.slug }));
}

// 동적 메타데이터
export async function generateMetadata({ params }) {
  const post = await getPostBySlug(params.slug);
  if (!post) return { title: '글을 찾을 수 없습니다' };
  return {
    title: post.title,
    description: post.excerpt,
    openGraph: {
      title: post.title,
      description: post.excerpt,
      images: post.coverImage ? [{ url: post.coverImage }] : [],
    },
  };
}

export default async function BlogPostPage({ params }) {
  const post = await getPostBySlug(params.slug);

  if (!post) notFound();

  return (
    <article className="max-w-2xl mx-auto py-12">
      <time className="text-sm text-gray-500">
        {new Date(post.date).toLocaleDateString('ko-KR')}
      </time>
      <h1 className="text-4xl font-bold mt-2">{post.title}</h1>
      <div
        className="prose prose-lg mt-8"
        dangerouslySetInnerHTML={{ __html: post.content }}
      />
    </article>
  );
}
```

## 4. 스타일링

Tailwind CSS 또는 CSS Modules를 사용합니다.

```jsx
// components/ui/Button.jsx
export function Button({
  children,
  variant = 'primary',
  size = 'md',
  className = '',
  ...props
}) {
  const baseStyles = 'inline-flex items-center justify-center font-medium rounded-lg transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed';

  const variants = {
    primary: 'bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500',
    secondary: 'bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 focus:ring-gray-500',
    danger: 'bg-red-600 text-white hover:bg-red-700 focus:ring-red-500',
  };

  const sizes = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-sm',
    lg: 'px-6 py-3 text-base',
  };

  return (
    <button
      className={`${baseStyles} ${variants[variant]} ${sizes[size]} ${className}`}
      {...props}
    >
      {children}
    </button>
  );
}
```

```jsx
// components/ui/Input.jsx
export function Input({
  label,
  name,
  error,
  as: Component = 'input',
  className = '',
  ...props
}) {
  return (
    <div className={className}>
      {label && (
        <label htmlFor={name} className="block text-sm font-medium text-gray-700 mb-1">
          {label}
        </label>
      )}
      <Component
        id={name}
        name={name}
        className={`w-full px-3 py-2 border rounded-lg text-sm transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 ${
          error ? 'border-red-500' : 'border-gray-300'
        }`}
        aria-invalid={!!error}
        {...props}
      />
      {error && <p className="text-red-600 text-xs mt-1">{error}</p>}
    </div>
  );
}
```

## 5. 컴포넌트 설계 패턴

### Server vs Client 컴포넌트 분리

```jsx
// components/Header.jsx — 서버 컴포넌트 (기본)
import Link from 'next/link';
import { MobileMenu } from './MobileMenu'; // 클라이언트 컴포넌트

const navItems = [
  { href: '/', label: '홈' },
  { href: '/about', label: '소개' },
  { href: '/blog', label: '블로그' },
  { href: '/contact', label: '연락처' },
];

export function Header() {
  return (
    <header className="border-b">
      <nav className="max-w-5xl mx-auto px-4 py-4 flex items-center justify-between">
        <Link href="/" className="text-xl font-bold text-blue-600">
          MyApp
        </Link>
        {/* 데스크톱 네비게이션 — 서버 렌더링 */}
        <ul className="hidden md:flex gap-6">
          {navItems.map((item) => (
            <li key={item.href}>
              <Link href={item.href} className="text-gray-600 hover:text-gray-900">
                {item.label}
              </Link>
            </li>
          ))}
        </ul>
        {/* 모바일 메뉴 — 클라이언트 컴포넌트 (인터랙션 필요) */}
        <MobileMenu items={navItems} />
      </nav>
    </header>
  );
}
```

```jsx
// components/MobileMenu.jsx
'use client';

import { useState } from 'react';
import Link from 'next/link';

export function MobileMenu({ items }) {
  const [open, setOpen] = useState(false);

  return (
    <div className="md:hidden">
      <button
        onClick={() => setOpen(!open)}
        className="p-2"
        aria-label="메뉴 열기"
      >
        <svg className="w-6 h-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path strokeLinecap="round" strokeWidth={2} d={open ? 'M6 18L18 6M6 6l12 12' : 'M4 6h16M4 12h16M4 18h16'} />
        </svg>
      </button>
      {open && (
        <ul className="absolute top-16 left-0 right-0 bg-white border-b shadow-lg p-4 space-y-2">
          {items.map((item) => (
            <li key={item.href}>
              <Link
                href={item.href}
                onClick={() => setOpen(false)}
                className="block py-2 text-gray-600"
              >
                {item.label}
              </Link>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
```

## 6. 데이터 페칭

### API Route Handler

```javascript
// app/api/contact/route.js
import { NextResponse } from 'next/server';

export async function POST(request) {
  try {
    const body = await request.json();

    // 서버사이드 검증
    if (!body.name || !body.email || !body.message) {
      return NextResponse.json(
        { error: '모든 필드를 입력해주세요.' },
        { status: 400 }
      );
    }

    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(body.email)) {
      return NextResponse.json(
        { error: '올바른 이메일을 입력해주세요.' },
        { status: 400 }
      );
    }

    // 이메일 발송 등 외부 서비스 호출
    // await sendEmail(body);

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Contact form error:', error);
    return NextResponse.json(
      { error: '서버 오류가 발생했습니다.' },
      { status: 500 }
    );
  }
}
```

### 서버 컴포넌트에서 데이터 페칭

```javascript
// lib/api.js
const API_URL = process.env.API_URL || 'https://api.example.com';

/**
 * 서버사이드 API 호출 (서버 컴포넌트에서 사용)
 * - Next.js fetch 확장 기능: 캐싱, 재검증
 */
export async function getAllPosts() {
  const res = await fetch(`${API_URL}/posts`, {
    next: { revalidate: 3600 }, // 1시간마다 재검증 (ISR)
  });

  if (!res.ok) throw new Error('게시글을 가져올 수 없습니다.');
  return res.json();
}

export async function getPostBySlug(slug) {
  const res = await fetch(`${API_URL}/posts/${slug}`, {
    next: { revalidate: 3600 },
  });

  if (res.status === 404) return null;
  if (!res.ok) throw new Error('게시글을 가져올 수 없습니다.');
  return res.json();
}
```

## 7. 테스트 전략

```jsx
// __tests__/components/ContactForm.test.jsx
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, it, expect, vi } from 'vitest';
import { ContactForm } from '@/components/ContactForm';

// fetch 모킹
global.fetch = vi.fn();

describe('ContactForm', () => {
  it('필드를 렌더링한다', () => {
    render(<ContactForm />);
    expect(screen.getByLabelText('이름')).toBeInTheDocument();
    expect(screen.getByLabelText('이메일')).toBeInTheDocument();
    expect(screen.getByLabelText('메시지')).toBeInTheDocument();
  });

  it('빈 폼 제출 시 에러를 표시한다', async () => {
    const user = userEvent.setup();
    render(<ContactForm />);

    await user.click(screen.getByRole('button', { name: '보내기' }));

    expect(screen.getByText('이름을 입력해주세요.')).toBeInTheDocument();
  });

  it('성공적으로 제출한다', async () => {
    fetch.mockResolvedValueOnce({ ok: true, json: () => ({ success: true }) });
    const user = userEvent.setup();
    render(<ContactForm />);

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

## 8. 성능 최적화

### Next.js Image 최적화

```jsx
import Image from 'next/image';

// 자동 WebP/AVIF 변환, 리사이즈, lazy loading
<Image
  src="/images/hero.jpg"
  alt="히어로 이미지"
  width={1200}
  height={600}
  priority  // LCP 이미지는 priority 설정
  className="rounded-lg"
/>

// 반응형 이미지
<Image
  src="/images/photo.jpg"
  alt="사진"
  fill
  sizes="(max-width: 768px) 100vw, 50vw"
  className="object-cover"
/>
```

### 폰트 최적화

```jsx
// app/layout.jsx
import { Noto_Sans_KR } from 'next/font/google';

const notoSansKr = Noto_Sans_KR({
  subsets: ['latin'],
  weight: ['400', '500', '700'],
  display: 'swap',
  variable: '--font-noto',
});

export default function RootLayout({ children }) {
  return (
    <html lang="ko" className={notoSansKr.variable}>
      <body className="font-sans">{children}</body>
    </html>
  );
}
```

### 메타데이터 (SEO)

```jsx
// app/layout.jsx
export const metadata = {
  title: {
    default: 'MyApp',
    template: '%s | MyApp',
  },
  description: '내 프로젝트 설명',
  metadataBase: new URL('https://example.com'),
  openGraph: {
    title: 'MyApp',
    description: '내 프로젝트 설명',
    url: 'https://example.com',
    siteName: 'MyApp',
    locale: 'ko_KR',
    type: 'website',
  },
  robots: {
    index: true,
    follow: true,
  },
};
```

## 9. 보안

### 서버 컴포넌트 보안

```jsx
// 서버 컴포넌트에서는 민감 데이터를 안전하게 처리 가능
// (클라이언트에 전달되지 않음)

// app/dashboard/page.jsx
export default async function DashboardPage() {
  // 이 코드는 서버에서만 실행 — DB 직접 접근 가능
  const data = await db.query('SELECT * FROM stats');

  // 클라이언트에는 필요한 데이터만 전달
  return <StatsGrid data={data} />;
}
```

### 환경변수 보호

```bash
# .env.local
# 서버 전용 (클라이언트에 노출되지 않음)
DATABASE_URL=postgresql://...
API_SECRET=secret-key

# 클라이언트 노출 (NEXT_PUBLIC_ 접두사)
NEXT_PUBLIC_API_URL=https://api.example.com
```

### 보안 헤더

```javascript
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          { key: 'X-Content-Type-Options', value: 'nosniff' },
          { key: 'X-Frame-Options', value: 'DENY' },
          { key: 'X-XSS-Protection', value: '1; mode=block' },
          { key: 'Referrer-Policy', value: 'strict-origin-when-cross-origin' },
          {
            key: 'Content-Security-Policy',
            value: "default-src 'self'; script-src 'self' 'unsafe-eval' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self';",
          },
        ],
      },
    ];
  },
};

module.exports = nextConfig;
```

## 10. 루트 레이아웃

```jsx
// app/layout.jsx
import { Noto_Sans_KR } from 'next/font/google';
import { Header } from '@/components/Header';
import { Footer } from '@/components/Footer';
import './globals.css';

const font = Noto_Sans_KR({
  subsets: ['latin'],
  weight: ['400', '500', '700'],
  display: 'swap',
});

export const metadata = {
  title: { default: 'MyApp', template: '%s | MyApp' },
  description: 'Next.js로 만든 프로젝트',
};

export default function RootLayout({ children }) {
  return (
    <html lang="ko">
      <body className={font.className}>
        <Header />
        <main className="min-h-screen max-w-5xl mx-auto px-4">
          {children}
        </main>
        <Footer />
      </body>
    </html>
  );
}
```
