# Four approved monster card original illustrations — 2026-10-20

The four user-supplied PNGs are connected to the existing unit IDs, without repainting or AI image generation. All originals and their transparent lossless WebP versions were saved to the user's Google Drive folder `네크로멘서 앤드 다이스/카드원화_4종_20261020`.

| Original | In-game ID | Artwork | Existing Legion Backdrop | SHA-256 |
|---|---|---|---|---|
| 1000015828.png | minotaur | `assets/cards/layered/minotaur.webp` | base_beast.webp | `af89212ccda9daf4163b3da096d0171dda14cd0b1f959fee06408bf2226225ba` |
| 1000015829.png | goblin-commoner | `assets/cards/layered/goblin_commoner.webp` | base_beast.webp | `3d4eb41679cc652b6153325553d5a5fb00045c73013b9e5eecf6aec5c278da09` |
| 1000015830.png | spiderling | `assets/cards/layered/spiderling.webp` | base_summon.webp | `8d88fe17ebe36700b62b7ea85fac32086554d27221a525a3caff19083e554b13` |
| 1000015831.png | guardian-seed | `assets/cards/layered/guardian_seed.webp` | base_plant.webp | `399515ae8849b3c497def2d43f0ca73fb366c7a6c0e158a8892a1f80bcfb0f6c` |

- No legacy flat card files, game logic, odds, unit data, animation sheets or existing 40 approved card portraits were modified.
- Minotaur/Guardian seed: black RGB background removed to alpha without redrawing. Goblin commoner/spiderling: existing PNG transparency preserved.
- Card regression now covers 44 registered layered units, including live soul-harvest choices, reward flight, brands and book return.
- Earlier lich correction is already merged in main: `soul_reaper.webp` restored, user's spellcaster portrait in `grave_priest.webp`.
- Post-merge remaining card IDs: plague-frog, abyss-claw-hunter, siren. Real PC visual QA is still needed.
