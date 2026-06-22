**주요 지적**

1. **[높음] “주석 달린 스니펫”은 문서 인용 규칙과 직접 충돌한다.**  
   현행 규칙은 코드 블록을 “실파일에서 복사”하고 placeholder·생략을 금지한다([core.md](/home/jun/project/claude-code-harness/core.md:98)). 그런데 `changelog.md` 안 스니펫에 설명 주석을 삽입하면 더 이상 실파일 복사가 아니다. 구현 playbook의 “코드 주석은 테스트 통과 후, 왜만” 규칙([implementation.md](/home/jun/project/claude-code-harness/playbooks/implementation.md:42))보다 이쪽 충돌이 더 치명적이다.

   수정안: 코드 블록은 원본 그대로 두고, 바로 아래에 “라인별 근거” 표를 둔다.

   ```md
   ```ts
   // 실파일에서 그대로 복사한 코드
   ```
   | 줄 | 근거 |
   |---|---|
   | L12-L18 | spec A의 불변식 때문에 early return |
   | L20-L24 | review.md 메서드 내부 렌즈: 입력 규모상 O(n) 유지 |
   ```

   “주석으로 설명”이라는 요구는 “문서상의 주석/해설”로 해석해야 한다. 코드 블록 내부 주석 삽입은 금지로 못 박는 게 안전하다.

2. **[높음] learned.md와 changelog.md는 같은 코드 스니펫을 두 번 설명하게 될 가능성이 높다.**  
   현행 learned는 “사용자 학습용 제품”이고 코드 스니펫 포함 풀 작성이 가능하다([core.md](/home/jun/project/claude-code-harness/core.md:96), [templates/learned.md](/home/jun/project/claude-code-harness/templates/learned.md:31)). changelog도 “왜 이렇게 짰나”와 스니펫을 요구하므로, 새 패턴을 도입한 구현에서는 거의 필연적으로 중복된다.

   수정안: 역할 경계를 이렇게 박아야 한다.

   - `changelog.md`: **이번 diff의 의사결정 로그**. 변경 단위별 근거, 대안, 리뷰 질문.
   - `learned.md`: **전이 가능한 학습 노트**. 새 라이브러리·패턴·비직관 버그·테스트 전략을 사용자가 다음 작업에도 써먹게 설명.
   - 같은 스니펫은 원칙적으로 `changelog.md`에만 둔다. `learned.md`는 `changelog.md#항목ID`를 참조하고, 개념 설명만 추가한다.
   - learned가 독립 학습 문서로 반드시 코드가 필요할 때만 대표 스니펫 1개를 재인용한다.

3. **[높음] “검증 통과 후 작성”은 기존 최소 안전선과 맞지 않는 실패 경로가 있다.**  
   현행 기록 단계는 테스트 실행 또는 실행 불가 사유 기록을 허용한다([templates/task.md](/home/jun/project/claude-code-harness/templates/task.md:62)). 그런데 changelog가 “검증 통과 후”만 가능하면, 테스트를 못 돌렸지만 코드 변경을 남기는 작업, 부분 실패를 보고하고 멈추는 작업, 긴급 수정 후 사후 기록 작업에서 산출물 조건이 붕 뜬다.

   수정안: “검증 통과 후”가 아니라 **“검증 단계 종료 후, 최종 응답 전”**으로 바꾸고, changelog 상단에 검증 상태를 넣어야 한다.

   ```md
   검증 상태: 통과 / 일부 실패 / 실행 불가
   근거: 명령, 실패 로그 요약, 실행 불가 사유
   ```

4. **[높음] “판단이 개입된 변경”은 그대로 두면 축소·팽창 둘 다 난다.**  
   구현자는 귀찮으면 “기계적 변경”으로 축소할 수 있고, 반대로 모든 hunk를 풀 설명해 문서가 폭증할 수 있다.

   집행 기준선은 “diff hunk 분류”가 가장 낫다.

   - `J 판단`: 런타임 동작, API/CLI 계약, DB/schema/query, 에러 처리, 트랜잭션, 검증/정규화, 보안/권한, 동시성/cache/time/env, 알고리즘/자료구조, 성능/자원, 테스트 전략을 바꾸는 hunk.
   - `M 기계`: 포맷, import 정리, lint, 순수 rename, 순수 이동. 단 public API rename은 `J`.
   - `G 생성`: lockfile, generated file, snapshot. 원인 결정은 `J`에 쓰고 생성물은 1줄 목록.
   - 불확실하면 `J` 또는 최소 1줄 근거. “기계적”이라고 쓰려면 “동작 동일 근거”를 붙인다.

