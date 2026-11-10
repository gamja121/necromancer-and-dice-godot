# 정상 우리집 타일 돌벽 수정 — 2026-11-10

작업 #381. 사용자는 기존 정상 집 타일 한 장의 외벽만 돌벽으로 맞추기로 결정했다. 내장 ImageGen 편집으로 home.png의 판자 외벽을 밝은 회색 석조로 교체하고, 집의 구도·지붕·문·창·굴뚝·돌 틀·투명 외곽을 유지했다. 전소 타일 및 정상/전소 배경과 게임 코드는 변경하지 않는다.

생성 PNG를 픽셀 후처리 없이 기존 home.png에 복사한다. 기존 home.png.import UID와 가져오기 설정은 유지한다. 교체 전 원본과 생성 원본은 프로젝트 밖 raw_assets/home_material_20261110에 보관한다.

- 런타임: assets/map/tiles/home.png
- 생성 해상도: 1456 × 1080, RGBA
- 이전 SHA256: eaf404bdd39db72e83195f2c24951eccaa407580f11cc9c45bade722f30cdaf0
- 새 SHA256: 92567a5149c94a9532dfa0336124896e006661520fcc21ab22a869afb5957e4a

## 사용 프롬프트

Use case: precise-object-edit. Asset type: one transparent PNG terrain tile for the existing game board. Image 1 is the ONLY EDIT TARGET: the intact home tile. Image 2 is ONLY a supporting material reference for the gray stone masonry on the burned home. Make the smallest possible change to image 1: replace the intact hut's exposed vertical wooden-plank exterior walls with pale gray hand-drawn stone masonry, so the normal house is a stone-walled house that plausibly becomes the existing burned stone ruin. Keep the house completely intact and welcoming. Preserve the exact original small house silhouette and scale, its single small triangular gable, intact thatched roof, wooden door, single side window, door/window frame positions, chimney and light smoke, grass, short entrance path and tiny compass. Preserve visible roof beams and wooden door/window frames. Do not redesign the architecture, enlarge it, add rooms, add an upper window, change the roof, change the camera, or import destruction from image 2. Preserve image 1's outer rectangular gray stone tile frame, all cracks, bevel shading, top/bottom/left/right square connector tabs, exact relative sizes and positions, muted gray/sepia ink style and blank interior background. The only changed material is the house's wall surface, drawn in the same thin dark pen lines and restrained gray tones as the original. Same landscape aspect ratio as the original 652x484 canvas (approximately 1.347:1), with the entire same tile silhouette and margins visible. True transparent alpha outside the stone frame, opaque scene inside the frame. No fire, no damage, no characters, no new lettering, no UI, no book/manuscript decoration, no new border, no watermark. Deliver just the single edited intact home tile.

## 검증

Godot 가져오기와 기존 test_contamination_gui_capture의 실제 Windows 보드 화면으로 정상 타일 크기와 가독성을 확인한다. 개인 저장은 격리하며 새로운 검사 파일은 만들지 않는다. 최종 검사와 동기화 결과는 작업 Issue에 남긴다.
