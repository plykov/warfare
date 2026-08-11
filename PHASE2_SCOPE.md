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
| **M18** | Art/audio pass | **Done** (all of M18a-d + M18-art-1/2 + M18-audio-1/2 merged) | See breakdown below | Engine-side polish and all 4 asset sub-milestones shipped via CC0 packs (Kenney.nl + Freesound.org). One open item: user has not yet confirmed the M18-audio-2 subjective full-mission listen |

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
| **M18-engine** — shader/material/lighting/foliage polish | No — procedural only (`FastNoiseLite`, `NoiseTexture2D`, `ProceduralSkyMaterial`, hand-authored meshes) | **Done — M18a-d all merged** |
| **M18-art** — real 3D models/textures for arenas, weapons, characters | Yes — CC0 asset packs (decided) | Sourcing decided (Kenney.nl, CC0), sub-milestones scoped, implementation not started |
| **M18-audio** — real music stems, SFX, voice-over | Yes — CC0 audio libraries (decided) | Sourcing decided (Kenney.nl, CC0), sub-milestones scoped, implementation not started |

### M18-engine breakdown

| # | Item | Touches | Contract preserved |
|---|---|---|---|
| **M18a** | Shared corruption-mask shader | New `world/shaders/corruption.gdshader`; `autoload/corruption_director.gd` (publish an `R8` texture from `cells` instead of only holding the array); `main.gd` (ground tiles read the shader instead of getting per-tile `albedo_color` writes) | `CorruptionDirector.sample()`/`purify()`/`corrupt()` and every signal contract stay untouched — this is a rendering-layer swap under data that doesn't change. The `high_contrast` accessibility toggle becomes a shader uniform instead of a hardcoded branch, same visible behavior. **Done — CI-green and visually verified, see below.** |
| **M18b** | Procedural sky + purity-reactive lighting | `main.gd` (`Environment.background_mode` from flat `BG_COLOR` to `ProceduralSkyMaterial`, driven by the same purity value that already drives fog) | No new signals — reads the same `zone_purity`-derived values `main.gd` already computes for fog/ambient color. **Done** (PR #14, merged) — implemented by Codex, code-reviewed, CI-green on all 3 platforms. |
| **M18c** | Richer procedural materials on arena structures | `world/chapter_arena.gd`'s `_add_structure()` (add a runtime `FastNoiseLite`-driven normal/roughness detail pass to the existing `StandardMaterial3D`) | `ChapterArena.recipe_for()` — the actual geometry layout data every test and every mission asserts against — is untouched; only the material each box gets is richer. **Done** (PR #16, merged) — implemented by Codex; uses `NoiseTexture2D.as_normal_map` for a real generated normal map rather than the cheaper fake-normal-from-grayscale approach originally scoped, a correct improvement on the original ask. |
| **M18d** | Foliage mesh upgrade | `world/restoration_director.gd` (`_build_growth_field()`/`_build_legacy_field()`: replace the flat `PrismMesh` with a small hand-built bent-blade `ArrayMesh`, still procedural, still one draw call via `MultiMesh`) | `MultiMesh.instance_count`, the per-cell transform math, and the `restoration_feedback_changed`/`restoration_legacy_changed` signals are untouched — this only changes what mesh each instance is. **Done** (PR #15, merged) — implemented by Codex; correctly used `ArrayMesh.surface_set_material()` where the original scope's draft code had incorrectly suggested `PrimitiveMesh`-only API. |

**Sequencing:** M18a first — it's the one item that's arguably a Phase-1 spec gap, not new scope, and
everything downstream (shaders reacting to purity) benefits from the mask texture existing. M18b/M18c/M18d
after, independently orderable — confirmed independently orderable in practice: all three touched different
files (`main.gd`, `world/chapter_arena.gd`, `world/restoration_director.gd`), were built and reviewed as
three separate single-file PRs with zero merge conflicts between them, and all passed CI on all three
platforms before merge.

**Testing gap, stated plainly:** the project's `renderer/rendering_method` is `gl_compatibility` and CI runs
`--headless`, which does not exercise the GPU pipeline — a shader with a syntax error would not be caught
by `test_runner.tscn`, `smoke_game.tscn`, or `campaign_smoke.tscn`. `CLAUDE.md`'s "launch `main.tscn` for a
play check" step is not optional for this milestone the way it's a formality for pure-logic changes; it's
the only check that actually catches a broken shader.

**Gap closed, `main` commit `d2f7ade`:** manual play check performed with normal (non-headless) OpenGL
rendering on real hardware. Commission 01's ground rendered as lit terrain with a real corrupt→pure
gradient across the tile grid, not flat/unshaded/black/white; live purify and corrupt both updated visible
tile color within one field tick; the `HIGH-CONTRAST CORRUPTION` accessibility toggle switched the corrupt
color between its two documented values on screen; switching to Commission 10 correctly swapped the
pure-ground color to that mission's authored `garden_color`. No shader compile or renderer errors. This is
the confirmation the "testing gap" above was waiting on — M18a is fully verified, not just CI-green, and
M18b/M18c/M18d are unblocked.

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

## M18-art / M18-audio — all four sub-milestones done, one subjective gate open

**Sourcing decision:** CC0 asset packs, specifically [Kenney.nl](https://kenney.nl) — consistently CC0
across every pack checked, widely used in Godot projects, and low-poly enough to not clash with this
game's existing procedural-block aesthetic. Confirmed via web search rather than assumed:

- Art: [Nature Kit](https://kenney.nl/assets/nature-kit) (330 assets), [Foliage Pack](https://kenney.nl/assets/foliage-pack) (100), [Castle Kit](https://kenney.nl/assets/castle-kit) (75), [Fantasy Town Kit](https://kenney.nl/assets/fantasy-town-kit) (160), [Graveyard Kit](https://kenney.nl/assets/graveyard-kit) (90).
- Audio: [Impact Sounds](https://kenney.nl/assets/impact-sounds) (130), [RPG Audio](https://kenney.nl/assets/rpg-audio) (50), [UI Audio](https://kenney.nl/assets/ui-audio) (50), [Interface Sounds](https://kenney.nl/assets/interface-sounds) (100), [Sci-fi Sounds](https://kenney.nl/assets/sci-fi-sounds) (70).

**Sub-milestones**, ordered safest/highest-value first (full detail handed to Codex separately, not
duplicated here — see the sub-milestone summary below for what's load-bearing):

| # | Item | Why it's the safe one to start with | Status |
|---|---|---|---|
| **M18-art-1** | Foliage models in `RestorationDirector` | `MultiMesh` already takes one shared mesh for hundreds of instances — swapping the mesh source for an imported model is close to a one-value change, same shape as M18d | **Done** (PR #18, merged) — used Nature Kit instead of the scoped Foliage Pack after finding the latter was 2D; bundled license independently re-verified |
| **M18-audio-1** | Cue SFX in `AudioDirector` | `play_cue(kind)`'s `match` dispatch is a clean seam; real fix is additive (a pooled `AudioStreamPlayer` set for one-shots) alongside the existing ambient generator, not a rewrite of it | **Done** (PR #19, merged) — code-reviewed line-by-line before merge: headless guard correctly extends to the new player pool, idle-first/round-robin logic verified correct, new test genuinely asserts stream distinctness (not just non-null); CI green on all 3 platforms |
| **M18-audio-2** | Ambient bed replacement | Replaced the single `AudioStreamGenerator` ambient path with 5 looping `AudioStreamPlayer`s, each volume-driven by the *same formulas* that computed the synthesized layers' amplitudes | **Done** (PR #22, merged) — code-reviewed line-by-line: `ambient_gain_for()` is an exact port of the original per-layer gain math (`corrupt = (1-purity)*0.0035`, `pure = lerp(0.003,0.012,purity)`, `water = purity*0.0018`, `bird = purity*0.0028`, `legacy = legacy_strength*0.0045`, veiled → pure pinned to 0.0015 and everything else 0), converted to dB with an -80dB floor, never stop/restart (volume-only crossfade); headless guard correctly extended to the 5 new players; new `_test_ambient_asset_mapping` pins exact gain values, not just distinctness — a stronger test than M18-audio-1's. **Open item: the subjective full-mission listen-through has not been confirmed by the user.** Objective checks (looping, gain curve, crossfade smoothness, non-silence, seam level) all passed per Codex's report, but "do the 5 layers sound right together" is a taste call only the user can make — do not treat this as fully closed until they do one mission with audio on and confirm. |
| **M18-art-2** | Arena structure models in `ChapterArena` | Reused `_add_structure()`'s existing "stretch a mesh to fit an arbitrary box" contract with 3 Castle Kit props (wall/column/platform) non-uniformly scaled the same way | **Done** (PR #21, merged) — code-reviewed line-by-line: `_model_kind_for_size()` classifies every recipe box into wall/column/platform by proportion with a safe wall default (no unhandled case); `recipe_for()` and `_add_structure()`'s signature/`BoxShape3D` collision are byte-for-byte untouched, confirmed directly from the diff; rotation-then-scale-then-recenter ordering in `_model_visual_for_size()` is correct (rotation and scale are applied to the node before `visual.basis` is read for the recentering offset, so the offset reflects the final transform, not a stale one); per-kind `uv1_scale` (4.5/3.25/6.0) preserved. Real-GPU playcheck (Codex): 22/22 structures visual AABB == recipe size == collision size across chapters 1/4/7, 22/22 physics probes hit, rebuild time ~2.36ms avg (no regression vs. M18c's ~45ms baseline for the whole-arena rebuild). |

**Process requirements carried over from M18-engine, still binding:** no new signals should be needed for
any of this (pure consumers of state already published); confirm Godot's actual GLTF import behavior
empirically rather than assume it (this session's track record is specifically that unverified Godot API
assumptions have twice turned out wrong); the manual play check is required per sub-milestone, headless CI
cannot catch a wrong-scale or missing-texture asset any more than it could catch a broken shader; one PR
per sub-milestone.

**Process note — provenance-ledger conflicts across parallel sub-milestone branches:** M18-art-2 and
M18-audio-2 were developed as independent branches from the same `main` SHA, and both appended to
`assets/THIRD_PARTY_LICENSES.md`, so PR #22 conflicted after PR #21 merged first. Resolved additively
(merge `main` into the still-open branch, keep both provenance sections, reverify, push the merge commit)
— no provenance lost. Worth having sub-milestone branches rebase onto `main` before opening a PR in future
rounds where two art/audio branches are worked in parallel, to avoid the conflict rather than resolve it
after the fact.

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
the four new missions' purity targets). M13–M18a have since actually run — in CI (GitHub Actions, real
Godot 4.4.1 binaries on Windows/Linux/macOS runners) and, for M18a specifically, in a real non-headless
editor session with GPU rendering. Green throughout, but only after four reactive fixes, all of the same
shape — something that only breaks under real engine execution, never visible from code review alone:

1. macOS export needed `rendering/textures/vram_compression/import_etc2_astc=true` at the project level,
   not just the per-preset export option.
2. `RenderingServer.global_shader_parameter_get()` returns `Nil` for every parameter type under
   `--headless`, and `ImageTexture.get_image()` has the same readback problem — both discovered by CI, not
   guessed.
3. **`tests/campaign_smoke.gd`'s boss assertion — three attempts to diagnose, the first two wrong.**
   Attempt 1: assumed `EncounterDirector`'s tick cooldown (paced by real per-frame delta) meant the boss
   spawned too late; "fix" was to reset the tick and trust the engine's next scheduled frame. Attempt 2:
   assumed `TerritorialPrince.phase` (updated only inside its own `_physics_process()`, decoupled from the
   test's idle-frame loop) wasn't recalculating in time; "fix" was to force one synchronous
   `_physics_process(0.0)` call. Both looked correct, both reduced the observed failure rate, **neither was
   the actual bug** — proven when the identical "fixed" code failed the identical assertion again on a
   later CI run with zero changes in between, and a diagnostic-instrumented repro (Codex, ~1-in-30
   reproduction rate) showed the real sequence: the boss reliably spawns and reliably reaches phase 3 right
   on schedule (frame 220, exactly as the test intends) — then gets **fully defeated by ambient incidental
   damage** from the live encounter sometime in the ~140 frames after that, before the test's end-of-loop
   check. A defeated boss is a *stronger* success signal than "reached phase ≥ 2," not a failure. The actual
   bug: the test checked live node state at the very end instead of tracking what happened *during* the
   run — so when the boss was later defeated (a legitimate, expected outcome of a 360-frame mixed
   encounter), the check found no node and failed. Real fix: listen to `EventBus.boss_state_changed`
   (track peak phase reached) and `EventBus.boss_defeated` throughout the run instead of inspecting
   `get_tree().get_nodes_in_group("enemies")` only at the end. No production code changed — the two earlier
   "fixes" weren't wrong to leave in per se, they just weren't addressing anything real; both were removed
   as part of this correction since they added complexity without a purpose once the actual bug was found.

M18a's manual play check (see above) confirms the shader itself: reviewed by hand, passed headless CI, and
watched rendering on real hardware. But (3) is the one to actually internalize from this phase, and it cuts
deeper than "timing is hard": **a plausible-sounding mechanism, confirmed by a fix that measurably reduces
a failure rate, is not the same as a confirmed root cause.** Both of the first two campaign_smoke fixes had
a story that made sense, and both partially "worked" (lower flake rate) for a reason that had nothing to do
with why they seemed to work — they happened to also make the boss reach its damage/phase milestones
earlier in the run, which incidentally gave the *real* bug (later ambient defeat) less opportunity to
manifest before other, unrelated variance did. Reducing a flake rate is evidence a change did *something*;
it is not evidence the change fixed the thing you think it fixed. Get a direct diagnostic capture of an
actual failure before trusting a theory, especially the second time a "fix" doesn't fully hold.
