# Doom executor / Azazel layered card (2026-10-20)

The user-supplied `1000015815.png` depicts a winged horned goat-headed axeman corresponding to `doom-executor` (아자젤) in `data/units.json`. It is **not** the separate `minotaur` unit. No image was redrawn or generated. Only the original RGB black matte was extracted algorithmically into a transparent WebP with the full wings, axe, and tail preserved.

- Original asset: user's uploaded PNG (1229×1536), preserved unchanged in Google Drive.
- Runtime asset: `assets/cards/layered/doom_executor.webp` (1229×1536, RGBA with transparent outer corners), WebP lossless.
- Git blob SHA-1: `3cfba54e7a42fd24278b0410fc83594953d4d324`
- SHA-256: `62ea7e0433d77610c2f7dc6985d5ed55f29e6946e742f352cdf93ee1d6fbf9f6`
- Existing legion scenery: `base_demon.webp`. Existing card frame, owned brand UI, battle behavior, flattened legacy card, and other 31 layered portrait images are left untouched.
- 31→32 layered card coverage. Verify Godot card regression, return to book, and visually check transparent edge in a PC game.
- Drive backup folder: `네크로멘서 앤드 다이스/카드원화_아자젤_20261020`.

The unrelated P4 full-source story chain tests have failed on earlier `main` revisions due to boss / travel / story tile conditions. No story gameplay files are edited in this card artwork PR.
