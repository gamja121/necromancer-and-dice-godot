# 사건을 제외한 맵 원본 비교·이식 (2026-10-08)

## 비교 기준
GitHub gamja121/necromancer-dice-board의 main을 직접 읽고 기존 Godot 구현과 비교했다.
- v2-map-practice.js: 6208d397f9317b25c0cbfa5d1f86e24da2a895e2
- v2-map-practice.css: 9771892c804240770db32a08c1590b03d9d6312d
- v2-map-practice.html: 225ad37533422c1c83ca7034e210555331f5d511
- v2-music.js / v2-sfx.js 및 원본 UI·음악 자산.
원본 주소: https://github.com/gamja121/necromancer-dice-board

## 적용 범위
사건 대화·선택 결과·퀘스트 콘텐츠는 작성 중이라는 사용자 지시에 따라 제외했다.
원본의 TEST 버튼, 타일 편집/사진 편집/효과 실험 도구도 게임 UI에 추가하지 않았다.
현재 보드 크기, 타일 간격, 중앙 전장 프레임, 기존 보상·전투 규칙은 유지했다.

| 영역 | 기존 상태와 이번 작업 |
| --- | --- |
| 마을·제단·점술·세계수·묘지·언덕 | 기존 행동/결과/소모 규칙 유지. 먼저 원본 장소 사진과 양피지 행동 버튼을 표시하고 실제 행동 창으로 진입하도록 연결 |
| 우리집 | 기존 회복·낙인 계승·순찰 유지. 원본 버튼 이미지, 부상 상태에서 집 진입 시 회복 연출, 나가기 구름 전환 추가 |
| 숙영 | 전체 회복을 원본 방문당 1회 규칙과 연결. 체력이 가득 차 있거나 이미 사용했다면 비활성화. 회복·방문 기록 함께 저장 |
| 오염도 | 원본 HUD 프레임, 0/20/40/60/80 단계와 안정/확산/침식/재앙/임계, 280ms 게이지 변화, 보드 색조/균열/안개 추가 |
| 늪 | 기존 HP -1, 최소 HP 1 규칙 유지. 원본 -1 이미지 팝업과 영웅 붉은 점멸 추가. 재개 시 피해를 재적용하지 않음 |
| 워프 | 수동 클릭 이동도 저장/실패 복원 적용. 기존 자동 워프 결과를 360ms 소멸/420ms 등장으로 표현. 눈금·카드 기록 유지 |
| 맵 교체 | 우리집 나가기에서 구름이 덮인 1.32초 뒤 새 맵 생성/저장, 0.22초 유지 후 1.12초 걷힘. 실제 한 바퀴 귀환에서만 오염 +4와 바퀴 증가 |
| 세계수·점술 결과 | 기도 오염 변화 숫자/게이지 갱신, 점술 2 회복에 전체 회복 연출 연결 |
| 책·덱 | 원본 열린 이미지와 닫힌 이미지 연결, 책 열기/이동 효과음, 기존 공용 버튼 피드백 유지 |
| 오디오 | 원본 map-board.mp3 (선형 음량 0.3) 반복 재생. 전투 동안 맵 음악 일시정지/복귀 후 재개. 톱니 이미지 버튼과 Music/SFX 독립 스위치 추가 |

## 구조와 저장
- Trigger: 타일 클릭, 이동 도착, 장소 행동 확정, 우리집 나가기, 오디오 설정.
- Information: 현재 장소, HP, 방문 기록, 이동·보상·전투 상태, 오염도, 실제 귀환 여부.
- Interaction: map.gd, RunSession, MapState, 기존 장소 패널, MapPresentation, Tween, AudioServer.
- Visual: 장소 사진/버튼, 회복 십자가/플래시, 피해 팝업, 워프 페이드, 구름, 오염 HUD/보드, 열린 책/덱.
- Memory: 시각 효과는 런타임 전용. 회복/방문 제한/맵 생성 번호만 원정 저장에 포함. 오디오 항목은 기존 설정 파일에 추가.

