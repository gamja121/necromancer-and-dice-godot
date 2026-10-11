# 5단계 T — 공동묘지 구울 원화 비율·등장/대기 애니메이션 이식 (2026-10-12)

## 직접 검증한 웹 원본 대비 차이

- 고정 원본: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c` (수정하지 않음).
- `v2-map-practice.css:2029-2055`: `.graveyard-story-ghoul-layer`는 원화 래퍼의 **left 55%, top 18%, width 30%, height 64%**, 투명도 0.96, 변형 기준점 58%/82%.
- `v2-map-practice.css:2260-2280`: 0.82초 투명도·위치(+18%/+4%에서 정위치)·배율(0.86→1)·회전(2°→0°) 등장 후, **3.2초** 주기로 왼쪽 -1.2%/위 -0.6%와 -0.2°~+0.25° 미세 움직임.
- `v2-map-practice.js:5559-5573,6140-6160`: `threat` 비트에서만 등장 애니메이션 적용. `dialogue` 및 `choice` 비트는 이미 등장한 구울을 대기 애니메이션으로 직접 표시.
- 변경 이전 Godot `map.gd:show_graveyard_child_beat()`의 `StoryCharacterLayer`는 **원화 전체를 채우는 793.6×446.4 TextureRect**였고 움직임이 전혀 없었다. 이야기 첫 장면과 대화·선택 로직은 이미 존재했다.

## 수정 내용

- `map.gd`: 기존 Stage S의 1280×720, `TILE_EVENT_SCENE_RECT`를 유지하고, 위 웹 퍼센트를 `GRAVEYARD_GHOUL_FRACTIONS`로 적용한다. 화면 내 직사각형은 (679.68, 217.152), 238.08×285.696 (Godot 원화 박스에 대응시키기 때문에 고정 웹의 *전체 stage* 절대 크기와는 다름).
- 직접 자식 `StoryCharacterLayer`는 TextureRect **프레임 컨테이너**로 보존한다. 실제 원본 그림은 하위 `GhoulSprite` TextureRect로 1회 렌더링한다. 이렇게 해야 기존 `PanelEffectsModule`이 상위 프레임 입장·퇴장만 움직이고 하위 그림의 등장·대기 이동과 충돌하지 않는다. 버튼 터치 간섭은 계속 무시.
- `systems/graveyard_ghoul_motion.gd`: CSS 등장→대기 움직임을 Godot Tween으로 구현. 등장 여부는 기존 스토리의 `beat_index==1`만 확인한다. Tween은 TextureRect에 묶여 화면 종료·재시작 시 자동 해제되고 별도의 저장 필드를 만들지 않는다. CSS blur/drop-shadow/brightness 필터 픽셀 동일성은 아직 보장하지 않는다.
- **원본 소스 그림, 대화 프레임, 사용자 변경 원화 4종을 교체·삭제하지 않음**. 스토리 4비트, `계속`, `아이를 구한다`, `지나친다`, 전투 진입, 저장·보상 호출 순서는 변경하지 않는다.

## 기본 5원칙

1. **Trigger:** 원래 공동묘지 사건의 `threat` 비트 표시 시만 등장 효과. 이후 구울 포함 비트는 대기 모션. 신규 스토리 이벤트 없음.
2. **Information:** 웹 ghoul CSS 좌표 및 애니메이션 설정, 현재 `beat_index`, 기존 스토리 상태.
3. **Interaction:** 진행·선택·재시작은 기존 버튼과 세이브 상태가 담당. 장식용 `GhoulSprite`는 클릭/터치 무시.
4. **Visual:** 원화 오른편 소형 구울 배치와 0.82초 등장 및 3.2초 미세 이동을 표현. 서사 대화·보드 HUD 구성은 유지.
5. **Persistence:** 그림/tween 정보는 저장하지 않는다. 실제 사건 비트만 종전 JSON에 저장되고, 닫기·재실행 시 저장된 비트에 따라 같은 원본 그림을 다시 표시.

## 자동 및 실기 검증

- 신규 `scripts/test_ui_graveyard_ghoul_motion_stage5t.gd`에서 실제 맵의 4비트, 원본 WebP 텍스처, CSS 상대 좌표, 첫 프레임 투명도/변형, 0.82초 종결, 대기 drift, 모달 효과와 경쟁 없는 정위치, 대화·선택 기능, 빠른 종료 시 해제, 임시 저장 재실행, RNG/보상/전투 불변성을 확인.
- `.github/workflows/ui-graveyard-ghoul-stage5t.yml`: Godot 4.7.2 import, 신규 T 검사, 기존 공동묘지 이야기·추출(Stage 4), P4 중단 복원, S/R/Q/M 일반 장소·오디오, 제단·순찰·P4 맵 이동·4개 원화 연결·전체 원정 회귀 수행.
- **Windows/Android에서 실제 초당 프레임, 구울의 등장·대기 자연스러움, CSS의 밝기/그림자/흐림과 화면 비율 비교는 별도 승인 필요.** Headless CI 성공은 사람의 시각 승인과 다르다.
- 다른 작업자 main 변경을 병합하지 않으며 기존 웹 소스/데이터·원본·사용자 저장은 보존한다.
