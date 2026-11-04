# Book battle lock — 2026-10-09

- Supplied 1000015103.png copied byte-for-byte to assets/map/ui/book_battle_lock_sheet.png; original preserved in D:/Workspace/Games/necromancer-and-dice/raw_assets/map/.
- Four irregularly spaced images are displayed through AtlasTexture regions, with a uniform 540 x 576 canvas. No regenerated artwork, background removal, or resized source file.
- systems/book_battle_lock.gd attaches under the existing map TextureButton. Button position (13,550), size (133,133), pressed callback and button effects remain unchanged.
- Battle entry immediately disables the book, then displays 0 -> 1 -> 2 -> 3 at 100 ms intervals and holds the chained frame. Total 350 ms.
- Battle return hides the battlefield while 3 -> 2 -> 1 -> 0 plays, restores the existing closed-book image, then rebuilds the map.
- Loaded active battles/capture rewards show frame 3 immediately; no new save field is needed.
- Existing map buttons are still disabled during battle; this sheet only represents the inventory book.
- Trigger: entering/leaving embedded battlefield. Information: existing battle state and visual transition. Interaction: map.gd and its TextureButton. Visual: atlas texture only. Memory: transient lock/tween state, no persistence.
- Verification: headless editor import and actual OpenGL in-memory map session. Checked interrupted lock reversal, battle disabled state, final frame held, unchanged geometry, inventory opening blocked, map return restoring the closed book, active battle resume immediately locked. BOOK_LOCK_CHECKS failures=[]; no runtime errors/warnings.
- Screenshots: task workspace book_battle_locked.png / book_battle_unlocked.png. Temporary verification script was outside the project and removed. No test UI, commit or push added.
