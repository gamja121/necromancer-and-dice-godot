# 5단계 X — 광신도 소문과 제단 의식 그림 위치·등장 이식 (2026-10-12)

## 원본 대조 / 실제 차이

- 고정 원본 (읽기만): `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- `v2-map-practice.css:2538-2605`: 광신도 소문 행렬 `cultist-rumor-layer`은 **left:10%; bottom:0%; width:80%; height:80%**이며 최초 `procession`만 **0.50초** 아래 +2% / 크기 98.5% / 투명도 0에서 정상 표시. 제단 `cultist-altar-layer`는 **left:20%; bottom:7%; width:60%; height:60%**, 아래 +2% / 98.5% / 투명도 0에서 **0.48초** 등장. 소환 그림은 같은 좌표를 사용하며 원화별 z-index가 다름.
- `v2-map-practice.js:6383-6409,6500-6525`: 제단 `ritual_reveal`과 소문 `procession`에만 진입 재생, 그 뒤 일반 비트에서는 정지.
- `v2-map-practice.js:6819-6847,7057-7071`: 제단 `싸운다` 직후 소환 그림 등장, 전투 후 열린 완료 안내는 소환 원화 즉시 표시; `지나간다` 후에는 의식 그림을 유지한다.
- Godot 이전 `map.gd:show_cultist_rumor_beat(), show_cultist_altar_beat(), show_cultist_altar_followup()`는 모든 원화 레이어를 전체 `793.6×446.4` 크기로 그림 위에 겹쳐 표시하거나 정적인 InkSceneReveal만 수행하여 비율/위치/원본 CSS 재등장 시점 차이가 있었다.

## 수정

- `systems/cultist_story_layer_motion.gd` 신설: Stage S `TILE_EVENT_SCENE_RECT`에 웹의 퍼센트를 적용하고, `play()`에 소문 0.50초 / 제단 0.48초 위치·크기·투명도 모션을 구현. 의도된 비트 이외에는 정상 위치/불투명도 표시.
- `map.gd`: 원본 WebP 이미지 `CultistProcessionLayer`/`CultistRitualLayer`/`CultistSummonLayer`를 각각 실제 `TextureRect` 직접 자식으로 렌더링, 원본 의도대로 하나만 표시. 전투 선언 후에는 소환 원화가 등장, `지나간다`/전투 결과 후 최종 안내에서는 원화 종류 유지·정지. 기존 저장비트, 메뉴 버튼, 전투 선택 및 재고 관리 로직은 변경하지 않음.
- U단계의 `ui_custom_open_motion` 옵션으로 개별 이미지 애니메이션만 공통 모달의 +6px 이동 대상에서 제외. 원본 이미지·원화 수정, 리소스 교체, 외부 URL, 추가 데이터/전투 규칙 없음.

## 실행 전 기본 5원칙

1. **Trigger**: 마물 사냥꾼 단서 완료 후 마을 광신도 소문과 실제 제단 사건을 저장된 비트로 열 때, 이후 원래 `싸운다`/ `지나간다` 의사 표시.
2. **Information**: `CultistRumorEntry.current_beat()`, `CultistAltarEntry.current_beat()`, 선택·전투결과와 원본 CSS 비율/시간.
3. **Interaction**: 시각 효과는 클릭 무시. `계속`/`마치기`/`싸운다`/`지나간다`/`선택 변경` 및 출전 덱 기존 버튼만 상태 변경.
4. **Visual**: 소문 행렬 좌측 10%·하단 0%·80%, 제단 의식/소환 좌측 20%·하단 7%·60%; 원본 최초 공개 효과, 나머지는 정지.
5. **Persistence**: 비트/선택/결과만 기존 JSON 저장. Tween은 UI 종료 시 자동 정리, 원정 데이터/RNG/마물/보상 내용 변경 없음.

## 자동검사 및 보류

- `scripts/test_ui_cultist_layers_stage5x.gd`: 실제 아이 구출 → 마을 소문 → 기사단장 → 마물 사냥꾼 → 광신도 소문 6비트 → 제단 의식 3비트의 저장 경로를 이용. 각 그림의 실제 원본 WebP 연결, 기하 비율·좌표·클릭무시·등장·정지, 원본 `싸운다/지나간다` 및 선택 변경, 후속 안내의 정지 원화, 저장·재실행 복원을 검사. 임시 `user://` 세이브만 생성/정리.
- `.github/workflows/ui-cultist-layers-stage5x.yml`: Godot 4.7.2 headless 에디터 import, X 신규 검사, W/V/U/T 및 기존 P4·P5 장소/사건/오디오/전투/단일 원정 회귀검사.
- CSS의 drop-shadow 및 정확한 화면 블렌딩/색감, 저사양 Windows·Android의 체감 움직임은 실기 승인 전까지 동일하다고 주장하지 않음.
- 기존 웹 자료 읽기 전용 유지, P3-05/P4-01F/P4-02E-B/P5-03B 원화 실기 승인 미완료. 다른 개발자 main 커밋은 보존하고 합병·배포·PC 동기화 확인은 별도로 수행해야 함.
