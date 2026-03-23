# Vue 3 — 소규모 프로젝트 가이드

## 개요

- **도구**: Vite + Vue 3
- **구조**: 단순 컴포넌트 구조
- **API**: Composition API (`<script setup>`)
- **적합한 프로젝트**: 랜딩 페이지, 프로토타입, 소규모 웹앱

---

## 1. 프로젝트 구조

```
my-vue-app/
├── public/
│   └── favicon.ico
├── src/
│   ├── components/
│   │   ├── TheHeader.vue
│   │   ├── TheFooter.vue
│   │   ├── HeroSection.vue
│   │   ├── ContactForm.vue
│   │   └── ui/
│   │       ├── BaseButton.vue
│   │       ├── BaseInput.vue
│   │       └── BaseSpinner.vue
│   ├── composables/
│   │   ├── useForm.js
│   │   └── useLocalStorage.js
│   ├── utils/
│   │   ├── api.js
│   │   └── validation.js
│   ├── assets/
│   │   └── styles/
│   │       ├── variables.css
│   │       └── global.css
│   ├── App.vue
│   └── main.js
├── index.html
├── vite.config.js
├── package.json
└── .eslintrc.cjs
```

## 2. 상태 관리

소규모 프로젝트에서는 `ref`, `reactive`, `provide/inject`로 충분합니다.

```vue
<!-- src/components/ContactForm.vue -->
<script setup>
import { ref, reactive } from 'vue';
import BaseButton from './ui/BaseButton.vue';
import BaseInput from './ui/BaseInput.vue';
import { validateEmail } from '../utils/validation';

const emit = defineEmits(['submit']);

const formData = reactive({
  name: '',
  email: '',
  message: '',
});

const errors = reactive({});
const submitting = ref(false);
const submitted = ref(false);

function validate() {
  // 에러 초기화
  Object.keys(errors).forEach((key) => delete errors[key]);

  if (!formData.name.trim()) errors.name = '이름을 입력해주세요.';
  if (!validateEmail(formData.email)) errors.email = '올바른 이메일을 입력해주세요.';
  if (!formData.message.trim()) errors.message = '메시지를 입력해주세요.';

  return Object.keys(errors).length === 0;
}

async function handleSubmit() {
  if (!validate()) return;

  submitting.value = true;
  try {
    await emit('submit', { ...formData });
    submitted.value = true;
    Object.assign(formData, { name: '', email: '', message: '' });
  } catch {
    errors.form = '전송에 실패했습니다.';
  } finally {
    submitting.value = false;
  }
}
</script>

<template>
  <div v-if="submitted" class="success-message">
    <h3>감사합니다!</h3>
    <p>메시지가 성공적으로 전송되었습니다.</p>
    <BaseButton @click="submitted = false">다시 보내기</BaseButton>
  </div>

  <form v-else @submit.prevent="handleSubmit" novalidate>
    <BaseInput
      v-model="formData.name"
      label="이름"
      name="name"
      :error="errors.name"
      required
    />
    <BaseInput
      v-model="formData.email"
      label="이메일"
      name="email"
      type="email"
      :error="errors.email"
      required
    />
    <BaseInput
      v-model="formData.message"
      label="메시지"
      name="message"
      as="textarea"
      :rows="4"
      :error="errors.message"
      required
    />
    <p v-if="errors.form" class="error-text">{{ errors.form }}</p>
    <BaseButton type="submit" :disabled="submitting">
      {{ submitting ? '전송 중...' : '보내기' }}
    </BaseButton>
  </form>
</template>

<style scoped>
.success-message {
  text-align: center;
  padding: 2rem;
}

form {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  max-width: 480px;
  margin: 0 auto;
}

.error-text {
  color: var(--color-error);
  font-size: 0.875rem;
}
</style>
```

### Composable로 로직 분리

