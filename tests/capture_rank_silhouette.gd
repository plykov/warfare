extends Node3D

func _ready() -> void:
	_build_stage()
	var messenger := RankManifestation.new()
	messenger.name = "MessengerAtFiftyMeters"
	messenger.position = Vector3(-5.6, 0.0, 0.0)
	add_child(messenger)
	var seventh := RankManifestation.new()
	seventh.name = "OneOfTheSevenAtFiftyMeters"
	seventh.position = Vector3(3.2, 0.0, 0.0)
	add_child(seventh)
	# Let RankSystem's deferred startup announcement settle before assigning the
	# two independent comparison profiles.
	for _frame: int in range(5):
		await get_tree().process_frame
	messenger._rebuild(0)
	seventh._rebuild(7)
	for _frame: int in range(45):
		await get_tree().process_frame
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png("res://artifacts/rank-1-vs-rank-8-50m.png")
	print("GARDEN RECLAIMED CAPTURE: rank 1 and rank 8 rendered at 50m")
	AudioDirector.shutdown()
	await get_tree().process_frame
	get_tree().quit(0)

func _build_stage() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.006, 0.009, 0.012)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.28, 0.34, 0.42)
	environment.ambient_light_energy = 1.35
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-38.0, -24.0, 0.0)
	light.light_color = Color(0.72, 0.82, 1.0)
	light.light_energy = 2.2
	add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 3.2, 50.0)
	camera.fov = 19.0
	add_child(camera)
	camera.look_at(Vector3(0.0, 1.6, 0.0), Vector3.UP)
	camera.current = true
