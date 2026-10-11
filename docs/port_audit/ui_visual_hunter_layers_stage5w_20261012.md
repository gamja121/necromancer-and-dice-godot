# 5단계 W — 마물 사냥꾼 사건 원본 레이어/애니메이션 이식 (2026-10-12)

## 원본 확인 근거와 실제 차이

- 동결 웹: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c` (읽기만 함).
- `v2-map-practice.css:2480-2533`: 오염된 마물 현장 그림은 `left:13%; bottom:2%; width:74%; height:92%`, `hunter-scene-enter`의 0.52초 동안 3% 아래/96.5% 크기/투명도 0 → 정위치·불투명. 사냥꾼 초상은 `right:2%; bottom:25%; width:58%; height:78%`, 0.48초 동안 +7% 오른쪽/+2% 아래/96% 크기/투명도 0 → 94% 투명도(즉 opacity .94). 둘 다 장식용 클릭 무시.
- `v2-map-practice.js:6328-6365`: 11비트 중 현장 `warning_reveal`, `unnatural`, `clue`에서만 재등장 애니메이션, 초상 `identify`, `sent_by_commander`에서만 재등장. `player_reply`는 공통 웹 player-story-layer 동작을 재사용한다.
- 이전 Godot `map.gd:show_monster_hunter_beat()`에서는 `visual` 자산을 모두 **같은 793.6×446.4 전체 원화 위치**에 정지 이미지로 겹쳤다. 이전 V단계는 기사단장과 주인공에만 해당.

## 구현

- `systems/monster_hunter_layer_motion.gd` 추가: 원화 `TILE_EVENT_SCENE_RECT`에 웹 상대 퍼센트를 곱해 현장 `HunterSceneLayer`와 초상 `HunterPortrait`을 독립 배치한다. 0.52/0.48초 Tween과 100%/94% 종료 투명도를 비트별로 적용한다.
- `map.gd`: `MonsterHunterBeats.visual_art()`가 반환하는 기존 소스 WebP를 직접 TextureRect로 유지. 플레이어 응답에는 `HunterPlayerPortrait` + V단계 `CommanderPortraitMotion`의 원본 플레이어 x=-7%, y=+2%, 0.48초를 재사용한다. 최초 base 비트에서는 보조 레이어를 생성하지 않으며 다른 사건의 공통 모션은 변경하지 않는다.
- `PanelEffectsModule`에서 U단계에 추가한 opt-in `ui_custom_open_motion`을 써서 개별 인물/장면 Tween과 일반 창 슬라이드 충돌 방지. 실제 노드 삭제 시 Tween도 종료.
- 웹 CSS의 그림자/brightness/saturation/객체 렌더링의 픽셀 수준 일치와 Windows/Android 화면별 실기 평가는 아직 미검증. 기존 원화 파일과 저장 형식을 교체하지 않음.

## 기본 5원칙

1. **Trigger:** 실제 출전 구울을 이겨 아이를 구출하고, 마을 소문과 기사단장 의뢰가 완료된 뒤 세계수의 원래 11개 마물 사냥꾼 대사 비트에 진입할 때. 새 조건이나 사건은 만들지 않음.
2. **Information:** 기존 `MonsterHunterEntry.current_beat()`, `MonsterHunterBeats.visual/id`, 웹 CSS 원화 상대 위치 및 애니메이션 시간.
3. **Interaction:** `계속`/`마치기` 명시적 버튼으로만 저장 비트와 퀘스트 진행. 그림은 클릭 무시하며 추가 조작 없음.
4. **Visual:** 시체 현장 중앙 하단·사냥꾼 우측 반신·주인공 좌측 반신을 각기 다른 크기로 표시, 웹 원본이 지정한 비트에서만 해당 등장 연출.
5. **Persistence:** Tween/클릭차단/배치 정보는 저장하지 않음. 기존 원정·스토리·보상·RNG 데이터에 추가/변경 없음. 기존 P5 원화 4개와 raw_assets 원본 보존.

## 검증 범위

- `scripts/test_ui_hunter_layers_stage5w.gd`: 신규 세션의 실제 아이 구출 전투→마을 소문→기사단장 7비트 완료→세계수 마물 사냥꾼 11비트 접근. 각 비트별 정확한 원본 WebP 경로와 노드 수/타입, 원본 크기와 위치·재생 여부·시간과 투명도, 버튼, 닫기, 최종 비트 저장 후 재실행, 스토리 미완료/보상 불변성을 확인.
- `.github/workflows/ui-hunter-layers-stage5w.yml`: Godot 4.7.2 headless import와 신규 W 검사, V/U/T/기존 사건 중단/장소 오디오/보물·제단·순찰·맵이동/P5 원화/원정 전체 검사로 검증. 실기 시각 승인과 사용자 PC SHA 동기화는 별도 보류.
- 원본 웹 저장소 삭제·업데이트 없음; Godot `main`과 로컬 PC를 강제로 동기화하지 않음. P3-05/P4-02E-B/P5-03B 실기 승인 게이트는 여전히 TODO.
