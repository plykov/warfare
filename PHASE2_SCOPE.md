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
| **M18** | Art/audio pass | **Scoped, engine-side track approved** | See breakdown below | Splits into an asset-free "engine-side polish" track (approved, scoped below) and two asset-dependent tracks (art assets, audio assets) that stay blocked pending a source/budget decision |

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

## M18 — Art/audio pass (scoped, not yet built)

Investigated the actual rendering/audio code before writing anything down, rather than assume the
original scope doc's design was what shipped. It wasn't, in one load-bearing way:

- **Geometry** is procedural `BoxMesh` primitives (`world/chapter_arena.gd`). "Foliage"
  (`world/restoration_director.gd`) is tinted `PrismMesh` blades on a `MultiMeshInstance3D` — not plant
  models.
- **There are zero `.gdshader` files in the repo.** The original Phase-1 doc's S7 spec called for a
  shared corruption-mask texture read by one global shader uniform ("one texture, one uniform, every
  material reads it"). That was never built. What actually ships instead: `main.gd` sets a per-tile
  `StandardMaterial3D.albedo_color` on every individual ground `MeshInstance3D` directly in script. It
  works, but it's the one place Phase 1's own design doc and Phase 1's own code disagree — closing that
  gap is M18a below.
- **Audio** (`autoload/audio_director.gd`) is 100% synthesized sine/harmonic tones via
  `AudioStreamGenerator`. No `.ogg`/`.wav` files anywhere.
- **`assets/`** contains exactly one file: the title-screen key art PNG.

That last point is why "art/audio pass" isn't one milestone-sized decision — it's three, and only one is
gradeable without a human sourcing decision first:

| Track | Needs external assets? | Status |
|---|---|---|
| **M18-engine** — shader/material/lighting/foliage polish | No — procedural only (`FastNoiseLite`, `NoiseTexture2D`, `ProceduralSkyMaterial`, hand-authored meshes) | **Approved, scoped below** |
| **M18-art** — real 3D models/textures for arenas, weapons, characters | Yes — artist commission or a sourced/generated asset pack | Deferred pending a source/budget decision |
| **M18-audio** — real music stems, SFX, voice-over | Yes — licensed library, composer, or AI-generated audio | Deferred pending a source/budget decision |

### M18-engine breakdown

| # | Item | Touches | Contract preserved |
|---|---|---|---|
| **M18a** | Shared corruption-mask shader | New `world/shaders/corruption.gdshader`; `autoload/corruption_director.gd` (publish an `R8` texture from `cells` instead of only holding the array); `main.gd` (ground tiles read the shader instead of getting per-tile `albedo_color` writes) | `CorruptionDirector.sample()`/`purify()`/`corrupt()` and every signal contract stay untouched — this is a rendering-layer swap under data that doesn't change. The `high_contrast` accessibility toggle becomes a shader uniform instead of a hardcoded branch, same visible behavior. **Done.** |
| **M18b** | Procedural sky + purity-reactive lighting | `main.gd` (`Environment.background_mode` from flat `BG_COLOR` to `ProceduralSkyMaterial`, driven by the same purity value that already drives fog) | No new signals — reads the same `zone_purity`-derived values `main.gd` already computes for fog/ambient color. |
| **M18c** | Richer procedural materials on arena structures | `world/chapter_arena.gd`'s `_add_structure()` (add a runtime `FastNoiseLite`-driven normal/roughness detail pass to the existing `StandardMaterial3D`) | `ChapterArena.recipe_for()` — the actual geometry layout data every test and every mission asserts against — is untouched; only the material each box gets is richer. |
| **M18d** | Foliage mesh upgrade | `world/restoration_director.gd` (`_build_growth_field()`/`_build_legacy_field()`: replace the flat `PrismMesh` with a small hand-built bent-blade `ArrayMesh`, still procedural, still one draw call via `MultiMesh`) | `MultiMesh.instance_count`, the per-cell transform math, and the `restoration_feedback_changed`/`restoration_legacy_changed` signals are untouched — this only changes what mesh each instance is. |

**Sequencing:** M18a first — it's the one item that's arguably a Phase-1 spec gap, not new scope, and
everything downstream (shaders reacting to purity) benefits from the mask texture existing. M18b/M18c/M18d
after, independently orderable.

**Testing gap, stated plainly:** the project's `renderer/rendering_method` is `gl_compatibility` and CI runs
`--headless`, which does not exercise the GPU pipeline — a shader with a syntax error would not be caught
by `test_runner.tscn`, `smoke_game.tscn`, or `campaign_smoke.tscn`. `CLAUDE.md`'s "launch `main.tscn` for a
play check" step is not optional for this milestone the way it's a formality for pure-logic changes; it's
the only check that actually catches a broken shader.

### M18a implementation notes

- `world/shaders/corruption.gdshader` computes UV from world-space X/Z against `corruption_world_origin`/
  `corruption_world_size`, matching `CorruptionDirector.cell_to_world()`'s math — the two need to stay in
  sync if either changes.
- `CorruptionDirector._register_shader_globals()` registers `corruption_mask` (sampler2D),
  `corruption_world_origin`/`corruption_world_size` (vec3/vec2), `corruption_pure_color` (vec3, set from
  the active mission's `garden_color`), and `corruption_high_contrast` (bool, mirrors the existing
  accessibility setting) via `RenderingServer.global_shader_parameter_add/set` at `_ready()` — done in code
  rather than in project.godot's `[shader_globals]` section, since that section's serialization format
  can't be verified against a real Godot binary in this environment, whereas `RenderingServer` calls are
  ordinary GDScript that the headless test suite already exercises.
- The `corruption_mask` texture (`R8`, `GRID_WIDTH`×`GRID_HEIGHT`) republishes every corruption tick
  (`_emit_state()`, ~4.5 Hz) via `ImageTexture.set_image()` — same cadence the old per-tile CPU loop ran
  at, but now it's one texture upload instead of writing `albedo_color`/`emission` on up to 475 individual
  `StandardMaterial3D` instances every tick.
- `main.gd`'s `_build_corruption_tiles()` now assigns **one shared `ShaderMaterial`** to every ground tile
  (previously each tile got its own `StandardMaterial3D`); `_on_corruption_changed()` only still does
  per-cell CPU work for the small bloom-prop `MultiMesh` scaling, which this milestone didn't touch.
- Removed now-dead code this left behind: `main.gd`'s `_garden_color` var (only read by the coloring loop
  that no longer exists) and its no-op `_on_settings_changed` handler (the high-contrast reaction now lives
  in `CorruptionDirector._on_settings_changed_for_shader`).
