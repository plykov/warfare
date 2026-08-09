class_name EnemyBase
extends CharacterBody3D

var kind: StringName = &"DEMON"
var max_integrity: float = 55.0
var integrity: float = 55.0
var speed: float = 3.7
var attack_damage: float = 8.0
var attack_interval: float = 0.8
var tint: Color = Color(0.45, 0.02, 0.02)
var scale_factor: float = 1.0
var bound_remaining: float = 0.0
var marked_remaining: float = 0.0
var _attack_cooldown: float = 0.0
var _pulse: float = 0.0
var _body_material: StandardMaterial3D
var _last_damage_type: StringName = &"purify"
var ai_state: StringName = &"SEEK_OBJECTIVE"
var spreads_corruption: bool = true
var uses_projectiles: bool = false
var projectile_damage: float = 9.0
var projectile_speed: float = 12.0
var projectile_interval: float = 1.5
var _ranged_cooldown: float = 0.0
var _no_unclean_entry: bool = false
var _no_hidden_thing: bool = false
var _slow_remaining: float = 0.0
var _slow_scale: float = 1.0

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 3
	_build_body()
	EventBus.damage_requested.connect(_on_damage_requested)
	EventBus.bind_requested.connect(_on_bind_requested)
	EventBus.mark_requested.connect(_on_mark_requested)
	EventBus.impulse_requested.connect(_on_impulse_requested)
	EventBus.zone_laws_changed.connect(_on_zone_laws_changed)
	EventBus.slow_requested.connect(_on_slow_requested)
	_on_zone_laws_changed(IntercessorSystem.zone_laws)

func _physics_process(delta: float) -> void:
	if not GameState.is_playing():
		return
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_ranged_cooldown = maxf(0.0, _ranged_cooldown - delta)
	_slow_remaining = maxf(0.0, _slow_remaining - delta)
	if _slow_remaining <= 0.0:
		_slow_scale = 1.0
	bound_remaining = maxf(0.0, bound_remaining - delta)
	marked_remaining = maxf(0.0, marked_remaining - delta)
	if _no_hidden_thing and kind == &"FALLEN":
		marked_remaining = INF
	_pulse += delta
	_update_visual()

	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -0.2
	if bound_remaining <= 0.0:
		var player: Node3D = get_tree().get_first_node_in_group("player") as Node3D
		var player_distance: float = global_position.distance_to(player.global_position) if player != null else INF
		var next_state: StringName = &"ENGAGE_PLAYER" if player_distance < 7.5 else (&"REPOSITION" if uses_projectiles and player_distance < 17.0 else &"SEEK_OBJECTIVE")
		if _no_unclean_entry and kind == &"DEMON" and Vector2(global_position.x, global_position.z).length() < 8.5:
			next_state = &"REPOSITION"
		_set_ai_state(next_state)
		var target_position: Vector3 = Vector3.ZERO
		if ai_state == &"ENGAGE_PLAYER" and player != null:
			target_position = player.global_position
		elif ai_state == &"REPOSITION":
			var radial := Vector3(global_position.x, 0.0, global_position.z).normalized()
			target_position = global_position + radial * 4.0 + Vector3(-radial.z, 0.0, radial.x) * 2.5
		var direction: Vector3 = target_position - global_position
		direction.y = 0.0
		if direction.length_squared() > 0.1:
			direction = direction.normalized()
			velocity.x = direction.x * speed * _slow_scale
			velocity.z = direction.z * speed * _slow_scale
			look_at(global_position + direction, Vector3.UP)
		if uses_projectiles and player != null and player_distance > 3.2 and player_distance < 18.0 and _ranged_cooldown <= 0.0:
			_ranged_cooldown = projectile_interval
			var shot_direction: Vector3 = (player.global_position + Vector3.UP - (global_position + Vector3.UP * 1.4)).normalized()
			EventBus.hostile_projectile_requested.emit(global_position + Vector3.UP * 1.4, shot_direction, projectile_speed, projectile_damage, kind)
	else:
		velocity.x = move_toward(velocity.x, 0.0, delta * 15.0)
		velocity.z = move_toward(velocity.z, 0.0, delta * 15.0)
	move_and_slide()

	var player_node: Node3D = get_tree().get_first_node_in_group("player") as Node3D
	if player_node != null and global_position.distance_to(player_node.global_position) < 1.65 and _attack_cooldown <= 0.0:
		_attack_cooldown = attack_interval
		EventBus.player_damage_requested.emit(attack_damage, kind)
		EventBus.enemy_attack_landed.emit(kind)
	elif Vector2(global_position.x, global_position.z).length() < 2.7 and _attack_cooldown <= 0.0:
		_attack_cooldown = attack_interval
		EventBus.thin_place_damage_requested.emit(attack_damage * 0.7)
	if spreads_corruption:
		EventBus.corruption_requested.emit(global_position, 1.55, delta * 0.11)

func can_take_damage(damage_type: StringName) -> bool:
	return damage_type != &"utility" and damage_type != &"mark"

