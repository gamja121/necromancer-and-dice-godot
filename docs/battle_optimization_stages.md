# 전투 최적화 단계별 검증 — 2026-10-21

작업: [Issue #216](https://github.com/gamja121/necromancer-and-dice-godot/issues/216).
기준 소스: `31566c5b6e279fa5ac97041315c8d519e0ddf9ee`.
전투 규칙·난수·세이브 형식·원본 그림을 보존하며 표시와 로딩만 최적화한다.

## 적용 범위

| 단계 | 적용한 변경 | 검증 핵심 |
| --- | --- | --- |
| 1 | 로딩 중인 요청만 순회하고 완료 시 process 중단, 새 요청에서 재개 | 실제 이미지/오디오 로딩, 중복 요청, 유휴 콜백 0, 실패/무효 요청 |
| 2 | 평상시 바닥 그리기 명령 재사용 | 소환진은 기존 그림자와의 그리기 순서를 유지하며 계속 갱신; 종료·사망·배치·성장 시 무효화 |
| 3 | 현재 전투원 중심의 제한적 비동기 프레임 준비 | 전투별 추가 프레임 RGBA 추정 32MiB 한도, 프레임당 결과 1개, 중단 시 요청 회수 |
| 4 | 직접 관리하는 일회성 TextureRect 효과 재사용 | 전투당 유휴 64개 한도, 위치·크기·색·알파·재질·좌우반전·깊이 초기화, 새 효과와 같은 형제 순서 |
| 5 | 빈 상태/입자 및 안내 레이어의 재그리기 생략 | 활성 효과는 계속 갱신하고 마지막 제거 프레임은 한 번 그린다 |

32MiB는 **이 사전 준비가 추가로 보존하는 프레임의 픽셀 크기 추정 예산**이다. 게임 전체 RAM/VRAM 한도가 아니다.
모든 마물/모든 동작을 일괄 로딩하지 않는다. 준비 범위 밖의 프레임은 기존 texture 캐시와 로딩 경로를 사용한다.
준비 노드는 전투 레이어와 함께 해제된다. 로딩 도중 장면이 사라지면 정적 콜백이 완료된 요청을 이후 프레임에서 회수한다.
진행 중 요청을 기다리는 처리는 앱 자체가 종료될 때의 마지막 정리에서만 허용된다.

이펙트 풀은 타이머/트윈 없이 `art_items`가 수명을 관리하는 직접 스프라이트만 반납한다.
숫자 컨테이너와 그 자식 글리프, 실제 마물 스프라이트, 영구사망 전용 노드와 오디오는 기존 수명을 유지한다.
유휴 노드는 texture/material 참조를 비우고 전투 장면의 자식으로만 남는다. 치유 십자가 이미지는 기존의 한정된 공용 캐시에 추가한다(70×72, RGBA 환산 약 20KiB).

## 의도적으로 보류한 부분

전체 마물을 변경 플래그만으로 부분 갱신하는 재작성은 보류했다.
`render_units`는 매 프레임 호출되지 않으며, 실제 4대4 장면의 CPU 반복 호출 측정은 약 0.5–0.6ms였다.
당장은 불변 전후 스냅샷과 깊은 복사를 보존하는 편이 씨앗 성장·피격·영구사망 순서에 안전하다.
마물의 배치·체력·상태 정보를 광범위하게 캐싱하지 않고, 빈 표시 레이어만 갱신하지 않도록 범위를 좁혔다.

## PC에서 확인한 결과

환경: Windows 네이티브 Godot 4.7.2 Standard, Compatibility/ANGLE D3D11, GTX 1660 Ti.
그래픽 진단은 최대 120fps, 실제 4대4 생산 장면을 사용했다. headless 결과와 그래픽 캡처를 구분한다.

| 항목 | 변경 전 | 변경 후 |
| --- | --- | --- |
| 바닥 사용자 그리기 호출 / 정지 24프레임 | 23회 | 0회 |
| 빈 상태·입자 사용자 그리기 호출 / 24프레임 | 24회 | 0회 |
| 빈 안내 사용자 그리기 호출 / 24프레임 | 24회 | 0회 |
| 동일 편성의 준비 프레임 | 아군 attack-01 위주 | 추가 15개, 추정/실제 RGBA 모두 33,128,448 bytes, 32MiB 미만 |
| 회복 보고 8회 생성 CPU, 한 실행의 반복 3회 | 6.718 / 5.280 / 23.744ms | 2.031 / 3.155 / 1.979ms |

이는 해당 진단 호출 비용과 그리기 콜백 수다. 게임 전체 FPS/프레임 시간 개선율이 아니다.
실행 간 게임 난수는 고정하지 않았고 표본도 작으므로, 위 숫자를 일반적인 속도 향상 비율로 해석하지 않는다.
최초 효과 사용 비용은 약 25ms 내외로 남았다. 본 변경으로 모든 최초 로딩 지연이 사라졌다고 주장하지 않는다.
실제 그래픽 화면에서 그림자, 소환진, 제거 후 바닥, 사망 상태, 회복 숫자와 십자가를 확인했다.
휴대폰 실기기/장시간 플레이/웹 메모리 상한은 별도 측정 대상이다.

## 회귀검사와 실행

| 검사 | PC 결과 |
| --- | --- |
| `test_battle_resource_lifecycle.gd` | 13 passed, 0 failed |
| `test_battle_prewarm.gd` | 24 passed, 0 failed |
| `test_battle_effect_pool.gd` | 16 passed, 0 failed |
| `test_battle_visual_updates.gd` | 17 passed, 0 failed |
| 그래픽 `profile_battle_optimization.gd` (6개 캡처 포함) | 25 passed, 0 failed |
| `test_battle_animation_release.gd` | 48 passed, 0 failed |
| `test_battle_fate_impact.gd` | 20 passed, 0 failed |
| `test_battle_entry_summon.gd` | 87 passed, 0 failed |
| `test_battle_formation_order.gd` | 73 passed, 0 failed |
| `test_p4_all_monster_presentation.gd` | 912 passed, 0 failed |
| `test_p4_combat_map_return_integration.gd` | 160 passed, 0 failed |

최종 단계 소스로 전체 마물 표시 912개와 전투 후 지도 복귀 160개를 다시 확인했고 런타임 오류와 종료 누수 경고가 없었다. 지도 복귀 검사에서 보상 완료 후 이미 해제된 전투 노드를 캡처하던 테스트 콜백은 살아 있는 지도로부터 현재 전투를 조회하도록 수정했다. CI/PR 통합/PC 동일 SHA 확인은 별도 완료 조건이다.

편성 검사에는 기준 소스와 이미 어긋난 옛 적군 열/깊이 기대값이 있었다.
배치 스크립트와 검사 파일이 기준 커밋과 동일한 Git blob임을 먼저 대조한 후,
게임 배치를 수정하지 않고 현재 기준의 반대 방향 슬롯과 앞→뒤 깊이를 검사하도록 교정했다.
검사 끝에는 실제 소환 및 안내 코루틴이 끝난 뒤 장면을 해제해 테스트 종료 경고를 없앴다.

```powershell
godot --headless --path . --editor --quit
godot --headless --path . --script res://scripts/test_battle_resource_lifecycle.gd
godot --headless --path . --script res://scripts/test_battle_prewarm.gd
godot --headless --path . --script res://scripts/test_battle_effect_pool.gd
godot --headless --path . --script res://scripts/test_battle_visual_updates.gd
godot --path . --script res://scripts/profile_battle_optimization.gd -- --capture-dir <existing-output-directory>
```

자동 검사도 요약의 0 failed 외에 SCRIPT ERROR/Parse Error/ERROR/ObjectDB 누수 메시지를 실패로 취급한다.
회귀 워크플로: `.github/workflows/battle_optimization.yml`.
