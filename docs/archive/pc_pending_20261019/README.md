# PC 동기화 전 보존본의 누락 기록 복구

2026-11-04 복구. 아래 문서는 **2026-10-07~09 당시 기록**이며 현재 게임 규칙이나 새 제작 지시가 아니다. 원문 바이트를 보존했다. 문서 안의 미커밋·미게시·현재·최종 등의 표현도 해당 날짜를 기준으로 읽는다. 현재 기준은 최신 AGENTS.md, 시나리오 마스터와 실제 main이다.

원본은 2026-10-19 PC 동기화 전 백업 508d1b2의 미추적 부모 cd881080473e7eb47c53d3a6817a655582b3711b다. 테스트를 Git 기록에 남기려던 명시적 .gitignore 예외가 있었으며 폐기 지시는 발견하지 못했다. 실제 게임 원화/기능은 이미 게시돼 있어 되돌리거나 재교체하지 않았다.

## 회수한 당시 문서

- [animation_sheet_standard_2026_10_09.md](docs/animation_sheet_standard_2026_10_09.md)
- [book_battle_lock.md](docs/book_battle_lock.md)
- [goblin_commoner_remaster_2026_10_09.md](docs/goblin_commoner_remaster_2026_10_09.md)
- [hydra_remaster_2026_10_08.md](docs/hydra_remaster_2026_10_08.md)
- [hydra_remaster_2026_10_09.md](docs/hydra_remaster_2026_10_09.md)
- [lich_remaster_2026_10_09.md](docs/lich_remaster_2026_10_09.md)
- [texture_quality_audit_2026_10_07.csv](docs/texture_quality_audit_2026_10_07.csv)
- [texture_quality_review_2026_10_07.md](docs/texture_quality_review_2026_10_07.md)
- [vampire_remaster_2026_10_08.md](docs/vampire_remaster_2026_10_08.md)

## 테스트와 검증 근거

원래 tests/ 경로의 goblin_commoner_remaster.gd 및 lich_remaster.gd와 각각의 UID를 복구한다. tests/* 제외를 유지하고 이 네 파일만 정확히 허용한다. 테스트 기대값은 복구 시점 main과 일치하며 실제 재실행 결과는 [결정 및 검증 기록](../../missing_work_decisions_20261104.md)에 남긴다.

[manifest.json](manifest.json)에 13개 파일의 원본 Git blob·SHA256·복구 경로를 기록했다. 문서 9개와 테스트 2개, 대응 UID 2개 모두 원본과 바이트가 같다. 로컬 D:/Workspace/.../raw_assets 링크는 당시 원본 보관 경로이며 저장소에서 열리는 공개 링크가 아니다. 해당 원본·영상·시트 파일을 이 작업에서 다시 게시한 것은 아니다.

고블린 최초 부패 후보와 히드라 15/18프레임 시험은 문서에 폐기/대체 사실이 명시된 과거안이다. 최신 원화로 복원하면 안 된다. CSV도 리마스터 이전인 2026-10-07 측정치이며 현재 화질 판정으로 재사용하지 않는다.
