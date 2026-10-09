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

## Public Godot development policy (2026-10-10)

- Canonical development repository: https://github.com/gamja121/necromancer-and-dice-godot (public). The local active project remains C:/Dev/necromancer_and_dice.
- The completed HTML/JS implementation is reference material at gamja121/necromancer-dice-board, branch reference/html-final, commit e13d5149fcecc802e5d626f3bef6e5daecd3d66c. Develop new implementation in Godot; do not extend the old HTML/JS game.
- Godot Web export and automated Web publication are stopped. Do not run or restore Web export/deployment unless the user explicitly changes this policy. Existing export presets and web shell files are historical reference.
- The user authorizes committing and pushing completed, verified Godot work to the canonical public repository. Use feature branches for substantial changes, fetch and preserve remote main changes, then integrate tested work into main so connected GPT/Codex can see it. Do not repeatedly ask for commit/push authorization for this scope.
- Before publication, inspect intended staged paths and scan for secrets. Keep .env, credentials, personal data, .godot, machine-local user saves, builds, source_assets and unapproved candidate art out of Git. Preserve existing working changes and publish only stable, tested work units; do not use a filesystem watcher to push half-written files.
- Public visibility allows reading and cloning; connected GPT/Codex still needs authenticated write permission for edits. Use this repository for .gd, .tscn, .tres, project.godot, runtime assets and port documentation.
- Read docs/development_policy.md and docs/godot_port_status.md for synchronization and port scope. Full port completion requires functional and visual parity checks, not just a working title or battle scene.
