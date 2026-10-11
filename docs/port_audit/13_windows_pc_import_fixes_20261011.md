# Windows PC import fixes — 2026-10-11

The public Godot main at 52ff436 was synchronized into the existing active PC project. Runtime files were compared against the previously published PC snapshot, backed up, and updated without changing the active Git branch/index or overwriting ongoing source_assets/unit_art_pipeline work. This update changes Godot only.

## Truncated event portraits

Godot 4.7.2 Windows import rejected both event portrait WebP files. The frozen web reference and its historical versions contain the same truncated data:

| Event file | Actual bytes | RIFF declared bytes |
|---|---:|---:|
| knight-commander-upperbody-hd.webp | 15,009 | 189,684 |
| necromancer-upperbody-hd.webp | 15,008 | 123,064 |

They cannot be decoded by Godot or Pillow. Matching a Git blob from the frozen web reference did not prove that the image was importable.

Both Godot event files now use the existing working intro portrait assets, copied without image generation or conversion:
- assets/intro/knight_commander.webp: 263,024 bytes, 1448 × 1086.
- assets/intro/necromancer.webp: 30,048 bytes, 480 × 360.

The event filenames and script references stay stable. This is a fallback to existing character art, not recovery of the missing HD data or proof of byte/visual parity with the damaged web portraits. The web reference and original source materials remain unchanged.

## Audio preference cleanup

Each title audio setting change previously created an unattached AudioSettings Control, called save_settings, and left the node unfreed. Four setting changes produced four leaked Controls and a retained audio_settings.gd resource on exit.

title.gd now stores the temporary node, saves the preferences, and immediately frees it. The persistent settings format and behavior are unchanged.

## Windows verification

Godot 4.7.2 Standard / Compatibility. The temporary validation user directory was separate from player saves/settings; project.godot was restored byte-for-byte afterward.

- Headless editor import: exit 0, no errors after portrait replacement.
- Original title audio test: 22 passed, 0 failed, no errors including shutdown after the node fix.
- Story state test: 103 passed, 0 failed.
- Original web unit catalog test: 654 passed, 0 failed.
- Battle motion test: 31 passed, 0 failed; all 47 species/733 frames decoded.
- OpenGL execution: title music resource/options, new game → intro → map, save → continue restoration, standalone battlefield; all checks passed, no engine/script errors.
- Title, intro, map and battlefield screenshots were inspected.

These checks validate this update and its fixes. Full P4/P5 migration approval and live speaker playback remain separate.

For the audio change: trigger is title volume/Music/SFX preference editing; information and controls are unchanged; visual presentation is unchanged; the same config is saved; the temporary Control is freed afterward.
