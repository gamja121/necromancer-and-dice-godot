# 히드라 25프레임 인게임 적용 — 2026-10-09

사용자가 독립 Godot 미리보기에서 승인한 후보를 실제 게임에 적용했다. 이 문서의 10/7/8 설정이 2026-10-08 문서의 이전 5/4/6 설정보다 우선한다.

- assets/battle/frames/hydra/: 공격 10장, 피격 7장, 사망 8장. PNG 25장 모두 승인 후보와 SHA256 일치.
- data/battle_visual_metrics.json: 히드라 항목만 변경. 1152×768, 기본 자세 top104/bottom743, 몸체 640px, impact_frame7, 순차 재생 배열10/7/8.
- 기존 2.0배 체급, 공용 공격/피격/사망 연출, 입력, 전투 규칙과 다른 유닛 설정을 유지했다.
- 기존 15프레임과 import 식별자를 원본 보관 폴더에 백업했다. 기존 .import 식별자는 유지했고 새 프레임의 .import는 Godot가 생성했다.
- 원본/승인 시트/프레임/처리 기록: D:/Workspace/Games/necromancer-and-dice/raw_assets/hydra_standard_25_20261009/.

Godot 4.7.2 headless editor import 종료0. NVIDIA OpenGL 실제 전장 play_strike에서 공격01→10→idle01, 피격01→07, animate_unit에서 사망01→08을 관측했다. 피격이 시작할 때 공격 텍스처가 attack-07.png임을 확인했다. 실제 embedded 설정으로 체급과 투명 배경을 캡처했다. 다른 유닛의 메타데이터가 바뀌지 않았고 git diff --check가 통과했다.

프로젝트에 검사용 버튼/스크립트는 추가하지 않았다. 검증은 Codex 작업 폴더의 일회성 실행으로 수행했다. 후보의 최종 게임 속도는 기존 공용 재생 속도를 따른다. 커밋과 푸시는 수행하지 않았다.
