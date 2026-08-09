class_name SlipperyField
extends Node3D

var radius: float = 3.0
var duration: float = 6.0
var _pulse: float = 0.0

func configure(at: Vector3, field_radius: float, field_duration: float) -> void:
	position = at
	radius = field_radius
	duration = field_duration

func _ready() -> void:
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.08
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.12, 0.22, 0.32, 0.44)
	material.emission_enabled = true
	material.emission = Color(0.06, 0.16, 0.3)
	material.emission_energy_multiplier = 2.0
	material.roughness = 0.08
	mesh_instance.material_override = material
	add_child(mesh_instance)

func _process(delta: float) -> void:
	duration -= delta
	_pulse -= delta
	if _pulse <= 0.0:
		_pulse = 0.25
		for enemy: Node in get_tree().get_nodes_in_group("enemies"):
			if enemy is Node3D and (enemy as Node3D).global_position.distance_to(global_position) <= radius:
				EventBus.slow_requested.emit(enemy, 0.5, 0.42)
	if duration <= 0.0:
		queue_free()
