# Main story book integration — 2026-10-24

The approved leather cover and open-paper artwork now run in the production map, rather than only in external previews. The same shell covers the eight main story events, their choice/outcome/follow-up views, the final dragon intro and the saved ending. Generic discovery, routine events, location functions and combat retain their separate interfaces.

The book uses the fixed 1280×720 composition at scale 0.84 and position (102.4,57.6). The illustration has one clipped 360×202.5 local rectangle. Orthographic cover/page rotation preserves physical height; the page texture ignores its source PNG minimum dimensions. Advancing an open story keeps the book open. A later visit/reload opens its saved scene afresh. Narration, speaker, dialogue and plain text choices have separate reading/click areas. Focus and mouse hover use an ink triangle; authored clue/quest/location stamps appear on the matching beats.

## Original gameplay ownership

- Trigger: existing actual arrival, eligibility and resume dispatch; no new contamination, boss or story gate.
- Information: existing authored narration/dialogue, choice captions and saved ending statistics. Speaker names move to their own line.
- Interaction: the original map callbacks commit each Continue/Finish/choice. The first input completes a reveal, without committing a decision. The final battle still requires explicit saved acknowledgement followed by ordinary roster confirmation.
- Visual: shared approved book assets and original scene layers/motions. Dragon camera tremor moves the picture foreground inside the page, not the book or background. Ending closes the cover before the existing title transition.
- Memory: no new save keys or migrations. RunSession retains choices, quest receipts, RNG, encounter, harvest and final-clear transactions. Pending harvest still resumes before the ending; Continue restores the completed record.

The final-clear implementation from the PC branch is preserved while merging public main's latest layered cards, inheritance UI and corrected map tests. Intermediate contamination 20/40/60 bosses retain their ordinary deck flow.

## Verification

Use Godot 4.7.2 editor import, then the existing/new scripts in scripts/: test_story_event_layout, test_story_typewriter, test_main_story_book, test_final_chapter_ui and test_p4_single_run_end_to_end. The main-story test extends the actual source chain and checks each production book/action without changing the authored transitions. Optional --screenshots=<directory> captures actual native scenes; --export-story=<file> exports successful real story completion for the final test's --source-story=<file> input. These paths are caller-supplied audit outputs and never part of player saves.

The older story visual regressions are updated for the approved book/art bounds and nested picture nodes. Isolated fixture setup now respects the existing cemetery/home and contamination gates; those gameplay gates are not weakened. The old HOME departure-caption test is also made explicit so a missing next-lap button cannot silently skip checks.

Automated victories use deterministic approach fixtures and boosted allied stats. These checks establish UI/progression/save integration, not an original-difficulty balance playthrough. Windows native captures are required in addition to headless CI. Local evidence and personal save hashes remain outside the repository.
