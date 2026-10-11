# 5단계 F — 전투 편성판과 마물/주사위 보관함 초과 선택창

기준: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c` (읽기 전용).

## 원본 근거
- `v2-map-practice.css` 598~634행, `v2-map-practice.js` 3310~3361행: 91% 너비 아트 편성판, 4슬롯 고정 앵커, 출전 카드 순서·피격률, 하단 68% 너비/34% 높이 카드 겹침, 선택 카드 -22% 상승.
- `v2-auto-battle-practice.css` 337~363행: 선택 카드의 순서 원형 배지(보조 안내).
- `v2-map-practice.css` 822~903행, `v2-map-practice.js` 3758~3845행: 최대 760px 어두운 카드 보관 패널, 가로 스크롤, 신규 카드 표식, 버릴 카드 한 장 선택시 -6% 상승/금빛 강조, 확정 전 버튼 잠금.
- `v2-auto-battle-practice.js` 2607~2672행: 영혼 포획으로 발생한 보관함 초과는 신규 카드 자체 버리기를 허용.

## 적용 범위
- `systems/battle_deck.gd`: 보유 개체 **id**를 기준으로 1~4마리 선택하며, 정확히 4개 앵커 유지. 피격률 1명 100%, 2명 35/65%, 3명 20/33/47%, 4명 15/20/27/38% 유지. 선택 순서를 보유 카드의 황금 원형 배지로 표시; 키보드 포커스 카드 상승을 호버와 동일하게 표시.
- `systems/reward_overflow.gd`: 보상 선택 기존/신규 카드 후보 및 개수 변동 없이 보관 창 크기·색·가로 스크롤·신규 배지·금색 선택 강조·확정 버튼 시각 잠금 이식. 선택한 카드만 올라가며 나머지 카드 색을 바꾸지 않음.
- 반드시 **기존 `session.start_encounter`, `session.start_story_encounter`, `session.claim_reward` 호출·반환·저장·보상 영수증 데이터 불변**.
- HTML 원본에 없는 보스/사건/낙인 규칙 신설 없음.

## 5원칙
1. Trigger: 전투 선택 진입 / 용량 10장·5장 초과 보상 선택.
2. Information: 소유 개체 ID, 출전 순서·피격률, 신규 보상, 버릴 카드 표시.
3. Interaction: 카드 터치/클릭/키보드, 출전 시작, 한 장 버리기 확정.
4. Visual: 원본 스케일과 카드 겹침, 4개 슬롯, 신규 배지, 선택 카드 부각.
5. Persistence: 기존 시점의 출전·보상 단일 커밋만 사용, 사전 선택은 저장 미반영.

## 검증
- 전용 `scripts/test_ui_deck_overflow_parity.gd`: 슬롯·선택 순서·정확한 피격률·4마리 제한·마물 10+1장/주사위 5+1장·신규 버리기·저장 실패 재시도.
- 기존 P4 실제 맵 전투/수확 복귀 및 보물 카드→집→다음 바퀴 회귀.
- `.github/workflows/ui-deck-overflow-stage5f.yml` 트리거.
- Godot 헤드리스 통과 후에도 Windows PC/Android 실제 터치·슬롯/겹침·긴 이름 및 스크롤 화면의 원본 나란히 시각 검증은 **미완료**. 통과 전 `main` 병합/배포하지 않는다.
