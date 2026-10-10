# 개발 및 배포 정책 — 2026-10-10 (웹 미리보기 재개)

현재 단일 원본 개발 저장소는 공개 `gamja121/necromancer-and-dice-godot`의 `main`이다.
게임 기능과 아트는 Godot 원본에서 개발한다.

## 현행 웹 미리보기 배포
사용자가 2026-10-10에 웹 확인을 다시 요청하여, 이전 'Web 자동 배포 중단' 방침 중 해당 부분을 변경했다.

- Godot 원본 저장소의 `.github/workflows/web-preview.yml`은 Godot 4.7.2 Web 빌드와 아티팩트 저장만 수행한다. **Godot 저장소에 새 Pages 사이트를 만들거나 배포하지 않는다.**
- 이미 Pages가 작동 중인 공개 `gamja121/necromancer-dice-board`의 `.github/workflows/publish-godot-pages.yml`이 `gamja121/necromancer-and-dice-godot@main`을 직접 checkout해서 검사, Web export, 모바일 가로방향 스크립트 적용 후 **기존 Pages**로 배포한다.
- 갱신은 기존 배포 저장소에서 수동 `workflow_dispatch` 또는 매시간 17분(UTC)의 일정으로 실행한다. GitHub의 예약 실행에는 지연이 있을 수 있다. 즉, Godot `main` 변경 직후 즉시 배포되는 구조는 아니다.
- 확인 주소: https://gamja121.github.io/necromancer-dice-board/
- 배포본의 `SOURCE_SHA.txt`와 `DEPLOYED_SOURCE_SHA.txt`에는 빌드에 사용한 Godot 원본 커밋을 기록한다. 사이트가 새 원본으로 실제 갱신되었는지는 워크플로 성공 및 SHA 비교로 따로 검증한다.
- 별도의 크로스 저장소 쓰기 인증키나 Godot 저장소의 Pages 생성 권한은 사용하지 않는다.
- 배포 저장소 루트의 과거 빌드 파일은 새 배포 워크플로의 입력이 아니며, 원본 Godot 코드나 아트 파일을 덮어쓰지 않는다.

## 보존 및 개발 흐름
기존 HTML/JS 완성본은 `necromancer-dice-board`의 `reference/html-final` 브랜치(커밋 `e13d5149fcecc802e5d626f3bef6e5daecd3d66c`)에 참고용으로 보존한다. HTML/JS 버전을 새로 개발하지 않는다.

PC에서 Godot를 실행하고 검증한 원본만 공개 Godot `main`에 commit/push한다. 세부 동기화 및 공개 제외 규칙은 `docs/development_policy.md`, 이식 상태는 `docs/godot_port_status.md`를 따른다.
