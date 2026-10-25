# Korean / English language selection — 2026-10-25

- Title Options and the in-game settings panel offer `한국어` / `English`. Default: Korean.
- Selection applies immediately and is saved separately in `user://language_settings.cfg`. World saves, canonical monster names/IDs, event receipts and audio preferences are unchanged.
- English covers live UI, introductory dialogue, the eight main event scripts, choices, units, effects, rewards and error/status messages. The catalog contains 1,006 entries, including derived dialogue fragments and the latest unit-info headings.
- Godot automatic translation keeps original `.text` values available to existing gameplay and sound classifiers. A bounded cache handles formatted/joined display strings. Nicknames are preserved in card/name widgets and formatted stats.
- English lettering for 18 dice cards and the battle deck title uses blank samples of the existing painted texture plus live text. Original Korean textures, artwork aspect ratios, book/illustration dimensions and hitboxes stay unchanged. Combat MISS/CRITICAL/POISON/IMMUNE use live English captions.
- Story reveal counts translated characters and releases the full line on a locale switch. The book reflows its text; English monster names fit the existing ribbons.

## Verification

Godot 4.7.2, headless, isolated APPDATA/LOCALAPPDATA (no interactive game window opened):

- `scripts/test_game_language.gd`: 88 passed, 0 failed. Covers persistence, both pickers, return to Korean, native source-string preservation, formatted messages, 18 card variants, combat captions, authored scenes from eight main events, every monster name ribbon and custom names.
- `scripts/test_layered_unit_cards.gd`: 0 failures.
- `scripts/test_inheritance_parchment_readability.gd`: 33 passed, 0 failed.
- Import/parse and whitespace checks: clean.
- Headless layout measurements do not replace an interactive visual review. The user will run the game themselves.

## Maintenance

Add new Korean display strings and their English translations to `data/localization/en.json`, preserving printf slot types/order and line breaks. Keep saved data in Korean/canonical IDs. Add context-specific source templates for new joined strings; never translate stored IDs or user-entered names. The Game Language workflow runs the focused regression on relevant source updates.

## UI review

Trigger: either options picker. Information: visible language autonyms. Interaction: selecting a language applies and saves it; failed saving keeps the previous selection. Visual: existing book/card sizes and painted menu style are preserved. State: a dedicated language preference; no rule, RNG or progression changes.
