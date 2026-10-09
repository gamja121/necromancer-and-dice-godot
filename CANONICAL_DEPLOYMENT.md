# Canonical deployment policy

- Source of truth: `gamja121/necromancer-and-dice-godot` `main`
- Public test URL: `https://gamja121.github.io/necromancer-dice-board/`
- The old HTML/JS implementation in `necromancer-dice-board` is not a deploy source.
- Only a successful Godot Web artifact may be published to the public test URL.
- Every published site records the source commit in `DEPLOYED_SOURCE_SHA.txt`.
- Do not use or share any other test URL as the current build.
Private main builds publish only build/web to the public repository using the GODOT_WEB_DEPLOY_KEY Actions secret. The public repository alone deploys Pages. Failed or stale builds never replace the live game. Local uncommitted game development is not published.
