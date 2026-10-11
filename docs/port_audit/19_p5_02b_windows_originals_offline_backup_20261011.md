# P5-02B — Windows PC 전용 원화 보존 및 독립 복구 검증 절차 (2026-10-11)

## 상태와 범위

**PC의 파일을 읽을 수 있는 연결이 이 대화에 없으므로 실제 백업은 미실시.** GitHub용 스크립트와 안전 회귀검사를 만들어도 P5-02B 상태는 \`TODO\`다. Windows 사용자가 **본인 PC에서** 실행하고 별도의 실제 장치로 복제·복구 확인한 증거가 있어야 승인할 수 있다.

Godot 원본 게임의 실제 PC 위치는 기본적으로 \`C:\Dev\necromancer_and_dice\`, 과거 웹 원본 보관 위치는 \`D:\Workspace\Games\necromancer-and-dice\`로 알려져 있다. 파일이 다른 위치에 있다면 아래 옵션을 실제 경로로 변경한다.

본 도구는 \`scripts/p5_02b_local_originals_backup.ps1\`이며 **GitHub에 올리는 스크립트는 파일을 외부로 전송하지 않는다.** 원본을 이동·삭제·수정하지 않으며, 자동 보존 후보는 아래 폴더다.

- \`D:\Workspace\Games\necromancer-and-dice\raw_assets\` — 웹 개발 중 제작 원화·별도 후보.
- \`C:\Dev\necromancer_and_dice\source_assets\` — Godot 기본 import에서 제외된 자료.
- 그 외 원화·PSD·Aseprite·Blender·저장되지 않은 제작자료 폴더는 \`-AdditionalSourcePaths\` 옵션으로 **명시적으로** 등록한다.

**주의:** 이 세 폴더가 모든 PC 전용 제작자료를 포함한다는 보장은 없다. 최초 발견 결과와 다른 프로젝트 폴더, 편집기별 원본 파일, Git 비추적/무시 파일을 사용자 PC에서 직접 검토해야 한다.

## 1. Windows에서 읽기 전용 감사

먼저 활성 프로젝트의 로컬 수정과 HEAD를 확인한다. 자동으로 Git 저장소를 reset/pull/merge하지 않는다.

\`\`\`powershell
git -C C:\Dev\necromancer_and_dice status --short
git -C C:\Dev\necromancer_and_dice rev-parse HEAD

powershell -NoProfile -ExecutionPolicy Bypass -File C:\Dev\necromancer_and_dice\scripts\p5_02b_local_originals_backup.ps1 -Mode Audit
\`\`\`

이 모드는 **파일 복사·쓰기·삭제 없이** 원본 폴더별 파일 수, 합계 바이트, 제외 후보 개수를 보고한다. 두 기본 경로가 없으면 성공으로 처리하지 않고 실패한다. 파일이 더 있는 폴더는 \`-AdditionalSourcePaths 'D:\MyArt\Originals'\`처럼 추가한다.

## 2. 물리적으로 독립된 드라이브에 최초 복사

**반드시** 검증된 외장 SSD/HDD 등 사용자 소유의 다른 물리 장치를 선택하고 새 백업 폴더명을 사용한다. 예시는 \`E:\Necromancer_Backups\P5-02B_20261011\`이며 실제 외장 장치 문자와 존재 여부를 먼저 확인해야 한다.

\`\`\`powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Dev\necromancer_and_dice\scripts\p5_02b_local_originals_backup.ps1 -Mode Backup -DestinationRoot 'E:\Necromancer_Backups\P5-02B_20261011'
\`\`\`

- 자동 복사 도중에도 원본 SHA256을 앞뒤로 읽어 파일 변경을 검출하며, 결과 파일 SHA256을 비교한다.
- 저장된 \`manifest.json\`에는 각 원화별 경로(로컬), 크기, SHA256 및 건너뛴 항목 목록을 기록한다. \`manifest.sha256\`으로 manifest 자체 변경도 검출한다.
- 도구는 심볼릭 링크·정션과 자격증명, 키 파일, 엔진 캐시, Git 내부 정보, 개인 저장 DB 형식을 의도적으로 제외한다. **\`Excluded\` 항목의 목록은 직접 확인해야 하며 해당 항목까지 무조건 백업했다고 가정하면 안 된다.**
- 대상이 같은 드라이브면 기본적으로 차단한다. \`-AllowSameVolume\`은 CI의 가짜 자료/임시 사본 검증용 예외이며, 그 결과는 **독립 재해복구 백업 승인 불가**.
- 이미 존재하는 백업 폴더에 덮어쓰지 않는다. 작업 중 실패 시 \`BACKUP_INCOMPLETE\` 표식이 남고, SHA 및 복사가 끝난 성공본에만 \`BACKUP_COMPLETE\`가 생긴다.
- **원본은 어떤 경우에도 지우거나 이동하지 않는다.** 백업 결과는 GitHub 공개 저장소에 커밋하거나 첨부하지 않는다.

## 3. 외장 장치를 분리·재연결하고 검증

\`\`\`powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\Dev\necromancer_and_dice\scripts\p5_02b_local_originals_backup.ps1 -Mode Verify -DestinationRoot 'E:\Necromancer_Backups\P5-02B_20261011'
\`\`\`

\`P5_02B_VERIFIED\`가 출력되고 종료 코드 0인지 확인한다. 검증은 원본 PC 폴더 대신 **외장 장치에서 읽은 백업의 각 파일 및 manifest 해시**를 검사한다. 실패하면 백업이 완료되었다고 보고하지 않는다.

하나 이상의 임의 원화/편집기 원본(PSD/KRA/BLEND 등)을 **사본으로 열어 편집기에서 복구**되는지 확인한다. 사본 복구 검사도 보고서에 기록한다.

## 4. 웹 고정 원본 이력의 두 번째 독립 사본

별도로 생성된 GitHub Release **P5-02A**에서 7개 파일 전부를 사용자 소유의 외장 장치 또는 GitHub 이외의 저장소에 복사하고, Release에 포함된 \`SHA256SUMS\`로 7개 파일 검증한다.

https://github.com/gamja121/necromancer-and-dice-godot/releases/tag/p5-02-frozen-html-final-e13d5149-20261011

Git 전체 번들 재조립의 SHA256은 \`5c4b08436d6bb2f56d4466e1b46f5b867a2215716fec08a277cb7ed95a37a7a4\`이다. 복구 안내와 정확한 SHA 기록은 \`docs/port_audit/18_p5_02_frozen_web_archive_20261011.md\`에 있다. **GitHub 내부의 두 저장소/Release는 GitHub 외부 복제본을 대체하지 않는다.**

## 5. 실제 승인 필수 기록

| 항목 | 상태 |
| --- | --- |
| PC 프로젝트 로컬 HEAD와 GitHub \`main\` HEAD 및 미커밋 수정 확인 | 미확인 |
| \`raw_assets\`, \`source_assets\`의 실제 위치·존재 여부 | 미확인 |
| 다른 PC 전용 원화·PSD·제작자료 검색 및 포함/제외 목록 승인 | 미확인 |
| 독립 외장 장치·사용자 소유 백업 경로 | 미확인 |
| 원화 복사 \`P5_02B_BACKUP_COMPLETE\` 로그 | 미확인 |
| 장치 재연결 후 \`P5_02B_VERIFIED\` 성공 | 미확인 |
| 복구한 PSD/원화를 실제 편집기에서 열어본 증거 | 미확인 |
| P5-02A ZIP·Git 번들 7파일 외부 독립 복제·SHA 검증 | 미확인 |
| 원본 삭제 금지·Pages 기존 배포 유지 확인 | 유지 |

위 검증이 완료되지 않으면 **P5-02B와 상위 P5-02는 \`TODO\`**다. 도구 자체의 GitHub CI 통과는 PC 자료 백업과 다르다. 작업보고서는 개인 PC 드라이브 경로나 원화 manifest·로그 전체를 공개 GitHub에 올리지 않고, 민감한 경로를 제거한 개수·검증 결과만 기록한다.
