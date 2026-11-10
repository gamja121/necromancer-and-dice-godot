# 저장소 안전 정리 감사 (2026-10-21)

대상: `gamja121/necromancer-and-dice-godot`, `main@2cbcb4b`를 기준으로 Git 추적 트리 전체(3,568개 항목)를 검사했습니다. **이 문서는 트리 및 파일 대응 감사**로, Godot 실기 실행·전면적인 미사용 코드 호출 그래프 검증을 대신하지 않습니다.

## 확인 결과

- 원본 없는 `.import` 보조 파일 **2개** 발견 및 이번 PR에서 삭제:
  - `assets/battle/frames/vampire/vampire-motion-sprite.webp.import` — 원본 `vampire-motion-sprite.webp`가 없음. 메타데이터에 `valid=false`로 표시되어 있었음.
  - `assets/battle/sfx/permanent-death.wav.import` — 원본 `permanent-death.wav`가 없음.
- 대응 원본 `.gd`가 없는 `.gd.uid` 파일: **0개**.
- Git 추적 트리의 `.godot/`, `__pycache__/`, `*.pyc`, `*.log`, `*.tmp`, `*.bak` 형식 임시 산출물: **0개**. 해당 경로는 기존 `.gitignore`로 일부 방지됨.
- 큰 용량은 정상 사용 가능성이 높은 게임 에셋: `assets/` 약 **477.9MB**(추적 파일 크기 합계), 특히 `assets/battle/frames/` 약 **255.1MB**. 바이너리 중복·이미지 무단 삭제 금지.
- `web/landscape-lock.css`, `web/landscape-lock.js`는 Godot 웹 미리보기 배포용으로 사용될 수 있으므로 삭제하지 않음.
- 기존 웹 저장소는 현재 Pages 배포에 계속 사용되며, 고정 웹 소스·Git 이력의 별도 보존 규칙이 있어 삭제 대상에서 제외.
- 최근 독립 낙인카드 제거 작업 및 관련 PR은 별도 작업이므로 이 PR에서 중복 수정하거나 충돌시키지 않음.

## 변경 제한과 남은 검토

1. 이번 PR은 **원본 없는 인포트 메타데이터만 삭제**합니다. 원화·음원·기획 원본 및 런타임 `.gd` 코드는 삭제하지 않습니다.
2. 문서·과거 이식 스크립트·사건·전투 시스템의 완전한 미사용 여부는 문자열 검색만으로 확정할 수 없습니다. 실제 Godot import, 리소스 로드와 회귀 테스트를 돌려야 하므로 후속 조사 대상으로 유지합니다.
3. 대량 자산 압축/재인코딩과 Git 과거 이력 재작성은 이 감사의 범위가 아닙니다. PC 제작 원본, 백업/복원 증거 및 사용자 검수 없이는 수행하지 않습니다.
4. PR 병합 뒤 `main`의 관련 CI와 별도 Godot 실기 테스트 결과를 확인해야 최종 정리 완료로 판정합니다.
