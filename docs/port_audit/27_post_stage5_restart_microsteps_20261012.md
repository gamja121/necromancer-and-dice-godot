# 5단계 통합 이후 작업 재시작 — 작은 검증 단계 (2026-10-12)

> **원칙:** 중단된 대화 직후 PR #104가 이미 `main`에 병합됐다. 동일 병합을 반복하지 않는다. 개인 PC의 안전한 실제 검증·독립 원본 백업·4개 변경 원화 확인·사용자 승인만 별도 단계로 수행한다. 체크리스트가 존재한다고 DONE으로 처리하지 않는다.
>
> 이 문서의 기본 상태는 **원격 GitHub 확인 완료 / 실제 사용자 PC 작업 미실행**. PC 원정 저장, 설정, 미커밋 수정, 원본 웹과 Assets, `main` 이력은 강제 덮어쓰거나 삭제하지 않는다.

## 확인된 GitHub 기준선 — S0 원격 상태 확인 (DONE)

- 표준 Godot 저장소: `gamja121/necromancer-and-dice-godot`. 재시작 당시 `main@8a97847db34932c11d441644b8b8e49ff7860fd3`.
- [#104](https://github.com/gamja121/necromancer-and-dice-godot/pull/104)는 GitHub에서 **merged=true**. 병합 커밋 `3d77aebecc7d405b197fa7526b01c5e6d6c16ec5`; 2026-10-12 08:57 KST 병합. PR이 중단 당시 초안이었던 이유로 중복 병합하지 말 것.
- 병합 커밋에 연결된 GitHub Actions **9종 성공**, Windows 호스트 Godot 4.7.2 **16개 1280×720 GUI PNG** 캡처. `main`의 이후 변경은 기술 감사 문서 한 개만이며, 런타임 파일 변경은 없음. 따라서 `8a97847`에서 신규 게임 CI를 실행했다고 쓰지 않는다.
- [기술 감사 종결 기록](26_p4_p5_technical_closeout_20261012.md)의 코드 검증 159개 기능(156 구현 + 3 승인된 의도적 변경), 역사적 에셋 791행 추적, 4개 변경 이미지 미승인 상태를 유지한다.
- Frozen Web `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c` 조회 확인. 원본 GitHub Release `p5-02-frozen-html-final-e13d5149-20261011`에 ZIP·분할 번들 2개·manifest·checksums·refs·README 총 **7개 업로드 상태/SHA256** 등록 확인. 원격 메타데이터 확인은 독립 오프라인 복구 검증이 아님.
- `migration_work_queue.tsv` 59개 = **47 DONE / 12 TODO**를 임의로 변경하지 않음. 12개: `P3-05`, `P4-01`, `P4-01F`, `P4-02`, `P4-02E-B`, `P4-04`, `P4-04B`, `P5-02`, `P5-02B`, `P5-03`, `P5-03B`, `P5-04`.

## 지금부터 작은 작업 하나씩 (승인과 증거는 섞지 않는다)

| 순서 | 상태 | 작업 범위 및 산출 증거 | 다음 단계로 가는 조건 |
|---|---|---|---|
| S1 | PC NOT RUN | 현재 PC Git SHA, 브랜치, 로컬 비추적/미커밋 파일 확인(읽기 전용) | 어떤 파일도 손실 없이 안전한 동기화 경로가 확정 |
| S2 | PC NOT RUN | 로컬 변경 별도 보존 후 원격 `main`과 코드/승인 런타임 원화 동기화 | 양쪽 정확히 같은 SHA 기록, 로컬 제작 원본/세이브 유지 |
| S3 | PC NOT RUN | 개인 PC Godot 4.7.2 에디터 import + 타이틀/인트로/맵 짧은 실기 | 실제 모니터·마우스·스피커에서 오류/깨짐 없음, V01–V02 증거 |
| S4-A | PC NOT RUN | 실제 주사위 장소 7종·사건창/선택 분기 관찰 | V03 및 `P4-02E-B` 사건 항목별 화면·저장 복원 증거 |
| S4-B | PC NOT RUN | 4마리 출전·주사위·전투 승패·영구사망 및 보물 중단 복구 | V04–V05 결과·단일 수령·예상되는 영구 손실 기록 |
| S4-C | PC NOT RUN | 집 귀환·HP 복구·타일 셔플·오염도·다음 바퀴·이어하기 | V06–V08 및 V01–V08 종합 승인, `P4-01F` 판정 가능 |
| S5-A | PC NOT RUN | 원본과 다른 4개 이미지: 점술가, 집 실내, 기사단장·주인공 상반신 | **4개 개별 사용자 화면 승인**, `P5-03B` 가능 |
| S5-B | PC NOT RUN | 7개 장소 배경·구름 4종(특히 손상된 4번)·상점·순찰·포획 화면 | `P3-05` 개별 승인. 불완전한 구름 4번을 자동 승인하거나 임의 생성하지 말 것 |
| S6 | PC NOT RUN | 47종 마물 × 카드·정보·공격·피격·사망 = **235개** 항목 실기 | `P4-04B` 증거와 완전 승인 |
| S7-A | PC NOT RUN | PC 전용 `raw_assets`/`source_assets`/PSD 및 기타 후보 **읽기 전용 Audit** | 찾지 못한 원본·제외 목록 파악. 빈 감사 결과를 '모두 백업'으로 판정 금지 |
| S7-B | PC NOT RUN | 사용자 소유 외장 물리 장치에 새 백업 + 재연결 Verify + PSD 실사용 복원 + Release 7파일 GitHub 외부 중복 복구 | `P5-02B/P5-02` 증거 PASS, 원본 무삭제 |
| S8 | BLOCKED | 완료 증거로 기술 검수·작업표 갱신, Pages 현행 공개 배포 이전·종료 절차 별도 검토 | `P5-03` 종합 승인 후 **사용자 별도 명시적 삭제 동의** 있을 때만 `P5-04` 검토 |

## S1 PC 준비 — 처음에는 아래 *조회 명령만* 실행

```powershell
git -C C:\Dev\necromancer_and_dice status --short
git -C C:\Dev\necromancer_and_dice branch --show-current
git -C C:\Dev\necromancer_and_dice rev-parse HEAD
git -C C:\Dev\necromancer_and_dice ls-remote origin refs/heads/main
```

- 이번 문서 작성 시 참고한 GitHub 원격 `main`: `8a97847db34932c11d441644b8b8e49ff7860fd3`. **PC 검증 당일** `ls-remote` 값이 다르면 그 최신 SHA를 기준으로 먼저 재비교한다.
- 로컬 파일·인덱스가 깨끗한지 확인하기 전 `git pull`, `git reset --hard`, `git clean -fd`, 강제 덮어쓰기 금지. 이 문서는 실행 능력이 없는 원격 ChatGPT가 PC 동기화를 완료했다고 주장하지 않는다.
- 단계 S2는 `docs/shared_source_sync.md`, S3/S4는 `14_p4_01_pc_visual_acceptance_20261011.md`, S5는 `20_p5_03_feature_asset_reconciliation_20261011.md` 및 `21_p5_03b_changed_visual_review_20261011.md`, S6는 `16_p4_04_monster_visual_acceptance_20261011.md`에 근거해 이미 정해진 통과 조건을 재사용한다.

## S7-A 읽기 전용 PC 원본 조사

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Dev\necromancer_and_dice\scripts\p5_02b_local_originals_backup.ps1 -Mode Audit
```

- **Audit는 복사·쓰기·삭제를 하지 않음**. 입력 폴더 누락 시 정상 완료로 표시하지 않는다. 다른 원본 보관 위치가 있으면 기존 문서의 `-AdditionalSourcePaths` 매개변수로 명시적 추가한다.
- 실제 외장 장치가 있는지 확인하기 전에는 `-Mode Backup`을 자동 실행하지 않는다. 외장 HDD/SSD에 백업되더라도 `-Mode Verify`, 에디터에서 원본 사본 열기, Release 7파일 독립 복제 없이는 최종 완료 불가.
- 백업의 전체 로컬 경로·원본 파일명·private manifest, 개인 저장 데이터, 신원 정보를 GitHub **공개** 문서에 복사하지 않는다. 필요하면 SHA 비교 성공/실패와 개수만 민감한 값 없이 기록.

## 현재 절대 하지 않는 일

1. 원본 웹 `necromancer-dice-board` 삭제/Pages 제거/이력 재작성 또는 Release ZIP/번들 삭제.
2. 개인 PC의 기존 `user://` 원정, 음량 설정, 미커밋 Git 상태, PSD·원화 후보 파일의 강제 초기화.
3. GitHub Windows CI PNG 16장을 사용자가 개인 PC에서 보고 승인했다고 서명하거나, 유효하지 않은 구름 4번·수정 초상 4개를 묵인.
4. `P4-01`, `P4-02`, `P4-04`, `P5-03`, `P5-04` 상위 항목을 자동검사만으로 `DONE` 변경.

## 다음 담당자/작업 스레드 전달 규칙

- 우선 현재 GitHub `main` HEAD를 다시 조회한 뒤 이 표의 **아직 NOT RUN인 첫 세부 단계**만 수행한다. 단계 완료 시 Git SHA·실행 주체·방법·개별 증거·남은 위험을 기록한다.
- GitHub와 개인 PC 양쪽 상태를 실제로 읽을 수 없다면 `PC NOT RUN` 그대로 유지한다. 사용자 입력 없이 방치되는 백그라운드 실행을 약속하지 않는다.
- 새 코드 결함이 확인되면 소규모 수정 브랜치 → 개별 실제 재현 → 관련 자동검사 → `main` 안전 통합. 다른 개발자의 `main` 커밋을 절대 덮어쓰지 않는다.
