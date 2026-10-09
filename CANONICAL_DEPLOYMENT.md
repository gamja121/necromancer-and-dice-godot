# Canonical deployment policy

- Source of truth: `gamja121/necromancer-and-dice-godot` `main`
- Public test URL: `https://gamja121.github.io/necromancer-dice-board/`
- The old HTML/JS implementation in `necromancer-dice-board` is not a deploy source.
- Only a successful Godot Web artifact may be published to the public test URL.
- Every published site records the source commit in `DEPLOYED_SOURCE_SHA.txt`.
- Do not use or share any other test URL as the current build.
