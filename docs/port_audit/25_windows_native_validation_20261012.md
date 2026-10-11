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
