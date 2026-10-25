# 일반 사건 카드 원화 v2 — 2026-10-25

사용자 요청으로 일반 사건 카드 배경을 내장 image_gen 이미지 생성 도구로 새로 제작했다. CLI/API fallback은 사용하지 않았다. 바랜 종이, 어두운 가죽 가장자리와 절제한 청동 장식으로 기존 판타지 원화와 맞췄다. 하단 보상 영역과 오른쪽 선택지 구조는 이전 요청을 유지한다.

게임 원화: `assets/map/ui/routine_event_card_base_v2.png` (1122×1402 RGBA, 실제 외부 알파 0..255). 생성 원본을 변형하지 않고 복사했다. 이전 SVG는 보존한다. 런타임 카드 452×560에서 새 테두리에 맞춰 삽화는 (45,112,362,259), 설명은 (42,459,368,64), 16pt로 맞췄다. 제목/내용은 이미지에 굽지 않아 한글·영문과 6종 사건을 공유한다. 발견 카드는 기존 원화를 유지한다.

검증: headless import 오류 0, 관련 6종 입력/한국어·영어/발견 UI 검사 86 통과·0 실패. 별도 임시 APPDATA에서 Windows 실제 그래픽 드라이버로 1280×720 게임 화면을 렌더·캡처하여 그림이 장식과 맞고 설명 끝이 고립되지 않는 것을 확인했다. 원정 저장·보상·선택 로직은 변경하지 않았다.

## 실제 사용한 생성 프롬프트

```text
Use case: stylized-concept. Asset type: production-ready reusable 2D RPG event card BACKPLATE, a single portrait card with genuinely transparent pixels outside its silhouette. Make a beautiful, finely hand-painted antique parchment card for a Korean dark medieval necromancer board game. Portrait aspect about 4:5, ideally 1024x1280. Flat straight-on orthographic UI asset, no perspective, no tabletop scene, no mockup. The card nearly fills the canvas with only about 1 percent transparent margin. Rich dark umber leather edge, weathered ivory vellum, subtle paper fibres, thin aged bronze engraved trim and restrained medieval corner filigree, a tiny discreet ornamental diamond crest at the top. Premium illustrated strategy-game UI; dignified, warm, tactile, readable, not cartoon or flat vector. IMPORTANT LAYOUT normalized to a 452 by 560 runtime card: header area x=50..402 y=32..92 is EMPTY pale parchment for a live category label; a single large EMPTY rectangular illustration aperture x=34..418 y=113..372, surrounded OUTSIDE that rectangle by a narrow beautiful bronze/ink picture frame. Fill the aperture with completely plain neutral dark warm parchment, NOT an actual scene; a separate live illustration will be placed exactly over this rectangle by the game. Bottom x=42..410 y=394..521 is an EMPTY light vellum text area, softly textured, spacious and unruled for a live title and two lines of description. Keep all ornament OUTSIDE these usable text and picture rectangles. Fine realistic edge wear and graceful framing instead of thick black boxes. Palette: faded ivory and warm tan paper, dark walnut edges, softly oxidized muted bronze. No green reward strip, no icons or slots at bottom, no buttons, no text, no lettering, no numerals, no handwriting, no runes that look like writing, no characters, no landscape scene inside, no glow, no jewels, no oversized skull, no watermark. Preserve alpha transparency outside card; interior paper stays opaque.
```


## 2026-10-25 일반 사건 전용 고서 삽화 6종 — 게임 카드 연결

이전 사건 유형·효과·선택지·보상/저장 규칙은 변경하지 않았다. 사용자가 대화에서 확정한 1254×1254 정사각형 고서 원화 6종을 WebP(고품질)로 복사해 별도 파일로 추가했다. 이전 사건 배경 원화는 삭제하거나 덮어쓰지 않았다. 제작 원본 PNG는 사용자 ChatGPT Library의 `/네크로멘서_앤드_다이스_원화/일반사건/`에 별도 보관한다.

| 사건 ID | 라이브 삽화 경로 |
|---|---|
| wounded_soldier | `assets/map/events/routine_wounded_soldier.webp` (기존 등록된 확정본 재사용) |
| abandoned_wagon | `assets/map/events/routine_abandoned_wagon.webp` |
| lost_traveler | `assets/map/events/routine_lost_traveler.webp` |
| smoke_camp | `assets/map/events/routine_smoke_camp.webp` |
| wandering_merchant | `assets/map/events/routine_wandering_merchant.webp` |
| broken_seal | `assets/map/events/routine_broken_seal.webp` |

배치: 공통 `event_discovery_card.gd`의 452×560 일반 사건 카드에서 정사각형 원화를 상단 452×452로 표시하며, 기존 양피지 하단에 동적 제목과 본문을 배치한다. 카테고리 라벨은 고서의 상단 테두리를 가리지 않도록 일반 사건에서만 숨긴다. 오른쪽 두 선택 버튼, 발견 카드 레이아웃, 저장/보상 규칙은 유지한다. `scripts/test_six_routine_cards.gd`에 실제 원화 경로·정사각형 크기·잘림 방지·레이아웃 검증을 추가했다.
