# 5단계 Y — 전이문과 마물의 왕 징조 그림의 원본 배치·등장 이식 (2026-10-12)

## 확인한 소스 및 기능 차이

- 고정 참조: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`; 읽기 전용.
- `v2-map-practice.css:2608-2650`: `.ritual-portal-layer` 세 종류(에너지·광신도·마물의 왕 징조)의 기본 영역 **left:2%, bottom:22%, width:75%, height:75%** → 상단 3%. 피벗 50%/100%, 클릭 없음, `.is-entering`만 **0.50초** 아래 2% 이동·98.5% 크기·투명도 0에서 원위치로 복원.
- 원본 JS `v2-map-practice.js:6418-6448`는 비트 `portal_reveal`, `crossing`, `omen`에서만 `.is-entering`을 켠다. 실제 고정 다섯 비트 ID는 `arrival`, `portal_reveal`, **`final_ritual`**, `omen`, `intervene`; `crossing` 비트는 없으므로 **광신도 `final_ritual`과 마지막 `intervene` 징조는 정지**한 것이 실제 원본 동작이다.
- `v2-map-practice.js:6890+` 전투 결과 화면은 동일한 징조 원화를 다시 불러오되 등장 애니메이션 없이 표시한다. 기존 Godot `map.gd`는 에너지·광신도·징조를 언제나 전체 793.6×446.4 원화 크기로 그리고 재생 시 `InkSceneReveal`을 일괄 적용하는 실제 차이가 있었다.

## 수정 사항

- 신규 `systems/ritual_portal_layer_motion.gd`: 원본 그림프레임 `TILE_EVENT_SCENE_RECT` 상대 퍼센트와 0.50초 불투명도/위치/크기 Tween 복원. 노드에 종속된 장식 트윈, `ui_custom_open_motion` 메타 사용으로 일반 PanelEffects 6픽셀 이동과의 경쟁 차단.
- `map.gd:show_ritual_portal_beat()`: 실제 `res://assets/map/events/ritual-portal-*-layer.webp`를 각각 `PortalEnergyLayer`, `PortalCultistsLayer`, `PortalOmenLayer`라는 직접 자식 `TextureRect`로 한 종류만 그림. **0.50초 등장 효과는 `portal_reveal`(에너지)과 `omen`(마물의 왕 징조)만** 실행, `final_ritual`/ `intervene`는 즉시 안정된 장면으로 표시.
- `map.gd:show_ritual_portal_aftermath()`: 전투 승패를 확인한 뒤 나오는 원래 징조 원화도 위와 동일한 75%×75% 영역에 정지 표시. 명시적 `마치기` 클릭 없이는 부활이나 왕 추적 플래그를 저장하지 않는다.
- 기존 `RitualPortalEntry`, `RitualPortalBeats`, `RunSession`, 원본 WebP, 저장 포맷, 부활 승패 분기, 카드/전투 계산을 변경하지 않는다. CSS의 밝기·채도·drop-shadow 픽셀 동일성은 PC 실기 확인 전까지 미승인이다.

## 게임 변경 검토 5원칙

1. **Trigger**: 선행 제단 완료 후 숲 전이문에 진입하여 저장된 비트의 스토리 레이어를 공개할 때. 새 사건/조건은 없음.
2. **Information**: 기존 `RitualPortalEntry.current_beat()`, 원본 `RitualPortalBeats.visual/id` 및 고정 JS/CSS 등장 타이밍.
3. **Interaction**: 장식 레이어는 마우스·터치 무시. `계속`, `저지한다`, `출전 마물 선택`, `부활 확인`, `마치기` 명시적 절차만 기존 저장/전투를 진행.
4. **Visual**: 전이문 에너지·광신도·징조 공통 75% 그림 배치, 에너지와 최초 징조 장면에서만 0.50초 페이드/작은 이동·확대, 전투 결과 안내는 정지.
5. **Persistence**: 애니메이션 위치/시간/Tween/메타가 세이브에 들어가지 않음. 기존 퀘스트·전투 승패·RNG·보상·마물 영구사망 불변.

## 자동검사와 남은 한계

- `scripts/test_ui_ritual_portal_layers_stage5y.gd`: 테스트 전용 임시 save에 기존 아이 구출 → 마을 소문 → 기사단장 → 마물 사냥꾼 → 광신도 소문 → 제단 `지나간다` + 명시적 Finish → 숲 전이문 5비트 실제 상태 전이. 비트별 원본 WebP·한 겹 배치·좌표·트윈 시작/종료·정지 여부·실제 버튼·RNG/스냅샷 불변, 재실행 복원, 명시적 저지 선언/실전투 승리 기록/결과확인/후속 징조를 검증한다.
- `.github/workflows/ui-ritual-portal-stage5y.yml`: Godot 4.7.2 임포트, Y 신규 검사와 X/W/V/U/T 및 지도·오디오·사건 저장·전투·원정 전체 회귀를 한 번 더 검증. 실제 Windows/Android UI 그림자·색감·느낌, PC/GitHub SHA 동기화는 보장하지 않는다.
- 고정 웹을 수정/삭제하지 않는다. `main`에 다른 작업이 있어 별도 브랜치 유지. P3-05/P4-01F/P4-02E-B/P5-03B Windows GUI 원화 검수는 미완료이며 웹 저장소 삭제 승인으로 간주하지 않는다.
