# Godot 이벤트 카드 인게임 연결 체크포인트 — 2026-10-14

## 완료 및 증거
- **PR #165 squash 병합 완료**: `01c37a8ef3c4de976218bb1268c46385355d12f0` (`main` 재확인).
- `systems/event_discovery_card.gd`: 재사용 가능한 Godot 카드, 양피지 프레임 SVG, 별도 이미지 슬롯, 동적 한글 텍스트, 실제 기존 `assets/map/tiles/forest.png` 섬네일, 확인 버튼.
- `map.gd`: 원래 메인 사건 판정과 재개가 **항상 우선**. 사건 타일 **실제 착지**와 첫 순찰 완료, 1회 시각 기록 조건에서만 "언덕 발견" 팝업. 미리보기에서는 지급/표시하지 않음. 기존 위치/보스/전투/루틴 사건 규칙은 이 작업에서 변경하지 않음.
- `scripts/test_event_discovery_card_ui.gd`: 동적 UI, 실제 게임 타일 그림, 원화 폴백, 확인 시그널 검증.
- `scripts/test_event_discovery_arrival_integration.gd`: 미리보기 차단, 실제 도착, 1회 중복 방지, 저장/재시작 후 유지, 오염도 10 메인 사건 우선 순서 검증.
- `.github/workflows/event-discovery-card.yml`: 전용 GitHub Actions 성공. `Godot Web Independence Guard`, Windows Native Godot smoke 및 별도 스토리 회귀 테스트도 통과한 실행을 확인.
- **기존 무관 실패**: shared die return / fortune die / location die layer 테스트가 **현재 '숙영 타일이 첫 바퀴에 반드시 존재'한다는 오래된 주장** 때문에 실패하는 실행이 있다. 발견 카드 PR 자체의 전용 테스트는 성공. 이 문제를 이번 작업에서 임의로 수정하거나 숨기지 않음.
- 새 원화 7개는 ChatGPT 제공 ZIP **`necromancer_event_card_assets_20261014.zip`** 안에 있음. GitHub/서버 내부로 실제 바이너리 전송은 **미완료**. 사용자 PC 동기화 **미확인**. GitHub Pages 배포 최신 반영 **미확인**.

## 승인된 원화 사용 순서
1. 원화 ZIP 내부에는 다음 상대 경로로 7개 PNG가 준비됨:
   - `assets/map/ui/discovery_card_base.png`
   - `assets/map/events/discovery_hill.png`
   - `assets/map/events/discovery_rest.png`
   - `assets/map/events/discovery_graveyard.png`
   - `assets/map/events/discovery_world_tree.png`
   - `assets/map/events/discovery_altar.png`
   - `assets/map/events/routine_wounded_soldier.png`
2. 사용자 PC의 **현재 Godot 저장소 루트**에서 안전 설치:
   ```powershell
   py tools/install_event_card_art.py "$env:USERPROFILE\Downloads\necromancer_event_card_assets_20261014.zip"
   ```
   이미 다른 원화가 있는 경로는 덮어쓰지 않으며, ZIP 파일명을 변경했으면 인자 경로를 조정한다.
3. Godot 리소스 import 후 실제 카드 화면에서 승인한 빈 양피지 원화와 언덕 일러스트, 게임 기존 타일 그림이 표시되는지 검토. 모든 원본 이미지를 ZIP/원화 보관 폴더에도 보관한다.
4. 그림의 스케일, 여백, 영문/한글 레이아웃, 버튼 가독성 등을 확인하고 **PNG 파일만 별도 검토 후** GitHub에 커밋/푸시한다. 원화 전송을 하지 않은 현재 브랜치에 PNG가 이미 있다고 말하지 않는다.
5. `main`과 PC의 SHA 및 배포 사이트 빌드 결과를 각각 확인한다.

## 향후 필수 구현 (이번 UI 작업과 구분)
- 현재 구현은 **언덕 발견 카드의 시각적 1회 표시**일 뿐 **언덕 타일을 실제로 잠금 해제·집에서 편성하는 게임플레이는 아니다**. 처음부터 `forest` 1개가 있는 옛 `MapState`와도 현재 충돌하므로 사용자 확정 장소 조건과 레거시 저장 호환을 통합해야 한다.
- 장소별 조건은 `docs/location_unlock_conditions.md`, 사건/루틴 우선순위와 카드 수급은 `docs/event_tile_unlock_design.md`/`docs/routine_event_design.md`을 보존.
- 보스는 **오염도 20/40/60 단계별 보스 + 최종 보스** 사용자 설계. 이번 이벤트 카드 PR은 해당 룰을 변경하지 않았음.
- 메인 사건 우선→조건부 발견 또는 루틴→집/보드 배치 여부 확정→보유 카드 5장/교체 및 저장 중복 방지 테스트 순서로 다음 작업.

## 기능 5원칙
- **Trigger**: 실제 사건 타일 도착·메인 사건 모두 우선·첫 순찰 조건.
- **Information**: 스토리 이벤트/월드 위치/원정 한바퀴 상태/1회 이벤트 기록.
- **Interaction**: `Map.show_tile` → `RunSession.set_event_flag` → `EventDiscoveryCard` → 확인.
- **Visual**: 재사용 가능한 양피지 카드(현재 SVG 폴백), 중앙 이미지(현재 기존 `forest.jpg` 폴백), 하단 실제 `forest.png` 타일; 승인 PNG 설치 시 교체.
- **Memory**: `event:discovery:forest:card_shown` 1회 시각 기록; **실제 해금/배치는 후속 작업**.
