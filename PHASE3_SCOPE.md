# GARDEN RECLAIMED — Phase 3 Scope
### Built on top of Phase 2 (M13–M18 closed, `CLAUDE.md` invariants unchanged)

---

## Starting point

Phase 2 (`PHASE2_SCOPE.md`) is closed: difficulty select, key rebind, New Game+, challenge missions,
cross-platform export, and the full M18 art/audio pass (engine-side shader/sky/blade work plus all four
sourced-asset sub-milestones) are all merged into `main`. One Phase 2 item remains open and is tracked
there, not here: user confirmation of the M18-audio-2 subjective full-mission listen.

Phase 3's direction, per explicit user decision: a **polish/accessibility pass**, not new content or new
systems. Everything below is additive to `SettingsState`/`ui/hud.gd`'s existing settings-panel pattern —
no new autoloads, no new signals beyond what a new setting needs, no rewrite of an existing contract.

## Milestones

| # | Milestone | Touches | Why it's cheap here |
|---|---|---|---|
| **M19a** | FOV / comfort slider | `player/player.tscn`, `player/player_controller.gd`, `autoload/settings_state.gd`, `ui/hud.gd` | Camera FOV is currently a fixed `92.0` in the scene file with no setting behind it at all — this is the single cheapest, most standard FPS comfort/accessibility option missing from the panel |
| **M19b** | Independent SFX / ambient volume | `autoload/audio_director.gd`, `autoload/settings_state.gd`, `ui/hud.gd` | M18-audio-1/2 already split cue playback and ambient beds into two separate player pools (`_cue_players` vs `_ambient_players`) driven only by `master_volume` today — exposing independent multipliers for each is a read-site change, not new plumbing |
| **M19c** | Colorblind-safe corruption palette | `world/shaders/corruption.gdshader`, `autoload/corruption_director.gd`, `autoload/settings_state.gd`, `ui/hud.gd` | `high_contrast` already proves the exact mechanism needed — a bool global shader parameter driving a `ternary` color swap in `corruption.gdshader`. This adds one more palette variant through the identical mechanism, not a new one |

**Explicitly not in this scope:** new gameplay systems, new content (chapters/missions/weapons), multiplayer.
Those were the other options offered and not chosen. If balance retuning based on real playtest data becomes
relevant later, that's a separate decision — nothing here assumes it.

---

## M19a — FOV / comfort slider

### Current state
`player/player.tscn` sets `Camera3D.fov = 92.0` as a scene-authored constant. Nothing reads or writes it at
runtime. This is also the standard "reduce motion sickness" lever for FPS games, missing entirely from the
settings panel that already has `mouse_sensitivity`, `screen_shake`, `reduced_flash`.

### Steps
1. Add `&"fov": 92.0` to `SettingsState.DEFAULTS`.
2. In `player_controller.gd`, on `_ready()` (or wherever it already reads `SettingsState.values` for
   `mouse_sensitivity` — reuse that exact pattern) set `camera.fov = float(SettingsState.get_value(&"fov"))`,
   and connect to whatever signal `mouse_sensitivity` changes are already consumed through (check how a live
   `mouse_sensitivity` change during play currently reaches the controller — this should be the identical
   wiring, not a new signal).
3. Add `_add_slider_setting(stack, "FIELD OF VIEW", &"fov", 70.0, 110.0, 1.0)` to `_build_settings_panel()`
   (or whatever the current function is named) in `ui/hud.gd`, right next to `AIM SENSITIVITY`.

### Contract to preserve
Invariant 4 (air acceleration uncapped) is a movement-physics concern; FOV is purely a camera/rendering
value and must not touch `player_controller.gd`'s movement math at all — if implementing this touches
anything beyond `camera.fov` assignment, that's a sign of scope creep, stop and reconsider.

### Verification
Headless: existing test suite should be unaffected (no test currently asserts on FOV — if one needs adding,
a simple `SettingsState.get_value(&"fov")` default-value + range-clamp test is enough, matching the pattern
of `_test_difficulty_multiplier`). **Manual play check**: confirm the slider actually changes the visible
FOV in real time, confirm it persists across a restart, confirm values at both extremes (70 and 110) don't
break HUD/weapon-viewmodel layout.

---

## M19b — Independent SFX / ambient volume

### Current state
`audio_director.gd`'s `_on_settings_changed()` computes one `master_db` from `master_volume` and applies it
to both `_cue_players` (with an added `CUE_GAIN_DB` offset) and, per `_update_ambient_levels()` (added in
M18-audio-2), to the ambient bed players via `ambient_gain_for()` converted to dB. There is currently no way
to turn down music/ambience without also turning down hit/cue sounds, or vice versa — a common accessibility
need (e.g., players who rely on cue audio for gameplay feedback but find continuous ambient beds fatiguing).

### Steps
1. Add `&"sfx_volume": 1.0` and `&"ambient_volume": 1.0` to `SettingsState.DEFAULTS` — these are
   *multipliers on top of* `master_volume`, not replacements for it (matches how `CUE_GAIN_DB` already
   layers on top of `master_db` today).
