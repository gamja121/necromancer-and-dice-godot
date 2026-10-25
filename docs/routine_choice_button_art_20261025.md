# 일반 사건 선택 버튼 원화 — 2026-10-25

사용자 요청으로 내장 image_gen 이미지 생성 도구를 사용해 선택 버튼 원화를 새로 제작했다. 카드와 같은 크림색 양피지, 얇은 청동/갈색 테두리와 절제된 모서리를 사용한다. 실제 캡션은 진한 갈색 라이브 텍스트이므로 한글·영문과 6종 사건에 재사용한다.

원화: `assets/map/ui/routine_choice_button_v1.png` (2188×718 RGBA). 생성 원본은 수정하지 않고 복사했다. 런타임 AtlasTexture가 실제 버튼 영역 (29,221,2131,273)을 선택해 주변의 투명 여백/희미한 알파 픽셀을 제외한다. 최종 버튼은 기존 250×58, 오른쪽 세로 배치이다. 텍스처를 카드 인스턴스가 소유해 화면 종료 시 함께 해제한다.

기본·호버·눌림·비활성화에는 같은 그림을 다른 밝기로 사용하고, 키보드 포커스에는 얇은 테두리를 표시한다. 기존 take/skip, 포커스 이동, 중복 방지, 저장 실패 시 재선택과 보상 로직은 유지한다.

검증: import 오류 0, 6종 실제 입력/한글·영문/재선택/발견 카드 회귀 86 통과·실패 0. 별도 임시 APPDATA에서 Windows 실제 게임 1280×720 기본/눌림 화면을 캡처해 시각 확인했으며 종료 시 그래픽/리소스 누수 로그가 없다.

## 실제 생성 프롬프트

```text
Use case: stylized-concept. Asset type: ONE finished 2D fantasy strategy-game CHOICE BUTTON BACKPLATE, no text, genuine transparent background. A single slim HORIZONTAL button, about 4.3:1 width-to-height, centered and almost full canvas width; any unused space must be truly transparent. Prefer a wide canvas. Clean, elegant, practical medieval UI, matching a hand-painted antique ivory parchment event card with muted bronze trim. The button is a soft pale warm vellum strip with extremely restrained paper fibre, subtle worn edges, a very thin dark walnut outer keyline and a delicate aged bronze inner rim. Small understated tapered/angled ends, only a tiny engraved notch at each far end; central 80 percent is clean light parchment with no marks, ready for a dark brown live label. Minimal ornamental detail, gentle shallow depth, crisp silhouette, readable at 250x58 pixels. Flat straight-on orthographic game asset with consistent neutral lighting, no perspective or dramatic cast shadow. This is a premium illustrated necromancer board-game UI piece, not a modern rounded brown rectangle, not a photoreal tabletop object. One button only, not a sheet or several states. No text, no letters, no runes, no icons, no arrows, no numerals, no watermark, no background scene, no skulls, no jewels, no ornate scrollwork, no rolled scroll ends, no bright shiny gold, no glow. Keep all surfaces inside the button opaque; outside silhouette transparent.
```
