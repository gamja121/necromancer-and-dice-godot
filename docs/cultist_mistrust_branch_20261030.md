# 광신도 조사 선택과 와전된 소문 (2026-10-30)

[Issue #359](https://github.com/gamja121/necromancer-and-dice-godot/issues/359). 사용자의 예언가 경유 분기 다음 작업으로, 다른 선택이 조사 결과와 주민 태도를 다르게 만들도록 구현했다.

## 실제 플레이 연결

아이를 지나침 → 방치 소문 → 기사단장의 예언가 의뢰 → 예언가의 문양 단서 → 광신도 소문과 추적 → 제단에서 **협력하는 척한다** → 사체 수레 이동 중 다음 의식 장소를 엿들음 → 주민이 동행 모습만 목격 → 다음 실제 마을 도착에서 **와전된 소문**.

조사 장면은 제안·수레·목격·이탈·단서의 5장면, 마을 후속은 도착·목격담·와전·반론·두려움·침묵·불신의 7장면이다. 목격 사실과 추측을 대사에서 구분하며, 아이의 운명이나 주인공의 숨은 정체를 새로 확정하지 않는다. 광신도는 수레를 옮길 노동력을 받아들이는 것이며 주인공을 알아보거나 경배하지 않는다.

## 사건 계약

| 항목 | 구현 |
| --- | --- |
| 발생 조건 | 기존 제단의 오염도50·실제 추적 완료 조건 유지. 새 선택은 예언가의 완료된 정보 출처와 광신도 소문 완료를 함께 검증 |
| 플레이어 정보 | 예언가에게 들은 문양을 알아보고 조사 가능성을 판단. 동행이 공범으로 보일 수 있다는 안내를 선택 전에 표시 |
| 행동 | 기존 싸움·지나감 유지. 새 선택 직후에는 선택 변경 가능; 첫 수레 행동을 저장한 뒤에는 되돌릴 수 없음 |
| 시각 변화 | 기존 사건책·금박/청색/붉은색 채색 필사본. 수레·주인공·광신도·목격자의 새1672×941 그림. 마을 후속은 기존 주민/주인공 레이어 사용 |
| 지속 기억 | 각 장면은 순차 bool 영수증. 조사 마지막 확인에서 제단 완료·기존 의식 추적·목격·소문 대기를 함께 저장. 마을 마지막 확인에서만 불신과 소문 완료를 저장 |

조사 의도를 선택한 것만으로 목격/소문을 만들지 않는다. 중간에 닫거나 재시작해도 같은 장면을 복원한다. 저장 실패는 원래 전체 snapshot으로 되돌린다. RNG·전투·마물·보상·예언 주사위는 이 이야기 처리로 소비하거나 추가하지 않는다.

소문은 다음 **실제 마을 도착**에서 시작한다. 현재 타일 미리보기, 원격 타일 클릭, 저장 불러오기만으로 첫 발견을 만들지 않는다. 이미 본 소문은 저장된 장면으로 복원한다. 새 오염도 문턱이나 임의의 불신 수치는 추가하지 않았다.

기존 의식 추적은 그대로 연결되어 이후 숲/사건 타일의 전이문 조사를 계속할 수 있다. 마을의 첫 불신은 관계 기억과 별도 사건이며 상점·집을 봉쇄하는 단계는 아니다. 불신의 추가 누적, 기사단의 추궁, 마녀사냥, 집 방화/HOME 봉쇄는 후속 작업으로 남는다.

## 상태와 호환성

- 제단 선택: `infiltrate`, `event:cultist_altar_encounter_01:choice_infiltrate`
- 조사 장면: `event:cultist_altar_encounter_01:infiltration:beat:N`
- 목격/소문 대기: `story:cultist:cooperation_witnessed`, `story:village_mistrust_01:pending`
- 마을 사건: `village_mistrust_01`, 일반 seen/complete/beat 영수증
- 첫 불신: `story:village:trust_eroded`

원래 v1 snapshot의 string 선택/사건 ID와 bool flags만 사용하므로 마이그레이션이 필요 없다. 새 선택은 전투 결과를 만들지 않는다. 기존 싸움/지나감 완료 판정과 전이문 완료 이후의 과거 제단 기록도 유지한다. 단독 목격 플래그, 잘못된 출처, 건너뛴/범위 밖 장면, 중복 선택 영수증은 진행시키지 않는다.

세 번째 선택이 하단 돌아가기와 겹치지 않도록 공통 책의 **3개 주 행동일 때만** 간격과 본문 높이를 맞췄다. 기존 1개/2개 선택의 좌표는 유지한다. 한국어·영어 실제 화면에서 버튼·본문·도장 글자를 함께 검사한다.

## 원화

`assets/map/events/manuscript_cultist_inquiry_scene.png` — 1672×941 RGB, 내장 ImageGen 생성 PNG를 픽셀 후처리 없이 복사. 기존 제단 배경의 테두리와 채색, 광신도 행렬 의상, 주인공의 뒷모습을 참조했다. 밉맵과 기존 manuscript 선형 필터를 적용한다. 생성 원본은 raw_assets에 별도 보존한다.

SHA256: `85a2454545686a85c0c9ad9f299f7bea11301b2f3abb7093825d544f4ea03e53`.

수레의 마물은 사건 삽화의 표현이며 보유 마물이나 영구 능력치를 새로 부여하는 기능이 아니다. 새 장면은 수레 이동/목격의 두 장면에서 사용하고, 원래 제단 도착·싸움·지나감 그림은 유지한다.

### 실제 생성 프롬프트

```text
Edit the first supplied game's approved illuminated manuscript painting. Keep its complete ornate gold-leaf, ultramarine blue and vermilion red border, floral marginalia, birds, rabbit/griffin motifs and 1672 x 941 landscape canvas unchanged. Repaint only the interior as a medieval night-time forest road beside the ruined altar. EXACTLY match the crisp rich hand-painted tempera/gouache and ink illuminated-manuscript miniature style, detailed full colors and sharpness of this approved game art; no woodcut, sepia monochrome, photorealism, 3D, UI or text.
Tell this concrete event in one readable picture: a small wooden two-wheel cart loaded with bulky MONSTER carcasses completely concealed by a worn cream cloth bearing the same red eye emblem as reference 2 is being pushed UP a slope by two skeletal monster servants. Reference 3 is the SAME protagonist: a secretive hooded necromancer viewed from behind or three-quarter back, ragged charcoal cloak, gold chains and small gold-edged book, hidden face. Place that protagonist beside the cart listening quietly to two hooded cultists (identity/costume from reference 2: patched tan hoods, dark robes, red/gold stoles). The cultists are pragmatic fellow travelers, not worshipping the protagonist, not kneeling. Keep the cart and protagonist clearly readable around middle-right inside the frame, with visible wheels and hands pushing to explain apparent cooperation. A frightened woodcutter carrying a bundle of sticks peeks from the left forest edge, looking back at the necromancer and cart while beginning to flee toward a distant village. The witness is large enough to see when the painting is reduced into a storybook. A torch, blue moonlit forest, stone ruins and distant warm village lights establish the same location as image 1. Balanced interior layout, figures completely within the decorative frame. No child, no visible gore or wounds, no exposed human remains, no new crown, no extra character faces for the protagonist, no labels, no lettering, no numbers. Full opaque 1672x941 landscape production artwork, matching existing main-story quality.
```

## 검증 경로

`test_cultist_mistrust_branch`는 실제 방치→예언가→광신도 정보 사슬, 선택 취소/확정, 잘못된 출처·영수증, 각 저장 실패의 롤백, 중간 JSON 복원, 원래 의식 추적 지속을 검사한다.

`test_cultist_mistrust_capture`는 실제 map.tscn의 버튼으로 양언어 조사/마을 사건을 진행하고 실제 1280×720 프레임버퍼8장, 미리보기/첫 로드 차단, 중간 복원, 본문·3개 선택·도장의 크기, 저장/RNG 불변을 확인한다. 프로필과 저장은 테스트 전용이다.

기존 제단 진입/선택/후속/실전투 분기, 전체 사건책, 언어, 예언가 경로, 부활 의식, 공통 사건 배치도 함께 회귀 검증한다. CI는 Prophet Story Event 작업에서 새 파일 경로와 두 GPU 캡처 흐름을 모두 실행한다.

### 최종 로컬 결과 (Godot 4.7.2 Compatibility)

에디터 임포트 오류0. 새 분기92, 실제 양언어 GPU988, 기존 제단 진입80·선택135·후속195·실전투 분기108, 전체 사건책337, 언어88, 예언가 진입160·GPU431, 부활 의식235, 공통 사건 배치25항목으로 **총2,874항목 통과**. 새8장면과 기존 예언가5장면을 실제 프레임버퍼로 저장하고 확인했다. GPU 확인에는 실제 수레/목격 원화, 3개 선택의 한영 배치, 영문 도장의 줄바꿈까지 포함한다.
