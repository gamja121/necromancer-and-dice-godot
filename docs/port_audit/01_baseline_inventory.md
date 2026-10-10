# 완전 이식 감사 1-1 — 기준본 고정 및 전체 목록

작성일: 2026-10-10

## 비교 기준

### 웹 최종 기준본
- 저장소: `gamja121/necromancer-dice-board`
- 브랜치: `reference/html-final`
- 고정 커밋: `e13d5149fcecc802e5d626f3bef6e5daecd3d66c`
- 이 커밋을 이후 완전 이식 감사의 유일한 웹 기준으로 사용한다.
- 웹 기준본에는 신규 기능을 추가하지 않는다.

### Godot 비교 기준
- 저장소: `gamja121/necromancer-and-dice-godot`
- 브랜치: `main`
- 1-1 조사 시작 시점 커밋: `bc692a1c9d4e752e16455bb2651419917b193e1a`
- 이후 감사 문서 추가 커밋은 게임 기능 변화로 계산하지 않는다.

## 전체 파일 스냅샷

| 구분 | 웹 기준본 | Godot 기준 |
|---|---:|---:|
| 전체 blob 파일 | 1,316 | 2,131 |
| 코드/데이터 계열 | 120 (.js/.html/.css/.json) | 69 (.gd/.tscn/.tres/.json/.cfg) |
| 문서 | 23 | 42 |
| 이미지/오디오 계열 | 1,097 | 981 |
| 주요 게임 코드 후보 | 68 | 52 |

Godot의 전체 파일 수에는 Godot가 생성한 `.import` 추적 파일 981개가 포함되어 있어 단순 파일 개수 비교는 이식률로 사용하지 않는다.

## 디렉터리 개요

웹 기준본:
- `art/`: 1,078개
- 루트: 133개
- `assets/`: 72개
- `scripts/`: 29개
- `.github/`: 4개

Godot 기준:
- `assets/`: 1,967개
- `systems/`: 78개
- `docs/`: 39개
- 루트: 21개
- `scripts/`: 19개
- `data/`: 4개
- `web/`: 2개

## 고정 인벤토리

- `docs/port_audit/web_reference_inventory.tsv`
  - 웹 기준본 1,316개 파일의 path / size / blob SHA
- `docs/port_audit/godot_baseline_inventory.tsv`
  - Godot 조사 시작점 2,131개 파일의 path / size / blob SHA

이 두 인벤토리는 이후 1-2~1-6에서 누락 여부를 추적하는 원본 목록으로 사용한다.

## 이번 단계의 판정

1-1 완료.

아직 기능 이식 여부는 판정하지 않았다. 파일이 존재한다고 이식 완료로 보지 않는다.
다음 1-2에서 웹 기준본의 실제 플레이 기능만 전수 목록화하고 테스트/실험실/브라우저 전용/배포 전용 항목을 폐기 대상으로 분리한다.
