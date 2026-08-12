# GARDEN RECLAIMED — Phase 5 Scope
### Built on top of Phase 4 (M20a-c: viewmodel arms, offhand gestures, weapon silhouettes — merged)

---

## Starting point

Per explicit user direction, Phase 5 scopes **more content** — following the exact playbook M16 (Phase 2)
already established and proved out: "content only, composed from existing primitives, no new arena
geometry," the same reasoning the original Phase 1 doc used for M11. Read directly from the code, not
assumed:

- `GameState.MISSION_PATHS` currently holds 12 missions: 8 core campaign commissions
  (`GameState.CORE_CAMPAIGN_LENGTH = 8`) plus 4 M16 post-campaign challenge trials (missions 9-12).
- `world/chapter_arena.gd::recipe_for()` is hard-pinned to exactly 8 chapters —
  `tests/run_tests.gd::_test_chapter_arena_recipes` asserts `fingerprints.size() == 8` over `range(8)`.
  M16's challenge trials don't add new arenas; `chapter_arena.gd::rebuild()` calls
  `clampi(index, 0, 7)`, so mission 9 (index 8) clamps to chapter 7 (Sevenfold Ascent) and reuses its
  geometry exactly — confirmed directly by `_test_challenge_missions`'s own assertion:
  `ChapterArena.recipe_for(CORE_CAMPAIGN_LENGTH).size() == ChapterArena.recipe_for(7).size()`.
- Every mission is composed from exactly 6 locked objective primitives — `PURIFY_ZONE`,
  `RESTORE_THIN_PLACE`, `SURVIVE_WAVES`, `ESCORT_HOST`, `BIND_TARGET`, `BREAK_IDOL`
  (`missions/objectives/*.gd`) — dispatched by `mission_director.gd::_build_objectives()`'s `match`
  statement. `_test_challenge_missions` explicitly asserts every M16 mission's `objective_ids` stays inside
  this set: "must reuse the six locked objective primitives, not a new one."
- Bosses are pure data, not new classes: `enemies/territorial_prince.gd::configure(boss_kind, title, power)`
  takes any `StringName` kind — the 5 existing bosses (`PRINCE_OF_DELAY`, `VOICE_OF_THE_ABYSS`,
  `ACCUSE_THE_GROUND`, `PRINCE_OF_THE_LONG_NIGHT`, `THE_FINAL_ACCUSER`) are just tuned `MissionResource`
  fields (`boss_kind`, `boss_name`, `boss_trigger_seconds`/`boss_trigger_purity`, `boss_power`), not
  per-boss code. `_test_boss_catalog` asserts exactly 5 today.

**What this means for Phase 5:** the cheapest, safest, most consistent next content wave is a **second
post-campaign challenge pack** — more `MissionResource` `.tres` files appended to `MISSION_PATHS`, reusing
the 8 existing arenas via the same clamp mechanism, composed from the same 6 objective primitives, and
either reusing an existing `boss_kind` or authoring one new data-only boss the same way M16 added its two.
No engine code changes are required at all for the missions themselves — this is the M16 pattern run a
second time, on schedule with how this project already scales content.

## Milestone

| # | Milestone | Touches | Why it's cheap here |
|---|---|---|---|
| **M21** | Second challenge-trial pack | `missions/data/mission_13..16.tres`, `autoload/game_state.gd` (`MISSION_PATHS` extended) | Zero new engine code — same reasoning M16 already proved for missions 9-12: content only, composed from the 6 existing objective primitives, no new arena geometry, at most one new data-only boss |

**Explicitly not in this scope:** a 9th arena chapter (would need new `recipe_for()` geometry and break the
`fingerprints.size() == 8` test contract — a real decision to reopen, not assumed here), a 7th objective
primitive, multiplayer. If a genuinely new arena or mechanic is wanted later, that's a different, larger
decision than "more content" and should get its own scoping round.

---

## M21 — Second challenge-trial pack

