# Necromancer and Dice — Godot

## 현재 개발 방식 — 2026-10-10

- 공개 Godot 원본: https://github.com/gamja121/necromancer-and-dice-godot
- PC 활성 프로젝트: C:/Dev/necromancer_and_dice
- PC에서 구현·검증한 작업을 commit/push하여 공개 main과 동기화한다. 연결된 GPT/Codex는 이 저장소의 원본을 확인하고 권한이 있으면 수정한다.
- 기존 HTML/JS 게임은 완성 기준으로 보존한다. 앞으로 개발은 Godot 이식에 집중하고 Godot Web 내보내기·자동 배포는 중단한다.
- HTML/JS 기준: https://github.com/gamja121/necromancer-dice-board/tree/reference/html-final
- 상세 운영 규칙: [docs/development_policy.md](docs/development_policy.md)
- 이식 상태 및 남은 범위: [docs/godot_port_status.md](docs/godot_port_status.md)

2026-10-10에 PC 게임 코드·실행 에셋 533개 파일을 공개 원본과 병합했다. 시작 흐름은 타이틀 → 새 원정 → 인트로 → 맵이며 이어하기는 저장된 맵을 복원한다. 동시 제작 중인 아트 후보·도구는 별도 작업이다. [동기화와 실행 검증 기록](docs/native_source_sync_2026_10_10.md)을 참고한다.


Godot 4.7.2 Standard / GDScript / Compatibility renderer.

## 실행

Godot에서 project.godot을 열고 F5로 실행한다. 기본 시작 장면은 project.godot의 application/run/main_scene 설정을 따른다.
독립 전장을 확인하려면 battlefield.tscn을 열고 F6로 실행한다.
Windows의 launch_game.cmd는 로컬 엔진 설치 경로에 맞춰 수정해서 사용한다.

## 2026-10-06 구현 상태

- 원본 아트 기반 전장, 마물 카드와 정보창, 공격/피격/사망 모션.
- 24타일 보드 맵, 주사위 이동, 워프/숙영, 전투 진입과 원정 저장.
- 보유 개체 1~4장을 선택하는 전장 덱 선택창과 선택 순서별 피격 확률.
- 대기 호흡, 접지 그림자, 투사체, 피격 플래시, 배속/일시정지에 맞춘 전투 연출.
- 원본 마물별 9종 타격 시트, 피해/회복 숫자와 상태 표시, 소환 마법진, 회복 입자.
- 아군 영구사망의 암전·강조·영혼/재 소멸·전용 소리·카드 소실. 적과 소환체 사망 구분.
- 전장 오디오 출력 장치/음량 선택 및 별도 사용자 설정 저장.
- 재사용 가능한 ButtonEffectsModule. 전투 시작 및 일시정지/계속 두 버튼에 적용.

원본 웹 게임의 모든 콘텐츠와 기능 이전이 끝난 상태는 아니다.
현재 상태와 제한은 docs 문서에 기록했다. 다음 작업은 docs/handoff_2026_10_06.md를 참고한다.

## 문서

- docs/map_port.md, docs/battlefield_port.md: 맵/전장 이식
- docs/rule_parity.md: 전투 규칙 대응
- docs/original_effects.md: 원본 효과 이식
- docs/permanent_death_audio.md: 영구사망/오디오
- docs/button_effects_module.md: 버튼 모듈 사용법

Godot 캐시, 빌드, 녹화 파일, 테스트 폴더, 개인 저장/오디오 설정은 업로드하지 않는다.
.uid 파일과 실행에 필요한 에셋은 함께 보관한다.

## 공용 마물 제작 도구

마물 프레임 분리·크기 정렬·시트 조립·Godot 미리보기·누끼 검수는 [공용 파이프라인](docs/unit_art_pipeline.md)을 사용한다. 생성 원본과 미승인 후보 이미지는 로컬에서 별도로 관리한다.
