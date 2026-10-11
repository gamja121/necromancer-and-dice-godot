# 5단계 J — 웹 맵 구름 전환의 원본 3단계 안개 레이어 복원 (2026-10-11)

## 원본 대조
- 웹 고정본: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- 웹 파일: `v2-map-practice.css` 662–705, 747–795행 및 `v2-map-practice.js` 4555–4581행.
- 기존 Godot Stage 5I는 8개 구름의 위치·속도는 원본화했지만, 단색 직사각형 1개를 천천히 밝히는 방식으로 CSS의 반투명 바탕 + `::before` 방사형 앞쪽 구름 + `::after` 중앙 흰 안개 + `.map-cloud-mist` 2개 반사광/세로 그라데이션을 구현하지 못했다.

## 변경 사항
- `systems/cloud_transition_fog.gd`: 안개 3종을 서로 다른 셰이더 uniform `bank_kind=0/1/2`로 렌더링. 앞·중앙은 CSS inset -12%, 짙은 중심 안개는 -8% 유지. 불투명도 애니메이션 파라미터는 `coverage`이며 클릭 이벤트를 수신하지 않음.
- `systems/map_presentation.gd`: 화면 전체 옅은 바탕 `CloudBackdropWash`에 0.18 알파, 첫 안개는 0.82/360ms, 중앙 베일은 0.95/260ms+360ms 지연, 중심 안개는 0.98/300ms+430ms 지연. 각 레이어 시작·완료 스케일을 CSS 값으로 조정; 오프닝 안개가 서서히 걷히고 구름 8개는 기존 Stage 5I 궤적으로 계속 이탈함.
- **CSS blur/drop-shadow와 방사형 색 혼합은 엔진 셰이더의 매끄러운 타원형 그라데이션으로 근사**. 픽셀 단위 동일성 승인 또는 실기 스크린샷 비교 완료를 주장하지 않는다.
- `cloud_refresh(change_board)`의 1320ms 가림, 220ms 대기, 1120ms 열림, 타일 변경 콜백·입력 잠금·저장 상태는 변경하지 않음.
- Stage 5H에서 훼손된 웹 4번 구름 원본은 그대로 미해결. 임의 원화 생성이나 에셋 삭제 없음.

## 5가지 기본 원칙
1. **Trigger:** 집 이후 타일 재생성 시 기존 `cloud_refresh` 호출. 신규 트리거 없음.
2. **Information:** 출발 지도·새 지도 전환 타이밍, 3개 안개 CSS 광원/가림 정도, 8레인 구름 매핑, 임시 비정상 4번 파일.
3. **Interaction:** 기존 주사위 버튼 및 기타 지도 버튼 모두 1회 전환 완료 전 입력 금지. 효과 레이어 자체는 클릭 무시.
4. **Visual:** 단색 한 겹에서 원본 배경 워시·이중 안개·중앙 안개의 별도 밝기와 진입·퇴장 단계로 복원.
5. **Persistence:** 셰이더 수치는 휘발성 렌더 속성, 원정 JSON·드롭·주사위·RNG·보상/영수증은 불변. 타일 변경 콜백 정확히 1회.

## 검증 및 승인 제한
- `scripts/test_ui_map_cloud_fog_stage5j.gd`: 레이어 3개+워시, 셰이더·마우스 투과, CSS inset, 가림별 opacity, 1320ms 타일 교체 1회, 220ms 입력 잠금, 오프닝 복구, 효과 레이어 해제.
- Stage 5I 원본 8레인 위치/모션 및 Stage 5H 원본 네 PNG 로딩·입력 검증 회귀.
- 실제 보상→집→타일 재배치·다음 바퀴, 전체 원정, 기존 5G 보관함 초과 선택 회귀.
- 4번 구름 복구 불완전, Windows PC 및 Android 실제 영상·가청·조작 확인 없음, `main` 병합·웹 배포·PC 동기화 없음. 시각적 100% 이식/게임 전체 완료/P5 삭제 승인 불가.
