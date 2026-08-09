# Garden Reclaimed — Agent Instructions

## Engine

Godot 4.4, GDScript. Never introduce C# or GDExtension without asking.

## The One Rule

Systems communicate through `EventBus` signals only. If system A needs to tell system B something, emit on `EventBus`; do not call across systems directly.

## Invariants

1. ARIEL cannot die. Damage drains Glory and causes Veiled state at zero.
2. Mission failure is territorial or Pride-based, never player death.
3. Weapons never reload and all twelve are carried at once.
4. Air acceleration is uncapped so strafe-jump speed gain is preserved.
5. Fallen are damage-immune until Rebuked under a Commission Token.
6. Synthetics ignore purification damage.
7. Host members withdraw rather than die.

## Verification

Run all three checks before claiming completion:

```text
godot --headless --path . res://tests/test_runner.tscn
godot --headless --path . res://tests/smoke_game.tscn
godot --headless --path . res://tests/campaign_smoke.tscn
```

Then launch `main.tscn` for a play check.
