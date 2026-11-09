# 전소된 우리집 장소 배경 — 2026-11-10

작업 #377. 일반 장소 화면인 show_burned_home이 채색 사건책용 manuscript_witch_hunt_ruins.png를 재사용하고 있었다. 기존 home.jpg의 구도와 황갈색 목판화 그림체를 기준으로 전소 전용 장소 배경을 제작하고, 장소 화면의 참조 한 곳을 home_burned.png로 교체했다.

사건책 원화와 시나리오·저장·집 봉쇄·다음 바퀴 규칙, 안내/버튼 좌표는 기존 구현을 사용한다.

내장 ImageGen 편집 사용. 편집 대상: assets/map/events/home.jpg. 파손 정도 보조 참조: assets/map/events/manuscript_witch_hunt_ruins.png. 생성 PNG를 픽셀 후처리 없이 복사했다.

- 런타임: assets/map/events/home_burned.png
- 원본: raw_assets/burned_home_20261110/home_burned_original.png (프로젝트 외부)
- 해상도: 1672 × 941
- SHA256: cdb94a512d46af665276fa592fccd239d21278603839326b3b5bb47bc0b36a67

## 사용 프롬프트

Use case: precise-object-edit. Asset type: finished full-screen 16:9 game location background, ideally 1920x1080, opaque. Edit target is image 1, the existing exterior of the protagonist's home. Image 2 is only a supporting reference for the extent of the burned-house damage; NEVER copy its illuminated-manuscript style or ornamental frame. Primary request: create the post-arson, completely burned-out version of the SAME house in image 1, matching the existing game's black ink woodcut/engraving on warm amber sepia parchment. Preserve image 1's camera perspective, horizon, large bare tree at left, lantern post, moon, distant castle ruins on the left hill, mountain silhouettes, foreground path and rustic fences. Replace the intact house with its unmistakable burned remains in precisely the same footprint: the entire thatched roof has collapsed, blackened broken rafters lie inside the low surviving stone walls, one broken front gable and the recognizable tall stone chimney remain, the doorway is hollow and dark. A modest amount of ash and fallen charred timbers on the entrance path. The fire is over, stillness after destruction; no active flames, no glowing interior windows, no people or new narrative props. Match image 1's dense crisp hand-drawn black hatching, strong silhouettes, aged ochre/amber paper texture and limited sepia palette exactly; the world should look like the SAME original home tile after a fire. Full bleed landscape scene all the way to all four edges. Absolutely NO decorative frame, NO gold/red/blue manuscript borders, NO book or page, NO flowers/birds heraldic motifs, NO UI, NO text or numbers, NO watermark. Do not crop the original into an inset. The surrounding environment remains intact. This is the actual location painting, not a picture of a painting.

## 검증

Godot 4.7.2 가져오기 오류 0. 기존 방화 분기 검사 1,874/0, 실제 한영 UI 검사 4,643/0으로 합계 6,517항목 통과. 실제 화면 14장을 생성했으며 전소 장소의 새 원화, 공통 안내와 버튼 위치, 사건책 그림, 집 봉쇄와 다음 바퀴 출발을 확인했다.
