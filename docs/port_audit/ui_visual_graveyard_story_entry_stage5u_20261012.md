# 5단계 U — 공동묘지 아동 사건 원화 등장/다음 안내 연출 복원 (2026-10-12)

## 원본 비교 및 발견한 차이

- 고정 HTML 원본: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`; 소스 읽기만 수행.
- `v2-map-practice.js:6104-6121`은 공동묘지 이야기 창을 처음 열 때 `playGraveyardStoryBoardDrop()`을 호출한다. `v2-map-practice.css:1985-2026`에서 원화가 **0.66초 동안** 6개 키프레임(-4.8%/-19%, -7°, 94%, 48% 투명도에서 시작)으로 내려앉고 작게 흔들린 뒤 제자리로 돌아온다.
- `v2-map-practice.css:2198-2205,2280-2283`은 **선택 장면 이전** 대화창의 `▼` 다음 안내 표시가 **0.9초 주기**로 y=0~+4px, 투명도 45~100%로 반복 움직이도록 규정한다.
- 기존 Godot `map.gd:show_graveyard_child_beat()`은 1비트의 원화 InkSceneReveal 및 전역 PanelEffects 0.20초 이동/페이드만 재생하고, 3비트의 다음 안내 `▼`를 정지 라벨로 표시했다. 스토리 비트·대화 액자는 이미 구현되어 있으므로 이 둘의 시각 연출만 부족했다.

## 변경 사항

- 신규 `systems/graveyard_story_entry_motion.gd`:
  - 원본 키프레임 0/45/61/75/88/100%를 0.66초에 따라 **위치, 회전, 크기, 투명도**에 각각 적용. 원본 그림 경로와 소재는 교체하지 않는다. `TextureRect.pivot_offset`은 50%/54%로 설정.
  - `play_next_hint()`는 기존 `StoryDialogueNext` 라벨에 0.9초 무한 루프를 적용하되 마우스/터치를 무시한다. 선택 장면에는 원래 라벨을 만들지 않는다.
- `map.gd`: 공동묘지 아동 `beat_index==0`에만 기존 펜그림 공개 효과에 추가해 그림 등장 적용. 대화 라벨은 이미 보이는 `▼`에만 반복 효과 적용한다. 다른 이야기 사건의 그림·저장 로직은 건드리지 않는다.
- `systems/panel_effects_module.gd`: `ui_custom_open_motion` 메타를 설정한 장식 이미지/라벨만 기존 공통 창 진입 +6px 이동에서 제외한다. 기본 창 페이드는 계속 유지하며, 나머지 장소·서사·전투/설정 창은 기존 UI 동작 그대로이다. 이 opt-in 없이 공통 모션을 변경하지 않는다.
- 두 Tween 모두 UI 노드에 종속된다. 닫기/다음 장면/게임 재접속 시 추가 콜백이나 저장값을 남기지 않는다. 첫 장면 이후 비트 또는 저장 복원 시 구울 연출(Stage T)과 본문 프레임(Stage P)은 독립적이다.

## 게임 5원칙

1. **Trigger**: 최초 공동묘지 아이 사건 그림이 새로 표시되는 첫 비트, 그리고 일반 대화 비트의 안내 표시 렌더링. 신규 이벤트 없음.
2. **Information**: 웹 고정 CSS 키프레임과 시간 및 현재 스토리 비트.
3. **Interaction**: `계속`/`나가기`/`아이를 구한다`/`지나친다` 클릭만 사건 변화 허용. 애니메이션은 클릭 신호를 발생시키지 않음.
4. **Visual**: 0.66초 원화 하강·반동과 0.9초 다음 단계 표시 왕복. 기본 지도와 다른 화면은 원래 구성 유지.
5. **Persistence**: UI Tween/메타값은 세이브에 추가하지 않음. 게임 상태/RNG/보상/전투 초기화·수정 없음. 원본 그림·사용자 변경 원화 4종 삭제·교체 없음.

## 검증 계획과 한계

- 신규 `scripts/test_ui_graveyard_story_entry_stage5u.gd`: 원본 WebP, 키프레임 시작/종료, 공통 PanelEffects와 경쟁 없음, 반복 표시, 선택 단계 표시 억제, 빠른 종료, 사건 상태·저장 재시작, 보상·RNG·전투 불변 검사.
- 신규 `.github/workflows/ui-graveyard-story-entry-stage5u.yml`: Godot 4.7.2 headless import 및 신규 검사, Stage T 구울·Stage 4 공동묘지·P4 사건 중단 복원·Stage S/R/Q/M UI 및 오디오·Stage 5P 대화·제단·순찰·실이동·P5 변경 원화 연결·단일 원정 회귀를 실행한다.
- 이 결과는 실제 Windows/Android 실기에서의 프레임률/펜그림과 하강 효과 시각 간섭, 시각적 비교, 접근성 저속·모션 감소 선호를 보장하지 않는다. 실제 승인과 `main` 합병/배포는 별도 작업이다.
