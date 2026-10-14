# 중단 복구형 AI 개발 — API 키 없는 실행 프로토콜 v2

## 사용자 제약 및 목표

- 사용자는 OpenAI API 키를 생성하거나 공유하거나 GitHub Actions Secrets에 저장하는 방식을 원하지 않는다.
- ChatGPT 대화가 종료되거나 멈춰도 현재 작업이 소실되지 않고, 클라우드에서 시작한 별도 개발 작업이 계속 실행되도록 한다.
- 채팅의 텍스트 기억에 의존하지 않고 GitHub Issue, 브랜치, 커밋 SHA, PR, CI 로그를 지속 가능한 사실 기록으로 삼는다.
- **중요한 구분:** 외부 클라우드에서 실행 중인 작업의 지속 실행과, 실패 후 *새 AI 작업을 무인으로 재시작*하는 기능은 다르다.

## 현행 구성(구현 완료)

- PR #154: GitHub Issue 템플릿, `tools/ai_runner/checkpoints.py`, 수동 체크포인트 기록, 매시 실행하는 워치독, 오프라인 테스트.
- 마지막 `running` 기록이 90분 경과하면 `recoverable` 또는 재시도 한도 초과 시 `blocked`라고 기록한다.
- 워치독은 GitHub Issues에 상태만 기록하고 AI 코딩 실행은 하지 않는다. `recoverable` != `running`.
- 저장소는 공개 `gamja121/necromancer-and-dice-godot`; 게임 코드는 Godot 4.7.2로 유지한다.

## 2단계 권장 인증: ChatGPT 계정 + Codex Cloud (API 키 불필요)

1. 사용자가 자신의 ChatGPT 계정으로 Codex Cloud를 연다.
2. 자신의 GitHub 계정으로 연결을 승인하고 공개 Godot 원본 저장소를 선택한다.
3. desktop/web에서 Godot 프로젝트용 클라우드 환경을 설정·게시한다. 모바일에서 해당 환경의 작업을 시작하거나 이어갈 수 있다.
4. Issue를 하나의 명세로 삼고 클라우드 작업을 만든다. **별도 작업 공간**인 점을 고려해 중요한 변경은 수시로 branch에 커밋한다.
5. Codex가 작업 중 채팅·PC가 종료되어도 원격 작업이 계속될 수 있다. 새 작업이 이전 작업의 미커밋 편집을 자동으로 복구하지는 않는다.
6. 중단·실패가 발생하면 원래 클라우드 작업으로 복귀하거나, 최종 커밋과 Issue 기록을 근거로 새로운 클라우드 작업을 시작한다.
7. 작업 완료 보고에는 브랜치, 최종 SHA, 테스트 결과, PR URL, 모바일 시각 검사 및 PC 동기화 여부를 포함한다.

## 반드시 지킬 상태 전이

```
ready → running → checkpoint → running → ... → complete
                  ↘ (90분 무응답) recoverable → running (새 실행)
                  ↘ (3회 실패) blocked (사람의 확인 필요)
```

- `checkpoint`는 기능의 정상 상태를 검증하고 커밋한 지점이다.
- **각 새 작업 단계 시작 시 `running` 상태를 다시 기록**해야 워치독이 그 단계를 감시할 수 있다.
- 커밋 후 진행 기록에 파일명·검증 로그·커밋 SHA를 남긴다. 기록이 실패해도 커밋/PR은 보존한다.
- 마지막 작업을 읽지 못하거나 충돌이 존재하면 재시도보다 `blocked`가 우선이다.
- 같은 Issue를 두 AI가 동시에 수정할 때는 자동 재개하지 않는다. PR/브랜치 충돌 확인 후 한 실행자만 유지한다.

## 실용적인 작업 단위

- 한 Issue에는 한 가지 화면, 버그, 기능만 넣는다.
- 작업을 대략 1~3개 소스 파일과 하나의 검증 경로로 쪼갠다. 파일 수가 아닌 실제 변경 위험이 기준이다.
- 큰 변경은 `계획 → 코드 → 테스트 → 시각검수 → PR`로 나눈다.
- 게임 규칙 변경 전에는 Trigger, Information, Interaction, Visual Change, Memory의 다섯 가지 원칙을 검사한다.
- 원본 아트·개인 저장 데이터·운영체제 설정·기존 미완성 로컬 변경을 임의로 덮어쓰지 않는다.
- CI를 통과한 뒤 PR 검토로 `main`에 합친다. CI만으로 실제 모바일 시각 검수나 PC 동기화가 자동 완료됐다고 주장하지 않는다.

## 권장 Codex Cloud 첫 작업 지시문

> 저장소: gamja121/necromancer-and-dice-godot. 먼저 AGENTS.md, docs/ai_execution_protocol.md, GitHub Issue #155 및 최신 main/PR을 읽어라. 변경은 해당 작업만의 feature 브랜치에서 수행하라. 시작 전 목표·완료 조건·수정 대상 파일을 정리하고, 작은 단위마다 검증 후 커밋하라. 각 체크포인트에 브랜치, SHA, 검사 결과와 다음 단계를 남겨라. 중단된 경우 마지막 정상 커밋에서만 재개하며 저장·전투규칙·원본 아트를 임의 변경하지 마라. PR과 검증 결과를 보고하되, 실제 확인되지 않은 배포·PC 동기화를 완료라고 보고하지 마라.

## 완전 무인 재시작을 원할 때의 인증 가능한 선택지

- GitHub Copilot cloud agent는 유료 플랜에서 GitHub Issue를 할당하면 독립적으로 코드를 수정하고 PR을 올릴 수 있다. 사용자가 GitHub에서 직접 사용 권한을 승인해야 한다.
- GitHub Copilot **Automations**는 현재 private/internal 저장소 전용이므로 현재 공개 저장소에서 해당 기능으로 자동 작업 시작을 보장하지 않는다.
- ChatGPT Work의 예약·GitHub PR 이벤트 트리거는 계정에서 기능이 활성화되어 있는 경우 감시/후속 조치에 이용할 수 있다. 단, 특정 Codex Cloud 작업의 자동 무인 재시작과 동등하다고 간주하지 않는다.
- 무엇을 사용하든 사용자 계정 인증/접근 권한, 비용, 최대 3회 재시도, 동시 실행 제한, 검증 게이트가 실제로 마련된 뒤 무인 재실행 가능 여부를 테스트해야 한다.

## 검증 및 운영 상태

- 1단계 구축 및 테스트: 완료(PR #154).
- API 키 없는 2단계 실행 지침: 이 문서 및 GitHub Issue #155에 기록.
- Codex Cloud GitHub 계정 연결: 사용자 승인이 필요하며 미확인.
- 클라우드 개발 실제 작업 실행, 강제 중단 후 복구 실험: 미실시.
- 실패 후 새 AI 작업이 자동 시작되는 기능: **미구현**.

공식 안내: https://help.openai.com/en/articles/20001545-using-codex-cloud
GitHub Copilot cloud agent: https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-on-github