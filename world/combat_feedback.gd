extends Node3D

func _ready() -> void:
	EventBus.combat_feedback.connect(_on_feedback)

func _on_feedback(kind: StringName, position: Vector3, tint: Color, strength: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var effect := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	effect.mesh = mesh
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
	var final_scale: float = clampf(strength * scale_factor, 0.4, 7.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector3.ONE * final_scale, 0.22)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.24)
	tween.set_parallel(false)
	tween.tween_callback(effect.queue_free)
