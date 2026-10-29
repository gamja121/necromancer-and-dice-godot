# Esc 게임 종료 확인 — 2026-10-29

요청 #352: Esc 키로 게임 종료 확인창을 열고 종료 또는 계속 플레이할 수 있게 한다.

- `QuitConfirmation` 자동 로딩 시스템은 루트 Window의 입력에서 Esc를 받는다. 하위 카드 메뉴·드래그 취소·설정창 닫기로 입력이 먼저 전달되지 않게 현재 이벤트만 차단한 뒤 지연 호출로 확인창을 연다. 키를 놓거나 반복 입력되는 이벤트는 창을 다시 만들지 않는다.
- 사용자 후속 요청에 따라 기존 대화용 양피지 재사용을 폐기하고 종료창 전용 양피지 `assets/map/ui/quit_confirmation_parchment.png`를 새로 제작했다. 자연스럽게 찢어진 가장자리와 절제된 접힘, 밝고 비어 있는 중앙, 실제 투명 배경을 사용한다. 640×320 창에서 원화를 통째로 표시하며 기존 글꼴·버튼과 `종료`/`계속` 기능을 유지한다. 기본 포커스는 계속이며 Enter는 계속으로 돌아간다. Esc 재입력과 계속 버튼은 취소한다. 실제 종료 버튼만 `SceneTree.quit()`을 호출한다.
- 창이 열린 동안 이전 pause와 time_scale을 기록한 뒤 트리를 멈추고 scaled 타이머도 동결한다. 취소하면 이전 상태와 유효한 Window/Control 포커스를 복원한다. 활성 카드 드래그는 취소하여 닫는 동안 놓친 포인터 해제가 카드를 나중에 사용하지 않게 한다.
- 기존 설정창 위에서도 그 Window의 자식인 exclusive 확인창으로 열어 원래 설정창을 보존한다. 한국어/영어 설정을 따르며 새 원화나 게임 규칙·저장 동작을 추가하지 않는다. 종료 시 마지막 자동 저장 상태를 기존 이어하기로 복구한다.
- `project.godot`는 자동 로딩 한 줄만 공유 변경에 포함한다. 기존 PC의 주석·줄 간격·항목 순서 변경은 그대로 로컬에 보존한다.

검증: Godot 4.7.2 import, 실제 InputEvent 경로의 Esc/Enter·중복·취소·일시정지·타이머·설정창·포커스·언어·저장 바이트 보존 검사, 실제 별도 프로세스의 종료 버튼, 기존 언어/타이틀/효과음/카드 터치 회귀, GPU 화면5장 확인. 개인 저장 대신 격리된 프로필과 임시 저장을 사용한다.

전용 양피지 적용 후 최종 import 오류 없음. 입력/취소25, 실제 GPU30, 별도 프로세스 실제 종료 확인 통과. 기존 언어88·타이틀23·효과음26·카드 터치27 검사도 통과했다. 오류·종료 누수 없이 확인했다.

원화 제작 방식: 내장 ImageGen, 신규 단일 PNG, transparent_background=true. 이미지에 글자·버튼·상징을 구워 넣지 않는다. 승인되지 않은 기존 시안 파일은 교체하거나 삭제하지 않는다.

최종 제작 프롬프트:

```text
Use case: stylized-concept. Asset type: production-ready, blank parchment background sprite for a dark medieval fantasy game's quit confirmation dialog. Create ONE original wide horizontal sheet of old parchment, approximately 2:1 width to height, viewed perfectly front-on and flat, centered and filling the canvas with only a small transparent safety margin. It must feel hand illustrated with fine black-brown pen-and-ink outlines, delicate etched crosshatching, muted sepia and warm light ivory paper, subtle natural fibers and light creases. Naturally worn irregular torn edges with restrained curled corners, dark aged edge shading, and a tiny soft contact shadow. The center 80 percent must be clean, light, flat, calm and almost untextured so live game text and two live buttons can be clearly drawn over it; keep texture and wear mostly near the perimeter. Quiet, elegant, grounded old tabletop RPG / illustrated medieval manuscript material, matching a hand-drawn sepia necromancer board game, not photorealistic and not glossy. No heavy geometric frame, no double or triple borders, no gold trim, no huge outline, no arrows, no skull emblem, no objects, no rolled scroll handles, no ribbons, no premade button shapes, no divided compartments, no text, no letters, no numbers, no symbols, no watermark, no game scene. Actual transparent alpha outside the single parchment; no background color, no checkerboard printed in image. This is the dedicated reusable blank background asset only, NOT a screenshot or complete UI mockup. High-resolution detailed hand-painted bitmap, landscape.
```
