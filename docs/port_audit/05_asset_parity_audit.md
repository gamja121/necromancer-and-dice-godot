# 완전 이식 감사 1-5 — 에셋 전수 대조

작성일: 2026-10-10

## 기준

- 웹 기준: `necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`
- Godot 기준: `necromancer-and-dice-godot/main@81404df2f96d88a62b060ebada7cc6ea67c8ce0b`
- Git blob SHA로 동일 바이트 여부를 확인하고, 경로가 달라도 같은 SHA면 동일 원본으로 판정했다.
- 런타임 필수 에셋과 웹 테스트/디오라마/중복 언어 자산을 분리했다.

## 전체 저장소 미디어 스냅샷

- 웹 이미지/오디오: **1,097개**
- Godot 이미지/오디오: **981개** (Godot `.import` 제외)
- 웹 미디어 중 Godot에 동일 blob SHA가 존재하는 파일: **755개**
- 단순 파일 개수는 이식률로 사용하지 않는다. 웹에는 테스트/참조/중복 자산이 많다.

## 이번 감사의 이식 관련 에셋 결과

- EXACT: **682개**
- FALLBACK: **1개**
- UPDATED: **39개**
- MISSING_REQUIRED: **1개**
- REPLACED: **13개**
- MISSING_WITH_UNPORTED_STORY: **21개**
- EXACT_RENAMED: **6개**
- DISCARD_DEV_ONLY: **10개**
- DISCARD_WEB_ALT: **18개**

### 핵심 카테고리

- map_tile: 19개
- place_asset: 18개
- map_background: 1개
- unit_card: 46개
- dice_card: 18개
- brand_card: 1개
- battle_frame: 552개
- info_portrait: 48개
- audio: 20개
- intro_asset: 3개
- title_asset: 6개
- story_event_asset: 21개
- ui_replacement: 10개
- dev_only_asset: 10개
- web_alt_asset: 18개

## 확정된 완전 대응

- **맵 타일**: 웹 정상 타일 18개가 Godot에 동일 SHA로 존재.
- **맵 기본 배경**: `default-map.jpg` 동일 SHA.
- **마물 카드**: 웹 46종 PNG가 Godot에 **46/46 동일 SHA**.
- **주사위 제어 카드**: 한국어 18종이 **18/18 동일 SHA**.
- **낙인 카드**: 동일 SHA.
- **전투 프레임**: 웹 `animation-test-frames`의 **552개 경로가 Godot에 전부 존재**. 이 중 **521개 동일 SHA**, **31개는 Godot에서 업데이트된 파일**이다. 경로 누락은 0개.
- **정보창 초상화**: 웹 48개 모두 Godot에 대응. 47개 동일 SHA, `dracula.png` 1개는 Godot 업데이트본.
- **오디오**: 웹 오디오 20개 중 **19개 동일 SHA**. 빠진 것은 타이틀 음악 `assets/title/title-theme.mp3` 1개다.
- **전투/맵 주요 UI**: 책, 카드더미, 낙인 아이콘, 전투 덱 보드, 마물 정보 프레임 등 핵심 자산은 동일 SHA 또는 명시적 Godot 대체본으로 확인.

## 정상적인 대체/차이

### 희귀 마물 처치 타일
웹 `rare-monster-cleared.png`는 기존 문서상 손상된 PNG라 Godot에서 `monster-cleared.png`를 공용 사용한다. 이식 누락으로 보지 않는다.

### 장소 배경
제단/숙영/언덕/공동묘지/집/마을/세계수 일부 JPG는 같은 파일명이지만 SHA가 달라 Godot 업데이트본으로 판정했다. 파일 자체는 존재한다. 최종 시각 검증은 1-6에서 한다.

### 구름 전환
웹의 여러 구름 파일 중 손상본이 있어 Godot는 `assets/map/ui/map_cloud_transition.png` 한 장을 재사용한다. 기존 이식 문서에 기록된 대체다.

### 인트로
웹의 저해상도 인물/청크 조립 구조 대신 Godot는:
- `assets/intro/necromancer.webp`
- `assets/intro/knight_commander.webp`
- `assets/intro/dialogue_frame.webp`
를 사용한다.

### 타이틀
웹의 영상/로고/버튼 이미지 대신 현재 Godot는 `assets/title/cemetery/`의 6개 레이어와 네이티브 UI를 사용한다. **영상/버튼/로고 파일이 없는 것은 의도적 시각 교체**로 본다. 단, 타이틀 음악은 W005 기능과 함께 아직 미이식이다.

### 개발용 자산
웹의 마을/공동묘지/언덕 디오라마 편집 자산과 비한국어 주사위 카드 원화는 제품 이식 대상에서 제외했다.

## 실제 에셋 공백

### 1. 타이틀 오디오
- `assets/title/title-theme.mp3`
- 웹 blob SHA: `68fa42d386482ee03e3b743cc510d89e94784415`
- 현재 Godot에 동일 오디오 없음.
- 1-4의 W005와 같은 미완 영역이다.

### 2. 사건 체인 원화
웹 실제 사건 런타임이 직접 참조하는 사건 원화/레이어 **20개**가 현재 Godot에 없다.

- 공동묘지 아이 사건 2개
- 구조/방치 소문 4개
- 기사단장 1개
- 마물사냥꾼 3개(배경/장면/초상)
- 광신도 소문 1개
- 광신도 제단 3개
- 부활 의식 전이문 4개
- 기사단장/주인공 상반신 폴백 2개

추가로 사건 선택 UI `graveyard-choice-parchment.webp`도 Godot에 없다.

이 공백은 1-4에서 확인한 **사건 런타임 17개 미이식**과 정확히 같은 범위다. 즉 독립적으로 잃어버린 에셋이라기보다, 아직 사건 시스템 자체를 옮기지 않았기 때문에 함께 남은 이식 작업이다.

## 전투 프레임의 변경본

웹 프레임 552개 중 Godot 경로 누락은 0개다.
31개는 SHA가 달라 업데이트본이다.
- `goblin-commoner`: 15개
- `soul-reaper`: 16개

이 파일들은 “없음”이 아니라 Godot 쪽에서 교체된 프레임이므로 1-6에서 실제 재생만 확인한다.

## 삭제 관점 결론

웹 저장소를 지금 삭제하면 안 된다.

현재 웹에만 남은 **실제 보존 필요 자산**은 최소:
1. 타이틀 음악 1개
2. 구현된 사건 체인의 사건 원화/인물 레이어 20개
3. 사건 선택용 양피지 UI 1개

즉 **최소 22개가 현재 Godot에 없는 이식 필요 자산**으로 확정됐다.

그 외 대량의 웹 전용/개발용/중복 자산은 Godot 이식 완료 후 폐기 가능하다.

전체 행별 SHA/경로 대조는 `docs/port_audit/asset_parity_audit.tsv`에 저장한다.
