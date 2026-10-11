# 5단계 K — 희귀 마물 처치 후 전용 맵 타일 원본 복원 (2026-10-11)

## 원본 대조 및 발견된 문제
- 원본: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- 원본 `v2-map-practice.js`의 `tileImageForType()` 2872–2875행: 일반 마물 완료는 `monster-cleared.png`, 희귀 마물 완료는 별도의 `rare-monster-cleared.png`를 선택.
- 원본 `art/v2-style/map-test/tiles/rare-monster-cleared.png` Git blob SHA: `219f359b3be64bcbf20b3f51c1e9d45361f4705b`.
- Godot 현재 브랜치에 `assets/map/tiles/rare-monster-cleared.png.import` 메타데이터는 있으나 실제 PNG는 없음. `map.gd:tile_path()`는 희귀 처치 상태를 일반 마물 타일로 강제 변환함. 원본과 달리 희귀 전용 돌 외형이 소실됨.

## 최소 변경
1. 원본 PNG의 Git blob SHA를 감사 근거로 보존. PNG 내부 손상된 청크 정보(PLTE 실제 길이 117 vs 기록 96, tRNS 실제 길이 32 vs 기록 48, PLTE·IDAT CRC 불일치)를 확인했다. 먼저 청크 정보만 보정했으나 원본 압축 IDAT도 손상된 것으로 판명돼 Godot 런타임 이미지 로딩이 실패했다. 독립 이미지 디코더 Pillow에서 손상 허용 모드로 픽셀을 추출하여 `assets/map/tiles/rare-monster-cleared.png`를 유효한 RGBA PNG로 재인코딩했다. 복원 Git blob SHA: `f0932e6246c650613c00284262e33904f6bd57c2` (Pillow 손상 허용 픽셀 디코딩 뒤 RGBA PNG 재인코딩). 원본 SHA `219f359b3be64bcbf20b3f51c1e9d45361f4705b`는 변하지 않으며 웹 저장소 변경 없음.
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

## 복구 진단
- 최초 CI에서 기본 PNG 파일 import 경로만 검사하는 것은 실제 실맵 텍스처 디코딩/표시를 입증하지 못하므로, 런타임 `Texture2D.get_width()`와 Map 버튼의 실텍스처까지 확인한다.
- 손상된 IDAT CRC를 보정해도 압축 데이터 자체 손상이 남아 있는지 여부는 런타임 테스트 결과로 최종 판단한다. 이미지 내용의 임의 리터칭 또는 웹 원본 덮어쓰기는 금지.

## 원본 압축 픽셀 손상·복구 제약
- Pillow 정상 디코딩: `OSError('broken data stream when reading image file')`.
- 손상 허용 복구: 크기 128×99, 알파 유효 영역 `(0,1,128,99)`, alpha 0–253, RGBA 고유색 32종, 픽셀 SHA256 `8f25a452d645992c46a3cd1217e4253264fd97691dfe96e9c0396357870c00d4`.
- 복구 파일 Git blob `f0932e6246c650613c00284262e33904f6bd57c2`; 손상된 웹 원본 blob `219f359b3be64bcbf20b3f51c1e9d45361f4705b`는 변경하지 않음.
- **주의:** 손상 허용 디코딩은 원본의 정확한 모든 픽셀 복원을 보장하지 않는다. 카드/타일 실루엣의 시각적 원본 승인 및 정상 PC 원화 수색이 필요하다. 헤드리스 텍스처 로딩 정상은 원본 100% 복원 판정이 아니다.
- 조사 전용 임시 워크플로 파일은 진단 로그가 GitHub Actions에 남으므로 최종 기능 브랜치에서 제거.

## 추가 CI 장애물: 이전 import 실패 sidecar
- `assets/map/tiles/rare-monster-cleared.png.import`는 실제 PNG가 없는 이전 버전부터 추적되고 있던 파일이며 `[remap] valid=false`, `dest_files`/ctex 출력 경로가 없는 실패 메타데이터다.
- 정상 RGBA PNG를 이 위치에 복원해도 Godot editor는 이 부정확한 기록을 그대로 참조하여 런타임 `load()`가 `Failed loading resource`가 됐다. 기존 sidecar는 **원본 아트가 아닌 생성된 임포트 실패 기록**이므로 제거하고 Godot 4.7.2가 새 런타임 캐시를 만들도록 한다.
- 검증: `godot --headless --editor --quit` 뒤 실맵 `load(res://...rare-monster-cleared.png)`, `TextureButton.texture_normal` 및 저장 복원. 이 조치로 그래픽 100% 동일 승인 여부가 바뀌지는 않는다.
