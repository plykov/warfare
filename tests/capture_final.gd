extends Node

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

func _ready() -> void:
	GameState._reset_for_test()
	GameState.unlocked_count = 8
	GameState.select_mission(7)
	var game := MAIN_SCENE.instantiate()
	add_child(game)
	for _frame: int in range(20):
		await get_tree().process_frame
	GameState.start_game()
	for _frame: int in range(100):
		await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://artifacts/final-gameplay.png")
	print("GARDEN RECLAIMED CAPTURE: final commission rendered")
	game.queue_free()
	await get_tree().process_frame
	AudioDirector.shutdown()
	await get_tree().process_frame
	get_tree().quit(0)
