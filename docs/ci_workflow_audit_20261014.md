# GitHub Actions 병목 전수 점검 — 2026-10-14

## 조사 대상과 근거

- `gamja121/necromancer-and-dice-godot`의 기본 브랜치에서 GitHub Actions YAML **67개**를 확인함. 이전 69개 수치는 현재 저장소와 일치하지 않음.
- 커밋 `df1c4fad5ac50e3107460743a60a55031f535dd8`에서 같은 시각에 14개 워크플로가 시작됨. 커밋은 `systems/run_session.gd`, `systems/exploration_actions.gd` 및 숙영 해금 관련 테스트 수정.
- `story-state-regression.yml`은 800줄이 넘고 다수의 Godot 스크립트 검사를 포함한다. 여러 기능별 워크플로에서도 `test_p4_combat_map_return_integration.gd` 등 공통 통합검사를 반복한다.
- 대다수 과거 `ui-...stage5*.yml` 워크플로는 특정 feature 브랜치에서만 push 트리거됨. 모든 67개가 매 커밋 실행되는 것은 **아님**.
- `ui-location-layout-stage5s.yml`만은 UI 전용임에도 `main`의 변경 종류를 제한하지 않았음.

## 병목 분석과 변경

| 유형 | 관찰 결과 | 조치 |
|---|---|---|
| 동일 브랜치에 빠른 연속 push | 느린 Godot import/통합검사가 서로 겹칠 수 있음 | 활성 핵심 워크플로 17개에 최신 커밋 우선 concurrency 추가 |
| 위치 화면 검사 불필요 실행 | Stage 5S가 main의 문서 변경에도 실행 | 맵·장소·UI 에셋 및 관련 검증 파일에 push.paths 추가 |
| 웹 미리보기 | web-preview에 이미 cancel-in-progress:true 존재 | 유지 (변경 없음) |
| 독립 기능 브랜치 검증 | 많은 역사적 Stage UI 워크플로는 특정 브랜치만 감시 | 비활성화·삭제 없음 |
| 검증의 중복 | 공통 E2E 테스트가 여러 워크플로에서 반복 | 현 단계에서는 테스트를 삭제하지 않음. 후속으로 성공률과 변경 영향 분석 후 통합 |
| AI 개발 감시 | 별도 경량 워크플로, 15분 cron + 20분 중단 의심 | 유지 (변경 없음) |

## 변경을 적용한 워크플로 (17개)

- `ui-location-layout-stage5s.yml`
- `story-state-regression.yml`, `windows-native-godot-validation.yml`
- `p4-natural-full-story.yml`, `p4-natural-commander-hunter.yml`, `p4-natural-home-lap.yml`
- `map-one-notch-gear.yml`, `patrol-six-slot-selection.yml`, `rest-tile-unlock.yml`
- `game-over-shatter.yml`, `graveyard-extraction-exit.yml`, `hill-forward-destination.yml`
- `shared-die-safety.yml`, `battle-formation-order.yml`, `battle-entry-summon.yml`
- `godot-web-independence.yml`, `contamination-ten-slot-art.yml`

모두 `github.workflow + event_name + PR 번호 또는 Git ref` 기반 concurrency를 사용한다. push/PR의 오래된 실행을 새로운 해당 워크플로 실행이 취소하지만, 수동 dispatch는 자동 취소되지 않도록 함.

## 기존 실패와 최적화의 구분

- `story-state-regression` (Actions run 38503422258): 전이문 재개 관련 검사 `P4_STORY_UI_INTERRUPTION: 43 passed, 4 failed`.
- `windows-native` (run 38503422334): 전이문 결과 화면 관련 `P4_FULL_SOURCE_STORY_CHAIN: 311 passed, 1 failed`.
- 이 둘은 테스트 내용이 실제로 실패한 것이므로 runner 병목으로 간주해 비활성화하지 않음. 게임 코드 문제는 별도 작업으로 수정/재검증 필요.

## 검증 방법과 제한

- `scripts/check_ci_workflow_policy.py`는 67개 워크플로를 열람하여 동시 실행 보호와 Stage5S 범위, 중복 검사를 요약.
- GitHub Actions의 Ruby YAML 구문 검사로 전체 워크플로가 YAML 파싱 가능한지 확인.
- 워크플로의 테스트 명령이나 게임 규칙/이미지는 변경하지 않음.
- 자동 취소는 **새 커밋이 생겨 같은 워크플로가 재실행될 때** 과거 실행만 정리한다. 서로 다른 14개 워크플로를 한꺼번에 하나로 합치는 기능은 아님.
- 후속 개선: 실제 CPU/실행 시간과 중복 스크립트 목록, 실패 유형이 충분히 축적되면 포괄 E2E 테스트를 공유 gate로 통합. 아직 테스트 제거/통합을 승인하지 않음.
- GitHub에 병합된 후에도 사용자의 로컬 PC가 같은 commit을 사용 중인지는 별도로 확인해야 함.