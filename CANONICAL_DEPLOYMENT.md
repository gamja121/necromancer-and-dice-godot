# 개발 및 배포 정책 변경 — 2026-10-10

현재 원본 개발 저장소는 공개 gamja121/necromancer-and-dice-godot이다.

기존의 비공개 원본 → Godot Web 빌드 → 공개 배포 저장소 자동 발행은 중단했다. web-preview.yml과 verify-and-deploy.yml은 GitHub에서 disabled_manually 상태이며, 원본 main의 Web 빌드 워크플로도 제거했다. 이 파일의 이전 Git 이력에 있는 자동 Web 배포 지침은 현행 지침이 아니다.

기존 배포 사이트는 마지막 게시 상태로 남을 수 있지만, 앞으로 Godot 변경 사항을 확인하는 최신 개발 기준은 아니다. PC에서 Godot를 실행해 확인하고, 검증한 원본을 공개 main에 commit/push한다.

기존 HTML/JS 완성본은 necromancer-dice-board의 reference/html-final 브랜치에 보존했다. 개발·동기화 규칙은 docs/development_policy.md, 이식 상태는 docs/godot_port_status.md를 따른다.
