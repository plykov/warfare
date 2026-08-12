# GARDEN RECLAIMED — Phase 4 Scope
### Built on top of Phase 3 (M19a–c: FOV/comfort, split audio volume, colorblind palette — scoped, not yet built)

---

## Starting point

The reference images the user provided show the target first-person feel: armored bronze/gold gauntlet
forearms, a real held weapon (flaming sword) in the right hand, an empty raised left hand mid-gesture, and
the world's existing corrupt(purple fog/black roots)-to-pure(green grass/gold flowers) gradient framing the
shot. The world-side half of that gradient is already shipped (`corruption.gdshader`, M18a). **What's
missing is the viewmodel itself.**

Current state, read directly from the code, not assumed:
- `player/player.tscn`'s entire first-person visual is one `MeshInstance3D` named `WeaponModel`, a bare
  `BoxMesh` (either a `0.04×0.58×0.04` thin blade shape or a `0.15×0.12×0.54` blunt shape) tinted per
  weapon by `weapon_manager.gd::_equip()`. There are no arms, no hands, no gauntlets, and nothing in the
  left half of the screen at all.
- `weapons/weapon_manager.gd` already fully owns weapon state (12 `WeaponResource`s loaded from
  `weapons/data/*.tres`, each with a `tint`, `weapon_id`, `display_name`, `role`) and already switches
  `weapon_model.mesh`/`.material_override`/`.position`/`.rotation` per weapon in `_equip()`. This milestone
  extends that function's visual richness, it does not replace its ownership of weapon state.
- `player/rank_manifestation.gd` already solved "armored bronze/gold ARIEL" for the third-person
  manifestation body: `_body_material.albedo_color = Color(0.78, 0.76, 0.67).lerp(Color(0.72, 0.47, 0.16),
  _rank / 12.0)` — that exact bronze `(0.72, 0.47, 0.16)` is the same metal tone in the reference images'
  gauntlets. Reuse this color language for the viewmodel arms rather than inventing a new palette; it's
  already the game's established "ARIEL's armor" color, and reusing it keeps first-person and third-person
  visually consistent for free.
- `autoload/event_bus.gd` already publishes everything a left-hand gesture needs to react to without any
  new signals: `prayer_started`/`prayer_stopped` (Q), `declaration_issued`/`declaration_denied` (E),
  `legislation_commit_requested`/`law_enacted` (R), `weapon_fired`, `weapon_switched`, `combat_feedback`.

## Milestones

| # | Milestone | Touches | Why this order |
|---|---|---|---|
| **M20a** | Viewmodel arms/gauntlets | `player/player.tscn`, `weapons/weapon_manager.gd` | Pure geometry/material addition framing the existing weapon mesh — no new assets required, reuses `RankManifestation`'s bronze material approach; unblocks everything else visually before any asset sourcing starts |
| **M20b** | Left-hand cast gesture | `weapons/weapon_manager.gd` or a new small `player/offhand_controller.gd`, wired via existing `EventBus` signals only | Depends on M20a's left arm/hand existing; purely a pose/animation state machine over signals that already fire, no new gameplay state |
| **M20c** | Twelve distinct handheld weapon silhouettes | `weapons/weapon_manager.gd`, `assets/models/weapons/` | Depends on M20a's hand anchor point existing to attach props to; needs real asset sourcing (CC0), so it's sequenced after the free geometry work, same reasoning M18-art-1 before M18-art-2 used |

**Explicitly not in this scope:** melee swing/attack animations, weapon-specific firing VFX beyond what
`combat_feedback`/`weapon_fired` already drive, any change to `WeaponResource` data or the 12 weapons'
balance numbers. This is a visual-fidelity pass on an unchanged weapon system, not a weapon-system redesign
— Invariant 3 (all twelve manifestations carried at once, never reload) is unaffected by anything here.

---

## M20a — Viewmodel arms/gauntlets

