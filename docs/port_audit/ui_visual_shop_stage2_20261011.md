# UI 2단계 — 웹 원본 마물 상점 디자인 이식
대상: `v2-map-practice.html`, `v2-map-practice.css` 원본 `reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- 원본 상판 `monster-shop-counter.png` 2,223,147 bytes. Git blob SHA `a5a8a79b08d1b22a865b501842c49af9d87e406a`.
- CI가 원본 이미지를 SHA 검사 후 **오직 feature 브랜치**에 저장하고, Godot가 해당 로컬 리소스를 사용한다. 다른 저장소를 런타임에서 다운로드하지 않는다.
- 마물 상점 한정으로 원본 중앙 82% 프레임·왼쪽 거래 카드·오른쪽 3/4/5개 수평 스크롤 카드·원본 양피지 취소/닫기 버튼·상태 바를 복원.
- `RunSession.shop_offers`, `RunSession.shop_trade`, 제단·점술가 기능, 저장 구조 변경 없음.
- Trigger: 마을 선택. Information: 보유 마물, 제안 카드, 선택, 불가 사유. Interaction: 기존 상점 API. Visual: 상판·슬롯·가로 카드 배열. Persistence: 기존 1회 거래 및 저장 유지.
- `scripts/test_shop_ui_parity.gd`에서 3/4/5개, 리소스, 기존 장소 격리 확인; P4 맵과 단일 원정 검사 병행.
- Windows 실제 1280×720 시각 승인과 모바일 가로 화면 검사는 아직 별도 과제. 자동검사만으로 픽셀 동일성을 주장하지 않음.
