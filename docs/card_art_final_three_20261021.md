# Last 3 approved card originals — 2026-10-21

Exactly the three user-uploaded original illustrations were used; there was no image repainting/synthesis. Only the exterior black matte of the RGB claw-hunter PNG was removed programmatically. The other two PNGs already contained transparency. Lossless WebP keeps the original color/detail and alpha.

| Original PNG | Monster slug | Runtime asset | Existing background | Runtime SHA-256 |
| --- | --- | --- | --- | --- |
| 1000015834.png | abyss-claw-hunter | `assets/cards/layered/abyss_claw_hunter.webp` | base_demon.webp | c48ce5eeabd8c9f809657d1d12a385bb2f0fdd8868d4c220e8c96e4f24748e2e |
| 1000015833.png | plague-frog | `assets/cards/layered/plague_frog.webp` | base_plague.webp | 17c7a799b9084dcc64d4fd939d362f0367b56fd6c921e7dc349dc47c1efe4c89 |
| 1000015741.png | siren | `assets/cards/layered/siren.webp` | base_ice.webp | f211b05dabcf73819481de017a5157d87e887607e9233723ed0fdcdf088e2030 |

- Original PNGs and approved WebP binaries are backed up in the private Google Drive project folder `네크로멘서 앤드 다이스/카드원화_3종_20261021`.
- All 47 registered monsters use the existing `LayeredUnitCard`: independent portrait, in-frame legion backdrop, ribbon, title, up to three owned brands and portrait-only hover/selection zoom. Post-victory soul-capture choices and book-flight visuals retain the same portrait.
- No edits to previously approved portraits (including soul-reaper / grave-priest), flattened unit-card PNGs, animations, rules, die odds, save IDs, inventory or combat logic.
- Run `scripts/test_layered_unit_cards.gd`, `scripts/test_battle_entry_summon.gd`, `scripts/test_p4_all_monster_presentation.gd`, `scripts/test_p4_combat_map_return_integration.gd` and Godot headless import. Actual PC/mobile aesthetic sign-off is distinct from CI.
- Work item: https://github.com/gamja121/necromancer-and-dice-godot/issues/217
