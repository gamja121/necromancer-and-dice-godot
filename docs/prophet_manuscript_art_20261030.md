# 예언가 사건 원화 — 채색 필사본 통일 (2026-10-30)

추적: [Issue #357](https://github.com/gamja121/necromancer-and-dice-godot/issues/357).

사용자는 예언가 사건이 다른 메인 사건과 같은 원화 형식·화질을 사용하도록 요청했다. 이전 목판화 배경과 세로 컷아웃은 이 기준에 맞지 않아, 기사단장과 사냥꾼 사건의 실제 원화를 시각 비교한 뒤 배경과 인물을 다시 그렸다.

## 적용 기준

- 기존 메인 사건과 같은 1672×941 가로 캔버스, 금박·울트라마린·주홍색 채색 필사본, 꽃·새·동물 장식 테두리.
- 사용자 모델의 주름진 얼굴, 기운 후드, 긴 머리, 구슬·눈 문양 목걸이, 손과 보랏빛 수정구를 유지한다.
- 배경에 장식 테두리·막사·탁자·카드를 두고, 인물·수정구·연기는 같은 캔버스의 실제 RGBA 투명 레이어로 분리한다.
- PNG는 내장 ImageGen으로 생성한 결과를 픽셀 후처리 없이 복사한다. 작은 책 그림 영역에서는 기존 manuscript 공통 경로의 밉맵과 선형 필터를 사용한다.
- 사건 대사·분기·저장·보상·주사위 RNG·본문/버튼 위치는 그대로 유지한다. 수정구의 기존 약한 맥동만 새 가로 캔버스에 맞춰 보정한다.

## 적용 에셋

- `assets/map/events/manuscript_prophet_base.png`
- `assets/map/events/manuscript_prophet_actor.png`

기존 `prophet_story_base.png`와 `prophet_story_actor.png`는 이전 제작 기록이며 새 예언가 사건에서 참조하지 않는다. 이전 경로 구현과 검증 기록은 [prophet_story_event_20261030.md](prophet_story_event_20261030.md)에 보존한다.

## 생성 도구와 실제 프롬프트

내장 ImageGen 사용. 참조한 기존 원화는 `manuscript_commander_base.png`와 `manuscript_hunter_scene.png`; 사용자 첨부 모델은 얼굴·의상·수정구의 정체성 참조다. 원본 첨부의 개인 경로는 공개 저장소에 포함하지 않는다.

### 합성 원화 (불투명)

```text
Use case: style-transfer.
Asset type: final high-detail medieval illuminated-manuscript story-event painting, 16:9 landscape canvas matching 1672 x 941 px existing game paintings.
EDIT TARGET is image 1 (the game's approved commander painting). KEEP its complete outer illuminated frame, ornamental gold leaf, ultramarine blue and vermilion red panels, curling leaves, flowers, little birds, rabbit and griffin motifs, arch shape, border thickness, and exact overall framing. Only replace the painting INSIDE the frame. Image 2 is the prophet's identity/costume reference. Image 3 is the approved game's character painting style reference.
Repaint the interior as the prophet's medieval tent, in EXACTLY the rich hand-painted illuminated manuscript miniature style of image 1 and the character rendering of image 3: crisp confident ink contours, finely painted gouache/tempera colors, softly modeled faces and hands, golden highlights, vivid balanced colors, dense precise craftsmanship. Absolutely do not use rough black woodcut, sepia monochrome, grunge, horror engraving, photorealism, 3D rendering, glossy fantasy concept art, or an unframed picture.
Inside the ornate frame, depict the SAME old prophet from image 2 at the right of center, from head to belt, stern lined face, long dark hair, patched brown-gray hood and cloak, bead necklaces with circular eye medallion, both aged hands around a glowing violet crystal orb with very subtle purple wisps. Preserve identifiable face, nose, hair, patched hood, eye pendant and hand pose; translate all rendering into the SAME clean full-color painted manuscript style as image 3. The figure is one dignified weathered seer, not a new character, not a crowned magician. Hood top around y=18% of canvas, face near x=69%, torso and hands completely within the interior opening; no character or orb covers the gold border. Figure fits roughly x=47%-87%, y=17%-87% of full canvas.
The left interior shows a small wooden table with a few cards, a candle, stitched red-and-muted-blue tent drapes, discreet moon charms and a small opening onto a deep ultramarine evening sky. The interior must remain readable and richly colored like the existing manuscript scenes, without black muddy shadow masses. The purple orb is the only orb. No text, no lettering, no numbers, no user-interface. Return a sharp finished production painting at the same 16:9 format and detail level as image 1. This entire painting will be reduced into a book illustration; face and orb must remain legible.
```

### 배경 분리 (불투명, 합성 원화 참조)

```text
Edit the supplied approved illuminated manuscript painting to produce its BACKGROUND LAYER for a layered Godot storybook. Preserve EXACTLY the original full landscape canvas, 1672 by 941 pixels, framing, colored border and tent/table composition. Keep the ornate gold leaf, ultramarine and vermilion manuscript frame, birds, flowers, rabbit and griffin UNCHANGED. Remove ONLY the old hooded prophet character, the character's hands, necklaces, purple orb and all purple smoke. Seamlessly paint the tent curtain, camp opening and tabletop that were hidden behind that character, consistent with the same fine colored tempera/gouache and ink illuminated manuscript style. Keep the table foreground, cards, candle, objects and lighting in the exact existing positions. No person, face or orb may remain. Do not recrop, zoom, restyle, simplify, move the border, or add text. Opaque background, crisp full-resolution details matching the reference.
```

### 인물 분리 (transparent_background=true, 합성 원화 참조)

```text
Extract the single hooded prophet character from the supplied approved illuminated manuscript painting into a true TRANSPARENT RGBA foreground layer. The output MUST retain the FULL ORIGINAL 1672 by 941 pixel LANDSCAPE canvas; do NOT crop to the person, do NOT center or enlarge. Keep every character pixel in the SAME location, scale and pose as in the input: the hooded aged prophet is right of center, head around x=0.64 y=0.34, torso/hands around x=0.59 y=0.66, orb around x=0.72 y=0.67, ending above the front tabletop. Preserve the exact stern wrinkled face, patched brown hood and robe, long dark hair, beads, eye medallion, hands, violet crystal orb and delicate purple wisps. Preserve the fine painted colored manuscript ink/tempera style and detail. Remove ALL scenery, table, cards, candle, curtains, background and the entire ornate border so they become fully transparent alpha. Keep only the prophet figure plus orb and its subtle smoke. Do not add any floor shadow, white/black background, matte box or decoration. All four image corners and the left portion must be fully transparent. Preserve exact registration with the input painting so the layer can overlay a matching empty tent background without scaling or placement correction.
```

## 파일 무결성과 검증

SHA256 (생성 PNG와 적용 PNG 동일):

- base: `b6ff07f29674d2e7781db76f246786680924b918b2936e72206a0a0286dbe814`
- actor: `01690d47f8e0ac144988377e3b7c5ce3c8f61d4ee42804c16892bb4c823a0b25`

Godot 4.7.2 Compatibility에서 에디터 임포트 오류 0. 예언가 분기 160, 실제 GPU 사건책·복원·막사 기능·원화 검사 431, 기존 전체 사건책 경로 337, 공통 사건 배치 25항목으로 총 953항목 통과.

실제 게임 프레임버퍼 1280×720에서 기사단장 안내, 예언가 단서, 광신도 후속 소문, 인물 없는 첫 도착, 주인공 응답의 5장면을 캡처하고 확인했다. 기사단장 원화와 같은 크기·테두리·채색 형식을 비교했으며 인물·수정구가 테두리 안에 표시된다. 테스트는 개인 저장 대신 격리된 프로필과 PID 저장을 사용한다.
