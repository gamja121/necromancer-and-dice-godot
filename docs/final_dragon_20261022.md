# 초대형 최종 드래곤: 등장 연출과 애니메이션 (2026-10-22)

추적: [Issue #254](https://github.com/gamja121/necromancer-and-dice-godot/issues/254)

## 확정 범위

사용자 제공 원화의 드래곤이 최종 보스다. 최신 결정은 **등장 연출·애니메이션부터 완성하고 전투 조건은 나중에 결정**이다.
따라서 이번 결과는 명시적으로 재생하는 독립 연출 컴포넌트와 확인 화면이다. 기존 마지막 사건, 실제 보스 타일, 오염도·전투 개시 조건, 보상, 엔딩, 저장 형식에는 연결하지 않는다.
오염도 20/40/60 단계 기획도 그대로다. 80이나 100을 최종 전투 조건으로 가정하지 않는다.

## 결과와 사용

- 런타임 원화: `assets/battle/final_dragon/final_dragon.png` (RGBA 1871×840).
- 프레임: `assets/battle/frames/final-dragon/`, 고정 1024×640 PNG 28개.
- 대기 6장 / 공격 10장 / 피격 4장 / 퇴장 8장.
- 네이티브 메시 변형으로 날개·목·몸통·꼬리의 움직임을 만들고 발의 접지점을 유지한다. 원화에 없는 뒷면이나 별도 자세를 생성하지 않은 제한된 2D 변형이다.
- 책 페이지의 그림 영역에서 약 5.2초 동안 지면 그림자 → 먼지 → 아래부터 잉크처럼 드러남 → 포효 자세·최대 2.5px 진동 → 이름 → 대기 순으로 진행한다.
- 일반 해골 병사 세 명을 같은 지면에 배치해 약 5배의 높이를 보여 준다. 장면용 크기 기준이며 실제 전투 유닛은 생성하지 않는다.
- 0.25–2배속과 일시정지는 같은 시계로 움직인다. 잔잔한 연출은 1초의 드러남과 정지된 대기 그림을 사용하고 진동·먼지를 끈다.
- 공격은 6번째 프레임(0.58초)에 `attack_impact` 신호를 한 번 보낸다. 피해 계산은 포함하지 않는다. 등장 중 포효 자세는 이 신호를 보내지 않는다.
- 퇴장은 최종 알파 0으로 끝나며 처리를 멈춘다. 격파·승리·보상 판정은 하지 않는다.
- 사용하지 않는 프레임을 LRU 캐시에서 해제한다. 프레임 캐시 최대 10개와 표시 중인 별도 참조 1개를 합친 상한은 약 27.5 MiB다. 전체 28장을 동시에 상주시킨 70 MiB가 아니다. 배경·폰트·엔진 메모리는 이 프레임 수치에 포함되지 않는다.

확인 화면:

```powershell
& '<Godot 실행 파일>' --path '<프로젝트 폴더>' --script res://scripts/render_final_dragon_preview.gd
```

아래 조작부에서 등장 다시보기, 공격, 피격, 퇴장, 일시정지, 배속, 잔잔한 연출을 확인한다.
화면은 저장 파일을 쓰지 않는다. 컴포넌트는 트리에 추가하는 것만으로 재생되지 않으며 `play_intro()` 또는 `play_motion()`을 호출해야 한다.

향후 사건에 연결할 때 `systems/final_dragon_presentation.gd`를 생성한 뒤, 승인된 트리거에서 `play_intro()`를 명시적으로 호출하고 `intro_finished`를 기다린다.
최종 전투 조건·패배 후 복귀·보상·다시보기 및 재접속 정책을 먼저 결정한다. 등장 신호로 자동 승리나 피해를 확정하지 않는다.
종료 시 `stop()` 또는 노드 해제로 프레임 참조와 처리를 해제한다.

## 최신 공유 소스와의 구분

최신 main의 별도 작업 `2a4ad34`에는 `dragon` 유닛의 스탯·두 패시브와 `world.laps >= 60` 전투 편성 코드가 있다. 이 작업은 해당 변경을 보존하며 조건을 수정하지 않았다. 그 코드의 존재가 이 대화에서 최종 보스 조건을 확정했다는 뜻은 아니다. 사용자가 재확인한 오염도 20/40/60 단계 및 최종 조건과의 정리는 별도 작업이다.
이후 공유 소스 `33b806d`가 60바퀴 조건을 제거하고 오염도80 코드로 변경했으며, `93a9237`의 리소스 정리도 보존해 통합했다. 숫자80 역시 이 대화에서 확정한 값이 아니다. 이 문서의 조건 관련 기록은 공유 코드 변경 이력이며 사용자 승인 대신 사용할 수 없다.
독립 연출의 `final-dragon` 프레임 경로를 실제 `dragon` 유닛의 전투 그림에 연결하지도 않았다. 최종 사건에 넣을 시점과 일반 전투 배치는 조건 검토 후 연결한다.

CI 통합 기준에는 추가 원격 `0623880`의 마지막 사건 완료·명시적 확인 조건도 보존했다. 이 때문에 기존 스토리 재접속 검사의 ‘미완료 사건에서도 보스가 이미 있다’는 가정 2건이 실패했다. 재접속·묘지·제단·포털 검사 네 fixture의 같은 가정을 ‘미완료 사건에서는 보스가 없다’로 정정하며, 사건 두 칸·숲 미발견 및 재접속 동작 검증은 유지한다. 게임 조건 자체는 수정하지 않는다. 정정 후 로컬 결과는 재접속 88/0, 제단 108/0, 묘지 80/0, 포털 103/0이다.

## 원본과 제작 경로

원본 JPG는 로컬 `D:/Workspace/Games/necromancer-and-dice/raw_assets/final_dragon/original_1000012379.jpg`에 변경 없이 보관했다.
공개 저장소에는 원본 첨부 파일 대신 게임용 PNG와 프레임을 포함한다.

배경 분리에는 **내장 imagegen 편집 모드**를 한 번 사용했다. CLI/API 키는 사용하지 않았다.
생성 결과에는 일부 재해석이 있으므로 원본과 픽셀 단위로 동일한 컷아웃으로 보장하지 않는다. 원본은 별도로 보존했다.
이후 프레임 변형은 `scripts/render_final_dragon_frames.gd`의 Godot 메시로 렌더링한다. 원화 PNG는 변경하지 않으며, 알파 0.03 이하의 미세한 점은 메시의 구도 계산에서 제외한다.

최종 imagegen 프롬프트:

> Use case: background-extraction. Edit target: the supplied original dragon illustration, to become the existing Godot game's colossal final boss sprite. Remove ONLY the plain white background and the separate scribbled/crosshatched ground shadow beneath its feet; replace those with genuine alpha transparency. Preserve the original dragon's exact pose, complete silhouette, broad bat wings, long curled tail, small forelegs, planted hind feet, horned head facing RIGHT, pale eye, olive-black/brown color palette, all ink hatching, scales, and antique hand-drawn fantasy style. Keep the whole dragon inside the frame with transparent padding. Keep its original proportions and composition. Do not redesign, repaint into another style, add anatomy, add fire, add glow, add scenery, add text, add a new shadow, or change its pose. This is a faithful transparent cutout of this one specific drawing, not a new dragon design. Output one clean transparent PNG.

## 검증

로컬 최종 결과: 드래곤 139 통과/0 실패, 현재 마지막 사건 UI 300 통과/0 실패, 편집기 import 오류 없음, 실제 Windows 등장 완료 확인. GTX 1660 Ti / ANGLE에서 별도 실행한 6.5초 표본은 중앙 프레임 시간 33.33ms, p95 40.11ms, 시작 구간을 포함한 최대 150ms였다. 약 30fps 수준의 관측이며 60fps나 모든 기기의 동일 성능을 보장하지 않는다. 전체 게임 전투 성능 측정과는 별개다.

- `scripts/test_final_dragon_presentation.gd`: 프레임 존재·크기·잘림·동작, 실제 페이지 내부의 날개·발끝과 진동 여백, 실제 크기 비교 유닛의 배치, 일시정지·배속·중복 신호, 퇴장 완료, 네 가지 화면 비율, 캐시 반복 재생 및 해제, 개인 저장 바이트 보존.
- `scripts/profile_final_dragon_native.gd`: 실제 Windows Compatibility 렌더러에서 실제 시계로 등장 완료와 프레임 시간을 확인.
- `scripts/test_ui_king_hunt_layers_stage5z.gd`: 현재 맵 조건을 갖춘 두 부활 분기, 마지막 사건 5장면·저장 복원·명시적 확인을 포함해 300개 회귀 항목 통과.
- 추가로 실행한 기존 `scripts/test_monster_king_hunt_entry.gd`는 97 통과/75 실패와 후속 Dictionary 오류가 있었다. 최초 실패는 시험 맵에 forest가 없어 포털 위치를 저장하지 못한 부분이다. 해당 검사와 모든 기존 런타임 GDScript는 기준 커밋 `49196ca`에서 변경되지 않았다. 초기 실패 기록은 보존한다. 이후 원격 `48caf5b`가 실제 숲 발견 절차로 이 fixture를 수정했고, 최신 main을 통합한 재검사에서는 **195 통과/0 실패**로 확인했다. 이 검사 수정은 다른 작업의 변경을 그대로 받은 것이다.
- 편집기 import 및 실제 Windows PNG 캡처로 셰이더와 화면 구도를 확인. 헤드리스 검사만으로 시각 검증을 대신하지 않는다.
- `scripts/render_final_dragon_preview.gd -- --capture=<폴더>`는 정지 화면, `--record`를 더하면 12fps 연속 PNG를 출력한다. 기록·개인 저장·엔진 캐시는 공개 저장소에서 제외한다.
