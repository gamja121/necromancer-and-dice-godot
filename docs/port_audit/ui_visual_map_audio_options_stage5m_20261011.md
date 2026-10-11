# 5단계 M — 지도 오디오 OPTION 패널 원본 UI 복원 (2026-10-11)

## 기준과 차이
- 웹 고정본: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- `v2-map-practice.html`의 `#mapOptionsButton`, `#mapAudioOptions`; `v2-map-practice.css` 78–82행, 1319–1329행.
- 원본 1280×720 기준 오른쪽 2.2%, 위 11.5%, 너비 20%(256px, 최대 280px), 화면 위 z=130; 제목 `OPTION`, 우측 28×28 닫기, `배경음악` / `효과음` ON/OFF 두 줄(각 38px).
- 기존 Godot 지도 버튼은 이미 웹 HTML의 **인라인 원본 아이콘**과 동일한 `assets/map/ui/map_audio_options.webp` blob `517db847cf1af3ef19e686855745bcf5e182e8ed`(Git SHA를 파일에서 검증, 기존 파일 복사/변경 없음). 버튼 위치 1053,133 / 58×58도 맞다. 다만 클릭 시 뜨는 `systems/audio_settings.gd`의 창이 x=790, y=60, 가로 450px 보라색 판넬로 원본과 시각적 차이가 큼. 원본의 OPTION 제목·닫기 ×·두 개의 직접적 ON/OFF 제어가 없음.
- 원본의 `디오라마 테스트` 개발자 전용 도구는 게임 본편에 복사하지 않는다.

## 수정
- `systems/audio_settings.gd`: 브라운 계열 얇은 테두리 패널, x≈995.84/y=82.8, 폭 256px, `OPTION`/닫기 ×, 효과음과 음악 ON/OFF 54×30 버튼 2개. 각 버튼은 실제 Music/SFX 버스를 분리 제어하고 `user://audio_settings.cfg`에 지속 저장.
- 기존 Godot 출력 장치와 마스터 음량은 웹 원본에는 없지만 사용자 편의 기능이므로 **삭제하지 않고 접을 수 있는 `고급 설정`으로 이전**.
- 실제 맵 `map.gd`의 원본 아이콘 경로·위치·기존 `map_audio.get_child(0)` 연결 수정 없음. 설정 창만 변경. 저장 형식 `audio.music_enabled`, `audio.sfx_enabled`, `audio.output`, `audio.volume` 유지.
- 테스트를 위한 인스턴스 `save_file_path` 설정 가능. 기본 값은 기존 `user://audio_settings.cfg`; 실제 게임 동작과 호환.

## 5가지 기본 원칙
1. **Trigger:** 기존 원본 오디오 버튼 누름 → 옵션 열기/닫기. 음악과 효과음 토글 누름 → 해당 버스 음소거.
2. **Information:** Music/SFX 버스 mute 여부, 기본·선택 출력 장치, 전체 음량, ConfigFile 저장 값.
3. **Interaction:** OPTION 창의 × 닫기, 음악 ON/OFF, 효과음 ON/OFF, 고급 설정 확장·축소/장치/볼륨 변경. 기존 사용자 설정 파일 호환.
4. **Visual:** 원본 크기·위치·갈색 팔레트·제목·두 줄·OFF 감광. 네이티브 고급 옵션은 접었을 때 숨김.
5. **Persistence:** UI는 일회성 렌더; 음악/SFX/볼륨 설정 ConfigFile 저장 후 다음 시작 복원. 전투·맵·보상·RNG·원정 JSON 일절 수정 없음.

## 범위와 검증
- 신규 `scripts/test_ui_map_audio_options_stage5m.gd`: 실제 Music/SFX 버스 제어, ON/OFF 독립 저장, master 볼륨·출력 선택 지속 지원, 패널 닫기와 재열기, 실제 Map.scene 연결·원본 아이콘/위치, 별도 임시 ConfigFile 사용 및 정리.
- 기존 L 예언·P4 맵 장소 이동·보물→집→다음 바퀴·전체 원정 E2E Godot 4.7.2 회귀 검사.
- 웹 CSS의 그라데이션·그림자는 단색+에디터 StyleBox 음영으로 **근사**했고, 디오라마 테스트 도구는 상용 게임에서 생략. Windows/Android 실기와 화면 픽셀 동등성 미검증.
- 웹 원본 보존, `main` 병합·배포/PC 동기화 미수행, P5 삭제 승인 불가.
