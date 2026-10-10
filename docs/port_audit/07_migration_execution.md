# 2단계 실행 기록 — 미이식 기능 구현

작성일: 2026-10-10

## 진행 원칙

한 번에 큰 덩어리를 수정하지 않고, 각 소단계를 끝낸 뒤 확인하고 다음 단계로 이동한다.

## P1 사건 시스템 세분화

### 2-1 사건 에셋 이관
- **2-1A 초기 사건/소문 에셋** — 완료
- **2-1B 기사단장·마물사냥꾼·광신도 에셋 — 완료**
- **2-1C 부활 의식/전이문 에셋 + 남은 인물 레이어 — 완료**
- **2-1D 21개 사건 에셋 SHA/경로 최종 검증 — 완료 (21/21 일치)**

### 2-2 사건 상태기계
- event / quest / story 상태 저장 구조
- seen / complete / active / choice / battle_result
- 부활 상태와 추적 상태

### 2-3 공동묘지 아이 사건
- 사건 진입
- 구한다 / 지나친다
- 사건 전투 진입

### 2-4 사건 전투 공용 연결
- 반드시 전투 전 덱 선택
- 사건 context 전달
- 승패 후 사건 복귀
- 중단/이어하기

### 2-5 소문·기사단장·마물사냥꾼
- 구조/방치 소문
- 기사단장 조사
- 마물사냥꾼 조우

### 2-6 광신도·부활 의식
- 광신도 소문/제단
- 싸운다/지나간다
- 부활 의식/전이문
- 불완전/완전 부활

### 2-7 마물의 왕 추적
- 두 부활 결과에서 모두 추적 활성
- 사건 체인 종료/상태 검증

## 2-1A 완료 내용

웹 고정본 `reference/html-final@e13d5149...`에서 아래 7개를 Godot로 동일 blob SHA로 이관했다.

- `graveyard-child-base-v3.webp`
- `graveyard-child-ghoul-event-v3.webp`
- `rumor-village-base.webp`
- `rumor-villagers-whisper.webp`
- `rumor-villagers-turn.webp`
- `rumor-necromancer.webp`
- `graveyard-choice-parchment.webp`

Godot 경로:
- 사건 원화: `assets/map/events/`
- 선택 UI: `assets/map/ui/graveyard_choice_parchment.webp`

커밋: `0c21eb17d448709f7a9e33304eca1fa862eb749e`

P1-01 전체 21개 중 **7개 이관 완료, 14개 남음**.


## 2-1B 완료 내용

기사단장·마물사냥꾼·광신도 구간의 웹 런타임 필수 에셋 8개를 Godot로 이관하고 존재를 다시 확인했다.

- `knight-commander-village-day.webp`
- `monster-hunter-worldtree-base.webp`
- `monster-hunter-corrupted-beast-scene.webp`
- `monster-hunter-pen-clean.webp`
- `cultist-rumor-procession.webp`
- `cultist-altar-night-base.webp`
- `cultist-altar-ritual-layer.webp`
- `cultist-altar-summon-layer.webp`

Godot 경로: `assets/map/events/`

각 파일은 웹 고정본과 동일 blob SHA로 이관했다.

관련 커밋:
- `5a5da69da6ee2b2aa3c8952cd8fbf191d0985bbc`
- `9b7e7bafb714b1e4b935974121d24865ff9f2523`
- `15d3e4f47451973d99364cc610058d76aba7d3bb`
- `038a245608af76f582f12fc99073f70dd5ac89e6`

P1-01 전체 21개 중 **15개 이관 완료, 6개 남음**.

다음: **2-1C — 부활 의식/전이문 에셋 4개 + 기사단장/주인공 상반신 폴백 2개 이관**.


## 더 작은 단위 진행 기록

2-1 사건 에셋 이관을 파일 단위로 더 분할한다.

