# GARDEN RECLAIMED — Phase 2 Scope
### Built on top of v0.7.0 (Phase 1 / M1–M12 closed, `CLAUDE.md` invariants unchanged)

---

## Starting point

Phase 1 (`GARDEN_RECLAIMED_scope.md`, Part 5, M1–M12) is fully closed: every one of the 19 systems it
specified exists, there are zero `TODO(claude)` markers left in the tree, and CI runs 35 deterministic
tests plus gameplay/campaign/balance/export smoke checks. Phase 2 does not reopen that work. It adds
on top of it, following the same rule the original doc used for M11 ("no new systems written — content
only") wherever the milestone allows it, and treating any milestone that *does* need new code as a thin
addition wired through `EventBus`/`SettingsState`, never a rewrite of an existing autoload's contract.

## Milestones

| # | Milestone | Status | Touches | Why it's cheap here |
|---|---|---|---|---|
| **M13** | Difficulty select | **Done** | `autoload/settings_state.gd`, `autoload/corruption_director.gd`, `autoload/encounter_director.gd`, `ui/hud.gd` | Reuses the exact novice/skilled/expert tiers `tests/balance_sim.gd` already proves are fair — exposes them as a real setting instead of a test-only fixture |
| **M14** | Key rebind UI | **Done** | `autoload/settings_state.gd`, `autoload/event_bus.gd`, `ui/hud.gd` | `settings_state.gd` already had the persistence pattern (`ConfigFile`, `setting_update_requested`); this adds a `keybinds` section and a matching UI list, no new system |
| **M15** | New Game+ / Mastery mode | Proposed | `missions/mission_resource.gd` (new optional fields), `autoload/mission_director.gd` (read-only consumption) | Missions are pure data by design (S8/S19) — a harder purity target and an `ng_plus` flag are new fields read where `time_limit`/`target_purity` are already read, not a new code path |
| **M16** | Post-campaign challenge missions | Proposed | `missions/data/mission_09..12.tres` | Same reasoning the original doc used for M11: content only, composed from the 6 existing objective primitives, no seventh primitive |
| **M17** | Cross-platform export | Proposed | `export_presets.cfg`, CI legs alongside the existing Windows smoke pipeline | Godot's export system is already headless-verified for Windows in CI; adding Linux/macOS presets is config, not engine code |
| **M18** | Art/audio pass | Proposed | `world/chapter_arena.gd` (keep its recipe contract), `autoload/audio_director.gd` (keep its crossfade contract) | The original scope doc flagged art as "the only human-required deliverable." This is that line item, not a systems change — and it's explicitly the one milestone here that is *not* about minimizing rewrite, it's about spending the budget Phase 1 deliberately left untouched |

**Sequencing:** M13 → M14 → M17 first (cheap, low-risk, closes real gaps). M15 → M16 next (replayability
content, no new systems). M18 last, and scoped as its own project rather than a sprint — it's asset
production, not refactoring.

**Explicitly not in this scope:** multiplayer/co-op. Nothing in Phase 1 or in this list implies it, and it
would be the first change to force `EventBus` to become multi-peer-aware — a real architecture change, not
an additive one. Flag for a deliberate decision before it goes on any future list.

---

## M13 — Difficulty select (implemented)

- `SettingsState.DIFFICULTY_MULTIPLIERS` maps `novice`/`skilled`/`expert` → `0.75`/`1.0`/`1.3`, mirroring
  the efficiency profiles `balance_sim.gd` already simulates per mission.
- `SettingsState.difficulty_multiplier()` is read directly by `corruption_director.gd` (spread rate) and
  `encounter_director.gd` (wave cadence + territorial pressure intensity) — the same "autoload reads
  another autoload's plain data" pattern already used for `high_contrast`/`reduced_flash`/`screen_shake`.
- Persisted in the existing `garden_reclaimed_settings.cfg` under the `accessibility` section, same as
  every other setting.
- Selectable from the pause/settings panel as an `OptionButton`; changes apply on the next corruption
  tick and encounter tick, consistent with "changes save immediately."

## M14 — Key rebind UI (implemented)

- `SettingsState.REBINDABLE_ACTIONS` lists the 13 single-key keyboard actions (movement, jump, dash,
  pray, declare, legislate, reveal, ultimate, law prev/next). Mouse-bound actions (`fire`, `alt_fire`,
  `weapon_next/prev`) and the fixed numbered weapon row are intentionally left alone.
- `SettingsState.rebind_action()` edits Godot's live `InputMap` and persists to a new `keybinds` config
  section; `reset_key_binds()` restores the defaults captured at startup.
- New `EventBus.keybind_changed` signal, following the One Rule — nothing calls into another system
  directly to react to a rebind.
- HUD gained a "CONTROLS" list in the pause panel: click a row to arm it, press any key to commit. The
  settings panel is now wrapped in a `ScrollContainer` since the row count no longer fits the original
  fixed-height panel.
- Tests: `tests/run_tests.gd` gained `_test_difficulty_multiplier` and `_test_key_rebinding` (37 total,
  up from 35). Both were reviewed by hand — this environment has no Godot binary to run
  `godot --headless --path . res://tests/test_runner.tscn` locally, so please run the three verification
  scenes from `CLAUDE.md` before merging.
