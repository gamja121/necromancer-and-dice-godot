# Stage 5P — 원본 빙결 상태 배지 전투 UI 연결 (2026-10-11)

## 기준과 확인된 차이
- 웹 고정본: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- `v2-auto-battle-practice.js` 원본 마물 템플릿의 `.persistent-statuses .unit-status-freeze img`는 `art/v2-style/ui/freeze-status-label.png`를 참조하며, `v2-auto-battle-practice.css` 약 148–152행은 78px 상한, 상단 -6%, 밝은 파란 그림자, 독 상태와 독립된 표기를 지정한다.
- 원본 96×58 PNG Git blob `2f536e59286f4d50fb10dd4627a6409fe0e10976`는 IHDR/IDAT CRC가 정상. 이전 Godot에는 이 원본 파일이 없고 `BattleVisuals._draw()`의 직접 그리는 `빙결` 텍스트와 푸른 파티클만 있었다.
- 이번에는 원본 PNG **바이트 그대로** `assets/battle/ui/freeze-status-label.png`에 추가; 다른 원본 에셋 삭제·재압축 안 함.

## 실제 전투 화면
- `BattleVisuals.sync()`: 마물 `frozen == true`이면서 `alive`이고 제거되지 않았을 때만 원본 `TextureRect` 배지 표시. 아군·적군 모두 동일한 깨끗한 비반전 원본 아트를 사용하고 중복 생성하지 않는다.
- 적색 HP바 위 중심으로 78×47.125px의 원본 비율로 배치하고 실제 마물 좌우 이동을 따라간다. 마우스/터치 입력 무시, 대기/독/보호 상태의 실제 전투 법칙 변경 없음.
- 빙결이 풀리거나 마물이 사망·소환 제거되면 즉시 배지를 숨김. 다른 상태(독/보호) 텍스트와 빙결 파티클 효과는 유지하지만 중복 `빙결` 텍스트는 표시하지 않는다.
- 원본 CSS의 drop-shadow는 Godot에서 별도 GPU 렌더 검사 전까지 미구현·미승인. PC/Android 픽셀 단위 위치 검증은 별도 실기 작업.

## 개발 기본 5원칙
1. Trigger: 전투 규칙의 `frozen` 상태 진입·해제, 실제 전투 `render_units()` 호출. 배지 자체는 절대 전투를 시작하거나 RNG를 굴리지 않는다.
2. Information: `rules.units[].frozen/alive`, `visuals.removed`, 유닛 위치/체력 막대, 영구 보존 원본 PNG.
3. Interaction: 플레이어가 배지를 클릭할 수 없다. 상태는 주사위 낙인·전투 행동으로만 변경. 기존 유닛 카드 터치와 정보창 유지.
4. Visual: 얼어붙은 유닛 상단에 PNG 배지, 해제/사망 시 사라짐, 독/보호 표시는 독립 유지.
5. Persistence: 배지 노드 자체는 저장하지 않고 기존 `battle.rules.snapshot()/restore`에서 `frozen`값을 가져와 재구성; 원정 JSON 스키마·공격 수치·사망 규칙 변경 없음.

## 검증
- `scripts/test_ui_freeze_status_stage5p.gd`: 실제 Battlefield 노드, 원본 PNG 디코딩·무결한 에셋 크기, 아군/적군 빙결 표시 독립, 상태 해제/재빙결/사망/제거, 중복 노드 방지, 체크포인트 저장·복원, 새 전투 초기화, RNG/규칙 보존.
- 기존 UI 하단 카드 도킹, 전투 원본 규칙, 실제 전투→맵, 원정 종료 E2E 검사를 CI에서 실행.
- `main` 병합·PC 동기화·웹 배포·원본 삭제 및 Windows/Android 시각 최종 승인은 범위 외.
