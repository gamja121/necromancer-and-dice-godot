# Windows GitHub 실행기 실증 검사 — 실제 사용자 PC와 구분 (2026-10-12)

## 이 작업으로 실제 확인할 수 있는 것

이 검사는 `runs-on: windows-latest`에서 **Windows용 Godot 4.7.2 실행 파일**을 설치·실행하는 자동검사다. Linux headless 회귀검사와 달리 Windows의 파일 경로/리소스 임포트/Windows Godot 바이너리 차이로 발생하는 오류를 찾는다.

- `project.godot`를 **Windows에서 에디터 임포트**, 파싱 실패/리소스 누락 확인.
- **Windows 네이티브 headless 모드에서 실제 프로젝트** 새 게임→인트로→맵, 타이틀 음악과 설정값, 변경 그림 네 장의 픽셀 디코딩/장면 연결, 47종 마물 카드·전투 모션, 전체 기존 사건 승/패 분기, 최초 자연 맵 집 귀환·재배치, 공동묘지 구출→마을 소문→기사단장→사냥꾼까지 자연 주사위 이동 검증.
- 사용자 게임 세이브 대신 GitHub 실행기 `user://`의 독립 임시 파일을 생성하고 정리한다.
- **선택적 그래픽 캡처**: Windows 호스팅 실행기에 실제 그래픽 디스플레이가 있는 경우에 한해 `godot --path . --script res://scripts/test_windows_gui_evidence.gd`를 비-headless 모드로 실행한다. 타이틀·맵·집 실내·점술가 장면 4장의 렌더러 픽셀 PNG를 만들고 Windows에서 화면 버퍼가 비어 있지 않은지 검사한다. PNG는 GitHub Actions artifact 30일 보관; 캡처 실패는 로그로 남기며 원래의 Windows 네이티브 헤드리스 테스트 통과를 무효화하지 않는다.

GitHub Actions 워크플로: [Windows Native Godot Smoke and GUI Evidence](../../.github/workflows/windows-native-godot-validation.yml)

## 이 작업으로 확인할 수 **없는 것**

- 사용자의 실제 `C:/Dev/necromancer_and_dice` 체크아웃, 로컬 미커밋 파일, PSD/원화 폴더, `raw_assets`/외장백업 상태, PC 쪽 commit SHA 동기화 여부.
- 사용자의 모니터에서 보이는 디테일/색감/잘림/누끼/실제 마우스 입력과 실제 스피커 출력. GitHub Windows 가상 실행기와 사용자의 GPU·드라이버·오디오 디바이스는 다르다.
- 캡처 성공 자체는 네 그림의 원본 대비 미술적 승인, 모든 사건 화면의 Windows 실기 승인, 유저 승인이나 배포/삭제 승인이 아니다. 자동 PNG 캡처는 사용자가 별도로 시각 검수할 수 있는 증거물에 불과하다.
- GitHub Actions 호스팅 Windows 가상 실행기의 GUI가 불가능하면 **그 상태를 명시한다**. 헤드리스 검사만 통과했다면 실기 화면을 확인했다고 말하지 않는다.

**P3-05, P4-01F, P4-02E-B, P4-04B, P5-03B와 모든 상위 P4/P5 종료 게이트는 TODO**다. 백업/웹 원본은 변경하거나 삭제하지 않는다. Windows 검사 결과만으로 안전하게 웹 저장소를 삭제할 수 없다.

