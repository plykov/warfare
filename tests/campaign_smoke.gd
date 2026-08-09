extends Node

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

func _ready() -> void:
	GameState._reset_for_test()
	GameState.unlocked_count = 8
	GameState.select_mission(7)
	var game := MAIN_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	GameState.start_game()
	IntercessorSystem.start_prayer()
	for frame: int in range(360):
		if frame == 5:
			GameState.elapsed = 49.0
			# EncounterDirector's boss-trigger check only runs on its own 0.5s
			# tick, which is paced by real per-frame delta - "reset the tick
			# and wait for the next engine frame" turned out to still be a
			# timing race (observed passing 10/10 locally and on 3-platform CI
			# once, then failing on a later identical-code CI run). Call
			# _process() synchronously instead so the check - and the boss
			# spawn it triggers - happens on this exact statement, not on
			# whatever the engine's next scheduled frame turns out to be.
			EncounterDirector._tick = 0.0
			EncounterDirector._process(0.0)
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
					# TerritorialPrince.phase only advances inside its own
					# _physics_process(), which runs on the engine's independent
					# physics schedule - decoupled from this idle-frame loop, and
					# not guaranteed to fire again before the loop ends. Force one
					# synchronous update so the phase check below isn't a second
					# timing race layered on top of the boss-spawn one above.
					(enemy as TerritorialPrince)._physics_process(0.0)
		await get_tree().process_frame
	if RankSystem.rank_index != 7:
		push_error("Final commission must manifest ONE OF THE SEVEN")
		get_tree().quit(1)
		return
	var prince := get_tree().get_first_node_in_group("enemies") as EnemyBase
	var boss_verified: bool = false
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy is TerritorialPrince:
			prince = enemy as EnemyBase
			boss_verified = (enemy as TerritorialPrince).phase >= 2
			break
	if not boss_verified or prince == null:
		push_error("Final commission must spawn and phase an Accuser boss")
		get_tree().quit(1)
		return
	print("GARDEN RECLAIMED CAMPAIGN SMOKE: final commission mixed encounter ran 360 frames")
	game.queue_free()
	await get_tree().process_frame
	AudioDirector.shutdown()
	await get_tree().process_frame
	get_tree().quit(0)