- **Confirmed finding, not speculation — two rounds of it.** CI caught that
  `RenderingServer.global_shader_parameter_get()` returns `Nil` under `--headless` on all three platforms
  (Linux, macOS, Windows) — for every parameter, including plain `Vector2`/`Vector3` ones, not just the
  `sampler2D`. `global_shader_parameter_add()`/`set()` never errored, so registration itself isn't the
  problem; the readback specifically is unreliable headlessly. The first fix rerouted the test through
  `ImageTexture.get_image()` instead — which turned out to have the *same class* of problem: dimensions
  checked out against the image `create_from_image()` was seeded with, but pixel data written via a second
  `set_image()` call didn't come back through `get_image()`. `tests/run_tests.gd`'s
  `_test_corruption_shader_globals` now asserts against `CorruptionDirector._mask_image` directly — the
  plain CPU-side `Image` it writes to via `set_pixel()`, before the texture or RenderingServer layer is
  involved at all — which sidesteps both unreliable round-trips.
  `Image.create()`/`ImageTexture.create_from_image()`/`ImageTexture.set_image()` and the underlying
  `set_pixel()`/`get_pixel()` calls all work fine headlessly; it's specifically reading *back out* through
  the texture/RenderingServer layer that doesn't. Whether the shader itself actually receives correct
  values through `global_shader_parameter_add()`'s default-value argument and the `set()` calls when a real
  GPU renderer is attached is still an open question the manual play check needs to answer — two rounds of
  CI failures on the readback side are a reason for more caution here, not less.

## Test suite changes

`tests/run_tests.gd` went from 35 to 40 tests: `_test_difficulty_multiplier`, `_test_key_rebinding`,
`_test_challenge_missions`, `_test_new_game_plus`, `_test_corruption_shader_globals`. Existing tests that
hardcoded the old 8-mission count (`_test_mission_catalog`, `_test_boss_catalog`,
`_test_authored_corruption_layouts`) were updated to the new count of 12 (or, for
`_test_campaign_content_completeness`, scoped explicitly to `GameState.CORE_CAMPAIGN_LENGTH` so it stays a
pure historical record of the original locked 8-commission arc rather than silently absorbing the new
content). `tests/balance_sim.gd`'s pass message is now generated from `MISSION_PATHS.size()` instead of a
hardcoded "8", and `scripts/verify.ps1` / `scripts/smoke_windows.ps1` / `scripts/verify.sh` were updated to
match all current pass markers.

**This sandbox has no Godot binary**, so nothing here was run locally through
`godot --headless --path . res://tests/test_runner.tscn` before being pushed — everything was reviewed by
hand first (including a standalone Python re-implementation of `balance_sim.gd`'s exact formula to validate
the four new missions' purity targets). M13–M17 have since actually run in CI (GitHub Actions, real Godot
4.4.1 binaries on Windows/Linux/macOS runners) and are green after two reactive fixes: the macOS export
needed `rendering/textures/vram_compression/import_etc2_astc=true` at the project level, not just the
per-preset export option, and `tests/campaign_smoke.gd` had a latent timing flake (`EncounterDirector`'s
boss-trigger tick paced by real per-frame delta, which varies between the debug editor run and the exported
release binary) that surfaced on the Windows exported-build smoke check. M18a is pushed but its CI result
isn't confirmed as of this writing — watch for the same class of issue (something that only breaks under
real engine execution, not code review) before treating it as done.
