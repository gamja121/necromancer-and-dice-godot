# 공개 Godot 개발 운영 — 2026-10-10

## 단일 개발 흐름

PC 활성 폴더: C:/Dev/necromancer_and_dice
공개 원본: https://github.com/gamja121/necromancer-and-dice-godot
Godot 4.7.2 Standard / GDScript / Compatibility / Windows Native

PC에서 기능을 구현하고 검증한 다음 Git commit/push로 공개 main에 반영한다. 공개 저장소에서 연결된 GPT/Codex가 원본을 확인·수정할 수 있으며, GPT가 반영한 변경은 PC에 가져와 다음 작업에 통합한다. 공개 여부와 쓰기 권한은 별개이므로 수정은 인증된 GitHub 연결을 사용한다.

## 작업 단위별 동기화

1. 작업 시작에 Git 상태와 원격 main을 확인한다. 로컬의 다른 작업과 원격의 새로운 변경을 함께 보존한다.
2. 기능 수정은 Godot 원본에서 한다. .gd, .tscn, .tres, project.godot과 실행용 assets, 필요한 .uid를 함께 관리한다.
3. 안정된 작업 단위마다 필요한 import/runtime 및 기능·시각 확인을 수행한다. 실패하거나 제작 중인 후보를 완료본으로 게시하지 않는다.
4. 게시할 경로와 diff를 확인하고 비밀키 검사를 통과한 변경만 commit한다.
5. 원격 변경을 병합하여 검증한 결과를 공개 main에 push한다. 사용자님은 이 개발 범위의 commit/push를 승인했다.
6. GPT/Codex의 다음 작업은 최신 공개 원본에서 시작한다. 같은 PC를 여러 대화에서 수정할 때는 작업 경계를 확인하고 동시에 Git 브랜치를 변경하거나 미완성 파일을 일괄 commit하지 않는다.

저장할 때마다 자동 push하는 감시 프로그램은 사용하지 않는다. 검증한 작업 단위마다 동기화해 공개본에 미완성 상태가 올라가는 것을 방지한다.

## 기존 웹 게임과 Web 빌드

완성 HTML/JS 기준:
https://github.com/gamja121/necromancer-dice-board/tree/reference/html-final

고정 커밋: e13d5149fcecc802e5d626f3bef6e5daecd3d66c

기존 HTML/JS 게임에는 새 기능을 추가하지 않는다. 기능, 규칙, 자산, 연출, 저장·복원 동작을 확인하기 위한 읽기 전용 참조로 사용한다. 기존 웹 기능은 Godot로 이식한다.

Godot Web 내보내기와 새 Web 배포는 중단했다. 기존 export_presets.cfg와 web 파일은 이전 구현 자료로 보존하며 사용자님이 다시 요청하기 전에는 내보내기나 배포를 재개하지 않는다. 기존 Pages 주소의 마지막 게시물은 최신 PC Godot 상태와 다를 수 있다.

## 공개 제외 대상

.env, 비밀키, 개인 로그인 정보와 대화 기록, 개인 저장·오디오 설정, .godot 캐시, 빌드 결과물, source_assets 및 미승인 후보 원본은 게시하지 않는다. 원본 아트는 별도 raw_assets에서 관리한다. GitHub는 실행 원본과 승인된 게임용 에셋 중심으로 유지한다.
