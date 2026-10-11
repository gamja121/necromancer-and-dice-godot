# P5-01 — Godot 독립 실행 및 구 HTML/JS 의존성 감사 (2026-10-11)

## 결과

P5-01은 **게임 런타임 소스의 구 웹 프로토타입 의존성 탐색/검증** 범위이다. 원본 HTML/JS 저장소를 삭제하거나 새 웹 배포로 이전하는 작업은 아니다.

- 기준 GitHub: `gamja121/necromancer-and-dice-godot` — PR #88.
- 자동검사 기록: https://github.com/gamja121/necromancer-and-dice-godot/actions/runs/38138477320
- 실행 환경: GitHub Actions 신규 runner, 구 `gamja121/necromancer-dice-board` 저장소 미체크아웃, Godot **4.7.2**.
- 독립성 보호 자체 검사 **9 fixtures PASS**, Godot 런타임 파일 **80개** 스캔, 고정 리소스 경로 **252개 존재 확인**, 금지된 웹 저장소 / `http(s)://` / HTML·JS·CSS 웹 의존 파일 / 제외된 `source_assets` / 원격 또는 PC 고정경로 **0개**, 동적 템플릿 **43개**는 검사 대상 별도 취급.
- 동일 단독 Godot 체크아웃에서 headless editor import 및 `project.godot` 기본 실행 **PASS**.
- 검사 스크립트 `scripts/guard_web_independence.py`; 자동실행 `.github/workflows/godot-web-independence.yml`. 이 가드는 앞으로 관련 코드·씬·데이터·프로젝트 파일 변경 시 다시 실행한다.

## 검색 범위와 한계

현재 native runtime 코드, Godot 씬, 데이터 및 리소스 입력: 루트 스크립트·씬·`project.godot`, `systems/`, `data/`, `assets/` 안의 Godot 텍스트 파일. 개발용 `scripts/`와 `docs/`, CI workflow, `export_presets.cfg`는 검색 대상에서 제외했다. 개발 기록에는 의도적으로 원본 웹 URL이 들어갈 수 있으므로 실행 의존성으로 오판하지 않는다.

`res://...` 동적 경로 템플릿 43개는 문자열 조합·변수화된 리소스이므로 정적 파일 존재 확인을 생략하며, 기존 전장 47종/733장 프레임, 카드, 사건, 보상 및 실물 UI 경로를 포함하는 Godot 실행 회귀검사로 보완한다. **모든 가능한 동적 경로의 무결성을 수학적으로 증명하는 것은 아니다.**

`web/landscape-lock.js`와 `web/landscape-lock.css`는 **Godot 저장소 내부**에서 Web export 이후에 주입하는 모바일 세로 화면 안내용 UI이며, 옛 프로토타입의 코드 또는 그 저장소를 로드하는 코드가 아니다. Godot Web exporter가 생성하는 `index.html` 자체도 원본 웹 게임의 HTML 파일이 아니다.

## 중요한 별도 게이트

- **Web 미리보기 Pages**: 현행 웹 미리보기 URL은 여전히 기존 `gamja121/necromancer-dice-board`의 Pages에 배포된다. `CANONICAL_DEPLOYMENT.md` 참고. Godot 원본/기본 실행 독립성만으로 삭제하면 배포 사이트가 소실될 수 있다.
- **P5-02**: 웹 원본 고정 SHA `e13d5149fcecc802e5d626f3bef6e5daecd3d66c`를 포함하는 복구 가능한 ZIP/번들, 에셋·감사 문서 보존은 별도 TODO.
- **P5-03 / P5-04**: 159개 항목 종합 감사, 대체 Pages 계획, 보존본 검증, 사용자 명시적 최종 삭제 승인 없이는 웹 원본 저장소 삭제 절대 불가.
- **P4-01F / P4-02E-B / P4-04B / P3-05**: Windows GUI·가청 오디오·PC Git SHA 동기화·시각 품질 검수는 headless 검사로 승인할 수 없으며 TODO 그대로 유지.

## 다섯 원칙

새 게임 플레이 기능 추가나 기존 규칙 변경 없음. Trigger=CI PR/push에서 의존성 스캔 및 프로젝트 실행; Information=런타임 코드/씬/데이터/정적 리소스; Interaction=GitHub CI와 유지보수자; Visual=게임 UI 변경 없음; Persistence=게임 저장 파일 및 원본 에셋 불변.
