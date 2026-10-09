# 인트로 도입부 이식 (2026-10-09)

GitHub main의 v2-intro.html/js/css를 읽고 원본 도입부를 Godot 시작 장면으로 연결했다.
- HTML: 960039a94f54e832b664c84f7b7c34866da42889
- JS: d1cfbd2ae71e3542e82e0c780a6de5308902ba6b
- CSS: 715631a7ac5fecaedd0231012ea692a79853cddd
- 원본: https://github.com/gamja121/necromancer-dice-board/blob/main/v2-intro.js

## 동작
쿵쾅쾅. 글자가 820ms 확대/복귀하고 입력 안내가 점멸한다.
화면 클릭·터치·Enter·Space로 원본 대사 12줄을 한 줄씩 넘긴다. 키 반복 입력은 무시한다.
주인공은 왼쪽, 기사단장은 오른쪽에서 말하는 인물만 표시한다. 기사단장 이미지는 원본처럼 좌우 반전한다.
마지막 시스템 임무 안내에는 두 인물을 숨긴다. 다음 입력에서 520ms 암전 후 map.tscn으로 이동한다.
기본 화면과 보드 크기는 1280×720을 유지하며 인트로 캔버스는 창 크기에 맞춰 비율을 보존한다.
오른쪽 위 건너뛰기 또는 Esc로 맵에 바로 진입할 수 있다.
기존 저장이 있는 앱 시작에는 이어하기를 표시한다. 새 원정 후에는 건너뛰기만 표시한다.

## 저장 및 연결
project.godot의 main_scene을 intro.tscn으로 변경했다.
인트로 자체는 원정 생성·저장·진행 상태 변경을 하지 않는다. 이어하기/대사 완료/건너뛰기는 기존 맵의 저장 불러오기 흐름을 사용한다.
맵의 새 원정 확인 후에는 기존 방식대로 새 상태를 저장하고 인트로로 진입한다.
새 원정 저장 실패 시 기존 World/encounter를 복원하여 새 인트로로 넘어가지 않는다.
임무 수락 문구는 원본 도입부의 시스템 표시이며 새로운 퀘스트 상태나 사건 콘텐츠를 만들지 않는다.
기존 NOX 출력·음량/음소거 설정을 유지한다. 원본 v2-intro에는 도입부 전용 소리 재생 코드가 없어 별도 사운드를 추가하지 않았다.

## 구조
Trigger: 클릭·터치·Enter/Space, 건너뛰기/Esc, 새 원정.
Information: 현재 대사, 화자, 종료 여부, 앱 시작의 기존 저장 유무.
Interaction: Intro Control, Button, Tween, RunSession, SceneTree.
Visual: 충격 문구, 안내 점멸, 인물 교체, 대화창, 다음 표시, 암전.
Memory: 대사 번호/종료 상태는 런타임 전용. 인트로 자체 영구 저장 없음.

## 파일·자산
신규: intro.tscn, systems/intro_scene.gd(.uid), data/intro_dialogue.json, docs/intro_port.md.
수정: project.godot, map.gd. 기존 다른 작업 및 마물 리마스터 변경은 보존했다.
원본 JS와 동일하게 hero 3개/frame-v2 8개/commander 15개 텍스트 조각의 plain/reverse/base64-text 처리를 복원해 아래 WebP를 추가했다.
- assets/intro/necromancer.webp: 480×360 RGBA
- assets/intro/knight_commander.webp: 1448×1086 RGBA
- assets/intro/dialogue_frame.webp: 607×268 RGBA
원본 조각과 WebP는 외부 raw_assets/intro에도 보존했다.
크기/위치/대사창 비율은 원본 CSS에 대응했다. 주인공과 프레임의 확대 선명도는 제공된 원본 해상도에 제한된다.

## 확인
Godot 4.7.2 Compatibility editor import 및 실제 OpenGL 실행 확인.
충격 화면·기사단장·주인공·가장 긴 대사·시스템 문구·창 크기 변경 화면을 캡처하여 검토했다.
실제 Button 포인터 입력, Enter/Space, 키 반복 무시, 12줄 완료, 반복 종료 입력 방어, 맵 연결, 새 원정 재진입, 건너뛰기를 확인했다.
터치 이벤트를 Godot Input으로 주입하여 한 줄만 진행되는 것과 Esc 전환도 확인했다. 모바일 실기기 확인은 하지 않았다.
터치 별도 확인에서 맵 진입 직후 종료 시 ObjectDB 2개 경고가 있었다. 기존 맵 비동기 리소스 준비 중의 빠른 종료와 관련될 가능성이 있다. 인트로→맵→새 원정→인트로→맵 전체 흐름의 최종 실행은 exit 0, ERROR/WARNING 없이 완료했다.
개인 저장/오디오 설정을 복원했다. 임시 확인 스크립트는 프로젝트 밖에서 실행 후 삭제했다. 프로젝트에 테스트 코드나 테스트 버튼을 넣지 않았으며 commit/push하지 않았다.