### 2-1B 기사단장·마물사냥꾼·광신도
- 2-1B-1 기사단장 마을 장면 — 확인 완료
- 2-1B-2 마물사냥꾼 세계수 배경 — 확인 완료
- 2-1B-3 마물사냥꾼 오염 야수 장면 — 확인 완료
- 2-1B-4 마물사냥꾼 초상 — 확인 완료
- 2-1B-5 광신도 소문 행렬 — 확인 완료
- 2-1B-6 광신도 제단 야간 배경 — 확인 완료
- 2-1B-7 광신도 의식 레이어 — 확인 완료
- 2-1B-8 광신도 소환 레이어 — 확인 완료

위 8개는 현재 Godot에 존재하며 웹 기준본과 blob SHA가 전부 일치함을 재확인했다.

### 2-1C 부활 의식/남은 인물 레이어
- 2-1C-1 전이문 폐허 기본 배경 — 확인 완료
- **2-1C-2 전이문 에너지 레이어 — 이관 완료**
- 2-1C-3 전이문 광신도 레이어 — 이관 완료
- 2-1C-4 전이문 징조 레이어 — 이관 완료
- 2-1C-5 기사단장 상반신 — 이관 완료
- 2-1C-6 네크로맨서 상반신 — 이관 완료

2-1C-2 커밋: `b689bfd7a103330e7403b4126c4ce24cd03388bb`
웹 원본과 Godot blob SHA: `74fc6685b1b8a4936d92e82144b43911688fc7fd` 일치.


## 2-1C 최종 이관 커밋
- 2-1C-3 전이문 광신도: `ea5dd4f01783742014b2baab49bd86c1961c970f`
- 2-1C-4 전이문 징조: `8c07aad2a9375be4692e6460e5eaa982f76cd1db`
- 2-1C-5 기사단장 상반신: `18db239f2810a2469e959d21464bd9d2328ca73f`
- 2-1C-6 네크로맨서 상반신: `33788d9573c3f60aed018f1f5436cff5b6a791e4`
- 위 기록 이전의 단계별 잔여 수량은 당시 스냅샷으로, 현재 잔여 수량이 아님.

## 2-1D 최종 대조 — 21/21
- 검증일: 2026-10-10
- 웹 원본: `gamja121/necromancer-dice-board`의 `reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`
- Godot: `gamja121/necromancer-and-dice-godot`의 main
- 방법: 양쪽 GitHub 파일 경로, 바이트 크기, Git blob SHA 일치 확인
- 검증 결과: 21개 완전 동일 / 누락 0 / 불일치 0. UI 양피지 1개는 의도된 파일명 차이(하이픈 → 밑줄).
- 이번 작업: 이전에 확인한 4개를 포함해 21개 모두 전수 검증했으며 이미지·코드는 변경하지 않음.

