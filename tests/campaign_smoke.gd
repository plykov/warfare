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
		await get_tree().process_frame
	if RankSystem.rank_index != 7:
		push_error("Final commission must manifest ONE OF THE SEVEN")
		get_tree().quit(1)
		return
	print("GARDEN RECLAIMED CAMPAIGN SMOKE: final commission mixed encounter ran 360 frames")
	game.queue_free()
	await get_tree().process_frame
	AudioDirector.shutdown()
	await get_tree().process_frame
	get_tree().quit(0)