map_serial은 새 맵마다 증가한다. 방문 키에 맵 생성 번호를 포함하므로 나가기만 해서 새 맵이 생성돼도 지난 맵의 행동 제한이 이어지지 않는다.
구형 저장에는 map_serial=0을 사용해 기존 방문 키를 그대로 보존한다. 새 맵을 만들면 새 방식으로 전환한다.
맵 생성·회복·워프 저장 실패 시 이전 상태와 RNG를 복원한다.
연출 중 버튼을 비활성화하며, 효과 종료 시 기존 비활성화 상태를 복원하고 호출자의 다음 상태 변경 전에 정리한다.
맵 교체로 사라진 버튼은 WeakRef로 확인하여 해제된 노드 캡처 오류를 방지한다.
음악/효과음 버스는 기존 Master 아래에 추가한다. NOX 출력 선택과 Master 음량/음소거는 보존한다.

## 파일
신규: systems/map_presentation.gd, systems/contamination_hud.gd 및 Godot 생성 .uid.
수정: map.gd, systems/map_state.gd, systems/run_session.gd, systems/place_actions.gd, systems/exploration_actions.gd, systems/audio_settings.gd.
오디오 버스 연결만 추가: battlefield.gd, systems/battle_deck.gd.
신규 자산: assets/map/ui/contamination_hud.png, map_cloud_transition.png, parchment_button_variant_01~04.png, map_audio_options.webp, swamp_damage_minus1.png/.svg, assets/map/music/map_board.mp3.
기존 다른 작업과 미커밋 변경은 보존했다. Git commit/push는 수행하지 않았다.

## 원본 자산 제한
GitHub 원본 구름 4개 중 1·2·4번은 PIL/Godot가 PNG 손상을 보고했다. 로컬 원본과 GitHub blob SHA도 같아 단순 다운로드 문제가 아니다.
정상 3번(320×151, d10dcadffda9a4758314b54fc830011c1b9348d3)을 map_cloud_transition.png로 복사하고 좌우 반전/크기/위치/타이밍을 달리하여 8개 구름층을 구성했다.
원본은 외부 참조 폴더에 보존했으며 손상된 신규 런타임 복사본만 제거했다.
4종 구름 모양의 완전한 동일 재현은 정상 원본이 확보되면 교체 가능하다. 현재 확대 선명도도 원본 해상도에 제한된다.
늪 -1 SVG의 텍스트를 Godot SVG importer에 의존하지 않도록 실제 Edge 렌더링에서 RGBA PNG로 변환했다. 원본 SVG도 보존했다.
CSS의 multiply/다중 gradient 오염 배경은 Godot canvas shader로 대응한 표현이며 픽셀 단위 동일 이미지는 아니다.
PC 창에서 실제 렌더링을 확인했고 모바일 실기기 검증은 하지 않았다. 기존 Button 입력/레이아웃/중앙 전장 크기는 유지했다.

## 검증
Godot 4.7.2 Compatibility에서 신규 자산 editor import 확인.
프로젝트 밖의 임시 실행 스크립트로 실제 화면을 캡처하고 회복·중복 방문 제한·저장 실패 롤백·24칸 재생성·구형 저장·수동/자동 워프·늪 HP 1 보호와 재개 중복 피해 방지를 확인했다.
오염 0/40/80 HUD, 숙영 사진/버튼, 회복, 늪 팝업, 구름 덮임과 오디오 패널의 실제 PNG를 검토했다.
입력 복원 시점 및 해제된 버튼 콜백 오류를 수정한 뒤, 실제 숙영 버튼→회복→늪→수동 워프→집 구름 재생성→중앙 전투→맵 복귀를 재실행했다.
최종 실제 실행: exit 0, ERROR/WARNING 없음, 효과 종료 다음 프레임 입력 복원과 독립 음악/효과음 스위치 및 전투 음악 전환 확인.
사용자 원정 저장/오디오 설정은 검증 전 값으로 복원했다. 임시 스크립트는 삭제했고 프로젝트에 테스트 코드나 테스트 버튼을 추가하지 않았다.
git diff --check의 공백 오류도 정리했다.
