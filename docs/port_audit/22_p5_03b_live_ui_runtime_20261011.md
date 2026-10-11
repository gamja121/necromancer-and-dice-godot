# P5-03B-2 — 변경 이미지 4개 실제 Godot UI 연결 검사 (2026-10-11)

## 작업 목적

P5-03A 자동감사가 원본 웹과 Godot 이미지의 **Git blob 내용이 다르다**고 검출한 4개 파일을 사용자의 허락 없이 되돌리거나 교체하지 않는다. 대신 이미지가 **실제 Godot 게임 화면에 로드되고 올바른 위치에서 보이는 컨트롤에 연결되는지** 엔진 차원에서 재검증한다.

P5-03B 전체는 **Windows PC 실제 화면과 원본 대체 시각 승인**이 끝나기 전까지 TODO로 유지한다.

## 기존 원본과 SHA가 다른 파일

| 변경 이미지 | 실제 확인할 Godot 장면 | PC 승인 |
| --- | --- | --- |
| assets/map/events/fortune-teller.jpg | 지도 점술가의 막사 위치 패널 | 미확인 |
| assets/map/events/home-interior.jpg | 귀환 시 우리집 실내 패널 | 미확인 |
| assets/map/events/knight-commander-upperbody-hd.webp | 기사단장 실제 7비트 대사 초상 | 미확인 |
| assets/map/events/necromancer-upperbody-hd.webp | 기사단장 사건의 주인공 답변 초상 | 미확인 |

각 파일의 실제 SHA 차이와 원본 대응 경로는 [P5-03A 보고서](20_p5_03_feature_asset_reconciliation_20261011.md)를 따른다.

## 자동검사 범위

신규 `scripts/test_p5_changed_visual_runtime.gd`와 `.github/workflows/p5-03b-changed-visual-runtime.yml`이 다음을 실행한다.

1. Godot 4.7.2에서 프로젝트 자원을 재임포트하고 변경 이미지 4개를 Texture2D로 로드·픽셀 디코딩해 크기 확인.
2. 별도 `user://` 임시 원정으로 실제 `map.tscn` 생성. `show_home(true)`의 실내 그림과 `show_location(fortune_idx)`의 점술가 그림이 실제 모달의 TextureRect에 연결돼 있는지, 화면 좌표·크기·비율 유지 상태를 검사.
3. 실제 공동묘지 구출 및 사건 전투 승리 → 결과 확인 → 마을 구출 소문 저장·완결 → 기사단장 사건 진입 **정상 규칙**을 통과한 뒤, 실제 `show_knight_commander_beat()`로 7개 대사 장면을 순서대로 출력. 기사단장·주인공의 초상 TextureRect가 정확한 이벤트 비트에 연결되는지 검사.
4. 최신 P5-03A 감사 스크립트를 재실행해 **사용자 미승인 변경 그림 4개가 여전히 미승인**이며 웹 저장소 삭제가 허용되지 않았음을 확인.

이 검사는 **엔진 로드/이미지 디코딩/런타임 씬 연결 확인**일 뿐이다. 실제 그림 자체의 구도·잘림·배경 누끼·투명도·스타일 일치·사운드·원본 대비 미술 승인이라고 주장하지 않는다.

## GitHub Actions 실행 검증 결과

- PR #95: https://github.com/gamja121/necromancer-and-dice-godot/pull/95
- Godot 4.7.2 실제 UI 검증: https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/38146496235
- **114 PASS / 0 FAIL**, 변경 원화 4개 파일의 픽셀 디코딩, 지도 실내/점술가 모달, 정상 사건 진입에 따른 기사단장 7비트 초상 표시 검사 성공.
- 별도 P5-03A 재감사: 159개 기능·791개 역사 에셋 대조 통과. 변경 이미지 4개의 Git SHA 차이와 실제 Windows 승인 미완료 유지.
- 이 기록은 실물 모니터에서 사람이 본 이미지를 승인한 것이 아니며, 기존 웹 저장소의 보존/삭제 정책을 변경하지 않는다.

## Windows 사용자 PC에서 남아 있는 승인

- 1280×720 Godot 앱 실화면을 열고 각 모달이 실제로 완전히 표시되는지 확인.
- 사건 7비트에서 기사단장과 주인공 초상이 정상 교체되며 가장자리, 투명 영역, 대사와 겹침이 없는지 확인.
- 점술가 및 우리집 실내 배경과 웹 원본을 직접 비교해 **현재 변경본을 유지할지** 혹은 기존 원본을 복원할지 사용자 결정.
- 사용자 PC의 활성 Godot 프로젝트 SHA가 최신 GitHub `main`과 동일한지 확인.
- **P5-03B와 P5-03, P5-04, P3-05는 실기 승인까지 TODO.** HTML 원본, Pages 서비스, 다른 게임 코드, 그림 파일은 변경하거나 삭제하지 않는다.

명령:

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/test_p5_changed_visual_runtime.gd
python3 scripts/audit_p5_03_parity.py
```
