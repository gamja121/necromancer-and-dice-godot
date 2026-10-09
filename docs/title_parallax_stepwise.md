# 타이틀 패럴랙스 단계별 구현 계획

이 문서는 2026-10-09 작업을 기존 중단 지점에서 그대로 이어붙이지 않고, `main`에서 새 작업 브랜치를 만들어 단계별로 다시 시작하기 위한 기준이다.

## 작업 브랜치

`chatgpt/title-parallax-stepwise-20261009`

기존 중단 브랜치 `chatgpt/title-parallax-20261009`는 손대지 않고 보관한다.

## 1단계 — 구조만 만들기

목표:
- `title.tscn` 생성
- 배경 / 보드 / 전경의 정확한 3레이어 구조 생성
- PC 마우스, 모바일 터치/드래그 입력을 받는 패럴랙스 엔진 생성
- 아직 원화 파일과 메뉴를 연결하지 않음
- 아직 `project.godot`의 시작 장면도 바꾸지 않음

이 단계는 코드 구조가 안전한지 확인하는 단계다.

기본 이동량:
- Background: X 4px / Y 2.5px
- Board: X 11px / Y 6px
- Foreground: X 20px / Y 11px
- 입력이 없을 때는 아주 약한 자동 호흡 이동

레이어는 화면보다 좌우 48px, 상하 28px 크게 잡아 움직일 때 빈 가장자리가 보이지 않게 한다.

## 2단계 — 원화 3장 연결

- 사용자가 확정한 손그림풍 원화 3장을 각각 Background / Board / Foreground에 연결
- 원본 비율과 1280×720 구도를 확인
- 레이어 간 빈 공간, 경계, 잘림을 검사
- 이 단계에서는 메뉴와 시작 흐름을 바꾸지 않음

## 3단계 — 타이틀 UI

- NECROMANCER & DICE 로고
- 새 원정
- 이어하기
- 종료
- 로고와 버튼은 패럴랙스에 영향을 받지 않는 고정 UI로 둔다

## 4단계 — 실제 시작 흐름 연결

- `RunSession`에 새 원정 / 이어하기 진입 함수를 최소 범위로 추가
- `project.godot`의 `run/main_scene`을 `title.tscn`으로 변경
- 기존 map / battlefield 동작은 그대로 유지

## 5단계 — 검증

PC:
- 마우스 좌우/상하 이동
- 빠른 이동 후 부드러운 복귀
- 1280×720 실제 타이틀 구도
- 새 원정 / 이어하기

모바일:
- 터치 시작
- 드래그
- 손을 떼었을 때 마지막 위치에서 과도하게 튀지 않는지
- 16:9 landscape 화면에서 가장자리 노출 여부

최종 검증 전에는 main에 병합하지 않는다.

## 5가지 기본원칙

1. Trigger: 타이틀 화면의 마우스 이동 또는 모바일 터치/드래그.
2. Information: 포인터 상대 위치, 저장 파일 존재 여부.
3. Interaction: 1~2단계에서는 외부 시스템과 통신하지 않는다. 4단계에서만 RunSession과 연결한다.
4. Visual change: 세 레이어만 서로 다른 강도로 이동하고 로고/버튼은 고정한다.
5. Persistent state: 1~3단계에서는 저장 데이터를 변경하지 않는다. 4단계의 새 원정 선택 때만 기존 저장 흐름을 사용한다.


## 2단계 진행 결과 — 2026-10-09

완료:
- Background에 확정 배경 원화 연결
- Board에 투명 보드/마물 원화 연결
- Foreground에 투명 전경 프레임 원화 연결
- 세 레이어의 원본 종횡비가 모두 1672×941 계열(약 16:9)임을 확인
- Board / Foreground의 알파 투명 배경 유지 확인
- `ParallaxArt.clip_contents = true`로 오버스캔 이동 시 화면 밖 영역을 잘라내도록 설정
- 메뉴, RunSession, `project.godot` 시작 장면은 변경하지 않음

현재 GitHub에 연결한 파일은 **레이어 결합과 움직임 확인용 경량 프리뷰**다.
- Background: 320×180
- Board: 320×180
- Foreground: 160×90

이 해상도는 최종 화질용이 아니다. 실제 타이틀을 확정하기 전 원본 1672×941에서 최종 게임용 WebP를 다시 만들어 교체한다. 원화의 펜선이 중요한 만큼 최종본은 최소 실제 표시 크기 이상을 유지하고 게임에서는 가능한 한 축소 표시한다.

### 2단계 안전선

- `main` 미변경
- `project.godot` 미변경
- 저장 데이터 미변경
- `RunSession` 미변경
- map / battlefield 미변경
- 현재 작업은 `chatgpt/title-parallax-stepwise-20261009` 브랜치 안에서만 수행


## 3단계 진행 결과 — 2026-10-09