```javascript
// src/composables/useForm.js
import { reactive, ref } from 'vue';

/**
 * 폼 관리 컴포저블
 */
export function useForm({ initialValues, validate, onSubmit }) {
  const values = reactive({ ...initialValues });
  const errors = reactive({});
  const submitting = ref(false);

  function handleChange(field, value) {
    values[field] = value;
    if (errors[field]) delete errors[field];
  }

  async function handleSubmit() {
    // 에러 초기화
    Object.keys(errors).forEach((key) => delete errors[key]);

    if (validate) {
      const validationErrors = validate(values);
      Object.assign(errors, validationErrors);
      if (Object.keys(validationErrors).length > 0) return;
    }

    submitting.value = true;
    try {
      await onSubmit({ ...values });
    } catch (error) {
      errors._form = error.message;
    } finally {
      submitting.value = false;
    }
  }

  function reset() {
    Object.assign(values, initialValues);
    Object.keys(errors).forEach((key) => delete errors[key]);
  }

  return { values, errors, submitting, handleChange, handleSubmit, reset };
}
```

```javascript
// src/composables/useLocalStorage.js
import { ref, watch } from 'vue';

export function useLocalStorage(key, defaultValue) {
  const stored = localStorage.getItem(key);
  const data = ref(stored ? JSON.parse(stored) : defaultValue);

  watch(data, (newValue) => {
    localStorage.setItem(key, JSON.stringify(newValue));
  }, { deep: true });

  return data;
}
```

## 3. 라우팅

소규모에서는 Vue Router 기본 설정으로 충분합니다.

```javascript
// src/router.js
import { createRouter, createWebHistory } from 'vue-router';
import Home from './pages/Home.vue';

const routes = [
  { path: '/', component: Home },
  { path: '/about', component: () => import('./pages/About.vue') },
  { path: '/:pathMatch(.*)*', component: () => import('./pages/NotFound.vue') },
];

export const router = createRouter({
  history: createWebHistory(),
  routes,
});
```

```vue
<!-- src/App.vue -->
<script setup>
import TheHeader from './components/TheHeader.vue';
import TheFooter from './components/TheFooter.vue';
</script>

<template>
  <div class="app">
    <TheHeader />
    <main>
      <RouterView />
    </main>
    <TheFooter />
  </div>
</template>
```

## 4. 스타일링

Vue의 `<style scoped>`와 CSS Custom Properties를 활용합니다.

```css
/* src/assets/styles/variables.css */
:root {
  --color-primary: #42b883;
  --color-primary-hover: #33a06f;
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

```vue
<!-- src/components/ui/BaseButton.vue -->
<script setup>
defineProps({
  variant: { type: String, default: 'primary' },
  size: { type: String, default: 'md' },
  disabled: { type: Boolean, default: false },
  type: { type: String, default: 'button' },
});
</script>

<template>
  <button
    :type="type"
    :disabled="disabled"
    :class="['btn', `btn--${variant}`, `btn--${size}`]"
  >
    <slot />
  </button>
</template>

<style scoped>
.btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  border: none;
  border-radius: var(--radius-md);
  font-size: 1rem;
  font-weight: 500;
  cursor: pointer;
  transition: all var(--transition-fast);
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn--primary {
  background: var(--color-primary);
  color: white;
}

.btn--primary:hover:not(:disabled) {
  background: var(--color-primary-hover);
}

.btn--secondary {
  background: transparent;
  color: var(--color-text);
  border: 1px solid var(--color-border);
}

.btn--sm { padding: 0.25rem 0.75rem; font-size: 0.875rem; }
.btn--lg { padding: 0.75rem 1.5rem; font-size: 1.125rem; }
</style>
```

```vue
<!-- src/components/ui/BaseInput.vue -->
<script setup>
const props = defineProps({
  modelValue: { type: [String, Number], default: '' },
  label: { type: String, default: '' },
  name: { type: String, required: true },
  type: { type: String, default: 'text' },
  error: { type: String, default: '' },
  as: { type: String, default: 'input' },
  rows: { type: Number, default: 3 },
  required: { type: Boolean, default: false },
});

const emit = defineEmits(['update:modelValue']);

function handleInput(event) {
  emit('update:modelValue', event.target.value);
}
</script>

