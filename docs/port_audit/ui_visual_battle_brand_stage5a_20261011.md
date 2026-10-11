# 5단계 A — 전투 낙인 정보판 시각 이식

## 원본과 대응
고정 HTML `necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c` 의 `v2-auto-battle-practice.html` 55~80행, `v2-auto-battle-practice.css` 625~705행 기준.
원본 낙인 정보판은 중앙 **가로 82%, 높이 78%**, 주사위 결과 이미지 6장, 1열 마물 + 6열 주사위 숫자, 아군/적군 최대 8행, 누르면 효과 설명을 확인하는 구조.

기존 Godot `systems/brand_reference.gd`는 헤더가 숫자 텍스트이고 전체 판 비율/상태 설명 구역이 원본과 달랐다. `assets/battle/dice/result-01.png`~`result-06.png` **기존 원본 이식 이미지를 직접 재사용**, 신규 이미지 파일을 추가하지 않음.

이번 수정:
- 1280×720에서 원본 비율의 정보판과 마물/주사위 격자, 6장 헤더 이미지.
- 아군/적군 각각 최대 4행; 살아있는 일반 소환 제외 마물 순서를 진영·슬롯 기준으로 유지.
- 축복 ✦, 저주 ☠, 발동 없는 칸 표시 및 눌러 효과 설명하는 기존 기능 유지.
- 다양한 전투 병력 수에 맞춘 스크롤; 데이터 손실·클리핑 방지.
- `Inheritance.normalize`, `face_mode`, `describe` 기존 규칙 유지. 실제 낙인 판정·주사위 RNG·전투 저장/복원 코드는 **불변**.

## 기본원칙
1. Trigger: 전투 준비 중 낙인 정보판 버튼.
2. Information: 마물 소속과 이름, 주사위 1~6, 축복·저주, 실제 효과 설명.
3. Interaction: 기존 `BrandReference.setup(rules)`, 전투 일시 상태의 오버레이 열기/닫기; 다른 턴 진행 영향 없음.
4. Visual: 원본 양피지 프레임·주사위 결과 그림·7열 × 8행 격자·하단 설명.
5. Persistence: 읽기 전용 화면이며 전투 `rules` 변경 및 저장 데이터 변경 없음.

검증: `scripts/test_ui_battle_brand_parity.gd`, 기존 전투 낙인 판정 `scripts/test_battle_source_parity.gd`, P4 전투/맵 복귀 검사를 별도 CI에서 수행.
**아직 실제 Windows/Android 화면을 나란히 캡처한 시각 승인이 아니며**, 전투 화면 전체/군단 HUD/유닛 정보 팝업은 5단계 후속 작업으로 남음.