## 실행 예

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/test_p4_run_entry_integration.gd
godot --headless --path . --script res://scripts/test_p5_changed_visual_runtime.gd
godot --headless --path . --script res://scripts/test_p4_all_monster_presentation.gd
godot --headless --path . --script res://scripts/test_p4_full_source_story_chain.gd
godot --headless --path . --script res://scripts/test_p4_natural_home_lap.gd
godot --headless --path . --script res://scripts/test_p4_natural_commander_hunter.gd
```

테스트는 GitHub-hosted Windows의 실패/통과 여부를 각각 기록한다. 검증 결과와 실행 ID는 CI 이후 문서에 추가한다.

## 실측 결과 — Windows 네이티브 Godot 검증 (2026-10-12)

- CI 실행: https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/38178248371
- **Windows용 Godot 4.7.2** 설치와 프로젝트 에디터 임포트 **PASS**.
- 7개 Windows Godot headless 원본 런타임 스위트가 **총 1,621 PASS / 0 FAIL**:
  - 타이틀 원본 음악/설정 저장: **22 PASS**
  - 타이틀 새 게임→인트로→맵: **24 PASS**
  - Godot 변경 그림 4개 Texture2D·실제 UI: **114 PASS**
  - 47종 마물·애니메이션 연결: **912 PASS**
  - 사건 전체 원본 진행 및 승패/방치 분기: **321 PASS**
  - 완전한 자연 집 귀환과 타일 셔플: **65 PASS**
  - 공동묘지→구조 마을→기사단장→사냥꾼 무단축 자연 이동: **163 PASS**
- Windows 그래픽 드라이버는 **Windows / OpenGL ES 3.0 ANGLE / Microsoft Basic Render Driver (D3D11)**로 동작. 실제 Windows GPU 하드웨어와 동일한 환경이라고 해석하지 않는다.
- 최초 Windows 그래픽 픽셀 버퍼에서 **1280×720 PNG 네 장** 생성 확인: 타이틀 2,091,198바이트, 맵 1,955,260바이트, 집 실내 1,691,557바이트, 점술가 막사 1,609,670바이트. `InkSceneReveal` 0.65초 연출 때문에 **최초 점술가 캡처는 애니메이션 중간 프레임**이었으며, 이후 검수본은 완결 프레임을 기다리도록 시험 코드를 개선했다.
- 오디오: GitHub-hosted Windows에는 유효한 WASAPI 출력 장치가 없어 `audio_device_init`가 실패하고 Godot가 **dummy audio driver**로 대체되었음. 따라서 **가청 음질·사운드 ON/OFF 실기 승인은 절대 주장하지 않는다**.
- 원화 품질 승인, PC 파일 SHA 동기화, 실제 모니터·오디오, Windows 사용자의 원본 백업은 **미확인**이다. `P4-01H`라는 별도 자동검사만 DONE; P4/P5 상위/실기 항목은 변함없이 TODO.

CI artifact `windows-native-godot-validation`에 Windows 전용 테스트 7개 로그, 임포트 로그, 스크린샷 PNG 4개를 보존한다(30일). 검수용으로만 사용하며 원본 이미지 파일은 수정하지 않았다.

## 최종 Windows GUI 재캡처 결과

- 최종 PR 커밋 Windows CI: https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/38179186050
- Windows 네이티브 전체 7개 테스트를 **1,621 PASS / 0 FAIL**로 재확인. Windows GUI 렌더링 캡처는 **4 captured / 0 failed**.
- 점술가 장면은 `InkSceneReveal` 효과 0.65초가 끝날 때까지 1.1초 대기하고 `TextureRect.material == null`을 검증한 뒤 PNG를 촬영하여, 최초의 애니메이션 중간 프레임 오인을 방지했다.
- PNG 4장(타이틀, 맵, 집 실내, 점술가)은 모두 **실제 Windows/ANGLE 드라이버의 1280×720 렌더 결과**로, 이미지 내 주요 요소가 표시됨을 검토했다. 스냅샷만으로 모든 UI 모달·전투·애니메이션 프레임의 미술적 승인이나 사용자 PC 상호작용을 대신하지 않는다.
- 별도 원본 파일/저장소 삭제·조작 없음. GitHub-hosted 가상 머신은 실제 사용자 PC·오디오 장치·그래픽 드라이버와 다르므로, **PC 동기화·오디오 가청·235개 마물 화면 실기 승인/4개 변경 이미지 예술적 승인 = 미확인** 상태를 유지한다.
