# GARDEN RECLAIMED — Phase 6 Scope
### Built on top of Phase 5 (M21: second challenge-trial pack — merged, 16 missions)

---

## Starting point

Per explicit user direction, Phase 6 scopes **a true 9th arena chapter** — real new geometry in
`ChapterArena`, not another reuse of an existing recipe. This is explicitly a bigger change than any prior
content phase: `tests/run_tests.gd::_test_chapter_arena_recipes` currently hard-locks `ChapterArena` to
exactly 8 chapters (`range(8)`, `fingerprints.size() == 8`). Widening that is a deliberate contract change,
not an accidental break — the milestone below is designed to make that change coherent rather than just
technically pass a wider assertion.

### What the code actually does today (read directly, not assumed)

Three separate systems key off "which chapter," and they don't agree on how:

1. **`ChapterArena.rebuild(index)`**, called from `_on_mission_selected(index, _mission)`, uses the raw
   **0-based mission catalog index** — `chapter_index = clampi(index, 0, 7)`. It ignores the `mission`
   parameter entirely. This is why all 8 post-campaign challenge trials (missions 9-16, catalog indices
   8-15) render the same "Sevenfold Ascent" geometry: every index ≥ 7 clamps to 7.
2. **`RankSystem._on_mission_selected`**: `rank_index = clampi(mission_data.chapter - 1, 0, RANKS.size() - 1)`
   — uses the **1-based `MissionResource.chapter` field** instead, clamped against `RANKS.size() == 8`.
   Every mission's `.tres` file sets `chapter` to its own catalog position + 1 (core missions: 1-8;
   challenge missions: 9-16, verified directly from `mission_09.tres` through `mission_16.tres`). Since
   `RANKS.size() - 1 == 7`, every challenge mission (`chapter` 9-16) already clamps to rank index 7, "ONE OF
   THE SEVEN" — this is independent of `ChapterArena` and **will not be affected by anything in this
   milestone**.
3. **`ChapterLandmark._rebuild(chapter, accent_color)`** also reads `MissionResource.chapter` directly (not
   the catalog index), with an explicit `match` statement whose `_:` default (`_build_seven_spires()`)
   already handles every chapter value ≥ 8 gracefully. This system needs **no changes** for this milestone
   — it already generalizes correctly.

So `ChapterArena` is the odd one out: it's the only one of the three that ignores `MissionResource.chapter`
and clamps the raw catalog index instead. That's *why* a "9th chapter" has never mattered before — nothing
currently asks for chapter index 8. `RankSystem` and `ChapterLandmark` already prove the intended pattern
(`mission.chapter`-driven, clamped against a fixed roster size); `ChapterArena` should follow it too.

### The design decision this creates — resolved here, not left open
Widening `ChapterArena`'s roster to 9 recipes only matters if something selects index 8. Two ways to do
that:
- **(Rejected)** Widen the raw-index clamp from `clampi(index, 0, 7)` to `clampi(index, 0, 8)`. This would
  silently retarget **all 8 existing challenge missions** (catalog indices 8-15 all clamp to the new max, 8)
  in one step, with no way to have some challenge missions keep the old arena and others use the new one.
  Too blunt, and it perpetuates the mismatch with `RankSystem`/`ChapterLandmark` rather than fixing it.
- **(Recommended)** Switch `ChapterArena` to read `mission.chapter` the same way its two sibling systems
  already do, clamped against the new 9-recipe roster: `clampi(mission.chapter - 1, 0, 8)`. Because every
  challenge mission's `chapter` field is ≥ 9 today, `clampi(chapter - 1, 0, 8)` evaluates to `8` for **all
  of them** (9-1=8, 16-1=15→clamped to 8) — so this one change simultaneously (a) unifies all three
  chapter-selection mechanisms onto the same authored field, fixing the inconsistency, and (b) gives all 8
  post-campaign challenge trials a real, dedicated arena instead of reusing the core campaign's finale
  chapter. This is a visible, positive change to 8 already-shipped missions (they stop borrowing Sevenfold
  Ascent), which is worth calling out plainly rather than treating as a side effect.

## Milestone

