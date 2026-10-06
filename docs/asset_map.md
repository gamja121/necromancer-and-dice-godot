# 에셋 연결

원본: C:/Users/gamja/Documents/Codex/2026-05-28/new-chat/necromancer-dice-board

마물 46종 JSON의 slug와 `art/v2-style/ui/unit-card-{slug}.png`를 대응시킨다.
Godot 실행 경로: `res://assets/cards/unit-card-{slug}.png`.
없는 파일은 반영 스크립트에서 오류로 처리한다. 원본 카드 파일은 변경하지 않는다.

현재 카드 원화만 연결한다. 움직임 시트, 전장 배경, 음악·효과음은 다음 연출 단계에서 연결한다.
Windows 시스템의 맑은 고딕을 SystemFont로 요청한다. OS 글꼴 파일을 프로젝트에 복사하지 않는다.
모바일 및 배포용 공통 글꼴은 적절한 배포 라이선스의 한글 폰트로 후속 교체한다.
