# 평민 고블린 리마스터 · 2026-10-09

완료: 사용자 제공 25포즈의 공격/피격/사망 구조를 유지하여 Godot 인게임의 **평민 고블린(goblin-commoner)**에 적용했다. 창과 투구가 있는 고블린 병사(goblin-soldier)는 변경하지 않았다.

## 규격과 연결

| 항목 | 최종 값 |
|---|---|
| 개별 프레임 | 576×384 RGBA PNG |
| 전체 마스터 | 2880×1920, 5×5 |
| 서 있는 몸체 | 알파 ≥ 64/255 기준 320px |
| 바닥/몸체 메트릭 | top 52, bottom 371 |
| 공격 | 원본 1–10 → attack-01…10 |
| 피격 | 원본 11–17 → hit-01…07 |
| 사망 | 원본 18–25 → death-01…08 |
| 접촉/피해/피격 시작 | 공격 7번 |
| PNG 25장 총 크기 | 3,533,314bytes (약 3.37MiB) |

화질용 몸체 320px는 소스 해상도이다. 화면 표시 크기는 기존 일반 유닛 배율과 슬롯 깊이를 그대로 사용한다. 소환 슬롯의 0.88 깊이 배율도 유지했다. 죽거나 넘어지는 포즈를 각각 320px 높이로 늘리지 않았다.

## 변경한 그림

- 원본 6번: 팔이 아직 약간 굽은 타격 직전.
- 원본 7번: 완전히 뻗은 단일 펀치의 접촉 순간.
- 원본 24번: 뼈가 드러나고 갈비뼈 내부에 극소량의 마른 조직/천 조각이 남은 단계.
- 원본 25번: 조직이 더 사라지고 낮게 가라앉은 최종 골격.

최초 24번 후보는 앞선 23번보다 조직이 많아 부패가 역행해 보일 수 있어 폐기했다. 후속 편집 결과에서는 **24번만** 선택했다. 6·7·25번은 최초 승인된 편집 결과를 그대로 사용한다.

나머지 21포즈는 생성형 도구로 다시 그리지 않았다. 분리된 원본 PNG와 보강 전 입력 PNG의 SHA-256이 모두 일치함을 검증했다. 이후의 공통 업스케일/배율/캔버스 정규화는 전 프레임에 동일하게 적용했다.

원본은 실제 1536×1024이고 정확한 등분 격자가 아니다. 알파 연결요소 25개와 시각적 행을 기준으로 분리했다. 특히 원본 6번의 주먹이 등분 칸 경계를 넘으므로 단순 5×5 등분으로 자르지 않았다.

## 제작 방법과 프롬프트

이미지 편집 스킬의 **기본 내장 이미지 도구**를 사용했다. 4포즈 참조 시트 편집과 24번 단독 후속 편집, 총 두 번이며 별도 API/CLI 이미지 생성은 사용하지 않았다.

최종 프롬프트 세트와 선택 내역:
[imagegen_prompt.md](D:/Workspace/Games/necromancer-and-dice/raw_assets/goblin_commoner_remaster_20261009/imagegen_prompt.md)

기술 가공은 Godot Image로 분리/정렬/포장하고 기존 로컬 Real-ESRGAN x4plus를 사용했다. 모델의 RGB 결과에 원본 또는 선택된 편집 포즈의 알파를 다시 붙였다. 모델이 배경/실루엣을 새로 만든 것을 쓰지 않았다.

## 적용 파일

- 게임 PNG: assets/battle/frames/goblin-commoner/
- 프로필: data/battle_visual_metrics.json의 goblin-commoner 항목만 변경.
- 이식 가능한 검증: tests/goblin_commoner_remaster.gd 및 Godot UID.
- .gitignore: 이 검증 파일 두 개만 허용.
- 전체 마스터/원본/편집본/제작 스크립트는 D: raw_assets에 보관. 전체 마스터는 게임에서 중복으로 로드하지 않는다.

게임 규칙/유닛 정의는 수정하지 않았다. 평민 고블린은 기존 그대로 HP10 / ATK1 / SPD1, special 소환 유닛, 소환·야수 군단, 낙인/패시브 없음이다. 고블린 족장 소환 풀과 5번 슬롯, 일반 소환 사망 처리도 그대로다.

## 검증

- Godot 4.7.2 헤드리스 에디터 import 성공, 오류 없음.
- 자원/규격/프레임 순서/소환 회귀: **40 통과 / 0 실패**.
- GTX 1660 Ti Compatibility 실제 1920×1080 보드 검증: **89 통과 / 0 실패**.
- 1.0 / 1.5 / 3.0배에서 공격 10장, 피격 7장, 피해 표시와 피격 시작이 공격 7번.
- 실제 족장이 소환한 고블린이 새 이미지 사용.
- 사망 8장과 마지막 두 부패 단계가 실제 소환 사망 경로에서 재생, 정상 제거.
- 다른 유닛의 모든 시각 프로필 불변.
- units.json 전체 SHA-256 불변: 다른 유닛의 능력·스탯·군단·낙인·패시브 포함.
- 기존 PNG import UID 15개 유지, 게임 25장의 SHA-256이 최종 export와 일치.
- 모든 포즈 알파 ≥16/255 영역이 캔버스 내부, 공통 몸체 배율, 프레임6/7 바닥 정렬.
- 리치 자원 회귀 **33 통과 / 0 실패**.
- git diff --check 통과(기존 작업 트리의 CRLF 안내는 오류가 아님).

실전 QA의 RunSession은 메모리 전용 하위 클래스로 대체해 플레이어 저장 파일을 수정하지 않았다. Git commit/push는 이번 요청에서 수행하지 않았다.

## 원본, 백업, 결과물

D:/Workspace/Games/necromancer-and-dice/raw_assets/goblin_commoner_remaster_20261009/

- goblin_sheet_original.png
- four_edit_targets.png / four_edited_poses.png / decay_refined_reference.png
- goblin_sheet_runtime.png
- source_manifest.json / manifest.json / verification.json
- prepare_frames.gd / build_frames.gd / verify_goblin.gd / imagegen_prompt.md
- runtime/ (최종 PNG25장)
- backup_before_apply/ (기존 PNG/import, units.json, 메트릭)
- board_1080.png / board_attack_06.png / board_attack_07.png / board_decay_07.png / board_decay_08.png

작업 중간물은 현재 스레드 작업 폴더의 remaster_trial/goblin_commoner에 남아 있다. 재생 검증은 게임에서 최종 에셋을 직접 로드한 결과이고, 파일 미리보기의 투명 RGB 표시가 아니라 실제 GPU 보드 화면으로 배경/가장자리도 확인했다.

