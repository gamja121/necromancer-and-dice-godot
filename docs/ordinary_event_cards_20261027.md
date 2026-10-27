# 일반 사건 전체 카드 원화 — 2026-10-27

Issue #323: 모든 일반 사건을 같은 양피지 카드 양식으로 표시하고, 전용 그림이 없던 발견 사건을 새로 그린다.

## 전체 적용 목록

실제 일반 사건 추첨 목록은 `Routine.ORDER` 6종과 `Discovery.ORDER` 5종이다. 메인 스토리와 장소별 행동 화면은 별도다.

| 사건 | 원화 (`assets/map/events/`) |
|---|---|
| 쓰러진 병사 | `routine_wounded_soldier.webp` |
| 버려진 마차 | `routine_abandoned_wagon.webp` |
| 길 잃은 행인 | `routine_lost_traveler.webp` |
| 그을린 야영지 | `routine_smoke_camp.webp` |
| 낯선 행상인 | `routine_wandering_merchant.webp` |
| 깨진 봉인 | `routine_broken_seal.webp` |
| 언덕 발견 | `discovery_hill.png` (신규) |
| 숙영지 발견 | `discovery_camp.png` (신규) |
| 공동묘지 발견 | `discovery_graveyard.png` (신규) |
| 세계수 발견 | `discovery_world_tree.png` (신규) |
| 제단 발견 | `discovery_altar.png` (신규) |
| 사건 타일 미리보기 | `ordinary_event_preview.png` (신규) |

신규 6장은 내장 `image_gen`으로 기존 깨진 봉인 원화의 금박·울트라마린 고서 화풍에 맞춰 제작했다. 픽셀 후처리 없이 생성 PNG를 사용한다. 기존 승인된 반복 사건 6종 원화와 구형 장소 배경 파일은 보존한다. 원본 및 최종 프롬프트는 로컬 raw_assets의 `ordinary_event_cards_20261027`에 별도 보관한다.

## 공통 표시와 입력

- 전체 카드가 `routine_event_card_base_v2.png`와 동일한 제목·그림·본문 배치를 사용한다. 정사각 삽화는 `KEEP_ASPECT_CENTERED`로 전체 테두리를 표시한다.
- 반복 사건의 오른쪽 수락/거절 선택과 저장 재시도는 유지한다.
- 발견 사건은 오른쪽 양피지 안내에 실제 해금 타일과 해금 설명을 표시한다. 카드·오른쪽 영역·어두운 배경의 클릭/터치로 한 번 닫힌다.
- 스토리 없는 사건 타일 미리보기는 별도 중립 그림과 미리보기 설명을 사용한다. 해당 화면을 열고 닫을 때 추첨·보상·저장을 호출하지 않는다. 현재 타일의 기존 메인 스토리 재개 우선순위는 유지한다.
- 발생 확률, 장소별 자격 조건, 보상·방문 영수증·원정 저장 형식은 변경하지 않는다.

## 검증 범위

Godot 4.7.2 가져오기, 카드 UI·오른쪽 선택지·실제 발견 도착·반복 사건·다섯 발견 회귀와 Windows 렌더링을 확인한다. 미리보기와 발견 닫기는 실제 뷰포트 입력을 사용하고, 미리보기 전후 원정·RNG·저장 파일 불변성을 확인한다. 한국어 전체 카드 및 영어 긴 해금 안내/미리보기는 별도 화면으로 확인한다. 로그와 캡처는 작업 공간에 보관한다.

로컬 검증 결과: import 오류 없음; 발견 UI 0실패; 오른쪽 선택 97/0; 실제 발견 도착 73/0; 반복 사건 333/0; 다섯 발견 133/0. Windows 실제 렌더링은 210/0, 화면 14장(한국어 12, 영어 2)을 기록했다. 실행 로그에 오류·종료 누수가 없고 `git diff --check`도 통과했다.
