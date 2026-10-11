# 5단계 G — 보관함 초과 UI + 5단계 F 통합 검증 (2026-10-11)

## 기준 / 병렬 작업 보존
- Godot F 원본: `feature/ui-parity-treasure-reward-stage5f-20261011@4c5eb45`.
- 이미 존재하던 전투 편성/초과 UI: `feature/ui-parity-deck-overflow-stage5f-20261011@e1357ad`.
- 원본 HTML/JS 고정 소스: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- 두 브랜치는 3개 커밋만큼 분기되어 있었고, 변경 파일이 겹치지 않으므로 두 부모를 갖는 별도 통합 커밋에 각각의 작업을 보존한다. `main`과 기존 작업 브랜치는 변경하지 않는다.

## 적용 범위
- `systems/reward_overflow.gd`: 일반 760px 어두운 카드 보관함 / 영혼 포획 1120×360 별도 가로 11장 창, 신규 표식, 버릴 카드 금빛 윤곽·상승, 선택 전 확인 비활성화, 선택 후에만 `session.claim_reward` 수행.
- `systems/battle_deck.gd`: 선택 카드 4슬롯과 원본 피격률, 출전 순서, 카드 손패 위치·호버·키보드 포커스.
- F의 `systems/treasure_reward.gd`, F 전용 테스트, D·E 전투·수확 UI, 기존 저장·보상·중복 지급 방지 코드는 유지.
- G의 범위는 **기존 UI와 인터랙션 이식 및 충돌 검증**이며 게임 보상/보관 용량/전투 규칙을 신설·변경하지 않는다.

## 다섯 기본원칙
1. Trigger: 전투 진입시 덱 편성, 보상 확정 과정에서 보관 용량 도달 후 초과 화면.
2. Information: 보관 수량, 기존 카드와 신규 카드, 버릴 후보 선택, 전투 편성 순서/피격률.
3. Interaction: 카드 클릭/터치/포커스, 버리기 확정, 전투 시작.
4. Visual: 웹 원본과 동일 계열의 크기·배치·강조/잠금/카드 상승, 포획 전용 한 줄 배치.
5. Persistence: UI 선택 상태는 저장하지 않음. 기존 세션의 단 한 번 보상 확정, 오류 시 같은 선택 재시도.

## 통합 자동검사
- `.github/workflows/ui-deck-overflow-stage5g.yml`: Godot 4.7.2 import, G 편성/초과 UI, F 보물상자, E 영혼 수확, 실제 보물→집→다음 바퀴, 전투→맵 복귀, 단일 원정 전체 흐름.
- 검사 성공과 별개로 Windows/Android 1280×720 실제 터치, 겹침, 가로 스크롤, 긴 이름은 **시각 검사 미완료**.
- 포획 초과용 원본 JPEG가 아직 미이식되어 네이티브 양피지색 대체 상태. 이 항목은 **원본 아트 동등 판정 보류**.
- `main` 병합·Pages 배포·PC 동기화는 별도이며 이 브랜치 생성으로 자동 완료 처리하지 않는다.
