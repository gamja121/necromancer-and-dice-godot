# 전투 UI 5단계 E — 영혼 수확 선택판 시각 이식

웹 참조: `necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
`v2-auto-battle-practice.css` 32~47행: 화면 상단 7%·가로 최대 430px의 독립된 수확 패널, 후보 카드 82% 불투명, 선택 카드 녹색 테두리·화살표 강조.

## 적용
- `systems/corpse_capture.gd`에서만 새 `CaptureInfoPanel` 및 타이틀/상태 문구. 버튼 입력을 가리지 않도록 MouseFilter IGNORE.
- 1280×720 전투 / 1280×530 맵 내 전투 양쪽에서 top 7% 중심 정렬.
- 시체마다 `CaptureSelectedOutline`을 별도 자식 노드로 추가하고 선택 시만 표시. 기존 아이콘·낙인 프레임·제단 강화 배지를 변경하지 않음.
- 미선택 후보의 불투명도 0.82. 선택 후보 초록색 테두리와 기존 화살표 표시.
- 실제 `session.select_capture`, `session.roll_capture`, `session.claim_reward` 및 시도횟수/고정 대상/영구 사망/저장/맵 복귀 코드는 **변경 없음**.

## 다섯 원칙
Trigger=승리 후 영혼 수확. Information=대상, 필요 눈금, 남은 시도, 잠금 상태. Interaction=기존 카드/유닛 선택과 주사위 굴림. Visual=상단 배너·녹색 선택 윤곽·화살표. Persistence=기존 선택/판정 저장 데이터와 영수증 불변.

검증은 `scripts/test_ui_corpse_capture_parity.gd`, P4 전투→수확→맵 복귀 회귀, 이전 5D 카드 도킹 검사로 시행. 실제 Windows/Android 캡처 비교 및 원본 프레임 이미지 완전 동일 판정은 별도.
