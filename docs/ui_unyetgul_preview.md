# Local UnYetgul typography preview (2026-10-16)

User preference: D — 은옛글 (UnYetgul), keep the original regular/thin weight. Use it for functional/information UI, excluding dialogue and narration. No game-rule, RNG or saved-state changes.

## LICENSE SAFETY — do not ship the font
UnYetgul is part of unfonts-extra, pure GNU GPLv2 **without a font embedding exception** (the CTAN package explicitly warns of downstream licensing implications). The original font binary must **not** be committed to this public repository or included in a game package until a competent licensing decision has been made.

Source: https://ctan.org/tex-archive/fonts/unfonts-extra
Font listing: https://ctan.math.illinois.edu/fonts/unfonts-extra/

## How to try the selected typeface on your own Godot build
Obtain the original \`UnYetgul.ttf\` from a trusted source and review its license. For a personal, local test, place the file in either:

* \`res://assets/fonts/UnYetgul.ttf\` — relative to this Godot project folder; ignored by Git so it is not uploaded.
* \`user://fonts/UnYetgul.ttf\` — Godot's per-game user-data folder; also never uploaded.

Restart the project. \`UiTypography\` loads the first available local copy and assigns it at normal weight to information labels/buttons, including controls created after initial startup. The font is deliberately **not** embedded in the repository, installer, Web build, or game export. Without the optional local file, the previously shipped fonts remain unchanged.

### Exceptions
* Intro story dialogue/narration (existing intro theme)
* Story-map speech/narration tagged using \`ui_story_copy_role\` in \`map.gd\`
* Narrative description in discovery/routine event cards

### Implementation
* \`systems/ui_typography.gd\` registered under \`project.godot\` autoload
* \`scripts/test_ui_typography_preview.gd\` + workflow validate labels, rich text, buttons, exemptions and fallback
* No changes to font sizes, line breaks, alignment, colors, card layout, save files, game balance, RNG, story texts or audio. A font swap can change glyph widths; verify clipping on actual Windows/Android displays before release.
* Baked text inside images is not editable via font overrides and is unchanged.

Five principles:
1. Trigger: local preview TTF exists at game start.
2. Information: font file, label role, story-copy metadata.
3. Interaction: dynamically-created UI nodes through SceneTree.node_added.
4. Visual: regular UnYetgul on informational text; story text left as-is.
5. Memory: no save schema change; local file presence controls preview on next startup.
