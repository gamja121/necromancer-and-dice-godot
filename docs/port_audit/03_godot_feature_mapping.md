# 완전 이식 감사 1-3 — 웹 기능 ↔ Godot 대응 관계

작성일: 2026-10-10

## 조사 기준

- 웹 기준: `necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`
- Godot 조사 HEAD: `necromancer-and-dice-godot/main@f5c83f528c4cc076776066573b3ae2280da7ff75`
- 대상: 1-2에서 이식 대상으로 분류한 **159개 항목**
- 이번 단계는 **대응 파일을 연결하는 단계**다. `FOUND`는 “같은 이름의 시스템/상태/화면 후보가 코드에 존재”한다는 뜻이며 웹과 정확히 동일하다는 완료 판정이 아니다. 실제 규칙 차이는 1-4에서 판정한다.

## 상태 정의

| 상태 | 의미 |
|---|---|
| FOUND | 현재 Godot에서 대응 런타임/데이터/씬 후보를 찾음. parity는 미검증 |
| PARTIAL | 일부 대응은 있으나 빠진 부분 또는 이미 보이는 구조 차이가 있음 |
| NONE | 현재 Godot 런타임에서 대응 구현을 찾지 못함 |
| ENGINE_REPLACEMENT | 웹 전용 구현을 Godot 네이티브 방식으로 교체하는 대응 관계가 있음 |

## 결과

- 전체: **159**
- FOUND: **131**
- PARTIAL: **9**
- NONE: **17**
- ENGINE_REPLACEMENT: **2**

### 카테고리별

| 카테고리 | 전체 | FOUND | PARTIAL | NONE | ENGINE_REPLACEMENT |
|---|---:|---:|---:|---:|---:|
| 진입/타이틀 | 6 | 4 | 2 | 0 | 0 |
| 인트로 | 4 | 4 | 0 | 0 | 0 |
| 맵/원정 | 24 | 24 | 0 | 0 | 0 |
| 장소/타일 | 26 | 25 | 1 | 0 | 0 |
| 전투 | 41 | 37 | 3 | 1 | 0 |
| 보상/인벤토리 | 15 | 15 | 0 | 0 | 0 |
| 저장/복원 | 15 | 11 | 2 | 1 | 1 |
| 사건/퀘스트 | 15 | 0 | 0 | 15 | 0 |
| 연출/오디오 | 13 | 11 | 1 | 0 | 1 |

## 현재 대응 없음

