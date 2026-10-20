# Eight approved card art originals — 2026-10-20
Original user PNGs 5818–5825 are preserved in Google Drive `네크로멘서 앤드 다이스/카드원화_8종_20261020`. No image synthesis or repainting was used: remove black matte programmatically, create transparent lossless WebP. Original in-game animated sprites and flattened legacy hit textures are not altered.

CORRECTED after the user identified the 1000015819.png character: the image is **grave-priest (해골 소환사)**, NOT soul-reaper (리치). All eight PNGs are new layered cards: **32→40 registered cards**. The original lich `soul_reaper.webp` is restored exactly from commit `b4619c0d73f7458274f4df273c39b8d3055726b1` (blob `b8db4bfdbb4dff7a274696fa42e55666e6f24376`). Original supplied image in Drive is the same PNG; the approved cutout is reused as `grave_priest.webp`.

| Source PNG | Unit slug | WebP asset | Git blob SHA-1 | SHA-256 |
|---|---|---|---|---|
| 1000015818.png | abyss-eye | `assets/cards/layered/abyss_eye.webp` | `65e402b7342788ca3e5685698b0fbb6fead78215` | `f4b286dad4e8f49d7f842968c70bbc31ef822b21a561407cc1949b3a58988661` |
| 1000015819.png | grave-priest (해골 소환사) | `assets/cards/layered/grave_priest.webp` | `03a73bc54395b23edc6b67122a45d2c0c245c47a` | `c508c4ec6b4c90c878a09414601a984f23edf3af488967c03930c90841d8a762` |
| 1000015820.png | sea-wolf | `assets/cards/layered/sea_wolf.webp` | `0a90083c0a2cb7fa972382cb5177c66bd3446835` | `44ff9815c931896eb10112e60456281950902c6de41d6f96bd20885f1427aef8` |
| 1000015821.png | goblin-soldier | `assets/cards/layered/goblin_soldier.webp` | `e7cd3be81049f769da719f8da2d75085a279fa23` | `7bb95003702804eb01b0e3b8a863c50ae8f99cfbb9f4056000f0b601ee037c37` |
| 1000015822.png | goblin-chief | `assets/cards/layered/goblin_chief.webp` | `f6668c82a143a2f9cb979245efeef2e0fddc10d5` | `df806eef476026e92814dd5904d99c8cf5815a80720bfa90fc109794e47a52eb` |
| 1000015823.png | ghoul | `assets/cards/layered/ghoul.webp` | `cffa944309d855c0b9715d322a705d43ebdacd13` | `fb097fe8e21e4170d97af7e3df6251739aee0ee77fe0f66ca80e531909c67413` |
| 1000015824.png | plague-doctor | `assets/cards/layered/plague_doctor.webp` | `9dab561fc6ef869943bcfdf86f718a1e22c6ec77` | `20d8e531d12b2f3cb7d34fb0389f98f98c6195e1956136b5f8ec0bbdfbe9091f` |
| 1000015825.png | yeti | `assets/cards/layered/yeti.webp` | `60a7af85e0752ea9405f657dcff829ee90742897` | `c49db44b7b2b823e1c4d52ab145b22f1e3b872c0174df1f9e92ef4200db14485` |

Run `scripts/test_layered_unit_cards.gd` (including soul-harvest choices and book animation), Godot parse/import, card handoff/combat regression and visual smoke test. Previously failing unrelated story chain is kept out of this art change.

## Post-merge correction
The original eight-card PR #211 briefly and incorrectly overwrote the lich with the user's necromancer artwork. This follow-up restores the original lich image and maps the user image to `grave-priest`. Neither artwork nor any other game resources are modified.
