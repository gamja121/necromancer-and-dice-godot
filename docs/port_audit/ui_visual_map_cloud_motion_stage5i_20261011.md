# 5단계 I — 웹 구름 8개 레인 배치·회전·퇴장 속도 원본 대조 (2026-10-11)

## 기준과 원본 아트 검색 결과
- 고정 웹 기준: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`, `v2-map-practice.css` 705–790행, `v2-map-practice.html` 159–168행.
- 4번 PNG 웹 원본 SHA `d2f8ba62c1e48306e5a2d37d6e18fe0a7f311518`는 `reference/html-final` 및 과거 `rollback/asset-pipeline-before-20260929`, `rollback/map-story-events-before-20260930`, `chatgpt/restore-forest-standard-art-20261009`에서 동일하다. GitHub에서 발견된 정상 대체본은 없다.
- 이전 5H의 Pillow 손상 허용 복원본은 임시 실행 자산이며, 4번은 알파 유효 높이 66/182px 수준이라 **원화 동일 판정 불가**. 웹 기준 또는 복원되지 않은 픽셀을 임의로 생성하지 않는다. PC 원본 `raw_assets` 확인 및 Windows/Android 실기 검수는 보류.

## 코드 변경
- `systems/map_presentation.gd`의 이전 구름 그림 선택(1,2,3,4,2,1,4,3)은 보존.
- CSS `width`, `top/bottom`, `--cloud-y`, `--cloud-rot`, `--cloud-scale`, `--cloud-duration`, `--cloud-delay`를 하나의 8레인 원본 표로 고정. 특히 맨 아래 2레인은 `top: 68%/77%`가 아니라 `bottom: -18%/-9%`로 계산.
- 원본 CSS 왼쪽/오른쪽 시작 위치, 뒤집기, covered +108% / opening +235% 변환, 회전과 배율 위상, 레인별 시작 지연·퇴장 지연을 Godot 1280×720에 대입.
- 현재 임시 비정상 4번 원본 이미지 자체에는 추가 변경 없음. 지도 돌 셔플 콜백·영수증·주사위·저장 데이터 변경 없음.

## 다섯 원칙
1. Trigger: 기존 집 귀환 직후 `cloud_refresh` 호출(신규 호출 없음).
2. Information: CSS 레인/원본 순서/좌표/전환 위상과 종류별 미해결 이미지 손상.
3. Interaction: 전환 시작 시 버튼 비활성화, 가림 후 기존 타일 변경 콜백 1회, 이후 해제.
4. Visual: 레인별 실제 너비/아래쪽 앵커·좌우 시작점·회전/배율/속도/지연 및 퇴장 방향을 원본 근사 대신 수치 대응.
5. Persistence: `change_board` 호출 및 원정 저장 경로 불변. 시각 상태는 일회성 트윈이며 저장 대상 아님.

## 검증
- `scripts/test_ui_map_cloud_layout_stage5i.gd`: 8개 원본 CSS 수치와 각 위치·회전·크기·지연 비교.
- 기존 5H 그림 로딩·8개 노드·입력 잠금·콜백 1회 검증.
- 실제 P4 보상→집→돌셔플·다음 바퀴 및 단일 원정, 5G 카드 초과 회귀.
- **헤드리스 PASS만으로 실제 화면 동일 승인 금지**. 4번 원화 불완전, 완전 1280×720 영상 검수, PC-GitHub 동기화, main 병합 및 Pages 배포는 각각 미완료.