| # | Milestone | Touches | What changes |
|---|---|---|---|
| **M22** | Ninth arena chapter — dedicated challenge-trial ground | `world/chapter_arena.gd`, `tests/run_tests.gd`, `autoload/game_state.gd` | **Done** (PR #30, merged) — implemented directly by Claude Code rather than handed to Codex, since Codex's local branch never reached anywhere reviewable. New "COVENANT GAUNTLET" recipe (16 structures), `CHAPTER_LABELS`/`CHAPTER_TINTS` extended to 9, `ChapterArena` switched to `chapter_index_for(mission)` (matching `RankSystem`/`ChapterLandmark`'s existing pattern) instead of raw catalog index. All 8 challenge-trial missions (9-16) moved from reusing chapter 7 to the dedicated chapter 8. CI green on all 3 platforms. |

**Explicitly not in this scope:** no new mission content (the 16 missions from Phases 2 and 5 stay as-is,
just pointed at new geometry), no change to `RankSystem` or `ChapterLandmark` (both already correct), no
change to the 8 core-campaign chapters' recipes, no new objective primitive, no new boss.

---

## M22 — Ninth arena chapter

### Steps
1. Design the 9th chapter's geometry as a genuinely distinct arena, not a variant of an existing one —
   `_test_chapter_arena_recipes` will assert its `JSON.stringify()` fingerprint is unique among all 9, the
   same bar every existing chapter already clears. Suggested identity, since this arena's job is now to be
   the *shared home for every post-campaign trial* rather than one specific narrative beat: something that
   reads as a testing-ground/gauntlet rather than a story location — the 8 challenge missions' briefings
   already treat their setting as reused/abstracted ("the second trial wave begins where the spiral
   closes"), so the arena doesn't need to match any single mission's narrative, just needs to support all of
   them functionally (enough traversable space and structure variety for `PURIFY_ZONE`/`RESTORE_THIN_PLACE`/
   `SURVIVE_WAVES`/`ESCORT_HOST`/`BIND_TARGET`/`BREAK_IDOL` — all 6 primitives run here across the 8
   missions, including mission 16's all-six capstone).
2. Add the new case to `ChapterArena.recipe_for()`'s `match` statement (index 8), following the existing
   `_box()`-composition style every other chapter uses. Must satisfy `_test_chapter_arena_recipes`'s
   existing per-structure assertion (`Vector2(at.x, at.z).length() > 4.0`, keeping the central Thin Place
   clear) and its ≥4-structures-per-chapter minimum.
3. Extend `CHAPTER_LABELS` (currently 8 entries) and `CHAPTER_TINTS` (currently 8 `Color`s) to 9, in the
   same style as the existing entries (`"SEVENFOLD ASCENT"`-style all-caps label; a tint distinct from the
   other 8).
4. Change `ChapterArena.rebuild()` and `_on_mission_selected()`: read the mission's `chapter` field (the
   `_mission` parameter is already passed into `_on_mission_selected`, currently ignored — start using it)
   instead of the raw catalog `index`, clamped as `clampi(mission.chapter - 1, 0, 8)`. Verify this
   empirically against all 16 missions' actual `chapter` field values (1-8 for core, 9-16 for challenge) to
   confirm the mapping lands exactly where intended — don't assume the arithmetic without checking each one.

### Contract to preserve
The 8 core-campaign chapters (indices 0-7, `mission.chapter` 1-8): must resolve to the exact same recipes
as before — this is a refactor of the *selection mechanism*, not the core campaign's arenas. `RankSystem`
and `ChapterLandmark`: untouched, already correct. Every mission `.tres` file: untouched, no new fields
needed (`chapter` already exists and already has the right values for this to work).

### Verification
Headless: update `_test_chapter_arena_recipes` to `range(9)`/`fingerprints.size() == 9`. Update
`_test_challenge_missions`'s arena-clamp assertions (both the single `CORE_CAMPAIGN_LENGTH` check and the
M21-added loop over indices 12-15) to point at chapter 8 instead of chapter 7 — this is the deliberate
contract change this milestone exists to make, not a regression; update the assertion messages too so they
describe the new dedicated-arena reality rather than "reuses Sevenfold Ascent." Confirm the 8 core chapters'
fingerprints are unchanged (diff `recipe_for(0)` through `recipe_for(7)` against `main` before this
milestone — they should be byte-identical). `smoke_game.tscn`/`campaign_smoke.tscn`: must still pass.
**Manual play check, required**: load several challenge missions (at least one from M16, one from M21) and
confirm they now render the new dedicated arena, not Sevenfold Ascent; confirm all 6 objective primitives
function correctly in the new geometry (this is the first time some of these primitives run in this space);
confirm the core campaign's 8 chapters are visually unchanged; confirm collision/traversal in the new arena
works the same way every other chapter's `BoxShape3D` collision already does.

---

## Reporting back

Same standard as every round: plain pass/fail per verification item, name the specific file/function if
something's wrong, real manual play check required (arena traversal/readability is a felt check headless CI
cannot make), one PR for the whole M22 milestone.

---

## Outcome — merged

PR #30 was merged directly by the user on 2026-08-14, immediately after Claude Code opened it as a draft
and CI came back green on all three platforms (Windows/Linux/macOS).

**Difference from every prior milestone in this project:** this one was implemented by Claude Code itself,
not Codex. Codex had produced a local implementation twice (per its own handoff reports) but never
published it anywhere reachable — the branch was never pushed, so there was nothing to independently
review. Rather than wait for a third attempt, the user asked Claude Code to implement M22 directly. No
Godot binary was available in that sandbox, so the implementation was verified by hand (diff review,
manual geometry math against the central-clearance test rule) rather than by running the engine locally —
the real headless verification only happened once GitHub Actions ran on the pushed branch.

**Open item — not yet resolved, tracked here rather than assumed closed:** no human has played a challenge
mission in the new Covenant Gauntlet arena yet. CI confirms the geometry is structurally valid (test-passing
clearance, distinct fingerprint, correct per-mission arena selection); it says nothing about whether the
arena reads well, whether collision/traversal feels right in live combat, or whether enemy approach and
Host movement work sensibly around the four gates and lateral walls.
