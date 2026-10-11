# W080 — 웹 고정본 마물 46종 데이터 및 출현·보상 풀 정합성 (2026-10-11)

## 비교 기준

- 고정 웹 소스: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`
- 원본 `v2-design-data.js`의 `rows`: **46종**. 일반·고급·영웅 43종, 소환물 전용 특수 3종(씨앗, 새끼거미, 평민 고블린).
- Godot `data/units.json`: 원본 46종과 **12개 필드(slug/name/hp/attack/speed/grade/legions/brands/passives/chance/bonus/amount)를 전수 비교하여 차이 없음**. 별도로 `dracula` 1종을 포함하므로 정의는 47종.
- 데이터의 기준 사본을 `scripts/fixtures/web_v2_units_46.json`에 고정. 기존 웹 저장소 삭제 이전에 출처와 기존 게임 수치·속성 증거를 독립 보존할 수 있게 함.

## 46종 기준을 유지하는 방법

1. `EncounterGenerator.ROSTER`는 원본의 모든 일반·고급·영웅 43종과 소환물 2종을 유지하지만 Dracula는 제외. `eligible_roster()`는 특수 소환물 2종을 걸러 일반 랜덤 전투에 **43종만** 노출.
2. 스테이지 난수 생성(`slugs`), 정찰 기반 선출(`scout_intel`), 실제 보물상자 새 마물 후보(`RunSession.open_treasure`)가 공통 `eligible_roster`를 사용하여 웹 범위를 초과한 마물을 생성하지 않음.
3. **Dracula 삭제 금지.** 이미 Godot에 있는 `data/units.json`의 Dracula 레코드, 아트, 애니메이션, 이전 세이브의 개체/낙인 복원은 전부 계속 지원한다. 원본에 없는 확장이라는 이유로 기존 플레이어 자산을 훼손하지 않음.
4. 따라서 기본 게임은 원본 마물 범위를 유지한다. Dracula를 정식 랜덤 등장 대상으로 되돌리는 변경은 별도의 미래 콘텐츠 결정/테스트로 분리한다. 이 변경은 새로운 콘텐츠 추가가 아니다.

## 자동검증

- `scripts/test_web_unit_catalog_parity.gd`는 원본 fixture 46종의 필드 전체를 Godot `data/units.json`과 각각 비교한다.
- 실제 스테이지별 510회 일반 조우, 48회 정찰 기반 조우, 48회 보물상자 열기에서 Godot 추가 마물이 등장하지 않는지 검사.
- Dracula 보유 마물이 들어 있는 Godot `MapState` 저장 스냅샷이 계속 복원되는지도 확인한다.
- `.github/workflows/story-state-regression.yml`의 별도 W080 작업에서 기존 회귀검사와 함께 진행한다.

## 남은 사항

- W080은 **원본 46종의 데이터·일반 출현·보상 정합성 코드 검사 기준** 완료로 판정한다. 기존 이미지/전투 모든 개별 종의 실제 실행 중 공격·피격·사망 모션은 W195 및 P4-04에서 계속 검사한다.
- Windows GUI 실제 플레이와 영구 백업/웹 원본 저장소 삭제는 각각 P4, P5 단계에서 별도 처리한다.

## 이식 5원칙

- Trigger: 전투의 새 조우·정찰, 새 보물상자 마물 후보 생성.
- Information: 46종 원본 데이터, 43종 비소환 후보 및 추가 Dracula 보존 정책.
- Interaction: 기존 덱/보상 선택 흐름과 UI 변경 없음.
- Visual: 기존 모든 아트·애니메이션 파일 변경 없음.
- Persistence: 이미 보유한 Dracula 및 기존 저장·낙인 보존.