### Steps
1. Author 4 new `MissionResource` `.tres` files (`missions/data/mission_13.tres` through `mission_16.tres`),
   following `mission_09.tres`–`mission_12.tres`'s exact schema (every field M16's missions set — corruption
   pattern/seed, full Intercessor cue timeline with ≥3 cues and non-empty dialogue lines, title, briefing,
   scripture reference, objective composition, all balance-relevant tuning fields). Reuse
   `tests/balance_sim.gd`'s existing efficiency profiles to sanity-check the new missions' `enemy_budget`/
   `enemy_power`/`spawn_interval`/`target_purity` tuning the same way every prior mission's numbers were
   checked — don't hand-guess balance numbers a simulation can verify.
2. Compose each mission's `objective_ids` from the 6 existing primitives only — `PURIFY_ZONE`,
   `RESTORE_THIN_PLACE`, `SURVIVE_WAVES`, `ESCORT_HOST`, `BIND_TARGET`, `BREAK_IDOL`. Vary the combination
   per mission the way missions 1-12 already do (single-objective early, multi-objective later) rather than
   repeating the same composition four times.
3. Each mission's `chapter` field should reuse one of the 8 existing chapters (pick whichever fits the
   mission's tone/briefing — this is just which of the 8 authored arenas gets clamped into use, not new
   geometry). Confirm empirically which chapter index each new mission's position in `MISSION_PATHS` clamps
   to via `chapter_arena.gd::rebuild()`'s `clampi(index, 0, 7)` — don't assume without checking, the M16
   missions' actual clamp target (chapter 7 for all four, since indices 8-11 all clamp to 7) may or may not
   be what's wanted for indices 12-15; verify the clamp math for the new indices before assuming variety.
4. Bosses: either reuse one of the 5 existing `boss_kind` values on one or more of the new missions (some
   M16 missions omit a boss entirely — not every mission needs one, check `boss_kind = &""` on missions
   without one), or author one new data-only boss following `configure(boss_kind, title, power)`'s existing
   contract — no new `TerritorialPrince` subclass or code path needed either way.
5. Append the 4 new paths to `GameState.MISSION_PATHS` (`mission_13.tres` through `mission_16.tres`).

### Contract to preserve
`ChapterArena.recipe_for()`'s 8 existing chapters: untouched, no 9th case added. The 6 objective
primitives: untouched, no 7th class added. `TerritorialPrince`: untouched, no new code path — a new boss is
purely `MissionResource` field values. `GameState.CORE_CAMPAIGN_LENGTH` stays `8` (M21 missions are a
second challenge wave, same category as M16's, not a core-campaign extension).

### Verification
Headless: extend the existing test pattern the same way `_test_challenge_missions` already covers
missions 9-12 — either broaden its `range(GameState.CORE_CAMPAIGN_LENGTH, GameState.MISSION_PATHS.size())`
loop to naturally cover 13-16 (likely needs no change at all if the loop already spans to
`MISSION_PATHS.size()`, only its distinct-fingerprint-count and boss-count assertions need updating for the
new totals), and update `_test_mission_catalog`'s size assertion (`== 12` today) and `_test_boss_catalog`'s
count assertion (`== 5` today) to their new totals. Confirm `tests/balance_sim.gd`'s 12-commission matrix
extends cleanly to whatever the new mission count is. **Manual play check, required** per this project's
standing rule for anything with real gameplay tuning: play through all 4 new missions, confirm the reused
arena reads sensibly for each mission's tone, confirm difficulty feels intentional relative to its position
in the challenge-trial progression (these should feel at least as demanding as missions 9-12, not a
regression), confirm any new boss behaves correctly under `configure()`'s existing power-scaling contract.

---

## Reporting back

Same standard as every round: plain pass/fail per verification item, name the specific file/function if
something's wrong, real manual play check required (balance/pacing is a felt judgment headless CI cannot
make), one PR for the whole M21 pack is fine here since it's a single coherent content wave, unlike the
prior phases' independent-technique sub-milestones.
