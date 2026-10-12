# P4·P5 기술 감사 종결 증거 — 2026-10-12 (GitHub 기준)

> **판정: 이식 코드·자동 회귀·Git 추적 에셋 대응 검증 완료 / 사용자 PC 실기·오프사이트 제작 원본·삭제 게이트 미완료.**
> 증거 기준 Godot `main@3d77aebecc7d405b197fa7526b01c5e6d6c16ec5`, 고정 웹 `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
> 이 문서는 기술 감사의 **증거 스냅샷**이다. 과거 TSV 판정이나 `migration_work_queue.tsv`의 상위 승인 상태를 자동으로 DONE으로 바꾸지 않는다.

## 1. Main 병합 및 자동 검증 — 9/9 성공

- [UI 단계 1~5Z 통합 PR #104](https://github.com/gamja121/necromancer-and-dice-godot/pull/104): **병합됨**. 병합 HEAD `3d77aebecc7d405b197fa7526b01c5e6d6c16ec5`.
- 같은 HEAD에서 아래 **서로 다른 9개 GitHub Actions run 모두 성공**:
  1. [전체 상태·사건·전투 회귀](https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/38186229430)
  2. [Windows Godot 4.7.2 네이티브 / GUI](https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/38186229393)
  3. [주사위 기반 자연 원정 전체 사건 연쇄](https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/38186229451)
  4. [기사단장·사냥꾼 자연 진행](https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/38186229330)
  5. [집 귀환·다음 바퀴 자연 진행](https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/38186229436)
  6. [Web Independence Guard](https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/38186229373)
  7. [Godot Web 빌드](https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/38186229407)
  8. [P5-03 기능·원화 전수 대조](https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/38186229368)
  9. [P5-03B 변경 이미지 런타임 경로 검사](https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/38186229495)
- Windows 작업의 개별 **16장 실제 Godot GUI PNG 생성 단계도 성공**: `WINDOWS_GUI_PREVIEW: 16 captured, 0 failed` 및 `WINDOWS_GUI_SCREENSHOTS_CAPTURED 16`. 해당 스크립트는 1280×720 일치 조건을 검사한다. CI의 Dummy 오디오 환경은 **실제 스피커 청취 성공 증거가 아니다**.

### P4 항목별 자동 검사 증거

| 작업 | CI에서 검증한 경로 / 결과 | 기술 판정과 제한 |
| --- | --- | --- |
| P4-01 | `P4_SINGLE_RUN_END_TO_END: 55 passed, 0 failed`; 제목→인트로→맵→출전덱→전투→포획/보상→집→다음 바퀴, 별도 이동·보상/복귀·프로세스 재시작 검사 | **자동 통합 검사 성공.** 상위 P4-01 DONE 금지는 P4-01F 실제 PC 승인 요구 때문에 유지 |
| P4-02 | `P4_FULL_SOURCE_STORY_CHAIN: 321 passed, 0 failed`; `P4_CULTIST_ALTAR_BRANCH_INTEGRATION: 170 passed, 0 failed`; `P4_GRAVEYARD_BRANCH_INTEGRATION: 81 passed, 0 failed`; 전이문 `117/0`; 자연 연쇄 CI 별도 성공 | **자동 원본 사건·승패·방치 분기 검증 성공.** 실제 PC 화면·오디오 승인과 구분 |
| P4-04 | `P4_ALL_MONSTER_PRESENTATION: 912 passed, 0 failed`; 웹 46종 + 보호되는 드라큘라 총 47종, 카드·정보·공격·피격·사망 경로 검사 | **자동 실행·에셋 경로 검증 성공.** 47×5=235회 사용자 시각 관찰/승인이 아님 |
| 카드·제단 UI 회귀 | `CARD_SCREEN_REGRESSION: 66/0`; 사냥꾼 `516/0`; 제단 의식 `108/0`; 제단 선택 `135/0` | 출전 고정 4슬롯 및 레이어 모션 변경 후 현재 검사 기준으로 통과 |

**해석:** 위 경로는 GitHub 헤드리스/호스트 Windows에서의 자동검증이다. 실제 사용자 PC의 입력·청취·개인 환경 저장 복원과 최종 원화 승인이라는 다른 성질의 증거까지 입증하지 않는다.

## 2. P5 기능·에셋 기술 재대조

- 현행 `feature_parity_audit.tsv`: **159개** = 코드 이식 **156** + 승인된 의도 변경 **3** (`W005` 타이틀, `W151` 저장매체, `W202` 가로 화면 정책); 코드 미이식·부분 이식 항목 **0**.
- 역사적 `asset_parity_audit.tsv`: **791행 모두 현재 매핑 규칙으로 감사**. 웹 원본은 역사적 자산 기록을 덮어쓰지 않는다. 당시 '누락' 표기 22개는 **20개 원본 Git blob 동일**, **2개 변경 초상 대체본**으로 추적됐고 현재 파일 부재 **0**.
- 과거 `EXACT` 기록 중 현재 변경된 배경 **2개**까지 합쳐 다음 **4개 아트는 원본과 blob SHA가 다르고 시각 승인 보류**:
  - `assets/map/events/fortune-teller.jpg` — `effcf0425a5a3fb9d015b7046a9a9500132134e9`
  - `assets/map/events/home-interior.jpg` — `2623363f6851b5f7f70ac755dd798b208af0a08d`
  - `assets/map/events/knight-commander-upperbody-hd.webp` — `7710370f7462cf12da98f9721b054500d5b43c4e`
  - `assets/map/events/necromancer-upperbody-hd.webp` — `c707c93a5ca3feeca9a51c7baa1fd2252ea58970`
- 이 네 자산의 현재 HEAD blob SHA와 Git 추적 경로를 재대조해 **4개 모두 존재하고 핀 일치**를 확인했다. 기존 `DISCARD_DEV_ONLY` 10개 및 `DISCARD_WEB_ALT` 18개는 제품 런타임 필수 맵과 구분하고 원본 Git 아카이브에서 보존한다. **791개 원본이 전부 동일 바이트로 복제됐다는 뜻은 아니다.**
- [P5-03 CI](https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/38186229368)에서 `P5_03_CODE_AUDIT_PASS`, 누락 추적 매핑 0, 시각 검토 4개 및 `P5_03_DELETION_NOT_AUTHORIZED`를 동시에 확인했다.

## 3. 원본 보존·복원 경계

- [P5-02A 고정 웹 원본 Release](https://github.com/gamja121/necromancer-and-dice-godot/releases/tag/p5-02-frozen-html-final-e13d5149-20261011): GitHub API에서 ZIP, Git history bundle 분할 2개, `SHA256SUMS`, manifest, refs 및 복구 안내의 **7개 자산 모두 uploaded 상태·SHA256 digest 존재** 확인.
- 과거 백업 제작/검증 기록은 [P5-02A 보고서](18_p5_02_frozen_web_archive_20261011.md)를 따른다. 이 감사에서는 **GitHub API 등록/해시 상태만 재확인**했으며 모든 자산을 새로 다운로드해 오프라인 복원 테스트한 것은 아니다.
- 원본 웹 브랜치 `reference/html-final`은 조회 시 `e13d5149fcecc802e5d626f3bef6e5daecd3d66c`로 유지됐다. 원본 웹 저장소·GitHub Pages는 변경하거나 삭제하지 않았다.
- **P5-02B는 계속 TODO:** 개인 PC 전용 PSD/`raw_assets`/`source_assets`와 독립 오프사이트 사본, 실제 복구 증거가 없다.

## 4. 작업표 및 삭제 게이트

`docs/port_audit/migration_work_queue.tsv`의 공식 상태 **47 DONE / 12 TODO (59개)** 그대로 유지한다. 아래 미완료들은 **새 코드 오류의 증거가 아니라 상위 완료 조건 또는 실제 승인 증거가 빠진 상태**를 뜻한다.

| 분류 | 미완료 ID | 이 기록에서 완료 처리하지 않는 이유 |
| --- | --- | --- |
| 장소·원정·사건·마물 PC 승인 | `P3-05`, `P4-01F`, `P4-02E-B`, `P4-04B` | 실제 개인 PC UI·입력·가청 오디오·235개 시각 검사·동일 SHA 증거 없음 |
| 자동검사 통과했으나 상위 게이트 유지 | `P4-01`, `P4-02`, `P4-04` | 작업표는 자동 CI 합격과 상위 실기/최종 승인 조건을 분리한다; 근거 없는 DONE 승격 금지 |
| 원본/변경 화상 검수 | `P5-02`, `P5-02B`, `P5-03B` | PC 전용 원본 및 오프사이트 복구·변경 원화 사용자 승인 미완료 |
| 최종 기능/자료 승인 및 삭제 | `P5-03`, `P5-04` | 단순 159/791 코드 대조가 최종 승인·독립 백업·Pages 경로 이전을 대신할 수 없음; 삭제에는 **사용자 별도 명시 동의** 필요 |

## 5. 이번 자동 기술 감사 결론과 후속 원칙

1. **기술 수준: PASS** — 현재 `main`에서 UI 1~5Z, 원정·사건·전투 회귀, Windows 호스트 GUI 16장, 159개 기능 매핑 및 791개 자산 추적 경로가 자동검사와 Git 근거로 일치한다.
2. **완제품·PC 승인: NOT CLAIMED** — 게임의 재미/밸런스/Windows 개인 PC 체감, 4개 변경 원화 채택, 작업자 PC의 별도 제작 자료 보존은 증명하지 않았다.
3. **삭제 승인: DENIED / HOLD** — 웹 소스, 역사, 배포, 원본 제작자료를 삭제·강제 덮어쓰기·임의 변경하지 않는다.
4. 사용자 요청대로 개인 PC에서만 가능한 검증을 이번 GitHub 자동 작업의 **수행 대상에서 제외**한다. 이를 완료 또는 생략 승인으로 바꾸지 않는다.
5. 재현: `python3 scripts/audit_p5_03_parity.py --self-test`, `python3 scripts/audit_p5_03_parity.py --json-output /tmp/p5-03-audit.json`. UI/게임 통합은 위 링크된 9개 검증 워크플로가 canonical commit마다 기준이다.
