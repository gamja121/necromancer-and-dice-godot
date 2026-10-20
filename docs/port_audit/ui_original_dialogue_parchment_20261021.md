# 맵 사건 및 인트로 대화창 — 웹 원본 종이 질감 통일 (2026-10-21)

## 목표
- 실제 이전 웹 버전의 `art/v2-style/ui/intro-dialogue-box.webp` 기반 복원 파일을 기존 공용 대화창 일러스트 대신 사용한다.
- 적용 대상: 맵 일반 사건, 공동묘지 사건, 인트로에서는 고유한 원본 `assets/intro/dialogue_frame.webp`(607×268)을 사용한다. 사건의 진행, 선택지와 버튼, 전투, 저장은 변경하지 않는다.
- 파일: `assets/map/ui/intro-dialogue-box.webp` (원본이 말미 330바이트 잘려 0 패딩으로 디코드 복구한 파일: 이전 Stage5P 감사 기록 참고). 원본 파일은 손실 없는 완전 복구가 아님. 별도 `assets/intro/dialogue_frame.webp` 및 기존 `assets/map/ui/shared_dialogue_panel.svg`는 삭제/수정하지 않는다.
- 현재 안전 대화창 배치 `Rect2(205,516,870,132)`와 인트로 하단 `Rect2(102.4,489.6,1075.2,216)`를 유지한다. 원본 그림의 비율은 화면에서 늘어날 수 있으나 버튼과 대사 레인은 동일하다.
- 밝은 양피지 영역 안의 텍스트 색상은 짙은 잉크 `#21150d`로 조정하고 검정 그림자를 끈다. 그림 위 사건 제목은 기존 밝은 색상 유지.

## 5가지 기본 원칙
1. **Trigger:** 기존 대화 사건 또는 인트로 장면 열기.
2. **Information:** 기존 대사, 발화자, 선택 상태와 저장된 진행도.
3. **Interaction:** 실제 버튼의 연결/개수/좌표, 터치 차단 방지, 닫기 및 계속 동작 그대로.
4. **Visual:** 원본 웹 사건 양피지 및 원본 인트로 전용 그림과 짙은 잉크, 동작 화면의 안전 위치 유지.
5. **Memory/Persistence:** 원정 저장값, 오디오 옵션, RNG, 보상 수량 변경 없음.

## 검증
- `test_shared_dialogue_panel.gd`: 원본 이미지 디코드·RIFF·WEBP, 공용 맵/인트로 경로 및 터치 비간섭.
- `test_story_event_layout.gd`: 사건 설명·대사 영역 서로 비간섭, 짙은 잉크 대비, 버튼 위치·보상 불변.
- `test_ui_grave_dialogue_stage5p.gd`: 원본 프레임/대사/선택지, 저장·재개, 방치/구조 단계.
- 새 GitHub Actions 워크플로 `shared-dialogue-ui.yml`로 headless Godot 4.7.2 검증.
- PC·모바일 실제 텍스트 가독성과 종이 에셋 가장자리의 비율/왜곡은 실기 확인이 아직 필요하다.
