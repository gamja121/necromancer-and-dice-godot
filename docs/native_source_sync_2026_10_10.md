# PC Godot 원본 공개 동기화 — 2026-10-10

- PC 원본: C:/Dev/necromancer_and_dice, codex/non_story_ui_20261009, 기반 0ebaae3.
- 보존 스냅샷: 367c0ce. 게임 코드·실행 에셋 533개 파일, 92,103,563 bytes.
- 공개 main의 타이틀·한글 폰트·정책 5b4f476과 별도 사본에서 병합했다.
- 진행 중인 scripts/tools/source_assets, 개인 파일과 Godot 캐시를 제외했다. 활성 PC 폴더의 파일·브랜치·index는 변경하지 않았다.

## 통합 변경

project.godot의 기본 시작 장면은 공개 묘지 타이틀을 유지한다. 새 원정은 RunSession에서 새 세계를 만든 뒤 intro.tscn으로 진입하고 맵으로 이동한다. 이어하기는 저장된 세계를 불러와 맵으로 진입한다.

전장 폰트는 PC의 임베디드 전장 최적화를 보존하며, 독립 전장에서는 포함된 Nanum Gothic 폰트를 fallback으로 사용한다.

## 검증

Godot 4.7.2 Standard, Compatibility/OpenGL에서 확인했다. 검증 스크립트는 프로젝트 밖에 두고 별도의 임시 user 데이터 디렉터리를 지정했으며 실행 후 project.godot 원본 바이트를 복원했다.

- Headless editor import: 종료 0, 오류 0.
- Headless 실행: 타이틀, 새 세계 저장, 인트로 대사, 맵/보유 개체, 저장, 이어하기 복원, 독립 전장 진입 모두 통과, 오류 0.
- 실제 GPU 실행: 동일한 흐름 통과, 오류 0. 타이틀·인트로·맵·전장을 캡처하고 한글 표시를 확인했다.
- 검증 종료 전에 장면과 세션 리소스를 정리해 정상 종료를 확인했다.
- 공개 변경분 diff check 및 redacted 비밀키 검사 통과. 검사 로그와 임시 검증 파일은 공개 저장소에 포함하지 않는다.

이 검증은 기본 진입·저장·화면 통합 확인이다. 모든 장소·사건·퀘스트·전투 규칙이 완성 HTML/JS 기준과 일치한다는 전체 검증은 아니다. 남은 범위는 godot_port_status.md를 따른다.

## 운영

공개 Godot 원본에서 개발을 계속하고 검증된 작업을 commit/push한다. Godot Web 내보내기와 자동 배포는 중단했다. 고정된 HTML 기준은 necromancer-dice-board의 reference/html-final(e13d5149fcecc802e5d626f3bef6e5daecd3d66c)에 보존했다.