| 번호 | 웹 파일 | Godot 경로 | 바이트 | Git blob SHA | 결과 |
| ---: | --- | --- | ---: | --- | --- |
| 1 | `art/v2-style/map-test/events/graveyard-child-base-v3.webp` | `assets/map/events/graveyard-child-base-v3.webp` | 617608 | `e335d6fe4fe0eeba7792385b882873a1d9e6c52f` | EXACT |
| 2 | `art/v2-style/map-test/events/graveyard-child-ghoul-event-v3.webp` | `assets/map/events/graveyard-child-ghoul-event-v3.webp` | 26342 | `6942427000cb83bb2ccd7d6eba7a4f181d4bda62` | EXACT |
| 3 | `art/v2-style/map-test/events/rumor-village-base.webp` | `assets/map/events/rumor-village-base.webp` | 639334 | `fb208a65342ad4a98a6736d4083e60abd59bc5bd` | EXACT |
| 4 | `art/v2-style/map-test/events/rumor-villagers-whisper.webp` | `assets/map/events/rumor-villagers-whisper.webp` | 620868 | `01ea6bc1396c2f3653754df562eae5f4a8fecc3a` | EXACT |
| 5 | `art/v2-style/map-test/events/rumor-villagers-turn.webp` | `assets/map/events/rumor-villagers-turn.webp` | 464636 | `1728dce680507950888b51a09fea24395d5f2518` | EXACT |
| 6 | `art/v2-style/map-test/events/rumor-necromancer.webp` | `assets/map/events/rumor-necromancer.webp` | 504464 | `3571628a5ac10d8c5321b8a59f2ece5c4cd4d56f` | EXACT |
| 7 | `art/v2-style/map-test/events/knight-commander-village-day.webp` | `assets/map/events/knight-commander-village-day.webp` | 749340 | `d1ef0271cd81f9da88f8ae4b3987f3a798e27290` | EXACT |
| 8 | `art/v2-style/map-test/events/monster-hunter-worldtree-base.webp` | `assets/map/events/monster-hunter-worldtree-base.webp` | 895278 | `fcc1e031d0d091808c793acefabc652579604b9f` | EXACT |
| 9 | `art/v2-style/map-test/events/monster-hunter-corrupted-beast-scene.webp` | `assets/map/events/monster-hunter-corrupted-beast-scene.webp` | 804170 | `125187394b539989686a15262cb08848406d5ae1` | EXACT |
| 10 | `art/v2-style/event-portraits/monster-hunter-pen-clean.webp` | `assets/map/events/monster-hunter-pen-clean.webp` | 66522 | `da119b394f65919ac96e746796ac332984b98d1f` | EXACT |
| 11 | `art/v2-style/map-test/events/cultist-rumor-procession.webp` | `assets/map/events/cultist-rumor-procession.webp` | 684648 | `4555a1d63ba850a8811b595e53eb7a70356034b9` | EXACT |
| 12 | `art/v2-style/map-test/events/cultist-altar-night-base.webp` | `assets/map/events/cultist-altar-night-base.webp` | 631428 | `0c8d0a85cdbd46754d105c728d98e1a46683400a` | EXACT |
| 13 | `art/v2-style/map-test/events/cultist-altar-ritual-layer.webp` | `assets/map/events/cultist-altar-ritual-layer.webp` | 649792 | `61de4bd0a4d39ac0935a6eb92d138ef1a2665ac6` | EXACT |
| 14 | `art/v2-style/map-test/events/cultist-altar-summon-layer.webp` | `assets/map/events/cultist-altar-summon-layer.webp` | 744410 | `0a7421ee88ca9b7ab7d878658ba44d3ccaa64cf6` | EXACT |
| 15 | `art/v2-style/map-test/events/ritual-portal-ruins-base.webp` | `assets/map/events/ritual-portal-ruins-base.webp` | 710788 | `cd96ca140895c310391bb98183d938cb338e1340` | EXACT |
| 16 | `art/v2-style/map-test/events/ritual-portal-energy-layer.webp` | `assets/map/events/ritual-portal-energy-layer.webp` | 627950 | `74fc6685b1b8a4936d92e82144b43911688fc7fd` | EXACT |
| 17 | `art/v2-style/map-test/events/ritual-portal-cultists-layer.webp` | `assets/map/events/ritual-portal-cultists-layer.webp` | 721538 | `b523f9846221e6c8bd974de7da9452f5b27dad1e` | EXACT |
| 18 | `art/v2-style/map-test/events/ritual-portal-omen-layer.webp` | `assets/map/events/ritual-portal-omen-layer.webp` | 693740 | `2ca0f16de008aac924c11a15ff2475e9b40717dc` | EXACT |
| 19 | `art/v2-style/event-portraits/knight-commander-upperbody-hd.webp` | `assets/map/events/knight-commander-upperbody-hd.webp` | 15009 | `e54f787b10fb6cb43f405fd0924298f06c21082e` | EXACT |
| 20 | `art/v2-style/event-portraits/necromancer-upperbody-hd.webp` | `assets/map/events/necromancer-upperbody-hd.webp` | 15008 | `5879d8ad9661bf5777e4aa895710e9d047114598` | EXACT |
| 21 | `art/v2-style/ui/graveyard-choice-parchment.webp` | `assets/map/ui/graveyard_choice_parchment.webp` | 14756 | `4e45ec7de2ba76dfaa8e76ea3565f20069efe1eb` | EXACT |

**P1-01 story-assets: DONE.** 다음 진행은 `P1-02` 사건 상태기계이며, 원화 이관 완료가 사건 런타임 구현 완료를 뜻하지는 않음.