5. **[중간] 사후 합리화 방지 장치가 부족하다.**  
   작성자가 구현자=메인이면 “이미 만든 코드에 그럴듯한 이유 붙이기”가 된다. 특히 대안 기각 사유는 사후 창작되기 쉽다.

   수정안:

   - 각 changelog 항목에 `근거 출처` 필드를 둔다: `spec`, `task.md 결정`, `테스트 실패`, `리뷰 finding`, `기존 코드 패턴`, `사용자 결정`.
   - 출처 없는 판단은 `사후 추정`으로 표시한다.
   - 구현 중 큰 선택은 task.md 기록에 1줄 남기고, changelog는 그 기록을 참조한다.
   - 최종 작성 후 `git diff --name-only` 기준으로 “변경 파일 전부가 changelog에 J/M/G로 등장하는지” 셀프체크를 의무화한다.

6. **[중간] 배선이 core+template만으로는 약하다.**  
   현재 `templates/task.md` 기록 단계에는 learned 판정만 있다([templates/task.md](/home/jun/project/claude-code-harness/templates/task.md:69)). 매 코드 작업마다 만들 산출물이라면 task 템플릿의 기록 체크리스트에도 들어가야 실제 운용에서 빠지지 않는다.

   수정안: `templates/task.md` 기록 섹션에 한 줄 추가.

   ```md
   - changelog 판정: 코드 구현 있음 □ / 문서-only라 제외 □
     - 있음 → `changelog.md` 작성 완료 □ / diff 파일 전부 J-M-G 분류 확인 □
   ```

7. **[중간] review.md 렌즈 사용 트리거가 애매하다.**  
   changelog가 매 코드 작업마다 리뷰 연습 질문을 요구하면, `playbooks/review.md` §3도 사실상 매 코드 작업의 작성 트리거가 된다. 그런데 계획은 “playbook은 필요 시 포인터 1줄”이라 되어 있어, 실제 작성자는 렌즈 문구를 기억으로 재현하거나 템플릿에 중복 복사할 가능성이 있다. 이는 “규칙 하나=위치 한 곳” 원칙([core.md](/home/jun/project/claude-code-harness/core.md:12))과 충돌한다.

   수정안: `templates/changelog.md`에는 렌즈 이름만 두고, “질문 원문은 `playbooks/review.md §3`에서 고른다”를 명시한다. 즉 changelog 작성 시 review §3은 정식 트리거가 된다.

8. **[낮음] high-stakes phase 문서와 스니펫 중복 가능성이 있다.**  
   `templates/phase.md`에도 주요 변경 스니펫이 있다([templates/phase.md](/home/jun/project/claude-code-harness/templates/phase.md:35)). 대규모 작업에서 phase 스니펫과 changelog 스니펫이 겹칠 수 있다.

   수정안: phase는 “검증 게이트용 대표 스니펫”, changelog는 “최종 diff 의사결정 로그”로 분리하거나, phase에서 changelog 항목 ID를 참조하게 한다.

**핵심 수정 문구**

`templates/changelog.md`에 아래 기준을 넣으면 집행력이 가장 좋아진다.

```md
## 커버리지 규칙
최종 diff의 모든 변경 파일은 J/M/G 중 하나로 분류한다.
- J(판단): 동작·계약·데이터·에러·성능·보안·테스트 전략에 영향. full 항목 작성.
- M(기계): 동작 동일한 import/format/순수 rename/순수 이동. 1줄 목록.
- G(생성): lockfile/generated/snapshot. 원인 J 항목을 참조하고 1줄 목록.

코드 블록은 실파일에서 그대로 복사한다. 근거 설명은 코드 블록 안에 삽입하지 않고, 라인별 근거 표에 쓴다.
```

결론: 방향은 유지 가능하지만, 지금 계획 그대로면 가장 큰 결함은 “원본 스니펫에 주석 삽입”과 “learned 중복”이다. 이 둘은 도입 전에 반드시 문구로 막아야 한다.