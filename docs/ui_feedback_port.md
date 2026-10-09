# 공용 UI 피드백 · 2026-10-08

사건 콘텐츠 이식은 사용자 요청으로 보류한다. 이번 변경은 기존 UI의 시각적 피드백에 한정한다.

## 적용
- 기존 ButtonEffectsModule 재사용: 지도 일반 액션 버튼과 RewardUI의 확인/닫기/탭 버튼.
- PlaceActions/ExplorationActions의 카드 및 순찰 타일에도 적용.
- 일반 값: hover 1.04배, 회전 ±0.6도, 0.07초. 클릭 0.96배, 0.10초.
- 회전/크기를 별도 제어하는 보물 선택 카드, 전투 덱 카드, 이동 주사위, 지도 타일/보유 목록 아이콘에는 중복 적용하지 않는다.
- PanelEffectsModule: Control 직접 자식으로 재사용. 열기 0.20초, 콘텐츠 이동 6px; 닫기 0.12초, 하강 3px. 배경 암막은 고정해 화면 가장자리 틈을 방지한다.
- RewardUI 기반 창 및 지도 일반 장소/집 창에 열기 적용.
- 장소, 탐색, 계승, 보유 카드, 이동 주사위 카드 창의 돌아가기/닫기에 닫기 적용.
- 화면 교체/전투 진입/보상 확정은 기존 즉시 제거 흐름을 유지한다. 기존 전투 덱과 중앙 전투 진입 연출은 유지한다.

## 상태와 입력
Trigger: mouse_entered/mouse_exited/pressed 및 창 생성/닫기 요청.
Information: 버튼 hover/disabled/원래 transform, 창 원래 색상/콘텐츠 위치, Tween/closing 상태.
Interaction: 부모 Control/BaseButton, Tween, 지도 overlay 소유권.
Visual: 버튼 scale/rotation, 창 alpha/콘텐츠 y 위치. 원래 이미지/폰트/크기 유지.
Memory: 런타임만 사용. 저장 데이터와 게임 규칙 변경 없음.
닫는 동안 마우스/터치 차단과 버튼 비활성화를 적용한다. 중복 닫기는 무시하며, 이전 창의 콜백이 새 창을 제거하지 않도록 소유권을 확인한다.
외부 즉시 제거 및 exit_tree에서 Tween을 정리하고 원래 transform을 복원한다.

## 확인
Godot 4.7.2 Compatibility 실제 렌더로 집/순찰/보유 카드 화면을 확인했다.
빠른 hover 30회, 클릭 25회, disabled/터치 복귀, 중심 pivot, 중복 닫기 1회 완료, 순찰 선택/복귀, 보유 창 닫기, 진입 중 닫기/새 창 교체를 확인했다.
터치 입력 상태는 합성 입력으로 검증했다. 모바일 실기기 검증은 수행하지 않았다.
개인 저장 원본을 복원했고, 임시 검증 코드는 프로젝트에 추가하지 않았다.
