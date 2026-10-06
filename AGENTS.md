# Necromancer and Dice

- Godot 4.7.2 Standard, GDScript, Compatibility renderer. Windows Native / PowerShell.
- This is the single active Godot project. D:\Workspace\Games\necromancer-and-dice is reference/archive storage, not a second active checkout.
- Before changes, inspect git status and preserve unrelated user changes. Use a feature branch for substantial changes.
- Keep filenames lowercase snake_case. Preserve Godot .uid files. Do not hand-edit or track .godot caches.
- Runtime resources belong in assets; originals belong in D:\Workspace\Games\necromancer-and-dice\raw_assets. source_assets is excluded from Godot import; never reference it with load/preload.
- For gameplay/rule/event changes, review: trigger, required information, communication, visual change, and persistent state. Skip this review for simple asset or typo edits.
- Verify changes with headless editor import, a runtime smoke test, relevant tests, and git diff. Report failures honestly. Headless checks do not replace visual UI testing.
- Commit only intended, tested changes when authorized. Push only to an explicitly authorized remote/branch. Never force-push, rewrite history, or delete source assets without authorization.
- Never commit credentials, personal assistant data, or machine-specific secrets. Do not disable antivirus, the sandbox, or AnyDesk to speed up development.
