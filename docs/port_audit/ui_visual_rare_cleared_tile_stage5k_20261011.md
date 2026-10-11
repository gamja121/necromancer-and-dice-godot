# 5단계 K — 희귀 마물 처치 후 전용 맵 타일 원본 복원 (2026-10-11)

## 원본 대조 및 발견된 문제
- 원본: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- 원본 `v2-map-practice.js`의 `tileImageForType()` 2872–2875행: 일반 마물 완료는 `monster-cleared.png`, 희귀 마물 완료는 별도의 `rare-monster-cleared.png`를 선택.
- 원본 `art/v2-style/map-test/tiles/rare-monster-cleared.png` Git blob SHA: `219f359b3be64bcbf20b3f51c1e9d45361f4705b`.
- Godot 현재 브랜치에 `assets/map/tiles/rare-monster-cleared.png.import` 메타데이터는 있으나 실제 PNG는 없음. `map.gd:tile_path()`는 희귀 처치 상태를 일반 마물 타일로 강제 변환함. 원본과 달리 희귀 전용 돌 외형이 소실됨.

## 최소 변경
1. 원본 PNG의 byte-for-byte Git blob SHA를 유지하여 `assets/map/tiles/rare-monster-cleared.png`에 복원. 웹 원본 변경 없음.
2. `map.gd`의 희귀 완료→일반 완료 강제 치환 한 줄 제거. 기존 공통 `cleared` 분기에서 `rare-monster-cleared` 파일명 자동 선택.
3. 실전 `MapScene`에서 일반/희귀 2종 완료의 서로 다른 Texture2D 리소스, JSON 저장·재로드, 다음 바퀴의 완료 초기화, 보상·전투/저장 무변경 회귀 검사.

## 게임 시스템 5원칙
- **Trigger:** 기존 전투에서 희귀 마물 타일 `world.cleared` 등록 시. 신규 규칙 없음.
- **Information:** 원래 지도 타일 종류(희귀/일반), 완료 index, 원본 PNG 경로.
- **Interaction:** 지도 버튼·툴팁·전투 선택 등 기존 동작 유지, 텍스처만 다름.
- **Visual:** 희귀 마물 처치 전과 후가 전용 이미지로 구분, 일반 마물 완료는 기존 이미지 유지.
- **Persistence:** `tiles`, `cleared`, 보상·RNG·전투·영구사망 데이터 구조 무변경; 저장 복원 및 새 바퀴 생성 시 다시 처치 전 타일로 표시.

## 검증 경계
- Godot headless 임포트, 실맵 텍스처 및 저장/재실행/새 바퀴 테스트, 실제 일반전투·7종 장소 이동·J 구름 안개·전 원정 E2E 검사.
- PC/GitHub SHA 동기화, Windows·Android GPU 실화면·입력·사운드 최종 승인, 불완전한 웹 구름 PNG 4번 원화 복구 및 `main` 병합/배포는 별도 미완료. P5 삭제 승인 근거로 사용 금지.
