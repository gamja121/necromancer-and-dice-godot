# Battlefield presentation port — 2026-10-08

Compared the current GitHub main of gamja121/necromancer-dice-board:
- v2-auto-battle-practice.css, blob 1337ebc6bfa61e34949568ece257be264b51bbae
- v2-auto-battle-practice.js, blob 89874e690bb10b93de090821bd076b730817f6e7
- v2-unit-size.js, blob ad5f8878174c1a165a8cf7e48b34f9098673ae9e
- v2-unit-cards.js, v2-combat-effects.js, v2-presentation-rail.js.

Ported slot columns, per-slot depth scale/Y/z-order, species ratios, alpha>=128 foot calibration, enemy mirroring, idle breathing keyframes, thin orange gradient HP bars, centered dice, bottom card rest/tuck heights, battlefield shade and compact dark/gold controls. Attack focus advances the attacker by 36% of the source wrapper width, dims other units, and brings actor/target forward. Actual available attack/hit/death frame indices replace the fixed ten-frame playback. Impact happens in the middle of the attack; confirmed combo hits and counters replay separately, with simultaneous target hit frames. Source hit sheets, labels, healing crosses and digits remain AtlasTexture-based. Damage digits now pop/float with source keyframe values. Global presentation rail and per-unit blessing/curse chips replace the large custom arrow/brand circles.

New systems/battle_presentation_layout.gd and data/battle_visual_metrics.json contain presentation geometry and 45 available units' image bounds/frame indices. Bounds are calculated offline; no texture readback during combat entry or rendering. Regenerate metrics after replacing source frames. Effect caches/threaded prewarm remain intact.

Adaptation: the original web battlefield is 16:9; the game retains the user's map-embedded 980x406 area and frame, with logical 1280x530 layout. Web reference screenshots used the latest CSS/size/cards scripts with that wide logical size and current Godot PNGs. This is a visual reference harness, not an execution of the whole web game. Geometry follows source formulas, while wide framing, platform font/shader filtering, existing special permanent-death presentation and status overlays can still differ. Exact pixel identity is not claimed. Region backgrounds, gameplay rules, checkpoint timing, save schema and events were not changed.

Verification: actual OpenGL renders of the wide 4v4 layout, cinematic focus and map-embedded battle; full 4v4 round (9 actions in final run), rule snapshots unchanged by presentation, pause clock, card return, detail-window opening, and actual map dice/combat round. One warmed map battle first draw was 39.652ms; capped-60fps idle p95 was 16.74ms on GTX1660Ti. This is a small smoke sample, not a full performance guarantee. Godot import/runtime and git diff --check passed. Temporary review scripts stayed outside the project and were removed. User save bytes restored in finally. No project tests/debug UI were added.
