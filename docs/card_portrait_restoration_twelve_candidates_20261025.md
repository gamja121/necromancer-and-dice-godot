# 12 priority monster card ink-alpha candidate repairs — 2026-10-25

## Delivery
Read-only source inspection of all 48 production portraits was completed earlier. Twelve highest-priority portraits now have **non-destructive restoration candidates** and before/after verification on both parchment and dark backgrounds. Game production `main` is not changed.

### Actual candidate repair measures
| Monster | slug | enclosed gaps accepted | pixels restored | image % |
|---|---|---:|---:|---:|
| 지옥 사마귀 | `hell_mantis` | 120 | 11,402 | 0.6444% |
| 해골 기사 | `skeleton_cavalry` | 38 | 2,930 | 0.1552% |
| 데스 나이트 | `death_knight` | 93 | 10,938 | 0.6182% |
| 해골 소환사 | `grave_priest` | 58 | 4,116 | 0.2326% |
| 역병술사 | `plague_doctor` | 74 | 10,439 | 0.5530% |
| 고블린 족장 | `goblin_chief` | 83 | 6,010 | 0.3184% |
| 전갈 기사 | `scorpion_knight` | 106 | 16,083 | 0.8520% |
| 살점 골렘 | `flesh_golem` | 244 | 8,018 | 0.4247% |
| 숲의 장로 | `ancient_treant` | 100 | 12,811 | 0.6786% |
| 거미 여왕 | `spider_knight` | 166 | 12,719 | 0.6738% |
| 암석 골렘 | `stone_golem` | 126 | 18,057 | 0.9565% |
| 고블린 라이더 | `goblin_rider` | 154 | 3,646 | 0.1931% |

### Candidate generation guardrails
- Use the existing WebP image's RGBA. Retain *every unchanged pixel* and all original filenames as rollback copies.
- Only enclosed 8-connected alpha gaps, component areas 8–2500 px, surrounded by at least 62% dark opaque ink. Open body silhouettes and broad exterior gaps are excluded.
- Repaired pixels mix original hidden RGB and the closest opaque ink sample, restoring alpha only within selected gaps.
- Keep per-card exact changed-pixel masks and before/after comparisons in bright and dark compositions.
- **These are unapproved candidates, not restored master originals.** Some filled holes may have been intentional. Larger missing artwork remains unaddressed without the pre-key `raw_assets` source.

### Safety
- No production binary file changed.
- Source and candidate stored separately in local downloadable review ZIP.
- Do not merge this QA branch into `main` or replace `assets/cards/layered/*.webp` until supervised side-by-side inspection and a capture from the actual game at final card size.
- The source `raw_assets` / `source_assets` directories documented in project notes are not reachable from GitHub; recovering them is required for fully faithful restoration.

**State:** 48 portraits audited; 12 conservative revision candidates built and visually compared; 0 production masters replaced.
