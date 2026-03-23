# 프론트엔드 스킬 가이드

## 개요

이 디렉토리는 프론트엔드 프로젝트의 규모와 기술 스택에 따른 베스트 프랙티스 가이드를 제공합니다.

## 공통 매칭 조건

프로젝트에 적합한 가이드를 선택하기 위한 기준입니다.

### 기술 스택 선택 기준

| 스택 | 적합한 경우 |
|------|------------|
| **Vanilla JS** | 프레임워크 의존성 최소화, 웹 표준 중심, 경량 프로젝트, 라이브러리/위젯 개발 |
| **React** | 대규모 커뮤니티 활용, 풍부한 생태계 필요, SPA/CSR 중심, 유연한 아키텍처 |
| **Vue** | 점진적 도입 필요, 학습 곡선 최소화, 양방향 바인딩 선호, 중소규모 팀 |
| **Next.js** | SSR/SSG 필요, SEO 중요, 풀스택 기능 필요, React 기반 프로덕션 앱 |

### 규모 판단 기준

| 항목 | Small | Medium | Large |
|------|-------|--------|-------|
| **페이지 수** | 1~5 | 5~20 | 20+ |
| **개발자 수** | 1~2명 | 3~8명 | 8명+ |
| **개발 기간** | 1~4주 | 1~6개월 | 6개월+ |
| **상태 복잡도** | 로컬 상태 위주 | 공유 상태 존재 | 복잡한 전역 상태 |
| **API 연동** | 단순 REST | REST + 캐싱 | 다중 API + 실시간 |
| **빌드/배포** | 단순 빌드 | CI/CD 파이프라인 | 모노레포/마이크로 프론트엔드 |

## 규모별 아키텍처 분류

### Small (소규모)

- **목적**: 랜딩 페이지, 프로토타입, 소규모 도구, 개인 프로젝트
- **특징**: 플랫 구조, 최소 의존성, 빠른 개발
- **핵심 원칙**: YAGNI (You Aren't Gonna Need It) — 불필요한 추상화 회피

```
project/
├── src/
│   ├── components/     # 모든 컴포넌트를 한 곳에
│   ├── utils/          # 유틸리티 함수
│   ├── styles/         # 스타일시트
│   └── main.js         # 진입점
├── public/
└── package.json
```

### Medium (중규모)

- **목적**: 관리자 대시보드, B2B SaaS, 중규모 서비스
- **특징**: 기능(feature) 기반 폴더 구조, 상태 관리 라이브러리 도입, 라우팅 체계화
- **핵심 원칙**: 관심사 분리 + 기능 단위 모듈화

```
project/
├── src/
│   ├── features/       # 기능별 모듈
│   │   ├── auth/
│   │   ├── dashboard/
│   │   └── settings/
│   ├── shared/         # 공유 컴포넌트/유틸
│   ├── hooks/          # 공유 훅
│   ├── services/       # API 서비스
│   └── main.js
├── tests/
└── package.json
```

### Large (대규모)

- **목적**: 대규모 플랫폼, 엔터프라이즈 앱, 마이크로 프론트엔드
- **특징**: 독립 배포 가능한 모듈, 엄격한 의존성 규칙, 고급 캐싱/성능 최적화
- **핵심 원칙**: 독립성 + 점진적 확장 + 팀 자율성

```
monorepo/
├── apps/
│   ├── main-app/
│   ├── admin-app/
│   └── shared-app/
├── packages/
│   ├── ui/             # 공유 UI 라이브러리
│   ├── utils/          # 공유 유틸리티
│   └── config/         # 공유 설정
├── turbo.json
└── package.json
```

## 공통 체크 항목

모든 프로젝트 규모에서 반드시 확인해야 할 항목들입니다.

### 1. 코드 품질

- [ ] ESLint + Prettier 설정 완료
- [ ] TypeScript 사용 (strict 모드 권장)
- [ ] 일관된 네이밍 컨벤션 적용
- [ ] 코드 리뷰 프로세스 수립 (Medium 이상)

### 2. 접근성 (a11y)

- [ ] 시맨틱 HTML 사용
- [ ] ARIA 속성 적절히 사용
- [ ] 키보드 네비게이션 지원
- [ ] 색상 대비 비율 준수 (WCAG 2.1 AA)
- [ ] 스크린 리더 테스트

### 3. 성능

- [ ] Core Web Vitals 목표 설정 (LCP < 2.5s, FID < 100ms, CLS < 0.1)
- [ ] 이미지 최적화 (WebP/AVIF, lazy loading, srcset)
- [ ] 코드 스플리팅 적용
- [ ] 번들 크기 모니터링
- [ ] 캐싱 전략 수립

### 4. 보안

- [ ] XSS 방지: 사용자 입력 이스케이프, `innerHTML` 사용 금지
- [ ] CSP (Content Security Policy) 헤더 설정
- [ ] HTTPS 강제 적용
- [ ] 민감 데이터 클라이언트 노출 방지
- [ ] 의존성 취약점 정기 검사 (`npm audit`)
- [ ] CSRF 토큰 적용 (폼 제출 시)

### 5. 테스트

- [ ] 단위 테스트: 유틸리티 함수, 비즈니스 로직
- [ ] 통합 테스트: 컴포넌트 상호작용
- [ ] E2E 테스트: 핵심 사용자 플로우 (Medium 이상)
- [ ] 시각적 회귀 테스트 (Large)

### 6. 빌드 및 배포

- [ ] 환경변수 관리 (`.env` 파일 분리)
- [ ] 빌드 최적화 (tree-shaking, minification)
- [ ] 소스맵 설정 (프로덕션에서 비활성화 또는 별도 관리)
- [ ] CI/CD 파이프라인 구축 (Medium 이상)

### 7. 모니터링

- [ ] 에러 트래킹 (Sentry 등)
- [ ] 성능 모니터링 (Lighthouse CI, Web Vitals 리포트)
- [ ] 사용자 행동 분석 (선택)

## 파일 구조

```
skills/frontend/
├── README.md              # 이 파일
├── vanilla/
│   ├── small.md           # Vanilla JS 소규모
│   ├── medium.md          # Vanilla JS 중규모
│   └── large.md           # Vanilla JS 대규모
├── react/
│   ├── small.md           # React 소규모
│   ├── medium.md          # React 중규모
│   └── large.md           # React 대규모
├── vue/
│   ├── small.md           # Vue 소규모
│   ├── medium.md          # Vue 중규모
│   └── large.md           # Vue 대규모
└── nextjs/
    ├── small.md           # Next.js 소규모
    ├── medium.md          # Next.js 중규모
    └── large.md           # Next.js 대규모
```
