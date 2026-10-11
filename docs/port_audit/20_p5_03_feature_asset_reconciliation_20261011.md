# P5-03A — 159개 기능 및 791개 에셋 재대조 (2026-10-11)

## 범위와 판정

이 문서는 `docs/port_audit/feature_parity_audit.tsv`와 **2026-10-10 시점의 역사적 원본** `asset_parity_audit.tsv`를 현재 Godot `main`의 추적 Git blob/파일 경로와 대조한 **코드·저장소 수준 검사**다. 옛 TSV를 현재의 사실로 덮어쓰지 않는다.

- 기준 고정 웹: `gamja121/necromancer-dice-board@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- 새 교차 감사: `scripts/audit_p5_03_parity.py`, `.github/workflows/p5-03-parity-audit.yml`.
- 기존 기능 감사 총합: **159개**, `✅ 완료` **156개**, `🔵 의도적 변경` **3개**, 미이식 **0**, 부분 이식 **0**. `web_feature_master.tsv`에서 실제 필요한 159개 ID와 대조하고 각각의 Godot 후보 파일 존재 여부 검사.
- 의도 변경 W005: 웹 타이틀 영상/외형 대신 사용자 승인 Godot 묘지 화면 + 원본 음악. W151: IndexedDB → `user://` 저장. W202: 브라우저 가로 화면 강제 → Godot 화면 해상도/뷰포트 정책.
- 기존 에셋 감사 목록 **791개** 전체에 대해 기록된 Godot 파일의 존재와 Git blob SHA를 재검증한다. 역사적 `MISSING_REQUIRED` 1개 + `MISSING_WITH_UNPORTED_STORY` 21개는 현재 누락 결론이 아니다.

## 오래된 '누락 22개'에 대한 최신 확인

고정 웹에서 과거 누락으로 기록했던 22개 에셋은 현재 **전부 Godot 저장소에 파일로 존재**한다.

| 현행 재대조 | 수 | 설명 |
| --- | ---: | --- |
| 과거 누락 → **원본 blob SHA까지 완전히 동일** | **20** | 타이틀 음악 `assets/title/music/title-theme.mp3`, 공동묘지/마을/광신도 제단/전이문 사건 원화 18개, UI 양피지 1개 등. Git SHA로 개별 확인 |
| 과거 누락 → **대체 이미지 존재, 원본과 내용 차이** | **2** | 기사단장과 네크로맨서 상반신 초상화가 `assets/map/events/`에 존재하나 원본 SHA가 다름 |
| 과거 누락 → 현재 파일 부재 | **0** | 옛 22개 가운데 파일을 찾지 못한 항목 없음 |

### 기존 'EXACT' 감사 중 발견한 2개 불일치

2026-10-10 TSV에서 원본과 동일한 `EXACT`로 기록한 682개 중 **2개는 현재 실제 Git blob SHA가 기록과 달라** 반드시 최신 검수에서 구분해야 한다.

| 파일 | 웹 원본 SHA(앞 10자리) | 현재 Godot SHA(앞 10자리) | 확인 상태 |
| --- | --- | --- | --- |
| `assets/map/events/fortune-teller.jpg` | `8faf87019c` | `effcf0425a` | **변경본, 시각 승인 확인 필요** |
| `assets/map/events/home-interior.jpg` | `ed966e554b` | `2623363f68` | **변경본, 시각 승인 확인 필요** |
| `assets/map/events/knight-commander-upperbody-hd.webp` | `e54f787b10` | `7710370f74` | **변경본, 원본 대비 초상 확인 필요** |
| `assets/map/events/necromancer-upperbody-hd.webp` | `5879d8ad96` | `c707c93a5c` | **변경본, 원본 대비 초상 확인 필요** |

**이 네 파일은 존재하지만 원본 byte-identical이라고 표시하지 않는다.** 지금의 Godot 업데이트 자산을 사용자 승인 없이 되돌리거나 교체하지 않는다. 시각 품질·투명/해상도·사건 배치 확인 후 변경본을 채택할지, 원본 보존본을 사용할지 결정해야 한다. 코드/씬 동작이 통과했다고 실기 결과를 대신하지 않는다.

그 외 이전 감사에서 `EXACT`, `EXACT_RENAMED`, `UPDATED`, `FALLBACK`, `REPLACED`로 이미 대응이 지정된 741개는 현재 지정 파일이 모두 존재하고, **두 배경 이미지 이외** 이전 Godot SHA와 동일하다. 개발/웹 대체 원화 28개 (`DISCARD_DEV_ONLY` 10, `DISCARD_WEB_ALT` 18)는 별도 제품 기능이 아니며, 원본 웹 백업 Release에 보존한다. 원화에 대한 실제 구현/그래픽 승인 관문을 생략했다는 뜻은 아니다.

## P5-03 코드 수준 승인과 전체 삭제 게이트를 분리

- **P5-03A (자동 코드·자산 대조)**는 위 159/791 전수 검사 및 4건 변경 의심 상태 기록만 완성한다. CI 기록과 회귀검사가 통과하면 이 하위 검사만 DONE 가능.
- **P5-03 전체**는 여전히 TODO. PC만의 원화·PSD/외부 사본을 검증한 P5-02B가 TODO이고, Windows GUI/오디오·PC SHA 동기화 및 **변경 이미지 4개 실제 사용자 승인**도 끝나지 않았다.
- **P3-05, P4-01F, P4-02E-B, P4-04B** 등의 실기 게이트는 자동 검사로 완료 처리할 수 없다.
- **P5-04** 원본 저장소 삭제 조건: 자료·Git 이력의 독립 오프사이트 복원 검증, 159개 이식 근거, 현재 필수 게임 리소스 누락 0, 사용자 PC 시각·오디오 검수, Pages 미리보기의 대체 배포 경로, 그리고 **사용자의 명시적 최종 삭제 승인**을 모두 충족해야 한다.
- 기존 웹 원본 `reference/html-final`/메인 브랜치/웹 미리보기 배포를 **변경하거나 삭제하지 않는다**.

## 재현

```bash
python3 scripts/audit_p5_03_parity.py --self-test
python3 scripts/audit_p5_03_parity.py --json-output /tmp/p5-03-audit.json
```

검사 결과의 `P5_03_CODE_AUDIT_PASS`는 **추적 Git 리소스 수준에서 경로와 기록된 SHA가 설명 가능한 상태**라는 뜻이며, `P5_03_DELETION_NOT_AUTHORIZED`가 동시에 출력된다. CI 실행 시 생성한 JSON을 임시 Actions artifact로 보존한다. 헤드리스 게임 동작 CI는 별도로 수행한다.
