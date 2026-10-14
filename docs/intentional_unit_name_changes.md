# Approved unit display names

On 2026-10-14 the user selected **아자젤 (Azazel)** for the next demon artwork.

| Stable species ID | Previous name | Current name |
|---|---|---|
| doom-executor | 흑각 악마 | 아자젤 |

Only the display name changes. Species ID, art paths, combat stats and random pools remain unchanged.
Map and battle restoration update the name in copied owned units, corpses, rewards and encounter checkpoints. Original save input, identity, stats, brands and RNG state are preserved.
The frozen web fixture remains historical reference; its parity test permits only this explicit name exception.

Verified: headless editor import, runtime smoke, and existing catalog/save regression (670 passed, 0 failed).
The broader story-resume regression has an existing setup mismatch: it searches for a graveyard on lap zero, although the current map unlocks graveyards at lap one. Its first discovery fails before the renamed unit is involved. This change does not alter that test or map rule.
