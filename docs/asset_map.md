# 에셋 연결 (신형 마물 카드 기준)

실제 게임의 마물 카드는 정적인 옛 PNG 한 장이 아니라 `systems/layered_unit_card.gd`가 조립하는 레이어형 카드다.

- 마물별 실제 원화: `res://assets/cards/layered/<species>.webp` (정확한 파일명은 `LayeredUnitCard.PORTRAITS`에서 매핑)
- 종족별 배경: `LayeredUnitCard.BACKGROUNDS`의 WebP 또는 공통 `BACKGROUND`
- 이름띠: `LayeredUnitCard.NAMEPLATE`
- 낙인 아이콘: 기존 전투용 아이콘 시트
- 제단 강화 배지: `res://assets/cards/altar_upgrade_badge_1.webp` ~ `_3.webp`
- 전투 동작 및 정보창 초상화는 `res://assets/battle/` 하위 독립 리소스로 유지한다.

게임은 `LayeredUnitCard.install`, `sync_preview`, `make_preview`로 신형 합성 카드를 표시한다. 모든 47종(원본 46종 + 드라큘라) 카드 테스트에서도 개별 레이어 파일을 검사한다.

2026-10-24 기준 구형 `unit-card-*.png` 및 전용 `.import`는 안전 검사 후 저장소에서 삭제할 폐기 자산이다. 이전 카드의 커밋 이력은 GitHub에 남으므로 현재 런타임에서 다시 참조하지 않는다. 신형 WebP, 원본 캐릭터 이미지, 전투 동작, 저장 데이터, 주사위/낙인/상점 규칙은 변경하지 않는다.

Windows 시스템의 맑은 고딕을 SystemFont로 요청한다. OS 글꼴 파일을 프로젝트에 복사하지 않는다. 모바일 및 배포용 공통 글꼴은 적절한 배포 라이선스의 한글 폰트로 후속 교체한다.
