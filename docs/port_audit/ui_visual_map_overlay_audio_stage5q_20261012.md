# Stage 5Q — 맵 이벤트 창과 오디오 옵션 겹침 방지 (2026-10-12)

## 고정 웹 비교 결과
- Source: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`, `v2-map-practice.css` 1328–1330행.
- `.map-board.is-tile-event-open .map-audio-options {display:none}` 및 `.map-board.is-tile-event-open .map-options-button {visibility:hidden}`.
- `v2-map-practice.js:openTileEvent()`는 `is-tile-event-open` 클래스를 즉시 붙이고 `closeTileEvent()`는 닫힐 때 제거한다.
- 이전 Stage5M 구현의 `AudioSettings`는 고정 웹의 두 토글/256px OPTION 패널/오리지널 아이콘을 이식했지만, `map.gd`에서 새 장소/사건 모달을 띄울 때 UI를 가리지 않아 z-index 130에 준하는 팝업이 원화 위에 겹칠 수 있다.

## 최소 구현
- `systems/audio_settings.gd`: `modal_blocked` 상태, `set_modal_blocked()` 추가. 닫힌 경우 정상 유지, 열린 오디오 패널은 즉시 닫고 전체 오디오 Control과 아이콘을 숨기며 클릭을 차단. 닫힌 이벤트에서 다시 아이콘만 노출. `toggle_panel()`에서 가려진 시점의 강제 열기를 거부.
- `map.gd`: 공용 `overlay` 변수 setter에서 표시 상태를 동기화. 일반 장소, 이야기, 상점, 덱 편성, 소지품 등 기존 overlay 경로가 자동 적용돼 하나씩 다르게 처리되지 않음. `render()`로 음향 컨트롤 재구축 시 현재 overlay 차단 상태 즉시 반영.
- 맵 BGM/Music/SFX AudioServer 변경 없음. `user://audio_settings.cfg`에 새 값 쓰지 않음. 기존 `OPTION` 내용/원본 PNG/위치/내부 고급 설정도 유지.
- 웹은 특정 타일 이벤트 열림에만 숨기지만 Godot에서는 모든 전면 overlay를 적용 대상으로 사용. 겹침 방지 및 보유 카드/덱 선택 시 탭 가로채기 방지가 동일한 목표다.

## 게임 5원칙
1. **Trigger**: 맵 `overlay`에 실제 장소·이벤트·전투 편성·보유 창이 설치되거나 닫힐 때.
2. **Information**: 실제 `overlay` 존재 여부와 `map_audio` 컴포넌트, 기존 음악 토글 상태.
3. **Interaction**: 오디오 팝업을 이미 열었다면 이벤트 진입 시 강제 닫기. 이벤트가 열려 있는 동안 오디오 버튼 입력 거부. 닫으면 아이콘만 복원.
4. **Visual**: 기존 아이콘/오디오 옵션 창은 이벤트 원화 위에 남지 않음. 맵 복귀 후 아이콘과 원본 배치 복원.
5. **Persistence**: 차단은 휘발성 UI 상태만. 유저 오디오 설정, 마물, 보상, 주사위 RNG, 맵·사건 저장 데이터 변경 없음.

## 검증
- `scripts/test_ui_map_overlay_audio_stage5q.gd`: 실 map scene에서 OPTION 먼저 열기→전면 모달·점술가·세계수·집·보유 카드·출전 덱 열기→아이콘/패널 완전 숨김, 입력 강제 재열기 방지, 닫기 후 아이콘 재등장, 기존 Music/SFX 및 world snapshot/RNG 불변.
- 회귀: Stage5M 오디오, Stage5P 공동묘지 원본 대화창 및 저장복원, Stage5N 제단, Stage5O 순찰, P4 지도 이동/장소, 단일 원정.
- 이 단계는 Godot 4.7.2 headless 연결·규칙 검사만. Windows/Android 육안·실기 입력·실제 소리 검증 및 PC SHA 동기화는 여전히 필요.
- `main` 직접 변경, 웹 원본 변경, 저장소 삭제·배포·PC 동기화 없음.
