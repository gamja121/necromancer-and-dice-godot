# 마물 상점 창 UI — 2026-10-29

사용자 승인: 테이블을 없앤 단일 교환창 시안, 상인의 제안은 5장이 아닌 3장. 앞서 승인한 방문당 성공 거래 3회와 실제 남은 횟수 표시를 연결한다.

## 구현

- 1280×720 안의 단일 창 `(96,36,1088,648)`. 왼쪽에 내놓을 마물, 오른쪽에 제안 3장, 아래에 보유 마물과 고정 안내/나가기/교환 확정.
- 기존 마물 카드 레이어와 초록 주사위 카드 원화를 사용한다. 선택 테두리만 덧붙이며 선택하지 않은 유효 카드를 변색시키지 않는다. 많은 보유 마물만 하단 목록을 가로로 스크롤한다.
- 선택은 거래가 아니다. 확정 성공 후 마물·상품·횟수가 함께 저장된다. 마지막 마물, 가득 찬 주사위 보관함, 저장 실패를 기존 방식으로 처리한다.
- 모든 등급의 제안은 3장이다. 등급별 후보/주사위 풀은 유지한다. 이전 4·5장 캐시는 앞 3장의 ID와 RNG를 보존한다.
- 횟수는 같은 방문의 `shop_trade.used`에 저장하며 과거 저장의 누락 값은 0이다. UI를 닫거나 재시작해도 유지하며 새 방문에서만 초기화한다.
- 제단의 기존 공용 버튼 스타일, 예언, 회복, 원화 및 개인 저장은 변경하지 않는다. 테이블 원본 자산은 보존하고 상점 참조만 제거한다.

## 프레임 제작 기록

모드: 내장 ImageGen, 승인한 창 시안을 참조한 편집. 최종 사용 자산: `assets/map/ui/shop_window_frame.png`. 실제 카드/글자/선/버튼은 이미지에 구워 넣지 않고 Godot에서 표시한다. 투명 외곽 여백은 `AtlasTexture`의 원본 영역으로 제외한다.

최종 프롬프트:

> Edit target: the supplied approved Korean medieval game shop WINDOW screenshot. Asset type: production blank raster UI panel frame, transparent exterior. Extract/recreate ONLY its large rectangular dark window background and slim antique gold ornamental outer border as a clean empty game UI asset. Fill almost the full 16:9 image with this ONE rectangle, leaving a tiny transparent outside margin. Preserve the reference's warm charcoal-black worn paper inner surface, hand-inked tarnished gold outline, intricate restrained gold medieval filigree corner flourishes, and thin dark inset edge. Center of the panel stays opaque charcoal with extremely subtle quiet paper grain, near-uniform dark tone, ample flat empty usable space. Straight square edges with subtly rounded/chamfered corners. OUTER FRAME ONLY, no internal dividers or header plaque. Remove absolutely ALL cards, text, Korean letters, title, headerplate, counters, buttons, separators, icons, selection markers, map, objects and shadows outside the frame. No wood grain/planks/table/counter; no cards or parchment card silhouettes. The entire interior must be one empty dark surface ready for real native UI content. No new ornamental shapes in the center or along middle edges. Exterior beyond outline must be actual transparent alpha, not checkerboard. Border thickness around10px with corner artwork containedwithin50px. Output landscape ratio16:9, straight-on perfectly rectangular flat UI texture, no perspective, no text, no watermark.

## 검증 상태

- Godot 4.7.2 실제 GPU 화면 7장, 실제 포인터로 교환/나가기, 재진입/3회 완료/재시작/다수 보유 카드: 29 검사 통과, 오류/누수 없음.
- 상점·보물 저장/등급별 제안/이전 5장 캐시/저장 실패/횟수/가득 참/마지막 마물: 406 검사 통과.
- 실제 상점 창 배치·선택·명시적 확정·재진입·제단/예언 분리: 32 검사 통과.
- 제단 38, 직접 예언 232, 장소 안내 통일성 101, 주사위 보관함 23, 언어 88 검사 통과.
- 공개 CI 및 main/PC 동기화는 PR 체크포인트에서 최종 SHA와 함께 기록한다.
