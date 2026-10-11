# 5단계 P — 공동묘지 아이 사건의 실제 원본 대화 양피지 복구

2026-10-11 · 독립 작업 브랜치 · 웹 원본 불변

## 근거 및 누락
- 원본 웹: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- `v2-map-practice.html` 466행: `graveyard-story-dialogue`는 배경 WebP, 화자 `아이`, 본문, `▼`를 모두 가진다.
- `v2-map-practice.css` 2130–2200행: 하단 2%, 좌우 8%, 높이 30%의 프레임; 내부 이름/대사는 원목/갈색 글씨.
- 원본 JS 5296–5325행: 이미지를 `assets/intro-data/frame-v2/part-000.txt` ~ `part-007.txt` 8개를 연결하여 `data:image/webp;base64`로 사용. 오류 시에만 짧은 대체 `art/v2-style/ui/intro-dialogue-box.webp` 12000바이트를 사용.
- 종전 Godot는 공동묘지 아이 대사를 `아이: …도와주세요!` 단일 라벨로만 보여주고, 원본 대화창 아트를 저장하거나 렌더하지 않았다.

## 바이너리 출처와 정확도
- 고정 원본의 **실제 사용되는 8개 TXT 조각**을 순서대로 이어 붙이고 base64 디코드했으며 PNG/재압축/보정 없음.
- 총 base64 120,224자 → 90,166바이트 원본 WebP. 확인된 헤더 `RIFF/WEBP`, RIFF 선언 크기 90,158 = 실제 전체 길이-8, 단일 `VP8L` 90,145바이트. 새 Godot 파일 `assets/map/events/graveyard-dialogue-frame.webp` Git blob `948739b01ed1275f701cca0837f78634e7014c0b`.
- 단축 웹 fallback 파일(`intro-dialogue-box.webp`, blob `3bab039aa...`) **그대로 복사하지 않음**. 이는 원본 웹도 주 이미지 디코딩 실패 시에만 사용하던 대체 경로.
- Godot 런타임 WebP 디코딩 및 프레임·대사 표시를 신규 headless CI로 검증. Windows/Android 실기 색상·폰트·그림자 일치는 별도 승인 필요.

## 구현 5원칙
1. **Trigger:** 공동묘지 사건의 저장된 `dialogue` 비트에서만 UI 프레임 등장. 영구 저장 전 새 사건 자동 발생 금지.
2. **Information:** `GraveyardStoryBeats.beat`의 대사, 명시적 사용자 클릭으로 진행된 `StoryEventEntry`의 현재 비트, 복구한 8조각 원본 아트.
3. **Interaction:** 대화 아트와 글자는 클릭 통과. 기존 `계속`, `아이를 구한다`, `지나친다`, `나가기` 버튼을 가리지 않도록 계층/드로우 순서 유지; 버튼 없이 자동 전투 실행 금지.
4. **Visual:** 하단 8%-30% 원본 프레임에 아이 이름(갈색), 실제 대사, 다음 장면 표시 ▼; 초기 그림 장면에는 원본 프레임이 없고 아이가 말하기 시작할 때만 생김.
5. **Persistence:** 오직 `StoryEventEntry`의 기존 사건 진행/선택 상태를 저장. 프레임 자체, 애니메이션, 렌더링은 저장하지 않고 리로드 시 저장된 비트로 재구성. RNG, 전투, 영수증, 보상은 미변경.

## 검증
- 새 `scripts/test_ui_graveyard_dialogue_stage5p.gd`: 원본 아트 완전한 런타임 디코딩, 실제 맵 첫 발견→클릭 두 번→대사 표시→종료/재시작→같은 대사 재구성→세 번째 클릭→선택지 표시, 조기 왕/구울 전투 없음, 정확한 영수증/RNG, 유저 세이브 분리.
- 기존 `scripts/test_ui_graveyard_event_parity.gd` 낡은 `Panel`·존재하지 않는 이름 가정을 실화면 검증으로 보정하고, 실제 고정 사진 및 공동묘지 시체 추출 검증은 유지.
- P4 사건 중단 복원, 5O 순찰, P4 맵 장소, 전체 원정 E2E 회귀.
- 원본 웹 수정/삭제, `main` 병합, PC 동기화·배포, 픽셀 단위 실기 시각 검증은 하지 않음.

## 실제 CI 좌표 진단
- 1차 신규 검사에서는 원본 WebP 디코드·사건 0→1→2→3 전환·저장 재실행·분기 버튼이 모두 통과(35/36), 유일한 좌표 검사에서 대화 프레임 초기 Y=493.7669(기준 489.6)로 나왔다.
- `PanelEffectsModule._open()`이 모든 모달 직계 자식의 Y를 초기 6px 아래로 움직였다가 200ms에 걸쳐 원래 자리로 복귀시킨다. 시험은 애니메이션 도중 값을 읽은 것으로 판명. **실제 UI 코드·본체 위치 변경 없이** 270ms가 지난 후 원본 CSS 8%·30% 영역 좌표·크기를 정확히 검사하도록 수정.