func _on_damage_requested(target: Node, amount: float, damage_type: StringName, hit_position: Vector3) -> void:
	if target != self or not can_take_damage(damage_type):
		return
	_last_damage_type = damage_type
	var multiplier: float = 1.45 if marked_remaining > 0.0 else 1.0
	integrity -= amount * multiplier
	_body_material.emission_energy_multiplier = 5.0
	EventBus.hit_confirmed.emit(integrity <= 0.0, damage_type)
	EventBus.combat_feedback.emit(&"defeat" if integrity <= 0.0 else &"hit", hit_position, tint.lightened(0.35), amount / maxf(max_integrity, 1.0))
	if integrity <= 0.0:
		_defeat()

func _on_impulse_requested(target: Node, direction: Vector3, strength: float) -> void:
	if target != self or bound_remaining > 0.0:
		return
	var horizontal := Vector3(direction.x, 0.0, direction.z).normalized()
	velocity += horizontal * strength

func _on_slow_requested(target: Node, duration: float, scale: float) -> void:
	if target != self:
		return
	_slow_remaining = maxf(_slow_remaining, duration)
	_slow_scale = minf(_slow_scale, clampf(scale, 0.15, 1.0))

func _set_ai_state(value: StringName) -> void:
	if ai_state == value:
		return
	ai_state = value
	EventBus.enemy_ai_state_changed.emit(kind, ai_state)

func _on_zone_laws_changed(laws: Dictionary) -> void:
	var garden_laws: Array = laws.get(&"GARDEN", laws.get("GARDEN", []))
	_no_unclean_entry = &"NO_UNCLEAN_ENTRY" in garden_laws or "NO_UNCLEAN_ENTRY" in garden_laws
	_no_hidden_thing = &"NO_HIDDEN_THING" in garden_laws or "NO_HIDDEN_THING" in garden_laws
	if _no_hidden_thing and kind == &"FALLEN":
		marked_remaining = INF

func _on_bind_requested(target: Node, duration: float) -> void:
	if target == self:
		bound_remaining = maxf(bound_remaining, duration)
		EventBus.target_bound.emit(kind)
		EventBus.message_posted.emit("TARGET BOUND // %s" % kind, &"holy")

func _on_mark_requested(target: Node, duration: float) -> void:
	if target == self:
		marked_remaining = duration
		EventBus.message_posted.emit("TARGET SEALED FOR THE HOST", &"info")

func _defeat() -> void:
	EventBus.enemy_defeated.emit(kind, global_position)
	if kind == &"DEMON":
		if _last_damage_type == &"purify" or _last_damage_type == &"sonic":
			EventBus.purification_requested.emit(global_position, 4.0, 0.8)
		else:
			EventBus.corruption_requested.emit(global_position, 2.2, 0.28)
	elif kind == &"FALLEN":
		EventBus.purification_requested.emit(global_position, 5.0, 0.65)
	queue_free()

func _build_body() -> void:
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.52 * scale_factor
	shape.height = 1.7 * scale_factor
	collision.position.y = 0.85 * scale_factor
	collision.shape = shape
	add_child(collision)

	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = tint
	_body_material.roughness = 0.34
	_body_material.metallic = 0.35
	_body_material.emission_enabled = true
	_body_material.emission = tint.lightened(0.08)
	_body_material.emission_energy_multiplier = 0.7

	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.42 * scale_factor
	torso_mesh.height = 1.35 * scale_factor
	torso.mesh = torso_mesh
	torso.material_override = _body_material
	torso.position.y = 1.05 * scale_factor
	add_child(torso)

	var eye_material := StandardMaterial3D.new()
	eye_material.albedo_color = Color(1.0, 0.72, 0.16)
	eye_material.emission_enabled = true
	eye_material.emission = Color(1.0, 0.25, 0.02)
	eye_material.emission_energy_multiplier = 4.0
	for side: float in [-1.0, 1.0]:
		var horn := MeshInstance3D.new()
		var horn_mesh := CylinderMesh.new()
		horn_mesh.top_radius = 0.0
		horn_mesh.bottom_radius = 0.14 * scale_factor
		horn_mesh.height = 0.7 * scale_factor
		horn.mesh = horn_mesh
		horn.material_override = _body_material
		horn.position = Vector3(side * 0.28, 1.95, 0.0) * scale_factor
		horn.rotation.z = side * 0.45
		add_child(horn)
	var eye := MeshInstance3D.new()
	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.11 * scale_factor
	eye_mesh.height = 0.22 * scale_factor
	eye.mesh = eye_mesh
	eye.material_override = eye_material
	eye.position = Vector3(0.0, 1.55, -0.41) * scale_factor
	add_child(eye)

func _update_visual() -> void:
	if _body_material == null:
		return
	var base_energy: float = 3.1 if marked_remaining > 0.0 else 0.7
	_body_material.emission_energy_multiplier = lerpf(_body_material.emission_energy_multiplier, base_energy, 0.12)
	var bob: float = sin(_pulse * 4.0) * 0.03
	for child: Node in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).position.y += bob * 0.02