- **W120 사건 전투 후 사건으로 복귀** — 사건 전투 후 특정 사건 장면으로 복귀하는 웹 eventId 기반 런타임 대응을 현재 Godot에서 찾지 못함.
- **W163 사건 전투 덱 선택 중단 안전 복원** — 사건 전투 자체가 아직 Godot 런타임에 없어 eventId/runId 기반 사건전투 덱 선택 복원 대응도 찾지 못함.
- **W170 공동묘지 습격받는 아이 사건** — 웹의 9개 사건 ID, eventFlags/quest/story 플래그 상태기계 및 사건 대사/원화 런타임을 현재 Godot 코드/데이터에서 찾지 못함.
- **W171 아이 구한다/지나친다 선택** — 웹의 9개 사건 ID, eventFlags/quest/story 플래그 상태기계 및 사건 대사/원화 런타임을 현재 Godot 코드/데이터에서 찾지 못함.
- **W172 아이 구조 선택의 사건 전투** — 웹의 9개 사건 ID, eventFlags/quest/story 플래그 상태기계 및 사건 대사/원화 런타임을 현재 Godot 코드/데이터에서 찾지 못함.
- **W173 아이 구조 후 마을 소문** — 웹의 9개 사건 ID, eventFlags/quest/story 플래그 상태기계 및 사건 대사/원화 런타임을 현재 Godot 코드/데이터에서 찾지 못함.
- **W174 아이 방치 후 마을 소문** — 웹의 9개 사건 ID, eventFlags/quest/story 플래그 상태기계 및 사건 대사/원화 런타임을 현재 Godot 코드/데이터에서 찾지 못함.
- **W175 기사단장 오염 조사 사건** — 웹의 9개 사건 ID, eventFlags/quest/story 플래그 상태기계 및 사건 대사/원화 런타임을 현재 Godot 코드/데이터에서 찾지 못함.
- **W176 마물사냥꾼 조우** — 웹의 9개 사건 ID, eventFlags/quest/story 플래그 상태기계 및 사건 대사/원화 런타임을 현재 Godot 코드/데이터에서 찾지 못함.
- **W177 광신도 소문** — 웹의 9개 사건 ID, eventFlags/quest/story 플래그 상태기계 및 사건 대사/원화 런타임을 현재 Godot 코드/데이터에서 찾지 못함.
- **W178 광신도 제단 조우** — 웹의 9개 사건 ID, eventFlags/quest/story 플래그 상태기계 및 사건 대사/원화 런타임을 현재 Godot 코드/데이터에서 찾지 못함.
- **W179 광신도 제단 싸운다/지나간다** — 웹의 9개 사건 ID, eventFlags/quest/story 플래그 상태기계 및 사건 대사/원화 런타임을 현재 Godot 코드/데이터에서 찾지 못함.
- **W180 마물의 왕 부활 의식 장소/전이문 사건** — 웹의 9개 사건 ID, eventFlags/quest/story 플래그 상태기계 및 사건 대사/원화 런타임을 현재 Godot 코드/데이터에서 찾지 못함.
- **W181 의식 저지 전투 승패에 따른 불완전/완전 부활** — 웹의 9개 사건 ID, eventFlags/quest/story 플래그 상태기계 및 사건 대사/원화 런타임을 현재 Godot 코드/데이터에서 찾지 못함.
- **W182 마물의 왕 추적 사건** — 웹의 9개 사건 ID, eventFlags/quest/story 플래그 상태기계 및 사건 대사/원화 런타임을 현재 Godot 코드/데이터에서 찾지 못함.
- **W183 사건/퀘스트/스토리 플래그 상태기계** — 웹의 9개 사건 ID, eventFlags/quest/story 플래그 상태기계 및 사건 대사/원화 런타임을 현재 Godot 코드/데이터에서 찾지 못함.
- **W184 사건별 원화 레이어/대사 비트** — 웹의 9개 사건 ID, eventFlags/quest/story 플래그 상태기계 및 사건 대사/원화 런타임을 현재 Godot 코드/데이터에서 찾지 못함.

핵심적으로 **사건/퀘스트 15개 전부가 NONE**이다. 웹에서 실제 동작했던
공동묘지 아이 사건 → 구조/방치 소문 → 기사단장 → 마물사냥꾼 → 광신도 → 부활 의식 → 마물의 왕 추적
체인의 런타임 상태와 대사/원화 연결이 현재 Godot에는 없다.

또한 사건 전투가 없기 때문에 **W120 사건 전투 후 사건 복귀**, **W163 사건 전투 덱 선택 중단 복원**도 대응이 없다.

## 부분 대응으로 잡힌 항목

