# PC ↔ GitHub shared Godot source

The shared repository is https://github.com/gamja121/necromancer-and-dice-godot, public main.
The active PC project is C:/Dev/necromancer_and_dice.

The user requires frequent integration in both directions. PC work is committed to the shared repository; GitHub work is merged into the PC. A finished work unit includes verifying that both sides use the same published gameplay source and approved runtime assets.

## Begin work

1. Inspect git status, the current branch, pending changes and the active task that owns them.
2. Fetch origin main.
3. Merge current origin/main into the working branch while preserving unfinished work. Resolve overlapping changes with the original author's work intact.
4. Work from this shared baseline.

Typical Git commands:

```powershell
git status --short
git fetch origin main
git merge origin/main
```

A merge that reports a conflict or a local overwrite risk must be resolved by the coding task with backups and a comparison of both changes. Do not discard pending work to make the command succeed.

## Finish each stable work unit

1. Inspect and stage only intended code, scenes/resources, approved runtime assets and relevant documentation.
2. Run appropriate import, behavior and visual checks; scan intended publication for secrets.
3. Commit the validated work.
4. Fetch and merge the latest public main so parallel authors' changes are included. Check the merged result.
5. Push the validated integration to public main.
6. Update the PC working project from that exact public revision and check its gameplay files/assets. Preserve ongoing candidate art and personal files.
7. Report the shared commit and any remaining unintegrated changes.

```powershell
git fetch origin main
git merge origin/main
git push origin HEAD:main
git rev-parse HEAD
git ls-remote origin refs/heads/main
```

Commands above are the integration steps around a reviewed commit, not a command to publish all current files.

If a GitHub workspace cannot reach the PC, record the exact published commit and complete the PC step in the authorized local task. Until then, report the PC update as pending.

## Shared result and local state

The shared result includes GDScript, scenes, resources, project.godot, unit/rule data and approved runtime assets. Both sides should load the same gameplay implementation after integration.

Local save files, audio device preferences, .godot caches, source_assets originals and unapproved art candidates are kept locally. Work that is still being edited remains pending until it is ready to integrate.

## 2026-10-11 Git baseline repair

The PC gameplay tree already matched the public runtime source, while its Git branch/index still referenced 0ebaae3. After checking an empty staging area and confirming that 0ebaae3 is an ancestor of public main, the local Git baseline was advanced to the shared revision without modifying working files. The previous Git index/ref and working diff were backed up first.

Normal future synchronization uses fetch/merge and reviewed commits. The metadata-only advance was a one-time correction of the old PC baseline.

## Frequency

Apply these steps at every task start and after each completed, verified work unit, including work performed in another workspace. This document does not install a background synchronization service or scheduled task.
