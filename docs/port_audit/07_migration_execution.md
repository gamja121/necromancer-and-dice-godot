# 2단계 실행 기록 — 미이식 기능 구현

작성일: 2026-10-10

## 진행 원칙

한 번에 큰 덩어리를 수정하지 않고, 각 소단계를 끝낸 뒤 확인하고 다음 단계로 이동한다.

## P1 사건 시스템 세분화

### 2-1 사건 에셋 이관
- **2-1A 초기 사건/소문 에셋** — 완료
- 2-1B 기사단장·마물사냥꾼·광신도 에셋
- 2-1C 부활 의식/전이문 에셋 + 남은 인물 레이어
- 2-1D 21개 사건 에셋 SHA/경로 최종 검증

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
