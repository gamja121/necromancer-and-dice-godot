# P5-03B-1 — 네 개 변경 이미지의 원본/현재본 비교 자료 (2026-10-11)

## 목적과 보장 범위

고정 HTML/JS 원본 `gamja121/necromancer-dice-board@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`의 네 이미지와 현재 Godot `main` 추적 이미지를 직접 디코딩한 **검수용 시트**를 생성한다. 기존 GitHub 파일이나 웹 원본을 수정·삭제하지 않는다.

`scripts/build_p5_03b_visual_review.py`와 `.github/workflows/p5-03b-four-image-review.yml`이 수행하는 작업:

1. 원본 웹 저장소에서 **고정 커밋의 4개 이미지 바이트만** 읽기 전용 다운로드.
2. 각 원본의 실제 Git blob SHA를 역사적 `asset_parity_audit.tsv`와 검증. 현행 Godot 이미지 SHA는 `audit_p5_03_parity.py`에 기록된 네 개의 검수 대기 SHA와 일치하는지 확인.
3. Pillow로 두 파일을 전부 디코딩하고 크기·이미지 모드·투명/반투명 픽셀 수·파일 SHA256 측정.
4. 원본과 Godot 변경본을 동일한 미리보기 크기의 체크무늬 배경 위에 **비율 유지**하여 나란히 렌더링. 원본·Godot 이미지 그 자체는 절대 변경하지 않음.
5. 개별 PNG 비교표 4장, 전체 요약 PNG 1장, 원본 경로와 blob SHA가 기재된 `review-manifest.json`을 GitHub Actions artifact로 **30일 보관**.
6. 병합 후에도 **P5-03B 시각 승인 및 PC 화면·오디오 검사는 별도 TODO**. CI는 명시적으로 `visual_approval=PENDING`, `runtime_scene_acceptance=NOT_CHECKED` 기록.

## 검수 대상

| 번호 | 자료 | 웹 원본 SHA 앞 12자리 | 현재 Godot SHA 앞 12자리 | 실기 승인 |
| --- | --- | --- | --- | --- |
| 1 | 점술가 야영 이미지 `fortune-teller.jpg` | `8faf87019c1b` | `effcf0425a5a` | TODO |
| 2 | 집 내부 배경 `home-interior.jpg` | `ed966e554b6b` | `2623363f6851` | TODO |
| 3 | 기사단장 초상 `knight-commander-upperbody-hd.webp` | `e54f787b10fb` | `7710370f7462` | TODO |
| 4 | 네크로맨서 초상 `necromancer-upperbody-hd.webp` | `5879d8ad9661` | `c707c93a5ca` | TODO |

관련: [159개 기능·791개 에셋 최신 코드 감사](20_p5_03_feature_asset_reconciliation_20261011.md).

## 다운로드·검수

GitHub 저장소의 **Actions → P5-03B Four Changed Image Review Kit → 성공한 `main` 실행 → Artifacts**에서 `p5-03b-four-original-vs-godot-preview`를 받으면 된다. 생성물은 임시 리뷰본이며 30일 후 사라질 수 있다. 향후 확정된 사용자 승인 증거는 별도로 보존해야 한다.

네 개의 비교 PNG 및 `all-four-image-comparisons.png`를 보고 화풍·구도·해상도·인물 특징·배경의 이음새 등을 비교한다. **반드시 실제 Windows Godot 게임 화면에서 UI 확대/축소, 투명 배경, 시점, 잘림/잔상, 스토리 장면의 초상 위치, 사용자의 채택/교체 판단을 추가**한다. 헤드리스 출력·정지 비교 자료만으로 수락한 것으로 처리하지 않는다.

## P5-03과 삭제 게이트

- **P5-03A DONE:** 기능 159개와 원본 자산 791개 Git 추적 경로·blob SHA 자동 확인.
- **P5-03B-1:** 본 비교 시트 생성 및 검증 CI 통과 시 도구·리뷰 준비만 DONE.
- **P5-03B TODO:** 사용자의 **네 이미지 실제 화면 검수와 승인**, P3-05·P4-02E-B 등 실기 승인.
- **P5-03 전체 TODO:** P5-02 PC 전용 원화 외장 백업 미완료 및 실기 결과 불명.
- **P5-04 TODO:** 현행 Godot Web Pages가 여전히 레거시 웹 저장소에서 배포되므로 삭제·변경 금지.

실행 검증 명령은 `python3 scripts/build_p5_03b_visual_review.py --self-test`. 실제 비교는 워크플로가 고정 웹 이미지 다운로드 후 수행한다. 이 자료가 있더라도 웹 저장소는 최종 명시 승인 전까지 유지한다.
