# Necromancer and Dice — Godot

Godot 4.7.2 Standard / GDScript / Compatibility renderer.

## 실행

Godot에서 project.godot을 열고 F5로 실행한다. 기본 시작 장면은 map.tscn이다.
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
