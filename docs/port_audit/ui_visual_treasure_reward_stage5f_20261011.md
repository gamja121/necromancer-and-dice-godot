# 5단계 F — 보물상자 카드 보상 시각 이식 (2026-10-11)

## 기준
원본: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`, `v2-map-practice.css` 185–245행 / `v2-map-practice.html` 174–179행.

## 주요 변경
- 현행 Godot 보물상자 화면의 3장 카드 위치(314/530/746px), 크기(170×254), 회전(-7/0/+7)와 이미지, 4프레임 열기, 미믹 전환은 유지.
- 원본의 등장 효과: 카드당 420ms, 110ms씩 시차, 아래 22%에서 78% 크기로 등장.
- 선택 카드: 8% 위로 상승, 108% 확대, 금빛 테두리/광채; 미선택 카드: 48% 알파·22% 흑백·72% 밝기.
- 두 번째 클릭으로 거래가 **실제로 저장된 이후에만** 획득 카드 강조와 나머지 카드 퇴장. 기존 인벤토리로 카드 이동 효과 유지.
- 보상 상태·저장 중단 복원·초과 보관함·영수증·중복 지급·미믹·RNG 로직 변경 없음.

## 다섯 원칙
1. Trigger: 실제 보물상자 도착/열림 및 카드 클릭.
2. Information: 3개 원본 카드/선택 여부/한 번 더 눌러 확정·저장 상태.
3. Interaction: 기존 `select_treasure`, `prepare_treasure_reward`, `claim_reward` 호출.
4. Visual: 한 줄 3장 등장, 금빛 윤곽·선택 상승, 미선택 흐림/흑백, 획득 확인.
5. Persistence: JSON 구조 및 카드 소모·지급 불변; 중단 복원 및 중복 수령 검증.

검증: 원본 구조 전용 `test_ui_treasure_reward_parity.gd`, 실제 `test_p4_reward_home_lap_integration.gd`, 이전 5E 영혼 수확 및 기존 단일 원정. Windows/모바일 1280×720 시각 승인 별도; 픽셀 동일 판정 아님.
