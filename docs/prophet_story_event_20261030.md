# 예언가 원화와 방치 경로 사건 — 2026-10-30

> 원화 후속 수정: 사용자가 기존 메인 사건의 채색 필사본 형식을 요청하여, 이 문서의 초기 목판화 에셋은 새 사건에서 사용하지 않는다. 현재 에셋과 생성 프롬프트는 [prophet_manuscript_art_20261030.md](prophet_manuscript_art_20261030.md)를 참조한다. 아래 경로 구현과 초기 제작 기록은 보존한다.

사용자 제공 예언가 모델의 얼굴, 기운 후드, 눈 문양 목걸이, 손과 보랏빛 수정구를 기준으로 사건용 투명 캐릭터를 제작했다. 생성 도구는 내장 ImageGen이며 API 키나 CLI를 사용하지 않았다. 원본 첨부는 작업 영역에 보존하고 공개 저장소에는 적용 에셋만 포함한다.

## 연결한 플레이 경로

- 구조 승리와 구조 소문 완료: 기존 기사단장 대사 → 사냥꾼 의뢰 그대로.
- 아이를 지나침과 방치 소문 완료: 기사단장의 별도 7장면 대사 → 예언가 의뢰.
- 예언자의 막사에 실제 도착: 별도 9장면 사건. 최초 오염도30, 이미 시작한 사건은 정화 후에도 재개.
- 마지막 마치기에서만 예언가 사건/의뢰 완료와 인간·문양 단서를 한 번에 저장.
- 오염도40 이후 실제 마을/사건 방문: 예언가의 문양을 참조하는 광신도 소문 → 기존 광신도 추적.
- 사냥꾼을 만나지 않은 분기에서 사냥꾼 완료/의뢰/구조 인정 기록을 만들지 않는다.
- 기존 예언 주사위, 방문 횟수, 효과, 영수증과 RNG는 이야기 진행과 별개다.

새 원화:
- assets/map/events/prophet_story_actor.png — 1145×1374 RGBA, 생성 알파 보존.
- assets/map/events/prophet_story_base.png — 1672×941 RGB, 기존 막사의 목판화풍을 따른 근접 배경.

SHA256:
- actor: 8A300DA9E852507A2CE5C043DF722E57439EE508F985A32DC30463161A76A5F4
- base: 951BCF44E0859D0F78F609CFD2AA4A1A9BAD6396C5DC6B3878B1711778891050

기존 책 사건의 그림 영역과 본문/버튼 위치를 공유한다. 캐릭터의 수정구에만 약한 보랏빛 맥동을 더하고 첫 등장에만 들어오는 연출을 적용한다. 대사마다 배경 등장 효과를 반복하지 않는다.

## 적용 범위와 남은 구상

> 후속 구현: [광신도 조사 선택과 와전된 소문](cultist_mistrust_branch_20261030.md)에서 협력하는 척하는 선택과 첫 주민 불신을 연결했다. 아래 문단은 예언가 사건 최초 제작 범위의 기록이다.

사용자가 정한 예언가 경유 단서 획득까지 구현했다. 광신도에게 협력하는 척하는 선택, 목격담 와전, 주민 불신, 집 방화와 HOME 봉쇄는 아직 구상으로 남아 있으며 이번 코드에 포함하지 않았다. 전투 패배 시 원정 종료도 기존 규칙이다.

개인 저장은 읽거나 바꾸지 않고 테스트 전용 APPDATA/LOCALAPPDATA 및 PID 파일로 검증한다. 대사 진행/재시작, 원자적 최종 완료, 저장 실패 롤백, 잘못된 경로/단독 플래그, 기존 구조/사냥꾼/광신도/예언 경로와 실제 GPU 책 화면을 검사한다.

## 로컬 검증 기록

Godot 4.7.2 Compatibility. Editor import에서 스크립트/리소스 오류0.

| 검사 | 통과 |
|---|---:|
| 새 예언가 분기, 저장 실패, 출처 검증, 기존 점술 | 160 |
| 기사단장 진입 / 기존 대사 | 186 / 308 |
| 사냥꾼 진입 / 기존 대사 | 302 / 516 |
| 광신도 진입 / 기존 대사 | 240 / 391 |
| 이야기 오염도 조건 | 84 |
| 기존 전체 원정 이야기, 중단 복원 | 333 |
| 기존 예언 직접 흐름 | 232 |
| 언어와 카드 이름 | 88 |
| 실제 GPU 사건 화면, 저장 복원, 막사 기능 접근 | 390 |

각 검사는 최종 통과 결과만 집계했으며 총 3,230항목이다. 실제 프레임버퍼에서 기사단장의 예언가 안내, 예언가 단서 장면, 예언가를 참조하는 광신도 소문 3장을 캡처하고 시각 확인했다. 모든 새 이야기 문구의 영어 번역도 카탈로그에 포함했다.

추적: GitHub Issue #355. 후속 자동 검증: .github/workflows/prophet-story-event.yml.

## 실제 생성 프롬프트

캐릭터 (참조: 사용자 제공 예언가 모델, transparent_background=true):

```text
Use case: background-extraction / identity-preserve.
Asset type: transparent character portrait layer for an illustrated dark-fantasy Godot story event.
Input image 1 is the user's exact prophet character reference and edit target. Extract this SAME illustrated old seer, not a redesign. Preserve the exact stern wrinkled face, sharp nose, sunken eyes, long dark hair, patched brown-black hood and ragged cloak with stitching, layered bead necklaces and circular eye medallion, both aged hands and the violet crystal orb, violet ink-like wisps rising from it. Keep the original hand-inked crosshatching and muted sepia palette with purple as the only strong accent. Preserve original front-facing pose and proportions.
Remove ALL cream paper/background around the character and create a genuinely transparent RGBA background. Keep semi-transparent purple smoke edges and clean antialiased character edges. The figure should fill a tall portrait canvas from hood top to below the belt, centered, both hands and full orb fully inside the frame. Extend the lower cloak a little below the belt only to make a clean non-cropped portrait; do not change face, costume, hands or orb. Full hood must not touch top edge. No new scenery, no text, no border, no extra ornaments, no halo, no solid background, no checkerboard painted into the image. This is a production character cutout to be drawn over an existing camp background.
```

배경 (참조: assets/map/events/fortune-teller.jpg, transparent_background=false):

```text
Use case: illustration-story / compositing background.
Edit target: the attached existing game fortune-teller camp illustration. Create a closer, quieter 16:9 event backdrop of this SAME shabby forest seer's tent, keeping its medieval dark fantasy black-ink woodcut/crosshatching illustration style, muted parchment cream, worn brown/red canvas, deep blue-gray forest, warm candlelight. Move camera near the open tent doorway: hanging little moon/star talismans and stitched drapes, a low table with a few weathered cards and candle, distant night forest barely visible at the left edge. No people or creatures in this image. Do not put any crystal ball on the table, since a separate prophet actor layer will hold the violet orb. Keep the right half fairly dark and uncluttered behind that portrait; the left half should show the tent's candlelit interior and cards. The art must remain a flat hand-drawn ink-and-muted-wash game illustration, not photoreal, not a 3D render, not glossy. Full-bleed 16:9 landscape, no text, no UI, no borders or picture frame, no modern objects. Preserve the recognizable tent's hanging charms and worn cloth design. Controlled lighting so a purple character orb will read distinctly in foreground.
```
