extends Node

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

## Root cause of two previous "timing flake" fixes that only reduced rather
## than eliminated the failure rate (see PHASE2_SCOPE.md): this was never a
## synchronization bug. A frame-220 diagnostic capture on a real failing run
## showed the boss reaching phase 3 exactly as expected, then being fully
## defeated (queue_free()'d) by ambient incidental damage - not the test's
## scripted hit - sometime in the remaining ~140 frames. A defeated boss is
## a *stronger* success signal than "reached phase >= 2", not a failure; the
## bug was checking live node state at the very end instead of tracking what
## actually happened over the run. boss_state_changed/boss_defeated already
## fire everything needed - just listen instead of inspecting a node that
## may legitimately no longer exist.
var _boss_spawned: bool = false
var _boss_peak_phase: int = 0
var _boss_was_defeated: bool = false

func _ready() -> void:
	GameState._reset_for_test()
	GameState.unlocked_count = 8
	GameState.select_mission(7)
	EventBus.boss_spawn_requested.connect(func(_k: StringName, _t: String, _p: float) -> void: _boss_spawned = true)
	EventBus.boss_state_changed.connect(func(_title: String, _integrity: float, _maximum: float, phase: int) -> void: _boss_peak_phase = maxi(_boss_peak_phase, phase))
	EventBus.boss_defeated.connect(func(_kind: StringName) -> void: _boss_was_defeated = true)
	var game := MAIN_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	GameState.start_game()
	IntercessorSystem.start_prayer()
	for frame: int in range(360):
		if frame == 5:
			GameState.elapsed = 49.0
			EncounterDirector._tick = 0.0
		if frame == 30:
			EventBus.purification_requested.emit(Vector3.ZERO, 70.0, 0.72)
		if frame == 120:
			IntercessorSystem.declare()
			EventBus.rebuke_requested.emit(Vector3.ZERO, 80.0)
		if frame == 150:
			for enemy: Node in get_tree().get_nodes_in_group("enemies"):
				if enemy is FallenEnemy:
					EventBus.bind_requested.emit(enemy, 4.0)
				if enemy is SyntheticEnemy:
					EventBus.damage_requested.emit(enemy, 1000.0, &"kinetic", (enemy as Node3D).global_position)
		if frame == 220:
			for enemy: Node in get_tree().get_nodes_in_group("enemies"):
				if enemy is TerritorialPrince:
					EventBus.damage_requested.emit(enemy, 600.0, &"kinetic", (enemy as Node3D).global_position)
		await get_tree().process_frame
	if RankSystem.rank_index != 7:
		push_error("Final commission must manifest ONE OF THE SEVEN")
		get_tree().quit(1)
		return
	var boss_verified: bool = _boss_spawned and (_boss_peak_phase >= 2 or _boss_was_defeated)
	if not boss_verified:
		push_error("Final commission must spawn and phase an Accuser boss")
		get_tree().quit(1)
		return
	print("GARDEN RECLAIMED CAMPAIGN SMOKE: final commission mixed encounter ran 360 frames")
	game.queue_free()
	await get_tree().process_frame
	AudioDirector.shutdown()
	await get_tree().process_frame
	get_tree().quit(0)
