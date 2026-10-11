# Stage 5P — 공동묘지 아이 대화 양피지 웹 원본 복원 (2026-10-11)

## 원본 기준과 실제 차이
- 변경 불가 웹 기준: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- 웹 `v2-map-practice.html` 464–469행과 `v2-map-practice.css` 2130–2205행: 공동묘지 아이가 말할 때 `intro-dialogue-box.webp` 복구한 원본 기반 프레임 위에 ‘아이’ 이름, “…도와주세요!” 대사 및 다음 표시가 나타난다.
- 웹 원본 WebP: `art/v2-style/ui/intro-dialogue-box.webp`, Git blob `3bab039aa347faa7546e213de941213dd8cade8d` (12,000 bytes). **원본 자체가 330바이트 잘렸다.** RIFF/VP8 청크에서는 12,330바이트를 요구하며 Godot·Pillow 기본 디코딩 불가. 기존 Godot 맵에는 아이 대화 상자 파일이 없었고 `show_graveyard_child_beat()`는 텍스트만 사용했다.
- source prefix(12,000 bytes)를 1바이트도 바꾸지 않고 **누락된 뒷부분 330바이트만 0으로 채운 복구 WebP** blob `3ccec1f913e4df4f01a5e80888297c521ed48d6c` (12,330 bytes)를 Godot용으로 추가한다. Pillow 일반 디코드 및 dwebp 디코드에서 768×288 RGBA 동일 `sha256=c7ee30520ef60773f058ab4775304459dee2960196100dd69e5d3f108fcead26`으로 복원됨. ffmpeg 디코딩은 손상 복원 부위에 따라 다른 픽셀 결과도 냈음.
- **복원 한계:** 잘린 원본의 마지막 부분 330바이트는 복원할 수 없다. zero padding은 읽을 수 있는 이미지로 만드는 실용적 복구이며 손실 없는 100% 제작 원화 복원이 아니다. 원본 웹 Git SHA와 수정본 SHA를 별도로 기록하며 웹 소스는 변경하지 않는다.
- `assets/intro/dialogue_frame.webp`는 원본과 blob이 다른 **별도 인트로 전용 이미지**이므로 덮어쓰지 않는다.

## 작업
- 원본과 완전한 prefix가 일치하는 **zero-padded 복구 WebP**를 `assets/map/ui/intro-dialogue-box.webp`에 저장. 330바이트 패딩/RIFF 검증은 CI에서 별도 확인한다. 원본 웹/인트로 에셋 변경 없음.
- `map.gd`의 공동묘지 `show_graveyard_child_beat()`에서 **대사가 있고 구조 선택 전일 때만** 원본 WebP를 그림으로 표시. 1280×720 맵 기준 웹 CSS left/right 8%, bottom 2%, height 30% → `Rect2(102.4,489.6,1075.2,216)`, stretch scale.
- 발화자 ‘아이’와 대사 글자를 양피지 위에 별도 레이어 표시, 선택 전 계속 단계에서만 ▼. 사건 설명 텍스트는 프레임 위쪽으로 이동해 겹침 방지.
- 평상시 첫 두 장면에는 프레임 없음. 구조 선택 뒤에는 프레임/선택지를 통해 사건을 새로 실행하지 않고 기존 상태를 복원. 프레임 `MOUSE_FILTER_IGNORE`로 입력을 절대 가로채지 않는다.
- `계속`, `나가기`, `아이를 구한다`, `지나친다`, `공동묘지 기능`은 기존 실 버튼을 그대로 사용. 원본 웹 프레임 전체 터치로 다음으로 넘어가는 추가 경로는 입력 사고 가능성이 있어 만들지 않음.

## 구현 5원칙
1. Trigger: 실제 사건 시작과 `계속` 진행으로 **대사 장면**이 보여질 때만 프레임. 리로드·그림 생성 자체는 사건을 시작하지 않음.
2. Information: `GraveyardStoryBeats.beat`의 대사/선택 상태, 사용자 세이브의 `story_events`, 기존 원본 WebP, 전투/보상 상태.
3. Interaction: 기존 직접 버튼 선택만 사건을 한 단계 진행하거나 구조/포기를 기록. 프레임 비대화형.
4. Visual: 아이/대사·▼가 원본 양피지 위에 놓이며 해당 장면에만 보임. 후면 설명과 선택 버튼이 분리되도록 위치 조정.
5. Persistence: 비주얼은 저장하지 않고 이미 저장된 `current_beat`/choice로 프레임을 재구성. 자동 전투/왕 부활/보상/랜덤 소비 없음.

## CI 및 남은 항목
- 신규 `scripts/test_ui_grave_dialogue_stage5p.gd`: 실제 아이 사건 발견→2회 계속→원본 프레임→중단/재로드→같은 장면 복원→선택 두 개→직접 포기 및 중복 보상 차단. 전용 임시 세이브 생성·정리.
- 기존 공동묘지 UI 시각/시체 추출 회귀, 모든 사건 중단 복원(P4-03), 구조/포기/패배 후 재전투, 맵 장소, 단일 원정 E2E 검사.
- 웹 CSS에서 원본 프레임은 클릭하여 계속할 수 있지만 본 이식에서는 **의도적으로 기존 계속 버튼만 트리거**, 키보드/터치 오작동 방지. Windows/Android 실기에서 글자 가독성·버튼 겹침 및 픽셀 정합은 미승인.
- `main` 병합·배포·PC 동기화·원본 삭제 없음.

## 독립 이미지 복구 증빙
- 진단 GitHub Actions 실행에서 `original` Pillow normal/tolerant, `dwebp`, `ffmpeg` 직접 디코딩 모두 실패.
- `zero_pad` 330바이트 버전에서 Pillow·dwebp 정상 해독(동일 픽셀 해시). `length_fixed`는 Pillow 및 dwebp 실패. 복구 WebP의 앞 12,000바이트 Git blob은 웹 고정본 `3bab039aa347faa7546e213de941213dd8cade8d`와 동일함을 CI에서 검증한다.

## 실맵 레이아웃 측정 중 발견한 검사 시점 문제
- 복구 PNG/WebP 정상 가져오기와 사건 진행·저장 복원 검사 36개 통과, 첫 좌표 비교 1개 실패.
- 프레임 생성 직후 Godot 공통 `PanelEffectsModule`가 6px 아래에서 0.20초 동안 위로 이동한다. 초기 자동검사 시 측정된 실제 좌표는 `(102.4,494.0595)`, 최종 목표 `(102.4,489.6)`; 크기 `(1075.2,216)`은 정확했다.
- 공통 UI 애니메이션을 제거하거나 프레임을 임의 보정하지 않고, 0.29초 후 실제 좌표 0.5px 이내·크기 정확 일치로 검증한다.

- 추가 진단에서 0.29초 후 위치는 정확히 `(102.4,489.6)`, 크기는 `(1075.2,216.0001)`로 측정됨. Godot Control 높이 부동소수점 오차 `0.00009155px`만 남았으므로 위치·크기 모두 0.5px 미만 오차 요구. 시각 코드 및 원본 그림은 변경하지 않음.
