# AI 개발 작업 자동 복구 — 운영 프로토콜 v1 (단계 1)

## 목표와 현재 기능

단일 Godot 원본: gamja121/necromancer-and-dice-godot.
ChatGPT 연결이 끊겨도 개발 목표와 검증 완료된 결과가 보존되도록 GitHub Issue 댓글에
단계별 진행 상태를 남긴다. 저장소 소유자 본인이 등록한 [AI 작업] Issue만 관리한다.

현재 구현된 것:
- GitHub Issue 양식: 목표, 완료 기준, 수정 범위, 검사 계획.
- append-only 체크포인트: 단계, 브랜치, 마지막 커밋 SHA, 재시도 횟수, 시각.
- GitHub Actions 수동 기록기: AI Task Checkpoint (manual).
- 매시 11분에 90분 넘게 중단된 running 상태를 감지해 recoverable / blocked로 남기는 watchdog.
- 표준 라이브러리 Python 오프라인 회귀 테스트.

**중요:** 이것은 중단 감지 + 재개 가능한 기록이지 무인 코딩 재실행이 아니다.
GitHub Issue 댓글에 recoverable로 표시되었다고 실제 Codex 작업이 재시작된 것은 아니다.

## 작업 시작

1. Issues > New Issue > AI 개발 작업 (중단 복구)에서 공개 가능한 개발 목표를 작성.
2. 작업별 독립 브랜치를 생성. main을 최신으로 가져오고 다른 사람의 수정과 구분.
3. GitHub Actions > AI Task Checkpoint (manual) > Run workflow.
   issue_number, phase=ready, step, branch를 입력해 첫 기록을 남긴다.
4. 실행 전에 phase=running, attempt=1로 기록.
5. 검증 가능한 작은 단위마다 feature 브랜치에 커밋하고 phase=checkpoint로 SHA를 기록.
6. 새 단계 시작 시 phase=running으로 갱신. 자동감시 시각의 기준은 이 기록이다.
7. 테스트·시각검수·PR 병합 및 PC 반영을 확인한 뒤 phase=complete.

## 중단과 안전 규칙

- watchdog은 GitHub 예약 실행의 특성상 실행이 지연/누락될 수 있다.
- 90분 이상 running 기록이 멈추면 attempts 1~2는 recoverable, 3부터 blocked.
- 실제 재개 시 마지막 완료 커밋과 main의 변경을 비교하여 병합 충돌을 방지한다.
- 저장소 외부 Issue, 비소유자 작성 Issue, PR은 감시 대상에서 제외.
- ChatGPT 작업 내용이나 Issue 본문을 자동으로 셸 명령으로 실행하지 않는다.
- 미검증 게임 코드, 웹 배포, 삭제, 원본 아트의 변경을 자동으로 승인하지 않는다.
- 민감한 병원·개인·금융 정보 및 인증키를 공개 Issue나 PR에 기록하지 않는다.
- Codex용 API 키는 소스나 Issue가 아닌 GitHub Actions Secret으로 관리한다.

## 인증된 실행 환경에서 직접 확인

    python3 -m unittest discover -s tests -p test_ai_runner_checkpoints.py -v
    python3 tools/ai_runner/checkpoints.py watchdog --dry-run
    python3 tools/ai_runner/checkpoints.py record --issue 123 --phase ready --step "요구 사항 확정"

마지막 두 명령은 GITHUB_TOKEN과 GITHUB_REPOSITORY 환경 변수가 필요하다.
토큰은 출력하거나 로그에 남기지 않는다.

## 단계 2: 실제 무인 실행/자동 재개 (아직 미구현)

1. Codex를 별도 Linux 실행자에서 동작시키고 OPENAI_API_KEY를 GitHub Actions Secret에 연결.
2. 승인된 owner Issue만 취급하고 Issue 단위 동시 실행 잠금 설정.
3. 단일 실행 시간을 제한하고, 정기 heartbeat와 append-only 커밋 기록.
4. 중단되면 recoverable 작업에 대해 새로운 Codex 실행을 최대 3회 dispatch.
5. 이전 커밋에서 안전하게 복구; 게임의 main에는 자동으로 push하지 말고 PR 게이트를 거친다.
6. API 사용 비용 상한, 파일 수정 허용 목록, 위험 작업 차단 및 테스트 증거를 강제한다.
7. 의도적으로 중단하는 모의 작업으로 실제 재개와 중복 실행 방지를 검증한다.

PC ↔ GitHub 동기화와 기존 Actions 워크플로 충돌/중복 최적화는 별도 후속 단계.
