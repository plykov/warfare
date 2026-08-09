extends Node

const MAIN_SCENE: PackedScene = preload("res://main.tscn")

func _ready() -> void:
	var game := MAIN_SCENE.instantiate()
	add_child(game)
	await get_tree().process_frame
	GameState.start_game()
	for frame: int in range(300):
		if frame == 90:
			EventBus.purification_requested.emit(Vector3.ZERO, 5.0, 0.3)
		if frame == 150:
			IntercessorSystem.declare()
		await get_tree().process_frame
	print("GARDEN RECLAIMED SMOKE: gameplay ran 300 frames")
	game.queue_free()
	await get_tree().process_frame
	AudioDirector.shutdown()
	await get_tree().process_frame
	get_tree().quit(0)
