extends Node

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

func _ready() -> void:
	var game := MAIN_SCENE.instantiate()
	add_child(game)
	for _frame: int in range(20):
		await get_tree().process_frame
	_capture("res://artifacts/title.png")
	GameState.start_game()
	for _frame: int in range(90):
		await get_tree().process_frame
	_capture("res://artifacts/gameplay.png")
	print("GARDEN RECLAIMED CAPTURE: title and gameplay rendered")
	game.queue_free()
	await get_tree().process_frame
	AudioDirector.shutdown()
	await get_tree().process_frame
	get_tree().quit(0)

func _capture(path: String) -> void:
	var image: Image = get_viewport().get_texture().get_image()
	var error: Error = image.save_png(path)
	if error != OK:
		push_error("Failed to save capture: %s" % path)
