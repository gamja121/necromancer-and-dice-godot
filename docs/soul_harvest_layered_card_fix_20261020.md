# Soul-harvest card artwork parity — 2026-10-20

## Root cause
Battlefield cards install `LayeredUnitCard`, but `CorpseCapture.setup` created post-victory selectable corpse cards by copying only `scene.cards[id].texture_normal`. The original flattened texture is intentionally preserved for hit testing and legacy compatibility while the approved artwork is rendered in separate children, so the post-victory screen displayed outdated art.

## Visual-only fix
- Capture candidates now use the same independently rendered approved portrait, legion scenery, title, and owned-brand icon layers as battle cards. Flat fallback remains for monsters not yet migrated.
- The shared map book-flight receives the correct layered source. Standalone soul capture success uses the same visual copy when it exists, rather than recreating a flat old image.
- Failure dissolve shader is applied to the visible layered child art as well as the card container.
- No changes to capture odds, dice outcomes, corpses, roster, inventory or save transactions.

## Regression coverage
- Each of the 32 migrated monster cards creates a detached capture candidate with its correct approved portrait, preserves fallback hit/disabled textures, and supports a layered book flight.
- The real map combat integration checks candidate art paths and handles animated `Control` flights (not only `TextureRect`).
- Both `Layered Skeleton Monster Cards` and `Original Soul Capture Choice Visual Port 5E` CI workflows validate the changes.
