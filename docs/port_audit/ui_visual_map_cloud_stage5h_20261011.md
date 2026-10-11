# 5단계 H — 네 종류 원본 맵 구름 전환 이미지 복원 (2026-10-11)

## 원본 및 실제 결함
- 기준 웹 저장소: `gamja121/necromancer-dice-board/reference/html-final@e13d5149fcecc802e5d626f3bef6e5daecd3d66c`.
- 원본 4종: `art/v2-style/ui/map-cloud-transition.png`, `map-cloud-transition-2.png`, `map-cloud-transition-3.png`, `map-cloud-transition-4.png`.
- 이식 전 `systems/map_presentation.gd`의 `setup()`은 네 변수 모두 `assets/map/ui/map_cloud_transition.png`에 연결했다. 그러나 해당 기존 파일은 실제 웹 `map-cloud-transition-3.png`와 SHA가 같아 모든 구름이 3번 그림으로만 나타났다.

| Godot 런타임 파일 | 웹 원본 blob SHA |
| --- | --- |
| `assets/map/ui/map_cloud_transition.png` | `e7cad1e6394197a27d17f933f8010e3369aeb71d` |
| `assets/map/ui/map_cloud_transition_2.png` | `503e4f2b647b51e46834a303e0484082aee459d3` |
| `assets/map/ui/map_cloud_transition_3.png` | `d10dcadffda9a4758314b54fc830011c1b9348d3` |
| `assets/map/ui/map_cloud_transition_4.png` | `d2f8ba62c1e48306e5a2d37d6e18fe0a7f311518` |

각 PNG는 원본 base64에서 별도 Git blob으로 저장하여 SHA 동일성을 확인했다. GitHub에 PNG 이름만 변경해서 저장하며 원본 저장소는 수정하지 않는다.

## 수정 범위
- `systems/map_presentation.gd`: `setup()`에서 1~4번 서로 다른 이미지 로드, `cloud_refresh()`의 기존 8개 스프라이트 순서/속도/좌우 반전과 원본 콜백/잠금/페이드/보상 저장 호출은 그대로 유지.
- 추가 `scripts/test_ui_map_cloud_parity.gd`: 각 원본 이미지 Godot 디코딩, 네 가지 서로 다른 RID, 기존 늪 효과 유지, 전환 8개 중 종류당 2개, 사용자 입력 잠금과 해제, 보드 교체 콜백 정확히 1회, 임시 오버레이 제거.
- 기존 저장·보상·다음 바퀴/전투 후 귀환 검사를 그대로 재실행.

## 5가지 기본 원칙
1. **Trigger:** 집 다음 바퀴 등 이미 존재하던 실제 `cloud_refresh()` 호출. 신규 트리거 없음.
2. **Information:** 원본 4개 텍스처의 파일명/순서, 타일 변경 콜백, 사용자 입력 잠금 상태.
3. **Interaction:** 기존 보드 셔플 콜백과 사용자 입력 버튼만 관련, 새로운 액션 생성 없음.
4. **Visual:** 서로 다른 네 구름 실루엣을 2개씩 8개 표시, 진행 중 입력 차단, 완료 후 제거.
5. **Persistence:** 기존 타일 변경 콜백을 정확히 1회 호출하며 월드 JSON/보상·오염도·RNG 저장 형식은 변경하지 않음.

## 검증 범위 / 제한
- Godot 4.7.2 headless import 및 새 전용 UI 검증, P4 보상→집→셔플→다음 바퀴, 실제 단일 원정, 5단계 G 편성/초과 UI 회귀.
- Windows PC와 Android의 화면에서 구름 방향/겹침/속도 및 레이아웃 **시각 승인 미완료**. Headless 이미지 디코딩과 노드 생성 검사는 실기 승인 대체가 아님.
- 다른 작업자의 메인/사건/전투 중단 저장 작업을 보존하고 `main` 병합·웹 배포 및 PC 동기화는 별도 처리.
