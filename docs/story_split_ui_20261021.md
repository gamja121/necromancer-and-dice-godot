# 사건 UI — 좌측 삽화 / 우측 줄거리·대사·선택 (2026-10-21)

## 사용자 확정 의도
- 사건의 **서술(narration)**과 **인물의 말(speech)**을 시각적으로 분명히 구별한다.
- 왼쪽은 기존 스토리 원화(16:9 비율 보존), 오른쪽은 사건 제목 → 사건 이야기(나레이션) → 등장인물 대사 → 선택/계속/돌아가기 버튼.
- 화자의 실제 발화가 없는 장면은 대사 상자를 만들지 않고 사건 이야기 상자를 아래로 확장한다.
- 오른쪽의 버튼은 기존 Godot Button과 저장/진행 콜백 그대로. 본 작업은 시각 구도만.
- 루틴/발견의 독립 카드 UI는 별도 서체/가로구도 검토 대상으로 남기며, 이번 변경에서 메인 스토리 시스템을 우선 정리한다.

## 기술
- `systems/story_split_layout.gd`: 1280×720 정규 좌표, 16:9 원화 재배치, 우측 구역과 행동 버튼 계산.
- `map.gd`: **11개 실제 메인 사건/결과 화면**에만 `story_modal()` 사용. 기본 `modal()`, 비사건 장소·게임 규칙은 그대로. `image()`는 분리된 사건 패널 내부의 원래 그림 범위만 비례 변환하며, 동일한 원화를 재사용한다.
- 스토리 구도 내 내레이션·대사는 독립 밝은 양피지 텍스처, 별도 제목과 dark-ink 색상; 그림과 같은 레이어에 놓지 않는다.
- 이야기 없이 대사만 나타나는 예외/저장된 결과 안내는 원본 발화 또는 보조 설명 의미에 따라 처리한다.
- 인트로 양피지 변경 작업 PR #225/#226과 교차 편집 위험이 있으므로 현재 `GRAVEYARD_DIALOGUE_FRAME` 원본 참조 자체는 변경하지 않음.

## 기본 5가지 원칙
- Trigger: 기존 실제 사건/저장 재개
- Information: 기존 scene art, beat.effect, beat.speaker, beat.dialogue, choice states
- Interaction: 기존 버튼 콜백과 수량, scene skip/retry 규칙 유지
- Visual: 좌측 그림, 우측 나레이션/대사/선택; 대사 부재시 한 패널 확대
- State: UI 한정, save, RNG, map generation, rewards, combat 변경 없음

## 확인
- Godot editor import, `scripts/test_story_event_layout.gd`, `scripts/test_ui_grave_dialogue_stage5p.gd` 및 기존 스토리 UI/선택 검사 필요.
- PC/Android 실제 화면의 한국어 잘림과 터치 위치는 CI만으로 보장하지 않는다. 
- 관련 작업 https://github.com/gamja121/necromancer-and-dice-godot/issues/227