<template>
  <div :class="['form-group', { 'form-group--error': error }]">
    <label v-if="label" :for="`field-${name}`">{{ label }}</label>
    <component
      :is="as"
      :id="`field-${name}`"
      :name="name"
      :type="type"
      :value="modelValue"
      :rows="as === 'textarea' ? rows : undefined"
      :required="required"
      :aria-invalid="!!error"
      :aria-describedby="error ? `${name}-error` : undefined"
      class="form-control"
      @input="handleInput"
    />
    <p v-if="error" :id="`${name}-error`" class="error-text" role="alert">
      {{ error }}
    </p>
  </div>
</template>

<style scoped>
.form-group { margin-bottom: 1rem; }
label {
  display: block;
  margin-bottom: 0.25rem;
  font-weight: 600;
  color: var(--color-text);
}
.form-control {
  width: 100%;
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  font-size: 1rem;
  font-family: inherit;
  box-sizing: border-box;
  transition: border-color var(--transition-fast);
}
.form-control:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px rgba(66, 184, 131, 0.1);
}
.form-group--error .form-control { border-color: var(--color-error); }
.error-text { color: var(--color-error); font-size: 0.875rem; margin-top: 0.25rem; }
</style>
```

## 5. 컴포넌트 설계 패턴

### Slots을 활용한 합성

```vue
<!-- src/components/HeroSection.vue -->
<script setup>
defineProps({
  title: { type: String, required: true },
  subtitle: { type: String, default: '' },
});
</script>

<template>
  <section class="hero">
    <div class="hero__content">
      <h1 class="hero__title">{{ title }}</h1>
      <p v-if="subtitle" class="hero__subtitle">{{ subtitle }}</p>
      <div v-if="$slots.actions" class="hero__actions">
        <slot name="actions" />
      </div>
    </div>
    <div v-if="$slots.media" class="hero__media">
      <slot name="media" />
    </div>
  </section>
</template>

<!-- 사용 -->
<!--
<HeroSection title="환영합니다" subtitle="Vue로 만든 프로젝트">
  <template #actions>
    <BaseButton>시작하기</BaseButton>
  </template>
  <template #media>
    <img src="/hero.webp" alt="히어로 이미지" />
  </template>
</HeroSection>
-->
```

### Teleport 활용 (모달)

```vue
<!-- src/components/ui/BaseModal.vue -->
<script setup>
defineProps({
  show: { type: Boolean, default: false },
  title: { type: String, default: '' },
});

const emit = defineEmits(['close']);
</script>

<template>
  <Teleport to="body">
    <Transition name="modal">
      <div v-if="show" class="modal-overlay" @click.self="emit('close')">
        <div class="modal" role="dialog" aria-modal="true">
          <div class="modal__header">
            <h2>{{ title }}</h2>
            <button class="modal__close" @click="emit('close')" aria-label="닫기">
              &times;
            </button>
          </div>
          <div class="modal__body">
            <slot />
          </div>
          <div v-if="$slots.footer" class="modal__footer">
            <slot name="footer" />
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 1000;
}
.modal {
  background: var(--color-bg);
  border-radius: var(--radius-md);
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.15);
  min-width: 400px;
  max-width: 90vw;
  max-height: 80vh;
  overflow-y: auto;
}
.modal__header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.5rem;
  border-bottom: 1px solid var(--color-border);
}
.modal__body { padding: 1.5rem; }
.modal__footer {
  padding: 1rem 1.5rem;
  border-top: 1px solid var(--color-border);
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
}
.modal__close {
  background: none;
  border: none;
  font-size: 1.5rem;
  cursor: pointer;
  color: var(--color-text-muted);
}
.modal-enter-active, .modal-leave-active { transition: opacity 0.2s ease; }
.modal-enter-from, .modal-leave-to { opacity: 0; }
</style>
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
    throw error;
  }

  return response.json();
}

export const api = {
  get: (endpoint) => request(endpoint),
  post: (endpoint, data) =>
    request(endpoint, { method: 'POST', body: JSON.stringify(data) }),
};
```

```javascript
// src/composables/useFetch.js
import { ref, watchEffect, onUnmounted } from 'vue';
import { api } from '../utils/api';

