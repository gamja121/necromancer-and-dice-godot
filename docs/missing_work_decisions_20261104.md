# 미반영 후보의 채택·폐기 결정 확인 — 2026-11-04

작업 추적: [Issue #370](https://github.com/gamja121/necromancer-and-dice-godot/issues/370). 기준 main d52c9af. 사용자는 올리기로 한 작업이라면 게시하라고 요청했다. **원격 브랜치 업로드, 본편 병합, 미완료 개발은 서로 다른 상태다.** 미병합만으로 폐기 또는 업로드 누락으로 판단하지 않는다.

| 항목 | 확인된 결정 기록 | 이번 처리 |
| --- | --- | --- |
| 옛 원화·QA 문서 9개, 테스트 2개 | PC 백업은 동기화 전 보존본. 리치 기록에 테스트가 향후 기록에서 빠지지 않도록 Git 예외를 만들었다고 명시하고, 실제 .gitignore에도 두 테스트/UID 예외가 있다. 폐기 지시 없음 | 문서는 [역사 아카이브](archive/pc_pending_20261019/README.md), 테스트/UID는 원래 경로에 복구. 현재 런타임·원화 변경 없음 |
| 웜홀 최종 조우와 엔딩 후 원정 지속 #269 | [Issue #275](https://github.com/gamja121/necromancer-and-dice-godot/issues/275)의 확정 요구와 [체크포인트](https://github.com/gamja121/necromancer-and-dice-godot/issues/275#issuecomment-6351458840)에 검사 수정 후 병합 계획. 명시적 폐기 없음. 이후 [시나리오 기준서](SCENARIO_MASTER.md)는 조건부 분기를 요구하고 해당 PR의 특정 결말을 자동 승인하지 않음 | 이미 [원격 PR #269](https://github.com/gamja121/necromancer-and-dice-godot/pull/269)에 보존. 채택 의도는 있으나 구현·검증 미완료로 분리. 오래된 전체 브랜치 자동 병합 제외 |
| 마물 카드 24종 복구 #318 | [후보 상태 기록](https://github.com/gamja121/necromancer-and-dice-godot/blob/eb9e3a3151bcf92ed0279b28881d5db89c445fe7/docs/card_portrait_user_confirmed_24_restore_24_keep_20261025.md): 후보와 완성 원화를 구분, 개별 승인·먹선·밝고 어두운 배경 검수 후 교체. PR 본문에 본편 병합 예정 없음 | [원격 PR #318](https://github.com/gamja121/necromancer-and-dice-godot/pull/318)에 후보 검토 기록이 이미 보존됨. 완성 자산 일괄 반영 승인으로 해석하지 않음 |
| 선택형 전투 이펙트 #164 | [승인 범위와 반영 조건](https://github.com/gamja121/necromancer-and-dice-godot/blob/d06a91264a621c34d60d45081d5751bc8b76a6bb/docs/optional_battle_vfx_2026_10_14.md): 개발 범위는 승인했으나 분리 브랜치에서 검증/리뷰 전 자동 병합 금지 | [원격 PR #164](https://github.com/gamja121/necromancer-and-dice-godot/pull/164)에 이미 보존된 미완료 실험. 폐기 확정으로 분류하지 않음 |

## 웜홀 작업의 남은 실제 개발

PR269 head712fef0의 [검사 실행](https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/39855392045)에서 저장된 보드 이전 관련 두 검사가 실패하고 후속 실제 전투/저장 검사는 생략됐다. 현 main의 20/40/60 중간 보스와 별도 최종전, 책 엔딩·수확·세이브를 보존해 재통합해야 한다. 이 작업은 파일 업로드만의 문제가 아니며 시간 회귀/새 엔딩 조건을 임의로 발명해서 해결하지 않는다. 본 기록의 게시가 해당 기능의 구현 완료를 뜻하지 않는다.

## 복구 원본의 무결성과 현행 재검증

역사 문서 9개·테스트 2개·UID 2개는 [manifest](archive/pc_pending_20261019/manifest.json)의 원본 Git blob 및 SHA256과 대조한다. 테스트는 플레이어 저장에 접근하지 않는 기존 리소스/소환 회귀다. 현재 규칙과 비교한 뒤 Godot4.7.2로 다시 실행한다. 검사 결과와 게시·PC 동기화는 아래 및 Issue370 체크포인트에 남긴다.

Godot4.7.2 현행 재검증: 에디터 import 종료0/오류0, 평민 고블린 리소스·실제 소환40통과/0실패, 리치 리소스33통과/0실패. 합계73항목 통과, 스크립트 오류·종료 누수0. 원본13파일의 Git blob 및 SHA256 일치. 기존 다른 로컬 tests 파일은 계속 제외됨을 확인했다. 이 검증은 해당 원화/소환 회귀이며 전체 전투 연출의 새 시각 승인으로 주장하지 않는다.
