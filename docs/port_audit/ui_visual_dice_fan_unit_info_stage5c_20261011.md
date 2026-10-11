# 5단계 C — 전투 주사위 카드 팬 / 마물 정보창 원본 대조

고정 HTML: `v2-auto-battle-practice.html`, `v2-auto-battle-practice.css` 595~623, 275~306행, `v2-auto-battle-practice.js` 1223~1406행 (`reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`).

### 수정 내용
- 지도 전투 상태에서 주사위 카드 덱은 원본의 **오른쪽 아래 가로 13% 아트 버튼**으로 변경. `map-card-deck.png`와 `map-card-deck-open.png` 기존 아트 사용.
- 기존 `DiceHand`의 불투명 풀스크린 맵 오버레이 대신 **전투에서만** 투명한 닫기용 배경과 오른쪽 아래 카드 팬 표시. 오른쪽에서 왼쪽으로 5장, HTML의 x오프셋 4/-78/-160/-242/-324%, 기울기 +10/+5/0/-5/-10도 대응.
- 1280×720 독립 전투 / 1280×530 지도 내 임베디드 전투에서 각각 실제 전투 화면 아래에 정렬.
- 불가 카드 시각 비활성, 실제 `DragCard`와 기존 `DiceControl.can_use`, 소비 신호 `chosen(id)` 보존.
- `UnitInfo`는 원본 정식 프레임/초상/능력치/군단 정보와 좌우 2패널 위치가 이미 이식되어 있어 **불필요한 아트 재작업 없이** 5C에서 정보·버튼·전투 비변경 검증을 추가.
- 지도에서의 DiceHand(이동 주사위) 방식은 변경하지 않음.

### 변경전 원칙
Trigger: 이동이 아닌 전투 준비중 덱 아이콘. Information: 보유 장수, 상태, 사용할 카드 가능 여부. Interaction: 기존 소비/드래그/닫기 콜백. Visual: 원본 우하단 덱과 5장 팬. Persistence: 기존 카드 재고/주사위 RNG 저장 경로 불변.

### 검증과 미완료
`scripts/test_ui_dice_fan_unit_info_parity.gd` (5장 배열, 비활성, 빈 덱, 임베디드, 정보창), 기존 전투 HUD·낙인 확인표·규칙·실제 맵 복귀 회귀.
**PC/Android 실제 픽셀 이미지 비교는 아직 하지 않았고** 전투 하단 마물 카드 도킹과 5단계 전체도 후속 검증 사항이다.