### Technique
Build the arms the same procedural way `rank_manifestation.gd` already builds ARIEL's third-person body —
primitive meshes (capsules/cylinders for forearm segments, a box or sphere for a gauntlet cuff), not an
imported rig — so this milestone needs zero new assets and zero new import pipeline. Two
`MeshInstance3D`-based arm assemblies parented under `Head/Camera3D` (siblings of the existing
`WeaponManager` node, or children of it — your call, but keep `WeaponManager`'s existing node path
(`$WeaponModel`, `$MuzzleLight`) intact so `weapon_manager.gd` doesn't need touching for this step):
- **Right arm**: positioned/rotated to visually connect the existing `WeaponModel` mesh to a forearm and
  hand, i.e., the weapon now reads as *held* rather than floating. The existing weapon position/rotation
  per weapon type (`_equip()`'s two position/rotation branches) stays the anchor point; the arm is built to
  reach that point, not the other way around.
- **Left arm**: mirrored position, empty hand (open palm), idle-resting pose by default (M20b animates it).

### Steps
1. Add an arm-building helper (static or instance method, your call) producing a small hierarchy: upper
   forearm segment, wrist/gauntlet cuff (the bronze-tinted accent piece — see reference images' teal-gem
   cuff detail, optional nice-to-have, not required for a correct M20a), hand. Bandage-wrap texture detail
   from the reference images is a nice-to-have via the shared noise/detail texture pattern
   (`chapter_arena.gd::_shared_detail_texture()` already established this pattern for procedural surface
   detail — reuse it rather than reinventing, same as M18c did).
2. Material: reuse `RankManifestation`'s bronze/gold lerp approach directly — either call into a shared
   static helper if one gets factored out, or duplicate the specific color constants (your call on
   DRY vs. simplicity here, it's a handful of `Color` values, not a system).
3. Position both arms relative to `Camera3D` so they read correctly in the FOV range M19a will make
   adjustable (70°–110°) — check the arms don't clip weirdly at either FOV extreme once M19a lands (order
   dependency: if M20a ships before M19a, come back and check this once M19a merges).
4. Leave `weapon_manager.gd::_equip()`'s weapon-mesh logic untouched in this step; only add the arms framing
   it.

### Contract to preserve
`WeaponManager`'s public behavior (`_equip()`, `_fire()`, `EventBus.weapon_switched`/`weapon_fired` emission)
is completely unchanged — this milestone only adds geometry around the existing weapon mesh, it doesn't
touch weapon logic at all.

### Verification
Headless: `smoke_game.tscn`/`campaign_smoke.tscn` crash-check only, same as every visual milestone this
phase — headless CI cannot judge whether arms look right. **Manual play check, required**: confirm both
arms are visible and don't clip through the camera's near plane (`near = 0.05` today) or occlude the HUD,
confirm the right arm reads as holding the weapon rather than the weapon floating separately, cycle through
all 12 weapons and confirm the arm doesn't look wrong for the two existing mesh-shape branches, check FOV
extremes once M19a is available.

---

## M20b — Left-hand cast gesture

### Technique
A small state machine (2-4 named poses is enough: idle, praying, declaring/legislating, deflecting) driven
entirely by existing `EventBus` signals — no new signals needed. Something like:
```gdscript
EventBus.prayer_started.connect(func() -> void: _set_offhand_pose(&"praying"))
EventBus.prayer_stopped.connect(func() -> void: _set_offhand_pose(&"idle"))
EventBus.declaration_issued.connect(func(_token, _dur) -> void: _play_offhand_pulse(&"declare"))
EventBus.legislation_commit_requested.connect(func(_zone) -> void: _play_offhand_pulse(&"legislate"))
```
Poses can be as simple as a target rotation/position the hand `lerp`s toward each `_process()` tick (matches
`weapon_manager.gd`'s existing `recoil` lerp-toward-zero pattern — reuse that exact idiom, don't add a new
animation system/`AnimationPlayer` for what a few `lerp()` calls already cover elsewhere in this codebase).
A brief emissive pulse on the palm (reuse `RankManifestation`'s `OmniLight3D` "ManifestationFire" pattern at
a much smaller scale) sells "casting" without needing any new VFX system.

### Contract to preserve
No new `EventBus` signals — every trigger this needs already exists and is already published by
`intercessor_system.gd`/`pride_system.gd`/whatever currently emits `declaration_issued` etc. (verify the
actual emitter file before wiring, don't assume from the signal name alone).

### Verification
Headless: crash-check only. **Manual play check, required**: trigger each of Pray/Declare/Legislate in a
real mission and confirm the left hand visibly reacts within the same beat as the existing audio cue/HUD
message for that action (they should feel simultaneous, not offset), confirm the idle pose doesn't look
stiff/frozen when no ability is active for an extended period.

---

## M20c — Twelve distinct handheld weapon silhouettes

### Technique
Same non-uniform-scale-a-CC0-prop-to-fit technique M18-art-2 already proved out for arena structures,
applied to hand-held props instead of static-body structures: source a small number of representative CC0
prop meshes (a blade, a rod/wand, a horn/trumpet shape, a bowl/vessel, a chain/ring — the 12 weapons
naturally cluster into fewer silhouette families than 12, look at `weapons/data/*.tres`'s `display_name`s
directly to group them before sourcing anything) from a pack like Kenney's
[Weapon Pack](https://kenney.nl/assets/weapon-pack) or similar (verify CC0 licensing empirically the same
way every prior art milestone did — do not assume a pack's license without checking its actual license
file, this project has been burned by assuming pack contents before, see M18-art-1's Foliage-Pack-was-2D
correction in `PHASE2_SCOPE.md`). Attach each prop to the right hand's anchor point from M20a, replacing the
current two-shape `BoxMesh` fallback in `_equip()`.

### Contract to preserve
`weapon.tint` per weapon stays the emissive/albedo accent color applied to whichever prop is equipped
(same as today's box-mesh tinting) — the silhouette changes, the color language doesn't. `_equip()`'s
signature and every call site (`weapon_next`/`weapon_prev`/`weapon_%d` input handling) unchanged.

### Verification
Headless: crash-check only, plus keep whatever weapon-catalog test already exists passing unchanged.
**Manual play check, required**: cycle all 12 weapons in a real mission, confirm each has a visually
distinct, readable silhouette (not just a recolor), confirm nothing clips through the arm/camera at any
weapon's specific position/rotation offset, confirm switching is instant with no pop-in stutter (this
project's Invariant 3 — no reload — means switching happens on every single number-key/scroll press, so any
jank here is highly visible, more than a one-time load would be for most games).

---

## Reporting back

Same standard as every round: plain pass/fail per verification item, real manual play check required for
all three sub-milestones (this entire phase is visual-fidelity work, headless CI has nothing to say about
any of it), one PR per sub-milestone. M20a should land and get a real play check before M20b/M20c start,
since both depend on its arm/hand anchor geometry existing and looking right first.
