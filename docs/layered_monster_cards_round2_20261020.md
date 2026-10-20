# Second wave: seven additional live Godot layered monster cards (2026-10-20)

This is **not a flattened concept-art mockup**. User-provided character PNGs are separate transparent WebP resources used as `LayeredCardCharacter` nodes by the existing `systems/layered_unit_card.gd`. Other live layers: fixed parchment scenery, name ribbon/text, and real owned brand icon row. A monster portrait alone can zoom on selection or extend beyond the frame; other layers remain fixed. End-of-battle and reward-to-book flight duplicate the whole composited card (including current owned brands) rather than the obsolete single-image card.

| Monster ID from `data/units.json` | In-game name | User PNG | Portrait res://assets/cards/layered/ | Legion card background |
|---|---|---|---|---|
| `hydra` | 히드라 | 1000015773.png | hydra.webp | base_plague.webp (plague) |
| `flesh-golem` | 살점 골렘 | 1000015774.png | flesh_golem.webp | base_corpse.webp (corpse) |
| `forest-fairy` | 픽시 | 1000015784.png | forest_fairy.webp | **base_plant.webp** (plant, source 1000015745.png) |
| `bone-golem` | 뼈 골렘 | 1000015789.png | bone_golem.webp | base_skeleton_mist.webp (skeleton) |
| `abyss-harpy` | 심연 하피 | 1000015790.png | abyss_harpy.webp | base_demon.webp (demon) |
| `boulder-ogre` | 오우거 | 1000015791.png | boulder_ogre.webp | **base_beast.webp** (beast, source 1000015747.png) |
| `orc-warrior` | 오크 전사 | 1000015792.png | orc_warrior.webp | **base_beast.webp** (beast) |

Previously approved 12 layered cards remain unchanged, totaling **19 layered monster IDs** after this round. The remaining monsters use their previous art automatically.

## Processing and safety
The five RGB portrait PNGs with pure black matte (hydra, flesh-golem, abyss-harpy, boulder-ogre, orc-warrior) were flood-masked ONLY at their connected outer black backgrounds, preserving most dark interior ink. The forest fairy and bone golem originals already had alpha and were not rematted. All portrait alpha outside corners were checked transparent after conversion. Runtime WebP maintains original character raster dimensions and frame compatibility. The user-supplied PNG source images were not modified or overwritten in GitHub.

## Validation
The existing Godot GitHub Actions layered-card workflow checks imported textures, runtime rendering for all 19 IDs at four sizes, source backgrounds, alpha corners, legacy card texture compatibility, left-aligned owned brands, selection-only portrait zoom, book-animation layer copies, deck-to-battle, existing all-monster references and combat return-to-book. A visual pass on desktop is still recommended for character placement and dark edge halos, not claimed by headless tests.

No changes to gameplay, skill values, dice control, unit roster, ownership, save format, animations or portrait shader logic.
