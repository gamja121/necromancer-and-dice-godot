# ButtonEffectsModule

Control을 상속하는 독립 공용 스크립트: systems/button_effects_module.gd.
Button 또는 TextureButton 등 BaseButton의 직접 자식으로 추가한다.

구조:
Button
└─ ButtonEffectsModule

에디터에서 ButtonEffectsModule 노드를 추가하거나 Control 자식에 스크립트를 붙인다. 코드에서 사용할 때:

    var effects = ButtonEffectsModule.new()
    button.add_child(effects)

선택/사건 등 중요한 버튼의 예:

    var effects = ButtonEffectsModule.new()
    effects.hover_scale = Vector2(1.075, 1.075)
    effects.hover_rotation_degrees = 1.75
    button.add_child(effects)

Inspector 기본값:
- animation_duration: 0.07초
- hover_scale: Vector2(1.05, 1.05)
- hover_rotation_degrees: 1도, 진입마다 좌/우 무작위
- use_hover_rotation: true
- ease_type: EASE_OUT
- transition_type: TRANS_QUAD
- click_scale: Vector2(0.96, 0.96), 현재 scale에 곱하며 연속 클릭으로 과도하게 작아지는 것을 방지
- click_duration: 0.10초, 눌림 40% / 복귀 60%

현재 적용은 두 곳에 한정했다.
- 맵 전장 덱 선택의 전투 시작: 1.075배 / 1.75도
- 전장 일시정지/계속: 기본 1.05배 / 1도

Trigger: mouse_entered, mouse_exited, pressed. button_down/up 신호로 클릭 상태를 관리하지 않는다.
Information: 기본 scale/rotation/pivot, hover 방향/상태, 전용 Tween, disabled, 터치/마우스 입력 종류.
Interaction: 부모 BaseButton과 자기 Tween. 입력 종류 관찰은 이벤트를 소비하거나 재전송하지 않는다. 기존 pressed 연결을 제거하지 않고 모듈 자기 연결만 종료 시 정리한다.
Visual Change: scale/rotation만 Tween으로 변경. 텍스트·폰트·이미지·위치·크기·최소 크기·버튼 action_mode·클릭 로직은 수정하지 않는다.
Memory: 런타임 상태만 유지. 저장 없음. 회전은 자체 RNG로 결정하여 전투 RNG와 분리한다.

설치된 Godot 4.7.2의 extension API에서 Control.pivot_offset_ratio 지원을 확인했다. 픽셀 pivot_offset을 0으로 하고 ratio를 (0.5, 0.5)로 설정하므로 크기가 달라져도 중심을 유지한다. 두 pivot 값은 모듈 종료 시 원래 값으로 복원한다.
일반 버튼은 기본 ONE/0으로 복귀하며, 기존 비기본 scale/rotation이 있는 버튼은 해당 시작값으로 복귀한다.

기존 Tween은 새 이벤트마다 kill한다. 클릭 복귀는 당시 hover/disabled 상태를 다시 읽는다. 정상 클릭 직후 기존 콜백이 버튼을 disabled로 바꿔도 기본 상태로 복귀한다. disabled 상태에서는 새 hover/click 효과가 시작되지 않는다. 숨김·제거 시 진행 중 Tween을 종료하고 원래 상태를 복원한다. 잘못된 부모는 경고 후 비활성화한다.

터치 클릭은 hover를 남기지 않고 기본 상태로 복귀한다. 실제 마우스 입력으로 전환하면 hover가 다시 동작한다. 키보드/게임패드가 발생시키는 기존 pressed 신호도 그대로 받는다. SFX는 아직 추가하지 않았으며 향후 이 이벤트 처리 함수나 부모 신호에 연결할 수 있다. 같은 버튼의 scale/rotation을 다른 시스템에서도 동시에 Tween하지 않는다.

검증: import/전장 시작 성공. 실제 Godot 렌더러에서 hover 반복 24회, 연속 클릭 12회, 복귀 값, 버튼 크기 변경에 따른 중심값, disabled 전환/입력 무시, 터치 이벤트 후 복귀, 잘못된 부모의 안전한 경고, 기존 전투 confirmed 신호가 한 번 실행되는 것을 확인했다. 덱 버튼 hover 화면도 확인했다. 확인용 임시 호출은 원복했고 프로젝트에 새 테스트 코드·파일·버튼을 남기지 않았다. 모바일 실기기 및 실제 마우스 드래그 조작은 미확인이며, 해당 이벤트/상태 경로를 엔진에서 확인했다.

Godot Control 문서:
https://docs.godotengine.org/en/latest/classes/class_control.html#class-control-property-pivot-offset-ratio
