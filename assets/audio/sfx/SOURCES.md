# Game sound effects

These WAV assets were synthesized specifically for Necromancer and Dice on 2026-10-24 using deterministic filtered noise, damped wood/felt resonances, air, muted chimes and low organic harmonics. No downloaded samples, model API, or external paid services were used.

Existing page-turn and wooden-door recordings remain unmodified in assets/battle/sfx; see that directory SOURCES.md for their original user-provided names.

Mono PCM 16-bit, 24 kHz. One-shot, nonlooping. Runtime gain and rate limits are defined in systems/game_audio.gd.

## 2026-10-25 sound-design review

23 cues were rebuilt with individually timed paper, wood/glass resonance, air, suction, skin/scale crack and decay layers. Two new cues are card_use and dragon_critical. Reproduce with tools/audio/build_review_sfx.py in a NumPy Python environment. No external recording or paid service was added; user-provided door/page sources remain unchanged.
