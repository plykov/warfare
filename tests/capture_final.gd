extends Node

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

func _ready() -> void:
	GameState._reset_for_test()
	GameState.unlocked_count = 8
	var mission_two_cells: Array[float] = []
	mission_two_cells.resize(CorruptionDirector.GRID_WIDTH * CorruptionDirector.GRID_HEIGHT)
	mission_two_cells.fill(0.86)
	for y: int in range(5, 13):
		for x: int in range(5, 15):
			mission_two_cells[y * CorruptionDirector.GRID_WIDTH + x] = 0.08 + float((x + y) % 3) * 0.04
	GameState.garden_states["1"] = {"cells": mission_two_cells, "purity": 0.76}
	GameState.select_mission(7)
	var game := MAIN_SCENE.instantiate()
	add_child(game)
	for _frame: int in range(20):
		await get_tree().process_frame
	GameState.start_game()
	EventBus.debug_spawn_requested.emit(&"FALLEN", 1)
	await get_tree().process_frame
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy is FallenEnemy:
			(enemy as Node3D).global_position = Vector3(4.5, 0.1, -6.0)
			break
	for _frame: int in range(270):
		await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://artifacts/final-gameplay.png")
	print("GARDEN RECLAIMED CAPTURE: final commission rendered")
	game.queue_free()
	await get_tree().process_frame
	AudioDirector.shutdown()
	await get_tree().process_frame
	get_tree().quit(0)
