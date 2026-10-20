# Layered monster card art — 2026-10-20

All ten new monster portraits were provided by the user, and only the **card rendering** changed. The battle-unit models, gameplay rules, save IDs and legacy single-image cards remain untouched.

## Rendering contract

The existing `systems/layered_unit_card.gd` handles these **twelve** slugs using the same independent Godot nodes:

1. `LayeredCardBase`: parchment paper/frame + approved legion background (fully within card bounds).
2. `LayeredCardCharacter`: alpha-cutout portrait; may protrude above/laterally beyond the frame. Only this layer is magnified on selection/hover.
3. `LayeredCardRibbon` + `LayeredCardTitle`: common scroll/name, unaffected by character magnification.
4. `LayeredCardBrands`: real owned brand atlas icons, up to 3 left-aligned in bottom information panel.
5. Existing brand/frame decorations remain. `flight_visual_copy` duplicates **all** visual layers for the return-to-book and reward-to-book animation; no legacy flattened image flashes.

The original `TextureButton.texture_normal` is retained for compatibility but visually hidden by `self_modulate.a=0`; card sizing, clicks and existing data remain intact.

## New sources (user-supplied PNG -> runtime WebP)

| Unit slug | Portrait from conversation | Legion backdrop from conversation |
|---|---|---|
| corpse-slime | 1000015763.png | 1000015750.png (corpse) |
| dracula | 1000015764.png | 1000015742.png (demon) |
| ice-lord | 1000015765.png | 1000015749.png (ice) |
| grave-worm | 1000015766.png | 1000015746.png (plague/insect) |
| skeleton-cavalry | 1000015767.png | 1000015748.png (skeleton) |
| mummy-guardian | 1000015768.png | 1000015750.png (corpse) |
| soul-reaper | 1000015769.png | 1000015748.png (skeleton) |
| bone-hound | 1000015770.png | 1000015750.png (corpse) |
| mimic | 1000015771.png | 1000015744.png (summon/arcane) |
| ice-princess | 1000015772.png | 1000015749.png (ice) |

The two earlier skeleton cards (`skeleton-spear`, `skeleton-archer`) continue using their original scene and art. The new approved unit portraits are stored under `res://assets/cards/layered/`. Character PNG originals remain in the conversation/user's files and were **not** overwritten in GitHub. WebP optimizes approximately 4.2 MB of runtime assets in total while maintaining alpha and useful high resolution.

The `skeleton-cavalry` and `ice-princess` uploaded PNGs were RGB with **solid black backdrops**. Their outer connected black matte was removed before compression, preserving internal dark ink; visually verify small-card halos as part of manual QA.

## Acceptance

- `godot --headless --path . --editor --quit` imports assets.
- `scripts/test_layered_unit_cards.gd` checks all 12 monster cards and four display sizes, approved backdrop slugs, transparent outer pixel corners, selected/hover scaling, three left-aligned owned brands and complete copied book-flight layers.
- Other monsters use unchanged single-texture cards.
- `scripts/test_battle_entry_summon.gd`, `scripts/test_p4_all_monster_presentation.gd`, and `scripts/test_p4_combat_map_return_integration.gd` protect battle and book transfers.
- Final layout should be visually inspected in the real game at small card scale; headless tests alone do not certify the aesthetics.
