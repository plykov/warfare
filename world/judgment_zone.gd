class_name JudgmentZone
extends Node3D

var duration: float = 3.5
var radius: float = 5.0
var damage_per_pulse: float = 7.0
var damage_type: StringName = &"zone"
var tint: Color = Color(0.8, 0.1, 0.04)
var purification: float = 0.18
var _pulse: float = 0.0

func _ready() -> void:
	var ring := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.05
	ring.mesh = mesh
	ring.position.y = 0.04
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(tint, 0.22)
	material.emission_enabled = true
	material.emission = tint
	material.emission_energy_multiplier = 1.5
	ring.material_override = material
	add_child(ring)
	EventBus.combat_feedback.emit(&"zone", global_position, tint, radius)

func _physics_process(delta: float) -> void:
	if not GameState.is_playing():
		return
	duration -= delta
	_pulse -= delta
	if _pulse <= 0.0:
		_pulse = 0.45
		for enemy: Node in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy is Node3D and (enemy as Node3D).global_position.distance_to(global_position) <= radius:
				EventBus.damage_requested.emit(enemy, damage_per_pulse, damage_type, (enemy as Node3D).global_position)
		EventBus.purification_requested.emit(global_position, radius, purification)
	if duration <= 0.0:
		queue_free()
