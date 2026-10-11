# 5단계 V — 기사단장과 주인공 원본 사건 인물 연출 (2026-10-12)

## 웹 원본에서 직접 확인한 차이

- 참조 원본 (읽기 전용): `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- `v2-map-practice.css:2404-2473`: 기사단장 이미지 `.commander-story-layer`는 오른쪽 **3%**, 아래 **25%**, 폭 **52%**, 높이 **74%**, **좌우 반전**이 기본이며 `.is-entering`은 왼쪽 -7%/아래 +2%, 96% 크기, 투명 0에서 0.52초 동안 나타난다.
- 같은 CSS `.player-story-layer`는 왼쪽 **4%**, 아래 **25%**, 폭 **41%**, 높이 **63%**, 좌우 반전 없이 **0.48초** 등장한다.
- `v2-map-practice.js:6300-6315`: 기사단장은 `arrival`, `recognition` 비트에서만 등장 애니메이션을 재생하고 나머지는 즉시 표시한다. 플레이어는 `player_reply` 비트에만 표시하고 들어오면서 나타난다.
- 이전 Godot `map.gd:show_knight_commander_beat()`에서는 7비트 전부 기사단장/플레이어 원화를 동일한 (692,179), 265×338 좌표에 일반 고정 이미지로 표시했다. 좌우 반전과 웹 원본 0.52/0.48초 등장 여부가 빠져 있었다.

## 변경

- `systems/knight_commander_portrait_motion.gd` 신규: Stage S의 원화 프레임 (`TILE_EVENT_SCENE_RECT`)을 기준으로 서로 다른 두 등장 위치/크기를 원본 CSS의 퍼센트로 계산한다. 기사단장만 `flip_h=true`, 밑단 중심 피벗(50%/100%)을 사용한다. 0.52/0.48초 위치·크기·알파 변화는 텍스처 노드에 종속된 Tween으로 표현하고 4개 나머지 비트는 즉시 보여준다.
- `map.gd`: 인물 레이어에 `CommanderStoryPortrait`/`PlayerStoryPortrait` 이름을 부여해 원본 기존 WebP를 **직접 자식 TextureRect**로 유지. P5 기존 연결 검사가 기대하는 실제 원화 경로/TextureRect 타입을 유지하며 이미지 자체는 수정하거나 재저장하지 않았다.
- U단계에 구축된 `PanelEffectsModule`의 개별 예외 메타를 사용하여 커스텀 인물 진입 효과와 기본 +6px 자동 이동이 충돌하지 않게 한다. 다른 창/원화/사건의 공통 전환에는 영향 없음.
- CSS의 밝기·대비·채도·그림자 필터 픽셀 동일성은 여전히 별도 시각 검토 대상으로 남긴다. 특히 이미 대체된 P5 4개 그림은 사용자가 Windows/Android에서 확인하기 전에는 교체·삭제하지 않는다.

## 5원칙 검토

1. **Trigger** — 기사단장 사건의 실제 저장 비트 0/3 `arrival`/`recognition`, 주인공 응답 2 `player_reply`; 신규 사건이나 자동 진행 없음.
2. **Information** — `KnightCommanderBeats.beat()`의 유효 `id`, 기존 `portrait` 경로, CSS 퍼센트 위치·시간.
3. **Interaction** — 원본 `계속`/`마치기` 클릭만 스토리를 전진. 원화는 마우스·터치 무시.
4. **Visual** — 기사단장 우측/반전 52%×74%, 주인공 좌측 41%×63%; 지정 비트에서만 좌측 이동·확대·페이드.
5. **Persistence** — 신규 이미지 메타/Tween은 저장하지 않음. 기존 `RunSession` 사건 비트/퀘스트 저장과 보상/RNG/전투 계약 유지.

## 검증 및 보류

- `scripts/test_ui_commander_portraits_stage5v.gd`: 임시 저장 경로에서 실제 구울 승리와 마을 소문 종료→기사단장 7개 비트 접근, 원본 그림 텍스처 존재, 양쪽 위치, 미러링, 비트별 진입·정지, 임의 종료 및 저장 리로드 보존, 마물·보상 변경 없음 확인.
- `.github/workflows/ui-commander-portraits-stage5v.yml`: Godot 4.7.2 headless import, V 신규 검사, U 그림·대화창 움직임, T 구울, 기존 사건/저장 복원, 5S/R/Q/M/P, 제단/순찰/맵 이동, P5 원화 4종, 단일 원정 전체 회귀검사 포함.
- Windows·Android 실기에서 실제 색감·그림자·오른쪽 기사단장 시선·좌우 전환의 자연스러움 검증은 별도. 기존 `main`은 다른 개발자의 커밋을 보호하기 위해 자동 병합하지 않으며 웹 참조·사용자 로컬 저장/원화 원본을 보존한다.
