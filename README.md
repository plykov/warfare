# Garden Reclaimed

A playable Godot 4.4 campaign slice of a Quake-style territorial FPS where death has been relocated from the player to the ground.

You are **ARIEL**, a Seraph-class servant-warrior. Incoming damage drains Glory instead of health. At zero Glory ARIEL becomes **Veiled**: slower, dimmed, and unable to purify the garden. Corruption keeps spreading, and the mission fails only if it reclaims the Thin Place at the garden's heart.

## v0.4.0 — Authority and Arenas

- Territorial legislation now offers three selectable, persistent laws: Ground Holds, No Unclean Entry, and No Hidden Thing.
- Fallen and territorial princes fire visible hostile ordnance; Flaming Sword alternate fire parries it back as holy damage.
- Demons, Fallen, and Synthetics now have explicit objective, engagement, and repositioning profiles.
- Censer converts Fervency into blast power, Inkhorn seals Host allies, Bow creates slowing terrain, Key binds longer, and Chariot gains a charged ram.
- All eight commissions form distinct traversable arena silhouettes, from Watcher steps to the Sevenfold ascent.
- CI runs 25 deterministic unit tests plus gameplay, campaign, balance, exported-executable, and Windows package checks.

## v0.3.0 — The Living Garden

- Exact per-commission corruption fields, territorial laws, and Pride now persist in save schema v3 and return on replay.
- A GPU-instanced growth field blooms from purified cells while fog, lighting, and generated ambience respond continuously to restoration.
- Every ARIEL rank now has a named doctrine, weapon tier, ward value, character line, and mechanical identity.
- One of the Seven can spend a Commission Token on Sevenfold Judgment with `X`.
- Backtick opens an interactive field console; CI runs 20 deterministic tests and a 24-scenario campaign balance simulation.

## v0.2.0 — Thrones and Restoration

- True pause with persistent aim, volume, screen-shake, UI-scale, high-contrast, reduced-flash, and subtitle preferences.
- Twelve tactically distinct manifestations with named counterplay, alternate expressions, knockback, lingering judgment fields, hit confirmation, and procedural impact feedback.
- A wave-pressure director and three multi-phase territorial princes in Commissions 3, 6, and 8.
- A restoration ledger with attempts, clears, best time, best purity, replay status, and automatic migration from v0.1 saves.
- Fifteen deterministic tests plus gameplay, final-campaign, exported-executable, and Windows package smoke checks.

## Play

Open `project.godot` in Godot 4.4.1 and run the project, or download the Windows build from Releases.

- `WASD` move; mouse look; `Space` jump/hold to ascend; `Shift` Ophanim Dash
- `1`–`0`, `[` and `]` equip all twelve armaments; the wheel cycles
- Left mouse fires; right mouse uses the alternate expression
- Hold `Q` to Pray; `E` to Declare; `Z`/`C` select a territorial law and `R` enacts it
- `F` reveals tactical state; `Esc` pauses and opens accessibility settings
- `X` invokes Sevenfold Judgment at the final rank; backtick opens the field console

The campaign includes eight data-driven commissions using six locked objective primitives: Purify Zone, Restore Thin Place, Bind Target, Survive Waves, Escort Host, and Break Idol. Each chapter changes ARIEL's manifested rank, objectives, enemy mix, pressure, palette, landmark, and scripture framing.

Progress and settings are saved automatically. Completed commissions unlock the next chapter and preserve that commission's exact restored ground and enacted laws. Existing v0.1 and v0.2 progress migrates automatically to save schema v3.

## Campaign

1. The First Ground — learn purification and territorial failure.
2. The Watcher's Vigil — restore a weakened Thin Place.
3. The Prince's Delay — survive the Host's delay and overthrow its territorial prince.
4. The Rebuke — receive authority, Rebuke, and bind a Fallen.
5. Altar Fire — answer a fabricated idol with kinetic force.
6. Voice of Many — combine survival, restoration, reinforcement, and a counterfeit throne.
7. War in Heaven — fight mirror and idol together.
8. The Seventh Stands — hold all six objective verbs and defeat the Accuser at the Gate.

## Windows build

Install Godot 4.4.1 and its matching export templates, then create a release build from PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/build_windows.ps1 -Godot "C:\path\to\godot.exe"
```

The executable is written to `build/Garden-Reclaimed.exe`. Every pull request also produces a `Garden-Reclaimed-Windows` artifact after the exported executable passes its smoke tests.

## Verification

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File ./scripts/verify.ps1 -Godot "C:\path\to\godot.exe"
```
