# Card art: 13 original WebP files NOT YET uploaded (2026-10-20)

**BLOCKER — DO NOT MERGE THIS BRANCH WITHOUT THE ACTUAL 13 WEBP FILES.** Code-only mappings are staged here so the main game stays functional while binary uploads are pending. These are not placeholders.

- Six current layered portraits need content replacement, seven new portraits need files added.
- Put approved images at the exact path shown; verify SHA-256 before merging.
- Never overwrite flattened `assets/cards/unit-card-*.png`, cards frame, combat rules, original sprites/animations.
- After all 13 WebP uploads, run Godot headless editor import and `scripts/test_layered_unit_cards.gd`, then visual regression check for black backgrounds and clipping. Only then merge.

| Monster | Portrait path | SHA-256 of approved file |
|---|---|---|
| flesh-golem | `assets/cards/layered/flesh_golem.webp` | `b33c91962b54a0b888851f46bf6d455aa637956f16197ff9e8e2616a2c64061f` |
| forest-fairy | `assets/cards/layered/forest_fairy.webp` | `f54fde8b0cdb815f23da259e454524e1d9a1d48612ab4fdce8c2485cd241b702` |
| abyss-harpy | `assets/cards/layered/abyss_harpy.webp` | `ae063049892b01efd819fb4e94e490c748415abe1c843402605737be8934427a` |
| bone-golem | `assets/cards/layered/bone_golem.webp` | `829626aa35696a095547e1278f6d93317062a4ac8a296595dbede43e309f8d40` |
| boulder-ogre | `assets/cards/layered/boulder_ogre.webp` | `018b58538a9b9c589a9d3c40e39267fed1e1628fe3a6dfce4a29b46d5a118d0e` |
| orc-warrior | `assets/cards/layered/orc_warrior.webp` | `de7a05fa74e542d316065eff40155189aa04aaf99c81de9b7e812cdd287d272b` |
| goblin-rider | `assets/cards/layered/goblin_rider.webp` | `a9f8a10c613836f2c732c33fac242ad0e4054efc8834126c60722dbb481a6362` |
| mushroom-soldier | `assets/cards/layered/mushroom_soldier.webp` | `8c23b0ee624845dd697bbd1b1dd1eeb12fba4e51f4f5b5c4c8930afce0169eae` |
| cerberus | `assets/cards/layered/cerberus.webp` | `be6117576f9bf9ad89e95bc7b144dcae62c978df41f186014d0c96b2de585f01` |
| ancient-treant | `assets/cards/layered/ancient_treant.webp` | `0f4445beebe635c3aeafc3b00c0e9d19dde4bebc067382acd091ff7600567ba7` |
| spider-knight | `assets/cards/layered/spider_knight.webp` | `795ae42fa492e8f04e4779a06c52e71062effca4c7b0a99d83b6df16eef6f5e5` |
| crystal-devourer | `assets/cards/layered/crystal_devourer.webp` | `db6392636a6ae0978ca078ddf0e958f341bff2a2ca8b6d2e7255276b2adc49af` |
| kraken | `assets/cards/layered/kraken.webp` | `3550aa558a20827a87aec4388f598259e270c962d23fbe89b63fee762a852c6e` |
