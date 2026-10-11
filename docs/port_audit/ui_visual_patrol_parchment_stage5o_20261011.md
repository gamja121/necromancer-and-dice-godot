# Stage 5O — 순찰경로 버튼 원본 양피지 에셋 연결 (2026-10-11)

## 원본 대조
- 고정 웹 원본: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- `v2-map-practice.css` 1160–1183행: `.patrol-route-reset`와 `.patrol-route-confirm`은 `art/v2-style/map-test/events/enter-parchment.png`를 사용한다. `.patrol-route-close`는 `exit-parchment.png`를 사용한다.
- 원본 `enter-parchment.png` Git blob `03cb347d5c2ccec4779706f59167299971af0c8d`, `exit-parchment.png` blob `fc6524dc1096f731a214fee6fe86620778c7f0b1`. Godot `assets/map/events/` 아래 이미 저장되어 원본 SHA와 일치한다. 재압축·복사 불필요.
- 현재 `systems/exploration_actions.gd`의 집 `순찰경로` 장면은 두 원본 배경 판을 표시하지만, `기본값`, `경로 확정`, `닫기` 버튼은 기본 Godot 버튼이어서 양피지 그래픽이 누락돼 있었다.

## 최소 변경
- 집 순찰경로 장면의 세 버튼에 `StyleBoxTexture` 원본 PNG를 상태별로 적용. `닫기`에는 exit, `기본값`과 `경로 확정`에는 enter. 색상·텍스트 가독성도 갈색/황토 원본 팔레트로 맞춘다.
- 기존 버튼 위치·높이, 음악, 타일 드래그, 타일 교체, 상단 지도·집 UI, 다른 장소 버튼은 변경하지 않는다.
- 기존 inline `기본값` 콜백을 독립된 `reset_route()` 메서드로 분리해 실제 UI와 테스트가 동일한 동작을 호출한다. 영수증·경로 확정 방식과 저장 데이터 구조 변경 없음.
- 기존 `ButtonEffectsModule` hover 동작을 유지한다.

## 5원칙
1. **Trigger:** 집 → 순찰경로 → 기본값/경로 확정/닫기 사용자 입력. 자동 경로 확정 없음.
2. **Information:** UI 임시 `plan`, 저장된 `world.patrol_plan`, 방문 완료 `reward_receipts`, 원본 양피지 PNG 2장.
3. **Interaction:** 6개 현재 타일 + 5개 교체 후보; 기본값은 미저장 프리뷰만 초기화, 경로 확정 시에만 유효성 검사 및 영수증 1개 저장, 닫기는 출입 UI만 닫는다.
4. **Visual:** enter 양피지 2개와 exit 양피지 1개를 위치 그대로 배경 적용, 버튼 활성·비활성 상태 동일한 원본 실루엣.
5. **Persistence:** 이미지·프리뷰는 저장하지 않음. 경로 확정 후 `patrol_plan`과 방문 영수증만 기존 JSON에 저장, 재실행 후 다시 열면 확정한 경로·버튼 잠금 유지.

## 자동검증과 제한
- 새 `scripts/test_ui_patrol_parchment_stage5o.gd`: 실맵+실집 패널·원본 PNG 텍스처 연결·모든 5가지 버튼 상태·스왑/리셋·명시 확정·영수증 1회·RNG 불변·세이브 재시작·다른 숲 장소 UI 오염 방지·임시 저장 파일 정리.
- 기존 UI 순찰/상속·제단·오디오 옵션 및 P4 지도 이동·집/보상·원정 E2E 회귀.
- Windows/Android 실기 픽셀 겹침, 원본 hover 애니메이션 세부 시각 동등성은 미검증. `main` 병합·배포·PC 동기화/원본 변경은 실행하지 않는다.
