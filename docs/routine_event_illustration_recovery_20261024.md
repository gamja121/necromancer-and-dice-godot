# 일반 사건 6종 원화 연결 조사 및 부분 복구 — 2026-10-24

## 사용자 신고
실제 화면에서 **버려진 마차** 사건에 마차가 아니라 일반 마을 전경이 나온다. 이전에 제작한 사건별 삽화를 되찾아 표시한다. 원래 카드 양피지 UI, 설명, 보상, 선택, 저장 규칙은 바꾸지 않는다.

## 재현 가능한 원인
`systems/routine_event_catalog.gd`에 사건별 그림이 장소/메인 사건의 이미지로 지정되어 있다. `systems/routine_event_card.gd`는 해당 `entry.illustration`을 `event_discovery_card.gd`에 그대로 전달한다. 따라서 원인 중 하나는 렌더러가 아니라 **카탈로그 기본 경로**다.

| 사건 ID | 사건명 | 현재 기본 그림(원본 없을 때) | 독립 원화 우선 경로 |
|---|---|---|---|
| wounded_soldier | 쓰러진 병사 | knight-commander-village-day.webp | routine_wounded_soldier.png |
| abandoned_wagon | 버려진 마차 | village.jpg | routine_abandoned_wagon.png |
| lost_traveler | 길 잃은 행인 | forest.jpg | routine_lost_traveler.png |
| smoke_camp | 그을린 야영지 | camp.jpg | routine_smoke_camp.png |
| wandering_merchant | 낯선 행상인 | village.jpg | routine_wandering_merchant.png |
| broken_seal | 깨진 봉인 | altar.jpg | routine_broken_seal.png |

위 상대 경로는 모두 `res://assets/map/events/` 아래다. **해당 파일 이름을 미리 정한 것이지, 실제 6개 원화가 GitHub에 존재한다고 주장하는 것은 아니다.**

## 현재 원화의 실물 확인
- GitHub `main`의 `assets/map/events/` 목록 및 전체 추적 트리를 대조했다. `routine_*.png` 원화 6종 모두 **GitHub에는 없음**.
- 과거 제작 자료 `necromancer_event_card_assets_20261014.zip`을 실제 열어 `assets/map/events/routine_wounded_soldier.png` **한 장**이 있음을 확인했다. 2026-10-14 생성 원본 PNG와 바이트 동일, SHA-256: `9555229e814883ceb89ae2a2c0446508cc3a86bb273e71f725dcab2f0a55da92`.
- 이 ZIP의 나머지 이미지는 '언덕/숙영/공동묘지/세계수/제단' 발견용 원화 및 양피지 카드 배경이다. **다른 일반 사건 5종에 재사용하면 안 됨**.
- 별도 `tile_event_5_replacement_pack.zip`에는 village/home/altar/fortune-teller/graveyard용 구형 장소 그림만 있다. 독립 루틴 5종 원화가 아니다.
- 나머지 루틴 원화는 확인한 GitHub 저장소와 자료 ZIP에서 발견되지 않았다. 원본 경로가 확인되기 전까지 새로운 그림을 원본이라고 부르지 않는다.

## 이번 코드의 범위
- `Routine.details(id)`가 `routine_<id>.png`로 된 **해당 사건 전용 원화가 로드 가능할 경우에만** 우선 사용한다.
- 전용 PNG가 없는 현재 GitHub 빌드에서는 기존 기본 그림을 유지하여 누락된 경로로 인한 빈 카드/오류가 생기지 않도록 한다. **그러므로 이미지가 설치되지 않은 버려진 마차 화면은 여전히 마을 그림이 나온다**.
- 테스트로 전용 경로의 사건 ID 정합성, 있는 경우 우선 표시/없는 경우 폴백 유지, 기존 카드 보상과 클릭·저장을 검증한다.
- 새 원화 생성, 기존 장소 그림·카드 원본 삭제, 보상/효과/주사위 확률/저장 구조 변경 없음.

## 미완료 — 원상복귀 완료 조건
1. 확정된 6종 각각의 전용 원본 이미지를 안전하게 확보한다. 특히 `abandoned_wagon`은 **마차가 보이는 실제 승인 원화**여야 한다.
2. 실제 바이너리 파일을 위 자산 폴더로 GitHub에 추가하고 Godot import 및 6종 화면을 검증한다.
3. CI/PC 실기·최신 main 병합 및 PC 동기화를 확인한 뒤에야 **전체 6종 복구 완료**라 보고한다.

## 5원칙
- **Trigger:** 루틴 사건 실제 도착/재개 시 기존 카탈로그의 `details` 호출.
- **Information:** 저장된 사건 ID, 그 ID 전용 PNG의 `ResourceLoader.exists` 결과, 기존 기본 그림.
- **Interaction:** 원래 두 선택 버튼과 보상 수령/거절 그대로.
- **Visual:** 원본 PNG가 존재하면 그 사건만의 이미지. 없다면 현행 그림 유지(원화 미확보 상태를 문서화).
- **Memory:** 원정 저장/방문 영수증/효과/확률 등 변경 없음.
