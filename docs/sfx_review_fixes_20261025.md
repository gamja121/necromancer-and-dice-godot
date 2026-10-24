# SFX review fixes — 2026-10-25

User approved the six findings from the SFX audit. Base includes upstream 132b5a8, retaining one-use parchment fall and all prior book/dragon gameplay.

## Corrected behavior

- Pointer/drag and keyboard card activation share one manual card_use cue after selection validity checks. Active card/close/backdrop automatic cues are suppressed to prevent duplication; unavailable cards retain blocked feedback. ESC closes the dice hand and inheritance with the same cancel cue as the visible close controls. ESC during a card drag gives one cancellation cue.
- close_overlay owns book closing audio. story_modal explicitly suppresses closing on a beat replacement, retaining the open-page turn. dismiss_overlay no longer duplicates that cue. Actual return/feature navigation uses cancellation; story Finish remains confirmation regardless of parchment skin.
- Dragon normal hit and critical hit use separate cues. Outgoing criticals retain the original battle critical feedback. Damage, combat RNG and animation impact timing are unchanged.
- Defeat stops and releases embedded battle music/SFX before the terminal screen. Shatter audio uses the common service; skipping stops both tails. Heavy impact was reduced from -4 to -12 dB, with the echo at -16 dB.
- New result sounds differ by material, temporal sequence and resonance: paper/clinks for reward, suction for capture, breathing swell for recovery, dry dispersion for cleanse, wood resonance for prayer and staggered glass for prophecy. Ritual, inheritance and ending have separate progressions.
- Dragon reveal, breath/roar, rushing attack, impact, scale cracks/pain, critical hit and progressive collapse use separate layers/envelopes. Original user-provided wooden-door and page-turn recordings are unchanged.

## Audio assets

23 procedural WAVs rebuilt, including two new cues card_use and dragon_critical. Reproducible generator: tools/audio/build_review_sfx.py (NumPy; no external service or downloaded sample). Existing waveform lengths are retained, aside from rounding the previous dragon_death sample count to exactly 2.3 seconds. Runtime peak limit .76, 4 ms onset and 25 ms release fades.

Previous waveform correlations cleanse/prayer_bless and capture_success/prophecy_bless were .97286/.96829. Revised values are -.00090/-.00036; this measures structural separation, not a claim of subjective listening approval.

## Verification

- Godot 4.7.2 editor import clean.
- Native production-path regression: 36 passed, no diagnostics. Covers pointer/keyboard card activation, Escape, story completion/page replacement/navigation, dragon critical distinction, battle-music defeat handoff and skipped shatter tails.
- Six native SFX bus mixes have a maximum captured peak of .231354 with nonzero output and no clipping. Ear/speaker preference remains subject to the user's listening review.
- Existing actual saved defeat/Continue regression: 22 passed, no diagnostics.
- Shared audio backend/assets/mute/limits/ownership: 86 passed in the isolated sequential run, no diagnostics. An earlier concurrent teardown diagnostic did not reproduce in this sequential run.
- Latest one-use parchment UI: 15 passed, no diagnostics. Its stop hook previously created an empty tween; added stop_animation and preserved the existing fall's transforms and timing.
- Player saves/settings were isolated with per-run APPDATA/LOCALAPPDATA profiles. No rules, save format, original art or book dimensions changed.

The dedicated Game Sound Effects workflow now runs the reported-path regression alongside the existing service tests. This is focused audio/UI verification, not an original-difficulty full-run balance test.

Final condition-based focused regression: 26 passed with no diagnostics; card tests await the original chosen signal rather than a fixed animation delay.

Shared integration: preserved main 8dc865c (capture identity tests and unit-info brand grouping). Current unit-info regression: 15 passed, no diagnostics. No overlapping audio logic was changed during this rebase.
