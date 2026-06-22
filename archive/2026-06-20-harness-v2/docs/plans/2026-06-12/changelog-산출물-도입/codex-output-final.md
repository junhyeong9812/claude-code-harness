발췌 기준 최종 판정: **대부분 반영됨. 다만 커버리지 기준과 learned 경계 문구에 실행상 충돌이 남아 있음.**

이전 8지적 반영 여부:
1. 블록 내 주석 금지 + 라인별 근거 표: 반영
2. learned 경계: **부분 반영, 아래 중간 지적**
3. 작성 시점 + 검증 상태: 반영
4. J/M/G 전수 분류: **취지는 반영, 아래 높음 지적**
5. 근거 출처 + 사후 추정 + 셀프체크: 반영
6. task 템플릿 기록 체크: 반영
7. review.md §3·§4 원문 사용 + 트리거: 반영
8. phase 스니펫 중복 시 ID 참조: 발췌 기준 반영

**[높음] `git diff --name-only` 커버리지 기준이 실제 운용에서 오검출/누락될 수 있음**

`templates/changelog.md`는 “작성 후 셀프체크”로 `git diff --name-only`의 모든 변경 파일을 J/M/G에 넣으라고 합니다. 그런데 작성 후에는 `changelog.md`, `task.md`, `measurement-log.md`, 경우에 따라 `learned.md` 자체가 diff에 들어갑니다. 그러면 changelog가 자기 자신까지 분류해야 하는 순환이 생깁니다.

또 `git diff --name-only`는 기본적으로 unstaged 변경만 보므로, staged 변경이나 이미 커밋된 작업 범위는 빠질 수 있습니다.

수정안:
```md
최종 대상 diff의 모든 변경 파일이 J/M/G 중 하나로 등장해야 한다.

변경 파일 기준:
- 미커밋 작업: `git diff --name-only HEAD --`
- 커밋 후 작성: 작업 기준 커밋 범위 `git diff --name-only <base>...HEAD --`
- 현재 작업의 프로세스 산출물(`docs/plans/.../task.md`, `changelog.md`, `learned.md`, `docs/measurement-log.md`)은 커버리지 대상에서 제외한다.
- 단, 그 문서 자체를 수정하는 것이 작업 목적이면 대상 변경 파일로 포함한다.
```

**[중간] learned 스니펫 소유권 문구가 아직 충돌함**

`templates/changelog.md`와 core의 changelog 설명은 “스니펫은 changelog에만, learned는 changelog 항목 ID 참조” 방향입니다. 그런데 `core.md §3.5`의 learned 설명은 여전히 “풀 작성(... 코드 스니펫 포함)”이라고 되어 있고, `templates/task.md §5`도 “learned.md 풀 작성(... 코드는 실파일에서 복사)”라고 되어 있어 learned에 코드 스니펫을 넣는 것이 기본처럼 읽힙니다.

수정안:
```md
풀 작성(`templates/learned.md` 10항목). 코드 예시는 원칙적으로 `changelog.md` 항목 ID를 참조하고, 독립 학습에 꼭 필요한 경우에만 대표 스니펫 1개를 실파일에서 재인용한다.
```

`templates/task.md §5`도 같은 취지로:
```md
있음 → 별도 `learned.md` 풀 작성 (`templates/learned.md`; 코드 예시는 원칙적으로 changelog 항목 ID 참조, 필요 시 대표 스니펫 1개만 실파일에서 재인용) □
```

**[낮음] “산출물은 기본 task.md 1파일” 문구가 새 별도 산출물과 약하게 충돌함**

`core.md §3.5`에 changelog와 learned 별도 산출물이 추가됐는데, 바로 아래 “산출물은 기본 task.md 1파일” 문구가 남아 있어 신규 작성자는 changelog 의무를 예외로 오해할 수 있습니다.

수정안:
```md
프로세스 산출물의 기본은 `task.md` 1파일이다. 단, `changelog.md`, `learned.md`, `measurement-log.md`는 각 트리거 충족 시 별도 작성한다.
```

위 세 점을 고치면 이전 8지적은 실질적으로 닫히고, 트리거·커버리지·작성 시점도 실행 가능한 수준으로 정리됩니다.