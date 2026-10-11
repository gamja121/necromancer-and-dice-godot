# 5단계 Z — 마물의 왕 추적/세계수 사건의 원본 레이어 이식 (2026-10-12)

## 고정 웹 원본 비교

- 읽기 전용 `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- `v2-map-practice.js:6457-6482`: 마물의 왕 추적은 **기존 사냥꾼 레이어**를 재사용. 시체 장면 `beat.visual === "scene"`은 `beat.id === "trace"`일 때만 진입하고, 우측 초상 `beat.visual === "portrait"`은 `beat.id === "revival"`일 때만 진입. `destination` 초상과 `located` 마지막 시체 장면은 애니메이션을 반복하지 않음.
- `v2-map-practice.css:2479-2536`: 사체/사냥꾼 합성 그림은 `left:13%; bottom:2%; width:74%; height:92%`, 진입 0.52초(아래 3%, 시작 96.5%, 알파 0). 사냥꾼 초상은 `right:2%; bottom:25%; width:58%; height:78%`, 진입 0.48초(오른쪽 7%, 아래 2%, 시작 96%, 알파 0 → .94). 두 레이어는 컨테이너 외부 클릭 이벤트를 받지 않음.
- 이전 Godot `map.gd:show_monster_king_hunt_beat()`는 각각 원본 793.6×446.4 전체 원화 영역에 놓고 장면마다 `InkSceneReveal.play`를 무조건 호출해 CSS의 위치와 연출 시점이 달랐음.

## 최소 수정

- `map.gd`의 왕 추적 전용 그림 코드에 W단계에서 검증한 `MonsterHunterLayerMotion.source_rect()`와 `play()`를 그대로 재사용. 별도 유사 Tween 모듈이나 유사 원화 파일은 만들지 않음.
- 각 비트 원본 이미지를 텍스처 경로 그대로 직접 자식 `KingHuntSceneLayer`/`KingHuntPortrait`로 표시, 본래 5장면 `arrival`, `trace`, `revival`, `destination`, `located`의 그림 종류와 재생 조건을 정확히 보전.
- 두 부활 분기(`weakened`/`full`)가 설명 문장은 달라도 원본 초상 배치·출현 타이밍이 같음을 보장.
- 비트 3 `destination`의 `계속`에서 원래 `MonsterKingHuntEntry.finish()`를 통해 봉인 폐허/최종 전투 준비를 저장하고, 5번째 `located` 장면에서 `마치기`를 명시적으로 눌러야 시각적 승인 비트를 저장한다. 단순 그림 공개는 비트·보상을 변경하지 않음.
- 원본 WebP 파일·.uid·공통 PanelEffects·마물/전투/저장 시스템 변경 0. 이전 X/Y/W/V/U/T 검사들을 동일하게 보전.

## 설계 5원칙

1. **Trigger** — 정식 전이문 저지전 결과 확인과 부활 결과 `마치기` 이후 세계수 왕 추적 사건을 실제 저장된 순차 비트로 열 때만 재생.
2. **Information** — `MonsterKingHuntEntry.revival_mode/current_beat`, 원본 `MonsterKingHuntBeats.visual/id`와 W단계 소스 검증된 CSS 퍼센트·시간.
3. **Interaction** — 원화는 클릭 무시. `계속` 버튼으로만 다음 장면 저장, 마지막 `마치기`로만 인지 완료, 원래 `세계수 기능` 및 `돌아가기` 유지.
4. **Visual** — 시체 장면 좌 13%/하 2%/74×92%, 사냥꾼 초상 우 2%/하 25%/58×78%, `trace` 0.52초·`revival` 0.48초 한정.
5. **Persistence** — 애니메이션 상태/좌표/Tween은 저장하지 않고, 기존 의식 승패·왕 추적 상태·봉인 폐허 위치·명시적 마지막 승인·영구사망/전투/RNG/보상 유지.

## 검증과 남은 제한

- `scripts/test_ui_king_hunt_layers_stage5z.gd`: **승리→불완전 부활, 패배→완전 부활 두 독립 새 세션** 각각 정식 구출→마을 소문→기사단장→사냥꾼→광신도 소문→제단 통과→전이문 저지→승패 기록/결과 확인→마물의 왕 추적의 5비트를 실제 상태 엔트리 함수로 진행한다. 게임 지도 타일까지 도달하는 이동만 테스트용으로 단축; 보스 전투 승패는 테스트용 최소 Outcome 목객체를 `RunSession.finish_encounter()`에 전달하여 데이터 계약을 검증한다(실제 주사위 승패를 주장하지 않음). 그림 경로/노드 수/좌표/비율/투명도/진입 시점·정지 상태/버튼/저장복원/마지막 승인·보상 불변 검사.
- `.github/workflows/ui-king-hunt-stage5z.yml`: Godot 4.7.2 headless 임포트 + Z + Y/X/W/V/U/T 및 기존 지도/전투/오디오/원정 회귀검사. 기존 실제 전장 승패 E2E 테스트는 별도 유지.
- 실기 Windows/Android 화면 시야/색감/그림자/효과 자연스러움과 PC-GitHub SHA 동기화는 승인 미완료. 원본 웹 저장소/자료/개별 원화 보존, `main` 병합·배포 여부 명시적으로 보고.
