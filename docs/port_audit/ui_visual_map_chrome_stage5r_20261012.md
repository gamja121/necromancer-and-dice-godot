# UI 이식 5단계 R — 장소·사건 전면창 뒤 지도 조작 UI 가림 (2026-10-12)

## 원본 비교 및 발견

- 고정 기준: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- `v2-map-practice.css:179` — `.map-board.is-tile-event-open` 동안 `.dice-controller`, `.tile-info`, `.map-toolbar`, `.contamination-hud`에 `visibility:hidden`을 적용한다.
- `v2-map-practice.js:3956-3966`과 `:4597-4605` — 장소를 열 때 위 클래스를 추가하고 닫을 때 제거한다.
- Q 단계는 음악 옵션 버튼과 옵션 패널 겹침만 고쳤다. 기존 Godot `map.gd`는 뒤쪽 맵 주사위, 중앙 정보, 새 원정 버튼, 마물 보유/주사위 카드 아이콘 및 오염도 표시를 숨기지 않았다. 배경 반투명 덮개만으로 원본의 HUD 가림을 재현하지 못했다.

## 구현 범위

1. `map.gd`에서 `render()`가 직접 만드는 **지도 조작 UI 8개**(주사위, 중앙 상태, 지역·바퀴 정보, 새 원정, 보유 마물 버튼과 수량, 주사위 카드 버튼과 수량)를 `map_chrome` 배열로 관리한다.
2. `MapPresentation`이 그리는 **오염도 HUD**는 별도로 `presentation.gauge`의 `visible`만 변경한다. 이미지·효과·애니메이션 자산을 교체하지 않는다.
3. 기존 `overlay` setter에서 Q단계 `map_audio.set_modal_blocked()`와 동시에 `_sync_map_chrome()`를 호출한다. 창이 열리는 즉시 지도 UI를 숨기고 닫히면 복원한다. 다른 장소/상점/집/보유창/덱 선택도 같은 공용 장치로 처리한다.
4. **24개 지도 타일, 주인공, 맵 배경, 사건 원화, 보상·전투 로직은 변경하지 않는다.** 창 뒤 지도 맥락이 보이는 원본 방식을 보존한다.
5. `render()`가 맵을 새로 만들 때 이전 참조를 버리고 현재 보드의 8개 UI만 재등록한다. 키보드 입력·사용자 데이터·오디오 설정·저장 구조는 바꾸지 않는다.

원본 HTML에서는 `is-tile-event-open`에만 이 규칙을 적용한다. Godot에서는 Q단계와 동일하게 전면 `overlay` 전체에 공통 적용해 덱/인벤토리 앞에서 기존 맵 UI가 노출되지 않도록 한다.

## 게임 시스템 5원칙

1. **Trigger:** `overlay` 설치, 제거, `render()`에 의한 지도 재구성.
2. **Information:** 현재 `overlay` 생존 여부, 현 지도에서 생성한 `map_chrome` 8개, `presentation.gauge`.
3. **Interaction:** 전면창 열림 중 지도 조작 요소를 보이지 않도록 처리. 실제 이동·주사위·마물·보상·배경 타일의 규칙은 그대로 유지.
4. **Visual:** 지도 조작 UI와 오염도 표시를 숨기고 원본 타일/주인공은 계속 렌더링; 닫으면 정확히 복원.
5. **Persistence:** `visible`은 휘발성 화면 상태. 세이브, RNG, 보상 영수증, 오디오 환경설정은 읽거나 수정하지 않음.

## 자동검사 및 미검증

- 신규 `scripts/test_ui_map_chrome_stage5r.gd`: 실제 `map.tscn`에서 보드 HUD 8개+오염도 숨김/복원, 타일 24개/주인공 유지, 장소/행동창/집/보유/카드/전투 편성, 맵 재렌더, 세계 상태·난수·보상 불변 확인.
- `.github/workflows/ui-map-chrome-stage5r.yml`: Godot 4.7.2 import 후 신규 검사와 Q 오디오, M 오디오 옵션, P 공동묘지 대화, N 제단, O 순찰, P4 지도·장소, 단일 원정 end-to-end를 순서대로 실행.
- **GitHub Actions CI 실행 결과는 별도로 확인해 기록한다.** 이 문서의 검사 목록만으로 성공을 단정하지 않는다.
- **Windows·Android 실제 화면**에서 그림 잘림, 계층/터치, 다양한 화면 비율, 실제 소리 검증은 아직 남아 있다. UI 이식 완료, main 병합, 배포, PC 동기화로 판단하지 않는다.
- 원본 웹 저장소와 유저 원화·기존 저장 파일은 그대로 보존한다.