- **W005 타이틀 BGM/영상 및 사운드 토글** — Godot 타이틀 시각 장면은 있으나 현재 title.tscn/title.gd에서 웹의 타이틀 BGM·영상·타이틀 사운드 토글 대응은 확인되지 않음.
- **W006 옵션 패널** — 공용 오디오 설정 UI는 맵/전장에 있으나 타이틀 자체 옵션 패널 대응은 확인되지 않음.
- **W075 일반 이벤트 타일 기본 표시** — event 타일은 카탈로그와 진입 분기에 있으나 현재 map.gd의 일반 장소 이미지 매핑에는 event 키가 없어 완전한 표시 대응을 1-4에서 확인해야 함.
- **W080 마물 데이터 46종** — Godot 유닛 데이터가 존재하나 현재 units.json은 47종(웹 기준 46종 + dracula)이라 정확한 기준 대응은 1-4에서 확인 필요.
- **W086 동률 행동 순서 RNG** — 동률 처리 코드가 있으나 주석상 웹 랜덤 tie-break 대신 stable ID를 사용함. 상세 판정은 1-4 대상.
- **W094 같은 눈금 저주 전역 우선** — 웹은 같은 눈금에서 저주가 전역 우선인데 현재 Godot step()은 bless와 curse를 각각 누적하는 구조로 보여 상세 parity 검증 필요.
- **W153 revision 기반 커밋 충돌 방지** — 임시 파일 저장·실패 롤백은 있으나 웹의 revision 기반 충돌 검사를 직접 대응하는 필드는 현재 확인되지 않음.
- **W154 operationId 멱등성** — reward_receipts 기반 중복 방지는 있으나 웹의 범용 operationId 멱등성 계약 전체 대응 여부는 1-4에서 확인 필요.
- **W195 공격/피격/사망 모션** — 공격/피격/사망 연출 시스템은 존재하나 기존 이식 문서에 일부 마물 프레임 미완 기록이 있어 1-5 에셋 대조 필요.

특히 다음은 1-4에서 우선 비교한다.

- **W080 마물 데이터**: 웹 기준 46종인데 현재 Godot `data/units.json`은 47종이며 `dracula`가 추가되어 있다.
- **W086 동률 행동순서**: Godot 코드가 스스로 웹 랜덤 tie-break 대신 stable ID를 쓴다고 명시한다.
- **W094 같은 눈금 저주 우선**: 웹은 같은 눈금에서 저주가 전역 우선이지만 현재 Godot 전투 코드는 bless/curse를 각각 누적하는 구조다.
- **W153/W154 저장 계약**: Godot는 임시 파일 저장·rollback·receipt가 있으나 웹의 revision/범용 operationId 계약과 구조가 다르다.
- **W195 전투 모션**: 런타임 시스템은 있으나 기존 문서에 일부 마물 프레임 미완 기록이 남아 있다.

## 엔진 교체 항목

- **W151 IndexedDB 저장** → `systems/run_session.gd`의 `user://` 파일 저장으로 대체.
- **W202 브라우저 회전 처리** → Godot viewport/stretch 정책으로 대체 후보. 최종 Steam 창/해상도 정책은 별도 검증.

## 주요 대응 축

- 타이틀/진입: `title.gd`, `title.tscn`, `systems/run_session.gd`
- 인트로: `systems/intro_scene.gd`, `intro.tscn`, `data/intro_dialogue.json`
- 맵: `map.gd`, `systems/map_state.gd`, `systems/run_session.gd`, `systems/map_presentation.gd`
- 장소: `systems/place_actions.gd`, `systems/exploration_actions.gd`, `systems/home_inheritance.gd`
- 전투: `battlefield.gd`, `systems/battle_rules.gd`, `systems/battlefield_rules.gd`, `systems/battle_visuals.gd`
- 조우: `systems/encounter_generator.gd`
- 보상: `systems/corpse_capture.gd`, `systems/treasure_reward.gd`, `systems/reward_*.gd`
- 주사위 제어: `systems/dice_control.gd`, `systems/dice_control_hand.gd`
- 저장: `systems/map_state.gd`, `systems/run_session.gd`
- 오디오: `systems/audio_settings.gd`, 맵/전장 AudioStreamPlayer
- 사건/퀘스트: **현재 대응 런타임 없음**

## 다음 단계

1-4에서는 이 매핑표를 기준으로 파일 존재 여부가 아니라 **실제 규칙·수치·상태변화·저장·분기**를 웹 기준과 비교한다.
판정은 최종적으로 `✅ 완료 / 🟡 부분 이식 / 🔴 미이식 / 🔵 의도적 변경`으로 바꾼다.

전체 159개 행의 대응 관계는 `docs/port_audit/godot_feature_mapping.tsv`에 저장한다.
