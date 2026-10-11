# UI 시각 이식 3단계 — 순찰경로 및 집 낙인 계승

고정 웹 `necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.

## 순찰경로 (`systems/exploration_actions.gd`)
- 원본은 90%×82% 패널에서 왼쪽 2.95fr 교체 보드와 오른쪽 1.05fr 세로 현재 경로 보드.
- 웹 원본 두 판 이미지의 SHA 확인 후 `assets/map/ui/patrol-route-frame.webp`(943587c4bbf8ea3bd225eef9b119634ca2c62ce4), `patrol-route-current-frame.webp`(0bb95423378664765135b9a274db868165006b73)로 저장.
- 기존 Godot의 가로 6칸·5칸 배치를 왼쪽 예비 타일 5칸과 오른쪽 현재 경로 세로 6칸으로 교체. 원래 자리에서 기본값/닫기/경로 확정.
- `RoutePlan.valid`와 `RunSession.confirm_patrol` 및 저장 영수증 동작 변경 없음.

## 낙인 계승 (`systems/home_inheritance.gd`)
- 기존 원본 동일한 `inheritance-board.png`, `inheritance_info.webp` 사용 유지.
- 재료·낙인 정보·결과 3열 배치. 단일 탭 대신 **마물 전체 손패와 낙인 카드 팬을 동시에 표시**.
- 카드 클릭, 수혜 유닛 선택, 재료 마물/카드 소비, 낙인 3칸 제한, 상태 저장은 기존 `RunSession.inherit_at_home` 사용.
- 각 계승 카드의 hover/선택 가시성 및 손패 입장 연출 포함.

## 시험 및 남은 시각 승인
- Trigger: 집에서 순찰경로 / 낙인 계승 선택.
- Information: 현재 경로 6 / 교체 5, 재료·받는 마물·낙인·소모 안내.
- Interaction: 원본과 동일한 타일 교체 및 동시 카드 선택.
- Visual: 원본 이미지·배치/카드 팬·상태 안내.
- Persistence: 경로 확정 이후만 기록, 계승 1회 소모, 기존 저장 복원.
- 자동검사: `scripts/test_ui_route_inheritance_parity.gd`, 기존 상점 UI / P4 집·다음 바퀴 / 단일 원정.
- 실제 1280×720 PC GUI와 모바일 가로형 원본 대비 최종 시각 승인은 별도; 기능 테스트로 픽셀 동일이라고 표기 금지.
- 상점 2단계 브랜치의 코드·이미지를 보존하며 현재 `main`과 재통합 전까지 배포 불가.
