# HTML 시각 이식 4단계 — 공동묘지 사건/시체 추출

고정 웹 참조: `necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.

## 사건 장면
- `v2-event-lab.html/css`에 맞춰 왼쪽 장면·구울 레이어·하단 대사 박스, 오른쪽 사건 설명·선택지로 정렬.
- 기존 `graveyard-child-base-v3.webp` 및 `graveyard-child-ghoul-event-v3.webp`은 Godot 원본 그대로 재사용.
- 웹 원본 `intro-dialogue-box.webp` Git blob SHA `3bab039aa347faa7546e213de941213dd8cade8d`의 정확한 파일을 Actions가 다운로드/검증 후 브랜치에만 커밋.
- 아이 구출/지나침 선택, 전투 출전, 맵 복귀, 패배 후 재도전 콜백은 변경하지 않음. 결과 화면의 공동묘지 분기에도 같은 사건 화면 프레임 사용.
- **다른 사건(기사단장/사냥꾼/광신도 등) 화면은 4단계에서 미변경**. 캐릭터 원화가 다른 사건에 잘못 노출되지 않도록 분리.

## 공동묘지 시체 추출
- `v2-map-practice.css`의 어두운 직사각형 팝업과 두 열(시체, 추출 낙인), 각 3열 카드 그리드로 변경.
- 시체 선택 시 추출 가능한 낙인만 오른쪽 표시; 원래 `RunSession.extract_graveyard`에서 시체 영구 소비와 영수증/카드 저장 처리.
- 전역 맵·순찰·계승·상점, 전투 기능의 데이터 및 저장 구조는 손대지 않음.

## 검증 계약
Trigger: 공동묘지/사건 착지, 시체 추출 기능. Information: 상황·대화·선택·영구 소모. Interaction: 실제 기존 함수 호출. Visual: 사건 두 열과 대사 오버레이, 추출 두 열 카드 그리드. Persistence: 결말 저장, 전투 결과, 시체 소모와 카드 중복 방지.

자동 테스트: `scripts/test_ui_graveyard_event_parity.gd`; 원래 P4 공동묘지 전체 분기/승패/재도전 및 3단계/UI/집귀환 회귀 병행. 실제 Windows/Android 1280×720 이미지 비교는 완료 판정과 분리.
