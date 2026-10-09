# Non-story UI port — 2026-10-09

Active project: C:/Dev/necromancer_and_dice. Godot 4.7.2 Compatibility.
Scope: brand reference, dice hand gestures/presentation, book presentation, pending prophecy preview, world-tree result digits. Title and story events are excluded.

## Original sources
- gamja121/necromancer-dice-board main v2-auto-battle-practice.js (8ebefe1da5dc5c1a1e30b35535bf270e8b7e1cd5): buildBrandReferenceTable, brandFaceInfo, pointer drag threshold 34 and card use flight.
- main v2-map-practice.js (5585e160243bfb268b2f055d9d8b0cfa94c28647): animateBookCards, mapEffectiveUnitStats, showWorldTreeContaminationChange.
- v2-map-practice.css: 1150 ms prayer result float; three rows of v2-world-tree-prayer-digits.js.
- v2-auto-battle-practice.css: parchment reference panel and blessing/curse cell tints.

## Runtime review
Trigger: reference button / card pointer release or keyboard pressed / book open-close / unit inspection / prayer result.
Information: living units, normalized marks, pending prophecy, card availability and ID, stable card position, UI closing/animation state.
Interaction: existing battle Rules, RunSession, inventory and exploration panels; visual modules never consume rewards or write saves.
Visual change: parchment grid, fan/deal/return motions, 140 ms use flight, predicted unit stats and source digits.
Memory: transient UI state only; save format and run rules unchanged.

## Files and behavior
- systems/brand_reference.gd: living nonsummon first four allies (reverse slots), then enemies; six face columns. Curse has priority; empty cells disabled; names/cells open detail. Button next to battle close, not over audio. Ready phase only.
- systems/drag_card_module.gd: reusable child of BaseButton; receives mouse/touch via input surface; captures one pointer; canvas-coordinate conversion; cancel on sideways drag, Escape or focus loss; stable home even during return motion. Keyboard still uses parent pressed signal.
- systems/card_fan_motion.gd: shared 320 ms + 55 ms stagger transfers, reverse order on close; disables cards until settled.
- systems/dice_control_hand.gd: up to five-card fan, click/keyboard retained, upward drag 34 canvas units; use flight before chosen signal. Existing handlers consume/save once.
- systems/inventory_panel.gd: fanned cards for up to ten; horizontally scrollable fallback for larger brand collections. Book origin is passed by map; close motion precedes modal fade. Card caption on hover/focus for crowded hands.
- systems/unit_info.gd: optional prophecy preview copied locally; HP/current HP, attack, speed and source explanation. Does not mutate roster or consume prophecy; combat views use existing two-argument setup and do not double-apply.
- systems/world_tree_prayer_effect.gd + assets/map/ui/world_tree_prayer_digits.png: original +5/+3 purification and -1 failure graphics. Status text still reports actual contamination decrease/increase. Sequential arrival, float and fade.
- battlefield.gd / map.gd / systems/exploration_actions.gd: integration only.

## Verification
Godot headless editor import and startup completed. Temporary verification script existed outside the project and used an in-memory RunSession whose save_world returned true.
Headless and actual OpenGL runs exercised ten-unit book, close while opening, long brand list, pending prophecy preview with unchanged roster, disabled repeat card, cancelled drag return, mouse drag, touch drag, click and keyboard activation once, embedded battle reference/detail, curse priority and action gating, all three prayer digit rows visible.
Final actual GPU run: NON_STORY_UI_CHECKS failures=[]; no runtime errors or exit leak warnings.
Screenshots are in the task workspace non_story_*.png. Computer Use helper crashed twice; graphical verification used engine screenshots and injected viewport events instead. This does not constitute a physical phone/device test.
No project test scripts, test buttons, commit or push added.
