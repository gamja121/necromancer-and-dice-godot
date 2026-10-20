# 5 additional layered unit card portraits — 2026-10-20

Approved raw PNG source files were supplied in chat. Their black matte was removed algorithmically (no re-drawing, no generative image editing), and transparent RGBA WebP card files were uploaded. Originals and WebP assets are backed up in the user's connected Google Drive project folder `네크로멘서 앤드 다이스/카드원화_5종_20261020`.

These are **five newly layered slugs**, not duplicate replacements. Monster names correspond to existing `data/units.json` definitions. Existing flat cards and existing 26 portraits are unchanged. New images use existing legion scenery, separate character layer, ribbon, owned brand controls, and standard deck/combat/return-to-book logic.

| slug | WebP | Git blob SHA-1 | SHA-256 |
|---|---|---|---|
| stone-golem | `assets/cards/layered/stone_golem.webp` | `fb40cea7de04f9d49afad5f11fccc481cf9f0264` | `85fed76013889eeb15a80b1cb135b65ca914cd5bfc42678a758b79ef0940c7c1` |
| raging-treant | `assets/cards/layered/raging_treant.webp` | `6297c68fea91051b2602ad2418ccb7b8bc203334` | `9246bd1a80019f47f160b66961ba15ea6c7aadd1e7a7bb050752a1e61ee585d3` |
| scorpion-knight | `assets/cards/layered/scorpion_knight.webp` | `db826014a58ba768f09e619d61b60669289fac32` | `ba882a1c35ee1ac1982ed5edbf635762ba4663db391e8fba7d4af96272965f90` |
| death-knight | `assets/cards/layered/death_knight.webp` | `476e0f266ed70c4ef349838a9bd6e04b07d7e141` | `5d21c1a5b9ba4f8e0e8580dc1c6e0c89bf4ab7708bf35d6a32681c6657e86521` |
| hell-mantis | `assets/cards/layered/hell_mantis.webp` | `e89c53383223e90c445438e0d359340e4de2e19c` | `592d34356081c04f0e1bc49dedc69545bb20b14d9598ba8804757650353313ad` |

Run `scripts/test_layered_unit_cards.gd` (31 registered cards) and visual inspection against black-fringe regressions. The long-chain story test was previously failing on main for unrelated boss/tile progression conditions and is not modified by this art-only change.
