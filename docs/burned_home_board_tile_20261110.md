# 전소된 우리집 보드 타일 — 2026-11-10

작업 #379. 기존 정상 집 타일을 어둡게 표시하던 부분을 전용 전소 타일로 교체한다. 기존 home.png의 돌 틀·연결부·중앙 삽화 구성을 참조해 내장 ImageGen으로 제작했고, 생성 PNG는 픽셀 후처리 없이 사용한다. 틀 바깥에는 실제 알파 투명이 있다.

## 상태와 기능

방화 사건의 마지막 마치기로 저장된 완전한 전소 기록이 있을 때만 tile_path가 home_burned.png를 반환한다. 확인 전·보호·손상은 정상 home.png다. 실제 보드와 지도 전환이 같은 경로 함수를 사용하므로 저장/재시작/다음 지도에도 유지된다. 논리 타일은 home, 인덱스는 기존 HOME이며 v1 저장 구조는 바꾸지 않는다. 집 진입/회복/계승/순찰/HOME 숙영 해금은 기존 중앙 home_services_allowed 검사로 차단된다. 다음 바퀴 출발과 다른 장소의 회복은 기존 규칙을 사용한다. 기존 봉쇄 표시는 유지하고 중복 회색 틴트는 제거한다.

- 런타임: assets/map/tiles/home_burned.png
- 원본: raw_assets/burned_home_tile_20261110/home_burned_tile_original.png (프로젝트 외부)
- 해상도: 1456 × 1080, RGBA
- SHA256: 907eb9ae79724e073161d7ef3c58055740b51db16cbd03d0632971235d854594

## 사용 프롬프트

Use case: precise-object-edit. Asset type: transparent PNG board-game terrain tile. Edit target: the attached existing home.png tile, a horizontal gray stone-framed board tile with a small intact hut illustration. Primary request: change ONLY the little hut scene INSIDE the inner stone frame into the same hut AFTER A COMPLETE FIRE. The roof has collapsed, with blackened broken rafters and fallen charred planks inside low surviving stone walls, and the small masonry chimney remains standing. An unmistakable burned-out uninhabitable house silhouette that stays legible when displayed as a small 118px-wide game tile. No active flames: the fire has ended. Preserve the exact existing tile identity: its broad rectangular 4:3 aspect ratio (source 652x484), irregular gray stone bevel frame and corner cracks, four square stone connection tabs at top/bottom/left/right, their positions, the same outer silhouette, original shading direction, and the existing tiny compass mark near the bottom of the inner panel. Preserve the frame's gray-brown colors. Match the original small hand-drawn sepia ink illustration, restrained colors and dark contour lines. Inside panel: muted pale ash-gray background, black and charcoal hatching on the ruined hut, a few ashes and charred beams at its foot. Keep the ruin within the original hut's small central footprint; do not enlarge the house across the frame. Absolutely no book, manuscript ornament, gold border, extra labels, new text, UI, characters or scenery outside the frame. Isolated tile with true transparent alpha OUTSIDE its existing stone silhouette; the scene INSIDE the stone frame remains opaque. Keep the whole frame fully visible with the same small transparent outer margins as the original. Deliver one single finished tile, NOT a sheet or comparison. Keep the exact same landscape canvas proportions as the reference.

## 검증

기존 방화 분기 검사로 16조합의 결과, 집 기능 차단, 저장/재시작/다음 바퀴 유지를 확인한다. 기존 한영 UI 검사로 실제 전소 화면을 확인하고, 최종 결과는 작업 Issue에 기록한다.
