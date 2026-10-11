# 5단계 L — 점술가 예언 수정구 UI 원본 에셋 복원 (2026-10-11)

## 정적 원본 및 실제 누락
- 기준 웹: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- 원본 `v2-map-practice.html` 214–215행과 `v2-map-practice.css` 271, 483–505행: 점술을 시작하면 약 210px 수정구 이미지와 보랏빛 안개를 왼쪽에 띄우고, 결과는 별도 오른쪽 영역에 보여준다.
- 원본 `v2-map-practice.js` 4443–4495행: 예언 버튼을 누른 뒤 수정구를 표시, 주사위 결과 대기, 다음 전투 누적 효과를 나타냄.
- 이전 Godot에는 `assets/map/events/fortune-prophecy-ui.png.import`의 실패 메타데이터(`valid=false`)만 있고 실제 PNG가 없음. `systems/place_actions.gd`에는 주사위·하단 결과만 표시되어 수정구/보랏빛 효과/분리된 결과 영역이 없었음.

## 이미지 손상과 복원 한계
- 웹 원본 PNG Git blob: `86b834480296657b8f72c72f725fac92bbd30969`, 원본 크기 96×93, `IDAT` CRC 불일치.
- 독립 Pillow 정상 디코딩은 `OSError('broken data stream when reading image file')`; 손상 허용 모드의 RGBA 복구는 96×93, 알파 bbox `(0,0,96,92)`, 픽셀 339색, SHA256 `3c47e78a68457f8c1684d9c98ded8c0fae40b204c39685dcf0ca52cee5b51c7c`.
- Godot용 유효 PNG blob: `433c9296b170d660bc5bd8c341df4fc95fd0bd91`. 이전 `valid=false` 임포트 기록만 삭제해 Godot가 새로 가져옴. 소스 저장소는 변경하지 않음.
- **반드시 남길 제한:** 손상 허용 픽셀 복원은 원화 100% 동일을 보장하지 않는다. 실기 Windows/Android 시각·GPU·오디오 승인 및 손상되지 않은 제작 원본 확인은 미완료. 보라 글로우는 CSS blur의 Godot shader 근사.

## 변경 범위 및 5원칙
1. **Trigger:** 이미 존재하는 점술가 막사 `예언 듣기` 버튼. 즉시 랜덤 예언을 소비하는 기존 `session.fortune_prophecy`만 실행. 신규 랜덤/자동 예언 없음.
2. **Information:** 방문 사용 영수증, `last_prophecy.face/detail/visit`, 누적 `world.prophecy`, 기존 주사위 애니메이션, 수정구 원본 이미지.
3. **Interaction:** 실제 버튼 명시 입력 시에만 수정구 표시, 예언 중 버튼/닫기 잠금. 기존 주사위와 보상·출입 제어 변경 없음.
4. **Visual:** 최초 예언 시 왼쪽 수정구·보랏빛 광륜이 260ms 진입, 중앙 주사위 회전, 결과를 오른쪽 `FortuneProphecyOutcome`에 표시. 저장 중단 이후 이미 예언한 방문을 다시 열면 수정구·결과·주사위 면이 재표시됨.
5. **Persistence:** 기존 `fortune_prophecy()` 1회 영수증 및 스택·현재 HP/회복/전투 버프 형식 변경 없음. 화면은 지속 스냅샷으로부터 다시 구성, UI 효과 자체는 저장하지 않음.

## 회귀 검사
- `scripts/test_ui_fortune_prophecy_stage5l.gd`: 실제 Map/PlaceActions UI, 임시 원정 seed, 수정구 texture/규격, 버튼 누르기 전/후, 주사위 처리, 사용 영수증 정확히 1개, 결과 영역, 저장 재시작 재구성, 중복 차단.
- 기존 P4 장소 이동·중단 재개, 원본 5J 구름, 보상→집→다음 바퀴, 단일 원정 E2E CI 회귀.
- PC 실기 시각 승인/원화 복구와 `main` 병합·배포·PC 동기화는 이번 범위 제외. 웹 저장소 삭제 승인 아님.

## 새로 발견·수정한 저장 복원 숫자형 결함
- 최초 실맵 회귀에서 예언 데이터는 정상 복원됐으나, 저장된 `world.prophecy`의 네 효과 정수값과 `rolls`의 주사위 숫자, `last_prophecy.face`가 JSON 재로드 후 `float`으로 바뀌어 원정 스냅샷 불일치 1건이 발생했다.
- 오류를 전체 월드/모든 주사위에 일괄 대응하지 않고 `systems/map_state.gd:restore()`의 예언 필드만 `int`로 재정규화한다. 기존 데이터·주사위 난수 진행·전투 규칙은 변경하지 않는다.
- 실제 결과 제어 및 재진입 UI에 더해 재시작 전체 스냅샷 동일성과 정수형 값 보존 검사로 회귀를 막는다.