export function useFetch(endpointRef) {
  const data = ref(null);
  const loading = ref(true);
  const error = ref(null);

  let controller;

  watchEffect(() => {
    const endpoint = typeof endpointRef === 'function' ? endpointRef() : endpointRef;
    if (!endpoint) return;

    controller?.abort();
    controller = new AbortController();
    loading.value = true;
    error.value = null;

    api.get(endpoint)
      .then((result) => { data.value = result; })
      .catch((err) => { if (err.name !== 'AbortError') error.value = err; })
      .finally(() => { loading.value = false; });
  });

  onUnmounted(() => controller?.abort());

  return { data, loading, error };
}
```

## 7. 테스트 전략

```javascript
// src/components/__tests__/ContactForm.test.js
import { mount } from '@vue/test-utils';
import { describe, it, expect, vi } from 'vitest';
import ContactForm from '../ContactForm.vue';

describe('ContactForm', () => {
  it('모든 필드를 렌더링한다', () => {
    const wrapper = mount(ContactForm);

    expect(wrapper.find('[name="name"]').exists()).toBe(true);
    expect(wrapper.find('[name="email"]').exists()).toBe(true);
    expect(wrapper.find('[name="message"]').exists()).toBe(true);
    expect(wrapper.find('button[type="submit"]').exists()).toBe(true);
  });

  it('빈 폼 제출 시 에러를 표시한다', async () => {
    const wrapper = mount(ContactForm);

    await wrapper.find('form').trigger('submit');

    expect(wrapper.text()).toContain('이름을 입력해주세요.');
    expect(wrapper.text()).toContain('올바른 이메일을 입력해주세요.');
  });

  it('유효한 데이터로 submit 이벤트를 발행한다', async () => {
    const wrapper = mount(ContactForm);

    await wrapper.find('[name="name"]').setValue('홍길동');
    await wrapper.find('[name="email"]').setValue('hong@example.com');
    await wrapper.find('[name="message"]').setValue('안녕하세요');
    await wrapper.find('form').trigger('submit');

    expect(wrapper.emitted('submit')).toBeTruthy();
  });
});
```

```javascript
// vite.config.js
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';

export default defineConfig({
  plugins: [vue()],
  test: {
    environment: 'jsdom',
    coverage: {
      provider: 'v8',
      reporter: ['text', 'html'],
    },
  },
});
```

## 8. 성능 최적화

### 컴포넌트 지연 로딩

```javascript
import { defineAsyncComponent } from 'vue';

const AsyncAbout = defineAsyncComponent({
  loader: () => import('./pages/About.vue'),
  loadingComponent: () => h('div', 'Loading...'),
  delay: 200,
  timeout: 5000,
});
```

### v-once / v-memo

```vue
<!-- 정적 콘텐츠는 한 번만 렌더링 -->
<footer v-once>
  <p>&copy; 2024 My Company</p>
</footer>

<!-- v-memo: 특정 의존성이 변경될 때만 재렌더링 -->
<div v-for="item in list" :key="item.id" v-memo="[item.id, item.updated]">
  {{ item.name }}
</div>
```

### 이미지 lazy loading

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
<!-- Vue는 {{ }} 내 값을 자동으로 이스케이프합니다 -->
<p>{{ userInput }}</p>  <!-- 안전 -->

<!-- 위험: v-html은 반드시 새니타이즈 후 사용 -->
<script setup>
import DOMPurify from 'dompurify';
import { computed } from 'vue';

const props = defineProps({ html: String });
const sanitized = computed(() => DOMPurify.sanitize(props.html));
</script>

<template>
  <div v-html="sanitized" />
</template>
```

### 환경변수

```bash
# .env
VITE_API_URL=https://api.example.com
# VITE_ 접두사만 클라이언트에 노출됨
```

### CSP 설정

```html
<meta http-equiv="Content-Security-Policy" content="
  default-src 'self';
  script-src 'self';
  style-src 'self' 'unsafe-inline';
  img-src 'self' data: https:;
  connect-src 'self' https://api.example.com;
"/>
```

## 10. 전체 진입점

```javascript
// src/main.js
import { createApp } from 'vue';
import App from './App.vue';
import { router } from './router';
import './assets/styles/variables.css';
import './assets/styles/global.css';

const app = createApp(App);
app.use(router);
app.mount('#app');
```
