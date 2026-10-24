# Staged sound effects rollout — 2026-10-24

1. Common controls and shared voice/cooldown/scene-lifetime routing.
2. Main story book and choices.
3. Reward, recovery and environmental damage.
4. Battle outcome feedback and shared-die deduplication.
5. Place actions, transactions, prophecy and inheritance.
6. Final dragon and ending.
7. Focused native mix/pause/scene-exit checks.

Preparation: reuse existing 18 source clips and a small original procedural sound bank. Existing wooden-door deck entrance remains unchanged. No game rules, RNG, progress format, player save or personal audio settings changed.

Stage 1 implementation: UI press semantics, exact card selection/rejection, SFX bus, per-cue interval and category/total voice caps. Hover/focus animation stays silent. Book action buttons are marked manual because their first press may reveal dialogue. All former map/battle sound calls share one service. Runtime cue owners support stop and pause; scene departure stops scoped audio.

## Completed stages

- Stage 2: original paper recording for opening/page transitions; soft cover close, ink stamp and true story-choice confirmation. The first input that only reveals text stays silent. A beat replacement does not replay the cover opening.
- Stage 3: committed treasure/capture keep results, routine rewards, newly awarded place discoveries, actual HOME/rest recovery and fresh swamp arrivals. Saved movement resumes keep the visual replay but do not repeat the new swamp cue. Declined rewards, failed saves and result-screen reloads never emit gain sounds. Existing failed-capture dissolution sound is retained.
- Stage 4: positive critical impacts replace the normal hit cue; guard/block, missed actions and real healing receive separate cues. Healing bursts are grouped and rate limited. Embedded shared-die landing is no longer played twice; standalone and rolled-resume paths retain their one result cue. Battle reset/exit releases owned sounds; pause applies to current and later combat cues without changing music or pitch.
- Stage 5: successful trade, grave digging, committed ritual, prayer and prophecy result branches, inheritance dissolution and completion stamp. Outcome cues are attached after successful transactions, never setup/render methods.
- Stage 6: dragon reveal rumble, timed roar/impact, combat attack/hit/rot death and fresh ending clear/stamp. Skipping the unopened book suppresses the synchronous opened callback's dragon audio, then advances silently. Replay stops prior voices. Continue restores the ending without another victory/stamp cue.
- Stage 7: common per-cue and category/total caps, priority-aware voice replacement, owner pause and immediate map/battle exit cleanup. UI input tails can finish briefly; removed scene audio is stopped. Music/SFX switches and master volume remain the existing controls.

## Validation

| Check | Result |
| --- | --- |
| Godot editor import | clean |
| Shared controls, mute, voice limits, pause, asset bank, ownership | 82 passed |
| Existing deck/overflow | 92 passed |
| Existing title audio/settings | 23 passed |
| Focused production book/choice audio integration | 8 passed |
| Six routine cards incl. decline/overflow/save failure | 240 passed |
| Treasure reward selection/overflow | 33 passed |
| Battle entry/saved encounter | 87 passed |
| Fortune/prophecy UI | 44 passed |
| Route/inheritance behavior | 27 passed |
| Native Windows dragon skip/replay, new/resumed ending and six sound mixes | 25 passed, no diagnostics |
| Actual final combat, harvest, ending, title and Continue | 73 passed, no diagnostics |

The native SFX bus capture's maximum peak was 0.279218 for the six representative mixes (no clipping). The mix uses conservative gains; ear-based preference and speaker balance can be adjusted after the user's listening review. The native ending screenshot was visually inspected; fixed book/art layout is preserved.

A broad all-story legacy suite exceeded this task runner's 120-second limit and was stopped. It was replaced by the focused production-book check; no full original-difficulty run or universal all-game certification is claimed here. Early type-inference/test-fixture issues and an off-tree shutdown cleanup error were corrected; the final listed checks are clean. All execution used isolated APPDATA/LOCALAPPDATA profiles.

32 original procedural WAVs total about 1.02 MB. Source provenance is in assets/audio/sfx/SOURCES.md. New shared-service CI covers imported assets, control semantics, mute, voice caps, pause inheritance and scene cleanup.

## Shared-source integration

Preserved upstream main 9546154, including the location button stack and graveyard/fortune parchment UI. Post-integration editor import is clean; location layout 376 passed and current fortune UI 46 passed with no diagnostics.
