# 원본 대화창 UI 복원 (2026-10-21)

## 기준과 적용
- 사건 대화창: 별도 제작된 `assets/map/ui/shared_dialogue_panel.svg` 대신 기존 웹의 복구본 `assets/map/ui/intro-dialogue-box.webp`를 직접 사용한다.
- 인트로 대화창: 공통 SVG 대신 인트로 전용 원본 `assets/intro/dialogue_frame.webp`를 직접 사용한다.
- 기존 대화와 선택 기능을 유지하고, 맵 사건 대화창의 안전 좌표 `Rect2(205,516,870,132)`도 유지한다. 고정된 하단 버튼이 프레임과 충돌하지 않도록 화면 크기를 임의로 확대하지 않았다.
- 기존 SVG/원본 파일을 삭제하지 않는다. 원화나 다른 캐릭터 일러스트 수정 없음.

## 중요한 원본 한계
- `intro-dialogue-box.webp`는 웹 원본의 끝 330바이트 손상으로 발생한 디코딩 문제를 0 패딩으로 복구한 12,330바이트 WebP다. 기존 웹 원본과 픽셀 단위 완전 복구가 가능한 파일이라는 뜻은 아니다. 자세한 복구 근거는 `ui_visual_graveyard_dialogue_stage5p_20261011.md` 참조.
- 원본 그림 사용은 코드/에셋 수준에서 확인하되, 기종별 실제 픽셀 비교 및 터치 확인은 별도로 한다.

## 변경 5원칙
1. Trigger: 기존 인트로 장면 및 사건 대화 진입.
2. Information: 기존 화자, 대사, 사건 효과 및 고정 이벤트 진행 상태.
3. Interaction: 기존 계속/나가기/선택 버튼, 터치와 키보드 콜백 유지. 배경 그림은 클릭을 가로채지 않음.
4. Visual: 각각의 원본 WebP 양피지로 변경. 안전한 하단 두 줄과 버튼 영역 유지.
5. Persistence: 새 저장 값 없음. 사건 선택/보상/진행에 영향 없음.

## 검증
- `scripts/test_shared_dialogue_panel.gd`: 사건 10개 진입점의 공통 프레임, 원본 WebP RIFF 헤더 및 인트로 전용 원본 이미지, 장식과 입력 분리/사건 저장 무변경.
- `scripts/test_ui_grave_dialogue_stage5p.gd`: 아이 대사/선택 장면의 원본 소스와 상태 저장·재로드 회귀.
- `scripts/test_story_event_layout.gd`: 안전한 문구/버튼 레이아웃과 사건 인물 그림 영역 검사.
- `.github/workflows/shared-dialogue-ui.yml` 자동검사; 모바일 실기 확인은 별도.
