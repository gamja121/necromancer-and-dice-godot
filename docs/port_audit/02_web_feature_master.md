# 완전 이식 감사 1-2 — 웹 기능 마스터 목록

작성일: 2026-10-10

## 기준

- 웹 저장소: `gamja121/necromancer-dice-board`
- 브랜치: `reference/html-final`
- 고정 커밋: `e13d5149fcecc802e5d626f3bef6e5daecd3d66c`
- 이번 단계에서는 **Godot 이식 상태를 판정하지 않는다.**
- 목적은 웹 최종본에서 실제 플레이 기능, 규칙/상태, 웹 전용 구현, 개발 도구, 문서상 계획을 분리해 다음 단계의 기준 목록을 만드는 것이다.

## 분류 규칙

| 분류 | 의미 |
|---|---|
| REQUIRED | 플레이어가 실제로 사용하는 기능·UI·연출. Godot에서 동등한 경험/동작이 필요 |
| REQUIRED_RULE | 화면보다 규칙·상태·판정이 핵심. Godot에서 의미가 보존되어야 함 |
| WEB_IMPL_REPLACE | 기능 의미는 필요하지만 브라우저 구현은 버리고 Godot 방식으로 교체 |
| DEV_ONLY_DISCARD | 테스트/실험/편집 도구. 제품 이식 대상 아님 |
| WEB_ONLY_DISCARD | PWA, 서비스워커, Pages 등 브라우저 운영 전용. 삭제 대상 |
| REFERENCE_ONLY | 웹 회귀 테스트처럼 이식 코드는 아니지만 1-4 규칙 대조 때 증거로 사용 |
| INCOMPLETE_WEB_REFERENCE | 웹 자체도 완성 기능이 아님. 구현 완료로 세면 안 됨 |
| DESIGN_ONLY_NOT_RUNTIME | 문서에만 있는 계획. 웹 런타임에 실제 구현되지 않음 |

## 집계

- 전체 식별 항목: **181개**
- Godot 완전 이식 검사 대상(REQUIRED / REQUIRED_RULE / WEB_IMPL_REPLACE): **159개**
- 웹/개발 전용으로 폐기할 항목: **16개**
- 참고·미완성·설계문서 전용: **6개**

분류별:
- REQUIRED: 64
- REQUIRED_RULE: 93
- WEB_ONLY_DISCARD: 7
- WEB_IMPL_REPLACE: 2
- INCOMPLETE_WEB_REFERENCE: 1
- DEV_ONLY_DISCARD: 9
- REFERENCE_ONLY: 1
- DESIGN_ONLY_NOT_RUNTIME: 4

카테고리별:
- 진입/타이틀: 8
- 인트로: 4
- 맵/원정: 24
- 장소/타일: 26
- 전투: 41
- 보상/인벤토리: 15
- 저장/복원: 16
- 사건/퀘스트: 16
- 연출/오디오: 13
- 개발/폐기: 14
- 설계문서 전용: 4

## 핵심 확인 결과

1. 실제 플레이의 중심 런타임은 `v2-map-practice.js`와 `v2-auto-battle-practice.js`이며, `v2-rules.js`, `v2-run-state*.js`, 낙인/계승/제단/주사위 모듈이 이를 보조한다.
2. 웹 기준에는 24칸 맵, 오염도, 장소 행동, 전투, 영구사망, 영혼 수확, 보상, 낙인/계승, 주사위 카드, 저장/복원과 **실제 사건 체인**이 포함되어 있다.
3. 실제 웹 사건 런타임에는 공동묘지 아이 사건부터 구조/방치 소문, 기사단장, 마물사냥꾼, 광신도 소문/제단, 부활 의식 전이문, 마물의 왕 추적까지 코드가 존재한다.
4. 반면 `EVENT_FLOW.md`의 **아이 누나→구울화 아이→예언자→정화의 나무** 확장 체인과 실제 마물의 왕 최종전 본체는 웹 완성 런타임으로 취급하면 안 된다. 이것들은 별도 신규 Godot 콘텐츠 판단 대상이다.
5. Event Lab, 애니메이션 연습실, 타일 테스트, 이미지 테스트, SFX 샘플러, 구형 `v2.html`, 디오라마 편집 기능은 이식 대상이 아니다.
6. PWA 설치, 서비스워커, GitHub Pages 빌드/캐시는 웹 폐기와 함께 제거할 수 있다. 다만 웹 회귀 테스트는 1-4에서 규칙 증거로 활용한 후 폐기한다.

## 실제 게임 기능 묶음

### 진입·인트로
타이틀, 새 원정, 이어하기, 저장 초기화, 옵션, 인트로 대사와 맵 연결.

### 맵·원정
24칸 보드, 고정/랜덤 타일, 주사위 이동, 한 바퀴, 오염도 5단계, 보스 활성, 맵 재생성, 워프, 처치 타일, 순찰경로, 책/정보창, 전투 덱 선택.

### 장소
숙영, 늪, 세계수, 점술가, 집, 낙인 계승, 제단, 공동묘지 낙인 추출, 언덕 정찰, 마물 상점, 보물상자/미믹.

### 전투
46종 데이터, 1~4 편성, 공용 주사위, 타겟 가중치, 군단 10종, 낙인 10종, 패시브 10종, 소환/씨앗, 상태효과, 영구사망, 오염 기반 조우, 예언 적용, 사건 전투 복귀.

### 보상·인벤토리
영혼 수확, 획득 개체 생성, 마물 10칸, 주사위 카드 5칸, 주사위 제어 18종, 낙인 카드, 초과 보상 교체.

### 저장
RunState, 원자 커밋, 멱등 receipt, 전투/RNG/영혼수확/이동/사건전투 복원.

### 사건
실제 구현 사건 ID:
- `graveyard_child_ambush_01`
- `rumor_saved_child_01`
- `rumor_abandoned_child_01`
- `knight_commander_contamination_01`
- `monster_hunter_encounter_01`
- `cultist_rumor_01`
- `cultist_altar_encounter_01`
- `ritual_portal_trace_01`
- `monster_king_hunt_trace_01`

### 연출·오디오
맵/전투 음악, SFX, 주사위, 공격/피격/사망/대기, 타격 효과, 피해·회복 숫자, 소환, 카드 모션, Presentation 레일.

## 원본 데이터

전체 행 단위 마스터 목록은 `docs/port_audit/web_feature_master.tsv`에 저장한다.
1-3에서는 이 TSV의 **REQUIRED / REQUIRED_RULE / WEB_IMPL_REPLACE 항목 하나하나**에 현재 Godot 대응 파일을 연결한다.
