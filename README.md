# Garden Reclaimed

A playable Godot 4.4 campaign slice of a Quake-style FPS where death has been relocated from the player to the ground.

You are **ARIEL**, a Seraph-class servant-warrior. Incoming damage drains Glory instead of health. At zero Glory ARIEL becomes **Veiled**: slower, dimmed, and unable to purify the garden. Corruption keeps spreading, and the mission fails only if it reclaims the Thin Place at the garden's heart.

## Play

Open `project.godot` in Godot 4.4.1 and run the project.

- `WASD` move; mouse look; `Space` jump/hold to ascend; `Shift` Ophanim Dash
- `1–0`, `[` and `]` equip all twelve armaments; wheel cycles
- Left mouse fires; right mouse uses alternate fire
- Hold `Q` to Pray; `E` to Declare a Commission Token; `R` to Legislate `GROUND_HOLDS`
- `F` reveals tactical state; `Esc` releases/captures the mouse

The campaign includes eight data-driven commissions using the six locked objective primitives: Purify Zone, Restore Thin Place, Bind Target, Survive Waves, Escort Host, and Break Idol. Each chapter changes ARIEL's manifested rank, objectives, enemy mix, pressure, palette, landmark, and scripture framing.

Progress is saved automatically. Completed commissions unlock the next chapter and leave a persistent restoration advantage in later runs. The playable systems include Quake movement, Glory/Veiled hysteresis, all twelve armaments, spreading corruption, Thin Place defense, all three Intercessor verbs, token-gated Fallen, purification-immune Synthetics, automatic Host reinforcement, eight visible rank manifestations, territorial outcomes, synthesized audio, and headless tests.

## Campaign

1. The First Ground — learn purification and territorial failure.
2. The Watcher's Vigil — restore a weakened Thin Place.
3. The Prince's Delay — survive and pray the Host through.
4. The Rebuke — receive authority, Rebuke, and bind a Fallen.
5. Altar Fire — answer a fabricated idol with kinetic force.
6. Voice of Many — combine survival, restoration, and reinforcement.
7. War in Heaven — fight mirror and idol together.
8. The Seventh Stands — hold all six objective verbs in one commission.

## Verification

```powershell
godot --headless --path . res://tests/test_runner.tscn
godot --headless --path . res://tests/smoke_game.tscn
godot --headless --path . res://tests/campaign_smoke.tscn
```
