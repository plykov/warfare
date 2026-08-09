class_name HostileProjectile
extends Node3D

var direction: Vector3 = Vector3.FORWARD
var speed: float = 12.0
var damage: float = 9.0
var kind: StringName = &"DEMON"
var holy: bool = false
var lifetime: float = 5.0
var _material: StandardMaterial3D

func configure(origin: Vector3, travel_direction: Vector3, travel_speed: float, impact_damage: float, source_kind: StringName) -> void:
	position = origin
	direction = travel_direction.normalized()
	speed = travel_speed
	damage = impact_damage
	kind = source_kind

func _ready() -> void:
	add_to_group("hostile_projectiles")
	_build_visual()
	EventBus.projectile_parry_requested.connect(_on_parry_requested)

func _physics_process(delta: float) -> void:
	if not GameState.is_playing():
		return
	lifetime -= delta
	position += direction * speed * delta
	if holy:
		for enemy: Node in get_tree().get_nodes_in_group("enemies"):
			if enemy is Node3D and (enemy as Node3D).global_position.distance_to(global_position) <= 0.85:
				EventBus.damage_requested.emit(enemy, damage * 1.8, &"sonic", global_position)
				EventBus.purification_requested.emit(global_position, 2.4, 0.25)
				EventBus.combat_feedback.emit(&"impact", global_position, Color(1.0, 0.72, 0.2), 2.0)
				queue_free()
				return
	else:
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player != null and player.global_position.distance_to(global_position) <= 0.85:
			EventBus.player_damage_requested.emit(damage, kind)
			EventBus.combat_feedback.emit(&"hit", global_position, Color(0.85, 0.05, 0.12), 1.0)
			queue_free()
			return
		if Vector2(global_position.x, global_position.z).length() <= 2.2:
			EventBus.thin_place_damage_requested.emit(damage * 0.8)
			queue_free()
			return
	if lifetime <= 0.0 or absf(global_position.x) > 38.0 or absf(global_position.z) > 30.0:
		queue_free()

func _on_parry_requested(parry_position: Vector3, radius: float, return_direction: Vector3) -> void:
	if holy or global_position.distance_to(parry_position) > radius:
		return
	holy = true
	direction = return_direction.normalized()
	speed *= 1.4
	_material.albedo_color = Color(1.0, 0.75, 0.22)
	_material.emission = Color(1.0, 0.4, 0.04)
	EventBus.projectile_deflected.emit(kind)
	EventBus.audio_requested.emit(&"declare")

func _build_visual() -> void:
	var orb := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	orb.mesh = mesh
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.55, 0.015, 0.08)
	_material.emission_enabled = true
	_material.emission = Color(0.8, 0.02, 0.1)
	_material.emission_energy_multiplier = 4.0
	orb.material_override = _material
	add_child(orb)
	var light := OmniLight3D.new()
	light.light_color = _material.emission
	light.light_energy = 1.8
	light.omni_range = 3.5
	add_child(light)