완료:
- 패럴랙스와 분리된 고정 `TitleUI` 위에 타이틀 로고 추가
- `NECROMANCER` + `& DICE` 2단 로고 구성
- 반투명 어두운 메뉴 패널 추가
- `새 원정 / 이어하기 / 종료` 버튼 3개 추가
- 버튼에 normal / hover / pressed / focus 상태를 각각 적용
- PC 마우스와 모바일 터치에서 누르기 쉬운 264×48 기준 버튼 크기 사용
- 로고와 메뉴는 `ParallaxArt` 바깥에 있어 배경과 함께 움직이지 않음

현재 안전선:
- 버튼은 **시각 UI만 구현**했으며 아직 게임 시작 함수에 연결하지 않음
- `RunSession` 미변경
- `project.godot` 미변경
- 저장 데이터 미변경
- map / battlefield 미변경
- `main` 미변경

다음 4단계에서만 새 원정 / 이어하기 / 종료 기능을 연결하고, 타이틀을 실제 시작 장면으로 전환한다.


## 4단계 진행 결과 — 2026-10-09

완료:
- `RunSession.has_save()` 추가: 기존 원정 저장 파일 존재 여부 확인
- `RunSession.start_new_world()` 추가: 새 원정 상태 생성 후 기존 저장 방식으로 저장
- `RunSession.reload_world()` 추가: 메모리 상태를 비우고 저장 파일에서 다시 로드
- 타이틀 버튼 실제 동작 연결
  - `새 원정` → 새 원정 생성 → `map.tscn`
  - `이어하기` → 저장이 있을 때만 활성화 → 저장 재로드 → `map.tscn`
  - `종료` → `SceneTree.quit()`
- `project.godot` 시작 장면을 `res://title.tscn`으로 변경
- Stage 표시를 `TITLE PARALLAX · STAGE 4`로 갱신

### 4단계 안전성

- 기존 `ensure_world()`, `save_world()`, 전투 진입/종료 로직은 유지
- 새 함수는 타이틀 진입용 최소 래퍼로만 추가
- 이어하기는 저장 파일이 없으면 비활성화
- map / battlefield 파일 자체는 변경하지 않음
- 모든 변경은 `chatgpt/title-parallax-stepwise-20261009` 브랜치에만 존재
- `main`에는 아직 병합하지 않음

다음 5단계에서는 기능을 더 추가하지 않고 **검증만** 수행한다.
검증 대상은 타이틀 시작, 3레이어 이동, 새 원정, 이어하기, 종료, 1280×720 구도와 모바일 터치 동작이다.


## 5단계 검증 결과 — 2026-10-09

자동 검증 완료:
- Godot **4.7.2**에서 프로젝트 전체 import 성공
- `title.tscn`을 실제 시작 장면으로 headless boot 성공
- 타이틀 씬 핵심 노드 6개 존재 확인
  - Background / Board / Foreground
  - 새 원정 / 이어하기 / 종료
- 모바일 입력을 코드로 모사해 `InputEventScreenTouch`와 `InputEventScreenDrag`의 좌표 정규화 확인
- 전경 패럴랙스가 설정한 오버스캔 범위를 벗어나지 않는지 확인
- 새 원정 생성 → 저장 파일 생성 확인
- 저장값 변경 → 재저장 → `reload_world()`로 이어하기 복원 확인
- `project.godot`이 `title.tscn`을 시작 장면으로 지정했는지 확인

검증 중 발견 및 수정:
- 초기 Stage 2에 올린 경량 `background.webp`, `board_layer.webp`가 GitHub 업로드 과정에서 손상되어 Godot에서 로드 실패하는 것을 발견했다.
- 두 파일을 정상 WebP blob으로 교체했고 재검증에서 resource load / scene parse 오류가 사라졌다.
- 독립 smoke test에서 autoload 전역 심볼을 직접 참조하던 테스트 코드도 `/root/RunSession` 노드 조회 방식으로 수정했다. 게임 코드 문제는 아니고 테스트 실행 방식 문제였다.

최종 자동 검증:
- GitHub Actions `Title Stage 5 Verification`
- Run ID: `37873972836`
- 결과: **SUCCESS**
- Import / Boot / Wiring / Touch+Save Flow 전 단계 통과

### 아직 자동검증으로 확정할 수 없는 부분

- 실제 휴대폰 화면에서의 최종 시각적 품질
- 손가락으로 드래그했을 때 체감 움직임 강도
- 기기별 화면비/노치에서의 체감 여백
- 현재 연결된 경량 프리뷰 이미지의 최종 펜선 화질

따라서 기능 구조 검증은 완료됐지만, 원화는 아직 **프리뷰 해상도**다. 최종 타이틀 확정 전에 원본 고해상도 WebP로 교체하고 실제 폰에서 시각 검수한다.

### 5단계 안전선

- `main` 미병합
- map / battlefield 파일 미변경
- 기존 전투 규칙 미변경
- 검증용 GitHub Actions workflow는 결과 확인 후 제거하여 저장소에 일회성 도구를 남기지 않는다.
