# Stage 5N — 제단 의식 슬롯·정보 패널 원본 시각 복원 (2026-10-11)

## 정확한 웹 기준과 누락 확인
- 고정 원본: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- `v2-altar-ritual.css`, `v2-altar-ritual.js`에서 제단 의식은 뒤로 흐려진 맵 위에 왼쪽 재물/오른쪽 강화 대상 슬롯과 중앙 안내 카드 및 하단 마물 손패를 보여준다.
- 슬롯 보드 PNG `art/v2-style/map-test/events/altar-ritual-slots.png` blob `bb71e599c7f3a5e5c291088135a983021c0180d9`; 안내 패널 `altar-ritual-info.png` blob `9a79b5fd8abb22ddd5664dd0ebcf6dcbffa31bdd`.
- 두 PNG는 이미 Godot `assets/map/events/`에 **원본 해시 그대로 존재**했지만 `systems/place_actions.gd` 제단 UI에서 참조·표시하지 않았다. 기존 카드는 x≈178과 x≈952 양 끝에 있었고, 웹 원본의 전용 슬롯·안내 판을 사용하지 않았다.

## 변경
- Godot에서 원본 두 PNG 경로를 활용, 슬롯 보드 `Rect2(192,36,896,403.2)`(왼쪽 15%, 넓이 70%, 위 5%, 비율 520/234), 안내판 `Rect2(384,309.6,512,176)`(왼쪽 30%, 넓이 40%, 위 43%)를 표시. 별도 자산 생성/재압축 없음.
- 재물·강화 대상 카드를 슬롯 내부로 이동하고, 강화 단계·결과 안내 문장 및 `의식 실행` 버튼을 중앙 안내판 위에 표시. 확인·닫기 버튼에 기존 웹 양피지 variant 02/04 적용.
- 하단 스크롤 마물 손패를 x=192,y=532,가로896으로 조정. 슬롯/안내 판 260ms 진입 및 하단 카드 손패 680ms+160ms 진입 효과.
- 웹/원본의 개발자 전용/시각 장치만 이식. 상단 외형은 기존 제단 배경과 공존할 수 있도록 원본 에셋 우선 적용.
- 실제 마물 카드 hover, 텍스트 커닝, CSS filter/drop-shadow, PC와 모바일 렌더 픽셀 동일성은 실기 승인 필요.

## 기존 게임 5원칙
1. Trigger: 기존 `altar` 타일에 진입한 뒤 `의식` 클릭할 때만 시각 패널 표시. `의식 실행` 클릭 시에만 `session.altar_ritual` 호출.
2. Information: 선택된 재물/강화 대상, 강화 단계(최대 3), 방문 영수증, 원본 슬롯/안내판 PNG.
3. Interaction: 재물 선행 선택→다른 강화 대상 선택→확인. 유효하지 않은 선택은 버튼 비활성. 성공 후 중복 의식 차단.
4. Visual: 양쪽 카드가 슬롯 판 안에 들어가며 중앙 안내, 하단 손패, 양피지 닫기/확인 버튼 유지.
5. Persistence: 선택 카드·애니메이션은 휘발. 기존 `roster`, `altar_enhancements`, HP·공격력, `reward_receipts` JSON 및 영구 소멸 정책 일절 변경하지 않음.

## 검증
- `scripts/test_ui_altar_ritual_stage5n.gd`: 실제 Map/PlaceActions, 원본 PNG path/규격, 실제 버튼으로 선택·의식 실행, 재물 소멸, 강화 +1 공격·+2 최대 체력, RNG 불변, 영수증 1회, 파일 저장·재시작, 중복 차단, 임시 세이브 정리.
- 이전 M 오디오 옵션·P4 실제 장소 이동·보상 집 귀환·원정 E2E 자동검증.
- `main` 병합·웹 배포·PC 동기화 안 함. Windows/Android 실기 확인·웹 원화 100% 렌더 승인 안 함.

## 저장·재실행 시 발견·해결한 정수 복원 차이
- 초기 Godot CI: 제단 UI와 제물 희생/공격+1/체력+2/영수증 1회 모두 성공(36개 검사)이지만 전체 snapshot 동일성 1건 실패.
- `MapState.restore()`에서 `roster[].max_hp/attack/speed/current_hp`는 이미 정수로 변환했으나 신규 `roster[].altar_enhancements`는 실수 `1.0`을 그대로 두었다. 디버그 로그로 이 한 필드만 차이가 있음을 확인.
- `altar_enhancements`가 저장에 있으면 `int`로 복원한다. 실제 강화 정책, 영구 소멸, `reward_receipts`, RNG는 그대로. 재시작 후 snapshot 완전 동일·`TYPE_INT` 검사 추가.
