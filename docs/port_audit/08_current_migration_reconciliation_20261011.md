# Godot 전체 이식 현황 재대조 — 2026-10-11

## 작업 목적 (변경 금지)

**완성된 웹 프로토타입의 기능·규칙·대사·에셋·저장 및 연출을 가능한 빨리 Godot로 100% 이식하고, 전체 동작 검증과 원본 백업을 거친 뒤 기존 웹 프로토타입 저장소를 폐기한다.** 웹 버전에 새 콘텐츠를 만들거나 새 보스전을 발명하는 것은 이식 작업이 아니다. 원본에서 아직 구현하지 않은 최종 보스 전투는 Godot의 신규 콘텐츠 과제로 분리한다.

- 고정 웹 소스: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`
- Godot 기준: `gamja121/necromancer-and-dice-godot/main`
- **웹 저장소 삭제는 명시적 최종 승인 전 금지.** 현재 웹 저장소는 Godot Web 미리보기 Pages 배포 경로이기도 하므로 대체 배포 계획 확정 및 원본 아카이브까지 보존해야 한다.

## 갱신된 코드 수준 대응 (159개)

| 분류 | 2026-10-10 1차 감사 | 2026-10-11 구현/검사 확인 |
| --- | ---: | ---: |
| ✅ 구현·기능별 회귀검사 확인 | 133 | **155** |
| 🟡 부분 이식 / 결정·확인 필요 | 7 | **2** |
| 🔴 코드 미이식 | 17 | **0** |
| 🔵 엔진 의도 변경 | 2 | **2** |

**이 숫자는 전체 게임 완료율이나 P5 삭제 승인율이 아니다.** 새 게임 → 마지막 사건 → 다음 바퀴까지 연결해 플레이하는 P4 실물 통합·시각·강제 종료 검증이 남아 있다. 예전 1차 감사 문서의 133/7/17/2는 당시 기록이므로 역사적 스냅샷으로 보존한다.

### 구현 확인 근거

- W120/W163: 공용 사건 결과 복귀, 전투 덱 선택·체크포인트 중단 복원: `scripts/test_graveyard_battle_return.gd`, `scripts/test_story_battle_resume.gd`.
- W170~W172: 공동묘지 사건의 등장·선택·사건 전투: `scripts/test_graveyard_*.gd`와 `systems/story_event_entry.gd`.
- W173~W176: 구조/방치 마을 소문 → 기사단장 → 마물사냥꾼: `scripts/test_village_rumor_beats.gd`, `scripts/test_knight_commander_dialogue.gd`, `scripts/test_monster_hunter_dialogue.gd`.
- W177~W181: 광신도 소문·제단·싸움/지나감 → 전이문 부활 양 갈래: `scripts/test_cultist_*.gd`, `scripts/test_ritual_portal_revival.gd`.
- W182~W184: 마물의 왕 추적 5개 원본 장면, 상태 구조와 실제 맵 화면: `scripts/test_monster_king_hunt_location.gd`, `scripts/test_story_state_regression.gd`, `map.gd`.
- W094: 웹 `v2-rules.js`의 동일 마물·동일 눈금에서 저주 1개라도 있으면 다른 낙인 축복 전부 억제. `systems/battle_rules.gd`, 실전 `systems/battlefield_rules.gd`, `scripts/test_battle_source_parity.gd`에서 대응.
- W086: 실제 전장 `systems/battlefield_rules.gd`는 이미 웹과 같이 행동 우선순위 완전 동률을 저장 가능한 `rng.randf()`로 처리. 새 테스트에서 동일 체크포인트를 복원하고 난수·행동 순서가 재현되는지 검사. 구형 `BattleRules.step()`의 ID 순서는 실전 전장에서 쓰이지 않음.
- W153: `scripts/test_save_process_boundary.gd`와 CI에서 실제 독립 Godot 프로세스를 강제 종료하며 임시 파일·이전 커밋·새 커밋·이동 재실행 방지를 검증. 단일 작성자 정책과 남은 다중 인스턴스 한계는 [W153 정책 문서](09_w153_save_policy_20261011.md)에 명시. Windows 실기·P4 전반 통합검사 미완료.
- W005/W006: 고정 웹 원본 타이틀 음악을 동일 SHA로 가져왔으며 전체 음량·Music/SFX 공용 설정을 타이틀에 연결. [타이틀 오디오 이식 기록](10_title_audio_migration_20261011.md). 웹 title-loop.mp4와 Godot 묘지 패럴랙스의 시각 변경(P3-03)은 아직 최종 승인 대상이므로 W005는 부분 항목으로 유지.
- W080: 원본 `v2-design-data.js`의 46종 필드 전체가 현재 Godot 데이터와 일치. Dracula는 신규 43종 전투/정찰/보상 후보에서 제외했지만 기존 세이브·에셋·정의는 보호. [46종 고정 참조/정책](11_unit_catalog_parity_20261011.md)과 `scripts/test_web_unit_catalog_parity.gd`에서 검증.

## 다음 최단 경로 (우선순위)

1. **P3-03 / W005 시각:** 웹 영상 대신 사용 중인 cemetery 패럴랙스 타이틀의 최종 시각 변경 승인 및 실기 음악 재생 검사.
2. **P3-04~05 / W195 및 화면:** 전투 모션·장소 대체 시각 효과를 실제 실행 화면에서 검증.
3. **P4:** 양 사건 분기 및 승패·지나감, 게임 처음부터 다음 바퀴, 주사위·보상·전투·사건 중 저장/복원 전체 통합 검사.
4. **P5:** 실행 시 HTML/JS/웹 저장소 의존성 0 → 전체 원본·제작자료 백업과 SHA 검증 → 159개 최종 재감사 → 사용자 명시적 승인 후 웹 저장소 삭제. *P5 게이트가 하나라도 실패하면 삭제 금지.*

**작업 규칙:** 새로운 기능·콘텐츠 확대보다 미이식 기능과 검증 결함을 우선한다. 매 단계는 원본 대조 → 최소 변경 → 헤드리스/실기 테스트 → CI 확인 → GitHub main 병합. 기존 독립 병렬 작업(돌 타일 셔플 등) 보존.
