# 타이틀 오디오 및 옵션 이식 — W005/W006 (2026-10-11)

## 고정 웹 기준

- 원본: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`
- 원본 `index.html`: `assets/title/title-theme.mp3` 반복 재생 및 타이틀 영상 `title-loop.mp4`. `launch.js`는 BGM 기본 음량 0.34, 메뉴의 사운드 On/Off로 타이틀 영상 음향과 BGM을 동시에 켜고 끔.
- 원본 `v2-music.js`: 맵/전장 BGM 별도 처리, 맵 음악 0.30. Godot 맵/전장은 이전 이식으로 `Music`, `SFX` 버스와 `user://audio_settings.cfg` 저장을 사용.

## Godot 이식

- `assets/title/music/title-theme.mp3`: 원본 blob SHA **68fa42d386482ee03e3b743cc510d89e94784415**, 파일 크기 **816970 bytes**. 코드/파일에서 원격 HTML/웹 자산 참조 없음.
- `title.tscn`: 원본 묘지 패럴랙스 타이틀은 유지하며 `TitleBgm` (`AudioStreamPlayer`, `Music` 버스) 추가. `title.gd`에서 기존 고정 원본 BGM을 0.34 음량으로 루프 재생하고, 타이틀을 떠나면 노드가 제거되어 다음 장면의 음악과 중복되지 않음.
- `TitleUI/OptionsDialog`에 기존 전체 음량 외 Music/SFX 체크 컨트롤 연결. 타이틀에서 설정한 음악/효과음/음량을 다른 맵·전장과 **동일한** `user://audio_settings.cfg`에 저장하고 새 타이틀 진입 때 복원. 음량 0은 Master mute로 처리.
- 웹 단일 타이틀 음악 On/Off는 Godot의 통합 Music 토글로, 게임 전체 사운드 관리는 별도 SFX 체크로 제공. 원본 타이틀 영상은 기존 Godot 묘지 패럴랙스로 이미 의도적으로 교체해 두었으며, **타이틀 영상 시각적 대응의 최종 승인(P3-03)은 이 단계에 포함하지 않음**.

## 검증

- `scripts/test_title_audio_parity.gd`: 실제 `title.tscn`을 인스턴스화하고 원본 MP3 리소스/유효 재생시간/버스 연결, 옵션 UI, Music/SFX On/Off 및 Master 음량 변경, `ConfigFile` 저장, 공용 오디오 설정 복원, UI 재동기화 검사.
- 테스트는 `user://title_audio_parity_프로세스ID.cfg` 경로만 사용하고 실제 사용자 `audio_settings.cfg`에 쓰지 않음. 종료 시 임시 파일 삭제 및 AudioServer 버스 상태 복원.
- CI: `.github/workflows/story-state-regression.yml`에 등록. Headless 파서·오디오 리소스 디코딩·로직 검증이며 실제 PC 스피커의 음량/끊김과 화면 디자인 승인은 별도의 실기 검증.

## 다음

- `P3-01`: 원본 타이틀 음악 이식과 실제 재생 경로 **완료**.
- `P3-02 / W006`: 타이틀 Music/SFX/전체 음량 옵션 접근과 공동 저장 **완료**.
- `W005`: 음악/토글 부분은 완료. 원본 영상 `title-loop.mp4` 대신 cemetery 패럴랙스라는 의도적 엔진 디자인 변경을 사용자 시각 승인/문서 확정할 때 최종 판정.
- `P3-03`: 묘지 타이틀의 원본 영상 대체 승인과 P4 실제 화면·오디오 검증까지 유지.

웹 버전 삭제는 모든 P5 하드 게이트와 사용자 최종 승인 이후에만 실시한다.
