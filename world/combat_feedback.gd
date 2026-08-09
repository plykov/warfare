extends Node3D

func _ready() -> void:
	EventBus.combat_feedback.connect(_on_feedback)

func _on_feedback(kind: StringName, position: Vector3, tint: Color, strength: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var count: int = 8 if kind == &"synthetic_ricochet" else (6 if kind == &"deflect" else 1)
	for index: int in range(count):
		_spawn_effect(kind, position, tint, strength, index, count)

func _spawn_effect(kind: StringName, position: Vector3, tint: Color, strength: float, index: int, count: int) -> void:
	var effect := MeshInstance3D.new()
	if kind in [&"deflect", &"synthetic_ricochet"]:
		var spark := BoxMesh.new()
		spark.size = Vector3(0.025, 0.025, 0.72 if kind == &"synthetic_ricochet" else 0.52)
		effect.mesh = spark
		var angle: float = TAU * float(index) / float(maxi(1, count))
		effect.rotation = Vector3(angle * 0.3, angle, angle * 0.65)
		effect.global_position = position + Vector3(cos(angle), 0.25, sin(angle)) * 0.18
	elif kind == &"host_return":
		var column := CylinderMesh.new()
		column.top_radius = 0.34
		column.bottom_radius = 0.75
		column.height = 5.0
		effect.mesh = column
		effect.global_position = position + Vector3.UP * 2.0
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		effect.mesh = sphere
		effect.global_position = position
	var material := StandardMaterial3D.new()
	var reduced_flash: bool = bool(SettingsState.get_value(&"reduced_flash"))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(tint, 0.32 if reduced_flash else 0.75)
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 1.0 if reduced_flash else 3.5
	effect.material_override = material
	add_child(effect)
	var scale_factor: float = 0.35 if reduced_flash else (0.5 if kind == &"zone" else 0.16)
	var final_scale: float = clampf(strength * scale_factor, 0.4, 7.0) * (0.7 if kind in [&"deflect", &"synthetic_ricochet"] else 1.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector3.ONE * final_scale, 0.22)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.24)
	tween.set_parallel(false)
	tween.tween_callback(effect.queue_free)
