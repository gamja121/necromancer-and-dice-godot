# AI 개발 작업 인계·복구 — ChatGPT + GitHub 전용 프로토콜 v3 (2026-10-14)

## 사용자 확정 조건

- 코딩을 맡길 AI는 ChatGPT만 사용한다. Codex, GitHub Copilot, 기타 외부 코딩 에이전트는 사용하지 않는다.
- OpenAI API 키를 생성·보내거나 GitHub Actions Secret에 넣으라고 요구하지 않는다.
- 개발 원본은 `gamja121/necromancer-and-dice-godot`, 엔진 Godot 4.7.2.
- 채팅 중단 시에도 **검증된 코드·작업 계획·진행 상태는 GitHub에 남겨** 다음 ChatGPT 대화가 이어받게 한다.
- 일반 ChatGPT 채팅은 종료된 뒤 스스로 다시 실행할 수 없다. GitHub 워치독은 AI 코딩 재시작 도구가 아니다.

## 기존에 구축되어 작동하는 요소

- PR #154: Issue 양식, `tools/ai_runner/checkpoints.py`, 수동 체크포인트 기록, 15분마다 중단 점검, 오프라인 검증 테스트.
- 워치독은 최신 `running` 댓글 이후 20분 이상 무응답이면 `recoverable` 또는 `blocked`를 기록한다. 15분 간격으로 예약 점검하지만 GitHub schedule 지연/실패 가능하며 정확한 탐지시각을 보장하지 않는다. ChatGPT 알림 자동화는 최대 시간당 한 번 실행되므로 감지 직후 휴대폰 알림 발송은 보장하지 않는다.
- ChatGPT는 정상 작업 중 인증된 GitHub 연결로 코드·Issue를 읽고 수정·커밋·검증할 수 있다.

## 새로운 작업 절차

1. 작업 시작: `AGENTS.md`와 이 문서, 현재 관련 Issue, `main` 최신 SHA와 진행 중 PR을 먼저 확인한다.
2. 각 사용자 요청에 GitHub Issue 하나를 지정한다. Issue에는 목표, 완료 조건, 수정 허용/금지 파일, 테스트 경로와 다음 단계를 적는다.
3. 작업을 **작고 독립적으로 검증 가능한 단계**로 분할한다. 작은 수정은 기존 승인 절차 내에서 커밋하고, 큰 수정은 별도 feature 브랜치를 사용한다.
4. 변경 전 단계별 상태를 `running`으로 기록한다. 단계마다 수정 → 검사 → 커밋 → `checkpoint`를 반복한다.
5. 체크포인트 댓글에는 `phase`, `step`, `attempt`, `branch`, `commit`, `note`를 남긴다. `note`에는 완료된 파일, 검사 결과, 남은 작업과 주의사항을 적는다.
6. 최종 검증 후 PR을 검토하여 `main`에 병합하고 `complete`로 기록한다. PC 로컬 반영은 실제 확인 전까지 '미확인'으로 남긴다.
7. 도중에 ChatGPT 응답이 끊기면 **GitHub에 남긴 작업 기록**이 복구 기준이다. 사용자가 새 ChatGPT 대화에서 'Issue #번호 이어서'를 요청하면 최근 정상 SHA에서 복구한다.

## 재개 절차 (ChatGPT용)

1. `gamja121/necromancer-and-dice-godot`의 해당 Issue 댓글에서 마지막 유효한 `ND_AI_CHECKPOINT_V1` JSON을 읽는다.
2. 브랜치와 `commit` SHA, 관련 PR, 최신 `main`과 CI 상태를 확인한다.
3. 이미 적용된 수정은 반복하거나 덮어쓰지 않는다. 중단 이전의 미검증 내용은 별도로 조사한다.
4. 남은 단계만 선택해 `attempt`를 1 증가시키고 새 `running` 체크포인트를 기록한다.
5. 수정 → 테스트 → 안전한 체크포인트 커밋 → Issue 진행 기록. 불확실한 충돌과 반복 오류는 `blocked`로 알린다.

## 대화에서 재개할 때 사용하는 한 문장

> 네크로맨서 앤드 다이스 GitHub Issue #155와 docs/ai_execution_protocol.md를 읽고, 마지막 체크포인트·커밋·CI를 확인한 다음 미완료 단계부터 이어서 진행해줘. Codex/API 키 사용 금지.

## 확인해야 할 한계

- 중단 감지와 자동 코드 재실행은 서로 다르다. 현재 **중단 감지 + 다음 대화에서 안전한 재개**까지만 구현·운영한다.
- 별도 AI 실행자 없이 일반 채팅이 멈춘 뒤 **사람의 재요청조차 없이** 코딩을 지속·재시작하는 것은 보장할 수 없다.
- ChatGPT Work 모드가 계정에서 제공된다면 사용자 선택으로 장시간 작업을 별도 작업 환경에 맡길 수 있다. 일반 채팅의 자동 재개나 GitHub 워치독의 AI 재실행으로 오해하지 않는다.
- 동일 Issue를 두 채팅에서 동시에 수정하지 않는다. 워치독은 상태 기록만 하며 외부 입력을 코드/셸 명령으로 실행하지 않는다.
- 저장소는 공개이므로 Issue·PR에 비밀키, 개인정보, 개인 저장 파일 및 비승인 아트 원본을 올리지 않는다.
- 게임 규칙 변경에는 Trigger, Information, Interaction, Visual Change, Memory의 다섯 원칙을 검토한다.

## 적용 확인

- 1단계 GitHub Issue 체크포인트와 watchdog: 구축 완료 (PR #154).
- Codex/API 키 없는 ChatGPT 전용 작업 방식: 운영 지침 확정.
- 일반 채팅 중단 후 무인 AI 코딩 지속: 지원되지 않음.
- ChatGPT 새 대화에서 체크포인트 재개: 작업별 실전 검증 필요.

관련 작업 추적: https://github.com/gamja121/necromancer-and-dice-godot/issues/155