class_name CombatFeedbackDirector
extends Node3D

func _ready() -> void:
	EventBus.combat_feedback.connect(_on_feedback)

func _on_feedback(kind: StringName, position: Vector3, tint: Color, strength: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var count: int = instance_count_for(kind)
	for index: int in range(count):
		_spawn_effect(kind, position, tint, strength, index, count)

static func instance_count_for(kind: StringName) -> int:
	match kind:
		&"restoration_burst": return 12
		&"synthetic_ricochet": return 8
		&"deflect": return 6
		&"law_grid": return 4
		&"authority_ring": return 3
		_: return 1

func _spawn_effect(kind: StringName, position: Vector3, tint: Color, strength: float, index: int, count: int) -> void:
	var effect := MeshInstance3D.new()
	if kind in [&"deflect", &"synthetic_ricochet", &"restoration_burst"]:
		var spark := BoxMesh.new()
		var spark_length: float = 1.2 if kind == &"restoration_burst" else (0.72 if kind == &"synthetic_ricochet" else 0.52)
		spark.size = Vector3(0.025, 0.025, spark_length)
		effect.mesh = spark
		var angle: float = TAU * float(index) / float(maxi(1, count))
		effect.rotation = Vector3(angle * 0.3, angle, angle * 0.65)
		var radius: float = 0.5 if kind == &"restoration_burst" else 0.18
		effect.position = position + Vector3(cos(angle), 0.25, sin(angle)) * radius
	elif kind == &"prayer_column":
		var column := CylinderMesh.new()
		column.top_radius = 0.18
		column.bottom_radius = 0.62
		column.height = 6.5
		effect.mesh = column
		effect.position = position + Vector3.UP * 3.0
	elif kind == &"authority_ring":
		var ring := TorusMesh.new()
		ring.inner_radius = 0.72 + index * 0.42
		ring.outer_radius = ring.inner_radius + 0.07
		effect.mesh = ring
		effect.position = position + Vector3.UP * (0.12 + index * 0.08)
	elif kind == &"law_grid":
		var bar := BoxMesh.new()
		bar.size = Vector3(8.0, 0.04, 0.08)
		effect.mesh = bar
		effect.rotation.y = PI * 0.5 if index >= 2 else 0.0
		var lane: float = -2.1 if index % 2 == 0 else 2.1
		effect.position = position + (Vector3(0.0, 0.08, lane) if index < 2 else Vector3(lane, 0.08, 0.0))
	elif kind == &"host_return":
		var column := CylinderMesh.new()
		column.top_radius = 0.34
		column.bottom_radius = 0.75
		column.height = 5.0
		effect.mesh = column
		effect.position = position + Vector3.UP * 2.0
	else:
		var sphere := SphereMesh.new()
		sphere.radius = 0.08
		sphere.height = 0.16
		effect.mesh = sphere
		effect.position = position
	var material := StandardMaterial3D.new()
	var reduced_flash: bool = bool(SettingsState.get_value(&"reduced_flash"))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(tint, 0.32 if reduced_flash else 0.75)
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 1.0 if reduced_flash else 3.5
	effect.material_override = material
	add_child(effect)
	var scale_factor: float = 0.35 if reduced_flash else (0.5 if kind in [&"zone", &"restoration_burst"] else 0.16)
	var final_scale: float = clampf(strength * scale_factor, 0.4, 7.0) * (0.7 if kind in [&"deflect", &"synthetic_ricochet"] else 1.0)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect, "scale", Vector3.ONE * final_scale, 0.22)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.24)
	tween.set_parallel(false)
	tween.tween_callback(effect.queue_free)
