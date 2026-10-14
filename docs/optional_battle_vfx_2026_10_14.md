# Optional Battle VFX — implementation gate (2026-10-14)

Status: isolated experiment branch; NOT merged. No existing battle mechanics changed.

## Baseline
- Branch: `feature/optional-battle-vfx-20261014`, forked from `main` on 2026-10-14.
- Godot 4.7.2, Compatibility renderer.
- Existing combat already implements projectile, hit flash, summon circles, healing particles, and permanent-death soul/ash effects. Preserve all existing effects when experimental VFX is disabled.

## User-approved scope
- Optional **Battle VFX (Experimental)** toggle, default OFF.
- Independent Shadow Particle (attack), Energy Burst (impact), Dissolve (death) sub-toggles.
- Visual-only adapter: never change dice, brands, damage, win/loss, save-game, or permanent death.
- Do not duplicate battle gameplay. No wholesale import of a VFX library. Include only verified compatible resources and licenses.
- Provide rollback via toggle OFF and isolated PR branch; no automatic merge.

## Implementation sequence
1. Inspect `battlefield.tscn`, battle scripts, current animation timing, options persistence, and existing death effects.
2. Verify upstream effect filenames, Godot 4.7 compatibility, rendering method, dependencies, and license before importing.
3. Introduce a small isolated visual adapter with a no-op when OFF; avoid touching gameplay state.
4. Expose toggle(s) in existing settings UI; default OFF even for existing user profiles; keep UI legible with up to ten units.
5. Hook attack/impact/death visual events only. Sync impact to real resolved hit timing, not blindly to sprite frame 7. Avoid double-dissolve: existing death animation must remain default and experimental dissolve replaces only its visual finish when ON.
6. Validate ON/OFF parity, overlapping effects, unit lifetime, save/load, game over, Windows native and regression CI.
7. Open draft PR with evidence and explicit revert instructions. Do not merge without review.

## Five design questions
- Trigger: existing attack/impact/death visual events.
- Information: target visual anchor, animation state, unit lifetime, effect preferences.
- Interaction: none during battle; preferences in options.
- Visual change: optional shadow particles, short impact burst, post-death dissolve.
- Memory: only user preference; VFX never persisted as game state.

## Acceptance
- OFF produces visually and mechanically equivalent existing behavior.
- ON never blocks combat resolution and cleans up all effect nodes.
- Failure of a VFX resource gracefully falls back to existing visuals.
- No oversized assets, build cache, or unnecessary repository bloat.
