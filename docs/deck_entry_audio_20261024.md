# Battle deck entry audio — 2026-10-24

- User request: reuse the older game's wooden-door opening sound as the battle deck selection board descends.
- Reuse `assets/battle/sfx/treasure-chest-open.mp3` unchanged. `assets/battle/sfx/SOURCES.md` records its user-provided original `soundreality-opening-door-411632.mp3`; the archived web copy has the same SHA256.
- Trigger once when `BattleDeck.setup()` starts the existing 0.64-second board descent. Original 2.04-second nonlooping clip, pitch 1.0, -14 dB, SFX bus. Its natural tail continues after the board settles.
- Card selection redraws do not restart the entry sound. Existing card clicks are independent. Scene removal stops and releases both players, including an early departure.
- Gameplay, selection, UI layout, animation timing and personal audio settings remain unchanged.
## Validation

- Godot 4.7.2 editor import: passed without diagnostics.
- Existing deck/overflow suite: 92 passed, 0 failed.
- Native Windows production-deck smoke: 9 passed, 0 failed; captured a nonzero SFX bus signal, verified selection does not restart entry audio, original board settlement, nonlooping completion, normal removal and early removal cleanup.
- Separate temporary audio/save profile used for native and regression runs. Listening balance remains subjective; initial entry level is -14 dB.