2. In `audio_director.gd`, thread an additional `linear_to_db(maxf(sfx_volume, 0.0001))` term into the cue
   player volume calc in both `_on_settings_changed()` and `play_cue()` (both currently recompute
   `master_db + CUE_GAIN_DB` — check both sites, don't fix only one).
3. Thread `linear_to_db(maxf(ambient_volume, 0.0001))` into `_update_ambient_levels()`'s per-bed dB
   calculation, additive with the existing `master_db` and the `ambient_gain_for()`-derived level — same
   principle, an extra multiplier layered on the existing formula, not a replacement of it.
4. Add two more `_add_slider_setting()` rows to the settings panel: `"SFX VOLUME"` /
   `&"sfx_volume"`, `"AMBIENT VOLUME"` / `&"ambient_volume"`, range `0.0`–`1.0`, step `0.05`, matching
   `MASTER VOLUME`'s existing row.

### Contract to preserve
`master_volume` must keep working as an overall multiplier exactly as it does today — a player who never
touches the two new sliders should hear identical output to before this milestone (both new sliders default
to `1.0`, a no-op multiplier). `ambient_gain_for()`'s pure function and its existing test
(`_test_ambient_asset_mapping`) must not change — the new volume layer is applied on top of its output, not
inside it.

### Verification
Headless: existing audio tests (`_test_ambient_asset_mapping`, whatever cue-mapping test M18-audio-1 added)
must still pass unchanged since the headless guard means none of this runs without a real audio device
anyway — but a new pure-function-level test asserting the multiplier math (e.g., that `sfx_volume = 0.0`
drives cue volume to the floor while ambient is unaffected, and vice versa) is worth adding, following the
`ambient_gain_for()` static-function-is-directly-testable pattern. **Manual play check**: confirm each
slider audibly and independently affects only its own category, confirm `0.0` on either doesn't fully mute
the other, confirm defaults sound identical to before this milestone.

---

## M19c — Colorblind-safe corruption palette

### Current state
`corruption.gdshader` has exactly one accessibility color path today:
```glsl
global uniform bool corruption_high_contrast;
...
vec3 corrupt_color = corruption_high_contrast ? vec3(0.42, 0.0, 0.52) : vec3(0.006, 0.002, 0.009);
```
driven by `corruption_director.gd` reading `SettingsState.values.get(&"high_contrast", false)` and pushing it
through `RenderingServer.global_shader_parameter_set()`. The corrupt/pure gradient is the game's primary
diegetic feedback signal (mission progress, purity state) — for red-green colorblind players specifically,
a corrupt(purple)-to-pure(likely green-ish, verify by reading the rest of the shader) gradient risks losing
contrast exactly where it matters most.

### Steps
1. **Read the rest of `corruption.gdshader` first** to find every place a corrupt/pure color pair is chosen
   (the diff snippet above is one example, not necessarily the only one — grep the whole file, don't assume
   scope from a partial read).
2. Add `&"colorblind_safe": false` to `SettingsState.DEFAULTS`.
3. Add a second global shader bool `corruption_colorblind_safe`, wired through `corruption_director.gd` the
   identical way `corruption_high_contrast` already is (same `global_shader_parameter_add`/`_set` call
   pair, same settings-changed read site).
4. In the shader, extend each existing ternary to a 3-way choice (colorblind-safe palette takes priority
   over high-contrast if a player somehow enables both, or make the two mutually exclusive in the UI — your
   call, but pick one and document why in the PR). Choose an actual colorblind-safe pair (e.g., blue/orange
   instead of purple/green — verify with a real colorblind-simulation check, don't guess a palette and call
   it done; there are free online simulators for protanopia/deuteranopia/tritanopia, use one on a screenshot
   of both states).
5. Add `_add_toggle_setting(stack, "COLORBLIND-SAFE PALETTE", &"colorblind_safe")` next to the existing
   `HIGH-CONTRAST CORRUPTION` row.

### Contract to preserve
`corruption_high_contrast`'s existing behavior and test (`_test_corruption_shader_globals`) must be
unaffected when `colorblind_safe` is off (the default) — this is purely additive, a new global parameter
alongside the existing one, not a replacement.

### Verification
Headless: extend `_test_corruption_shader_globals` the same way it presumably already asserts on
`corruption_high_contrast`'s registration, for the new `corruption_colorblind_safe` parameter — same
CPU-side-`Image`-bypass pattern documented in `PHASE2_SCOPE.md` for why this test doesn't trust
`RenderingServer` readback. **Manual play check, required**: confirm the palette swap is visually distinct
from both the default and high-contrast states, and ideally run a real colorblind-simulation pass on
screenshots (not just "looks different to me") before calling this done — this is explicitly an
accessibility feature, so getting the actual color science right matters more than it does for a purely
aesthetic choice.

---

## Reporting back

Same standard as every round: plain pass/fail per verification item, name the specific file/function if
something's wrong, real manual play check required for M19a/c (visual) and M19b (audio) — headless CI
cannot verify any of these three end-to-end. One PR per sub-milestone.
