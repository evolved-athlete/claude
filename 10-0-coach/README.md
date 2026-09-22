# 10.0 Transformation Coach

Chat page that runs clients through the 10.0 Process (Vision → Belief → Identity → Standards → Goals → Affirmations) and assembles their Mind Movie.

Live: https://claude.ai/artifact/EW8uQafxG1PVWCbnDAq4Bb

- `prompts/` — the coach's operating manual. Edit these, not the page.
  - `05-opening-and-reentry.md`: the page sends the `> ` quoted lines under `## THE OPENING MESSAGE` and `## THE RE-ENTRY MESSAGE` verbatim, and fills the two `[brackets]` in re-entry from saved progress. Keep those headings and bracket texts if you edit it.
- `src.html` — page template; `<!--DOC:file.md-->` markers get the prompts inlined.
- `python3 build.py` → `dist/10-0-coach.html`, then republish that file to the same artifact URL.

How it runs: each reply is one Claude call on the client's own claude.ai account. The page sends the manual (only the current and next phase of 01, plus 02 from Phase 3 on), a running record of what's been captured, and the recent conversation. The coach ends each reply with hidden `<<<STATE>>>` / `<<<SAVE>>>` blocks the page uses to track the phase and build "Your document". Progress lives in the client's browser; "Save progress file" lets them move devices.
