# GARDEN RECLAIMED — Phase 2 Scope
### Built on top of v0.7.0 (Phase 1 / M1–M12 closed, `CLAUDE.md` invariants unchanged)

---

## Starting point

Phase 1 (`GARDEN_RECLAIMED_scope.md`, Part 5, M1–M12) is fully closed: every one of the 19 systems it
specified exists, there are zero `TODO(claude)` markers left in the tree, and CI runs deterministic
tests plus gameplay/campaign/balance/export smoke checks. Phase 2 does not reopen that work. It adds
on top of it, following the same rule the original doc used for M11 ("no new systems written — content
only") wherever the milestone allows it, and treating any milestone that *does* need new code as a thin
addition wired through `EventBus`/`SettingsState`/`GameState`, never a rewrite of an existing autoload's
contract.

## Milestones

| # | Milestone | Status | Touches | Why it's cheap here |
|---|---|---|---|---|
| **M13** | Difficulty select | **Done** | `autoload/settings_state.gd`, `autoload/corruption_director.gd`, `autoload/encounter_director.gd`, `ui/hud.gd` | Reuses the exact novice/skilled/expert tiers `tests/balance_sim.gd` already proves are fair — exposes them as a real setting instead of a test-only fixture |
| **M14** | Key rebind UI | **Done** | `autoload/settings_state.gd`, `autoload/event_bus.gd`, `ui/hud.gd` | `settings_state.gd` already had the persistence pattern (`ConfigFile`, `setting_update_requested`); this adds a `keybinds` section and a matching UI list, no new system |
| **M15** | New Game+ / Mastery mode | **Done** | `autoload/game_state.gd`, `autoload/corruption_director.gd`, `autoload/encounter_director.gd`, `autoload/mission_director.gd`, `ui/hud.gd` | No new mission fields needed — NG+ is a single stacking multiplier consumed at the same read sites M13's difficulty setting already touches |
| **M16** | Post-campaign challenge missions | **Done** | `missions/data/mission_09..12.tres`, `autoload/game_state.gd` (`MISSION_PATHS` extended) | Same reasoning the original doc used for M11: content only, composed from the 6 existing objective primitives, no seventh primitive, no new arena geometry |
| **M17** | Cross-platform export | **Done** | `export_presets.cfg`, `scripts/verify.sh`, `scripts/build_export.sh`, `scripts/smoke_export.sh`, `.github/workflows/build.yml` | Godot's export system was already headless-verified for Windows in CI; this is config plus two new CI legs, not engine code |
| **M18** | Art/audio pass | Not started | `world/chapter_arena.gd` (keep its recipe contract), `autoload/audio_director.gd` (keep its crossfade contract) | The original scope doc flagged art as "the only human-required deliverable." This is that line item, not a systems change — and it's explicitly the one milestone here that is *not* about minimizing rewrite, it's about spending the budget Phase 1 deliberately left untouched. Needs an artist/asset pipeline decision from the team before code work starts |

**Explicitly not in this scope:** multiplayer/co-op. Nothing in Phase 1 or in this list implies it, and it
would be the first change to force `EventBus` to become multi-peer-aware — a real architecture change, not
an additive one. Flag for a deliberate decision before it goes on any future list.

---

## M13 — Difficulty select

- `SettingsState.DIFFICULTY_MULTIPLIERS` maps `novice`/`skilled`/`expert` → `0.75`/`1.0`/`1.3`, mirroring
  the efficiency profiles `balance_sim.gd` already simulates per mission.
- `SettingsState.difficulty_multiplier()` is read directly by `corruption_director.gd` (spread rate) and
  `encounter_director.gd` (wave cadence + territorial pressure intensity) — the same "autoload reads
  another autoload's plain data" pattern already used for `high_contrast`/`reduced_flash`/`screen_shake`.
- Persisted in the existing `garden_reclaimed_settings.cfg` under the `accessibility` section, same as
  every other setting. Selectable from the pause/settings panel as an `OptionButton`.

## M14 — Key rebind UI

- `SettingsState.REBINDABLE_ACTIONS` lists the 13 single-key keyboard actions (movement, jump, dash,
  pray, declare, legislate, reveal, ultimate, law prev/next). Mouse-bound actions (`fire`, `alt_fire`,
  `weapon_next/prev`) and the fixed numbered weapon row are intentionally left alone.
- `SettingsState.rebind_action()` edits Godot's live `InputMap` and persists to a new `keybinds` config
  section; `reset_key_binds()` restores the defaults captured at startup.
- New `EventBus.keybind_changed` signal, following the One Rule.
- HUD gained a "CONTROLS" list in the pause panel: click a row to arm it, press any key to commit. The
  settings panel is now wrapped in a `ScrollContainer` since the row count no longer fits the original
  fixed-height panel.

## M15 — New Game+ / Mastery mode

- `GameState.ng_plus_available()` is true once `completed_count() >= MISSION_PATHS.size()` — every core
  commission *and* every M16 challenge trial cleared at least once.
- `GameState.begin_new_game_plus()` advances `ng_plus_cycle`, resets `selected_mission`/`unlocked_count`/
  `completed` for a fresh run, and persists the cycle in the existing save file (backward compatible —
  old saves default to cycle 0).
- `GameState.ng_plus_multiplier()` returns `min(1.6, 1.0 + cycle * 0.15)`, stacked multiplicatively with
  `SettingsState.difficulty_multiplier()` in `corruption_director.gd` and `encounter_director.gd`, and
  used by `mission_director.gd` to tighten the anchor-fail threshold (`fail_corruption / multiplier`,
  floored at `0.55` so a mission never becomes mathematically unfailable-to-not-fail). Deliberately does
  *not* raise `target_purity` — that would risk breaking `balance_sim.gd`'s "expert profile can always
  meet the target" invariant, which Phase 1 treats as load-bearing.
- Title screen gains a "BEGIN NEW GAME+" button, hidden until unlocked.

## M16 — Post-campaign challenge missions

Four new `.tres` files (`mission_09` through `mission_12`), appended to `GameState.MISSION_PATHS`. Each
recombines the six locked objective primitives at higher `enemy_power`/`enemy_budget`/`corruption_bias`
than any core-campaign mission. Purity targets were hand-verified against `balance_sim.gd`'s exact
formula (not just eyeballed) so the "expert profile must be able to meet the target" and "expert > skilled
> novice" invariants hold for all three competence profiles on all four missions.

Both `RankSystem` and `ChapterArena` clamp mission chapter index to 7 (`ONE OF THE SEVEN` / Sevenfold
Ascent arena) for any chapter beyond 8 — this was existing clamp behavior, not new code, and it's the
right behavior here: post-campaign trials are ARIEL at full rank, replaying the final arena at higher
pressure, not a new zone. `mission_director.gd`, `corruption_director.gd`, and every other system that
reads `MISSION_PATHS.size()` needed no changes; only tests with a hardcoded mission count did (see below).

## M17 — Cross-platform export

- `export_presets.cfg` gained `Linux Desktop` and `macOS` presets alongside the existing `Windows Desktop`
  one, mirroring its options (`x86_64`, unsigned/no-notarization for now).
- New bash scripts (`scripts/verify.sh`, `scripts/build_export.sh`, `scripts/smoke_export.sh`) parallel the
  existing PowerShell ones. They're separate rather than a rewrite of the `.ps1` scripts because
  `Start-Process -WindowStyle Hidden` (used throughout the Windows scripts) is Windows-only even under
  PowerShell Core — trying to share one script across all three OSes would have meant branching internally
  on platform, which is more fragile than two short, boring scripts.
- `.github/workflows/build.yml` gained `linux-build` and `macos-build` jobs, structured identically to
  `windows-build`: verify → export → smoke-test the exported binary → upload artifact.
- **Caveat:** the export preset `platform=` values (`"Linux"`, `"macOS"`) are my best-documented match for
  Godot 4.4.x's renamed export platform IDs, but this sandbox has no Godot binary to confirm against — the
  authoritative source is what your local Godot 4.4.1 editor writes when you use its Add... button in the
  Export dialog. Please open the project in the editor once and diff `export_presets.cfg` before relying on
  these in CI.

## Test suite changes

`tests/run_tests.gd` went from 35 to 39 tests: `_test_difficulty_multiplier`, `_test_key_rebinding`,
`_test_challenge_missions`, `_test_new_game_plus`. Existing tests that hardcoded the old 8-mission count
(`_test_mission_catalog`, `_test_boss_catalog`, `_test_authored_corruption_layouts`) were updated to the
new count of 12 (or, for `_test_campaign_content_completeness`, scoped explicitly to
`GameState.CORE_CAMPAIGN_LENGTH` so it stays a pure historical record of the original locked 8-commission
arc rather than silently absorbing the new content). `tests/balance_sim.gd`'s pass message is now generated
from `MISSION_PATHS.size()` instead of a hardcoded "8", and `scripts/verify.ps1` / `scripts/smoke_windows.ps1`
/ `scripts/verify.sh` were updated to match both new pass markers.

**This sandbox has no Godot binary**, so none of this — M13 through M17 — has been run through
`godot --headless --path . res://tests/test_runner.tscn` or the other two verification scenes `CLAUDE.md`
requires. Everything was reviewed by hand (including a standalone Python re-implementation of
`balance_sim.gd`'s exact formula to validate the four new missions' purity targets), but please run the full
verification loop, and `scripts/verify.sh` / `scripts/verify.ps1`, before merging.
