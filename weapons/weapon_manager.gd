class_name WeaponManager
extends Node3D

const WEAPON_PATHS: PackedStringArray = [
	"res://weapons/data/01_flaming_sword.tres",
	"res://weapons/data/02_live_coal.tres",
	"res://weapons/data/03_trumpet.tres",
	"res://weapons/data/04_bowl_of_wrath.tres",
	"res://weapons/data/05_sickle.tres",
	"res://weapons/data/06_key_chain.tres",
	"res://weapons/data/07_censer.tres",
	"res://weapons/data/08_chariot.tres",
	"res://weapons/data/09_measuring_rod.tres",
	"res://weapons/data/10_inkhorn.tres",
	"res://weapons/data/11_millstone.tres",
	"res://weapons/data/12_drawn_bow.tres"
]
const JUDGMENT_ZONE_SCRIPT: Script = preload("res://world/judgment_zone.gd")

@onready var camera: Camera3D = get_parent() as Camera3D
@onready var weapon_model: MeshInstance3D = $WeaponModel
@onready var muzzle_light: OmniLight3D = $MuzzleLight

var weapons: Array[WeaponResource] = []
var current_index: int = 0
var cooldown: float = 0.0
var recoil: float = 0.0
var _rest_z: float = -0.78
var _weapon_tier: int = 1

func _ready() -> void:
	for path: String in WEAPON_PATHS:
		weapons.append(load(path) as WeaponResource)
	EventBus.rank_profile_changed.connect(_on_rank_profile_changed)
	_equip(0)

func _process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	recoil = lerpf(recoil, 0.0, minf(1.0, delta * 15.0))
	weapon_model.position.z = _rest_z + recoil
	muzzle_light.light_energy = move_toward(muzzle_light.light_energy, 0.0, delta * 18.0)
	if not GameState.is_playing() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return

	if Input.is_action_just_pressed("weapon_next"):
		_equip(posmod(current_index + 1, weapons.size()))
	if Input.is_action_just_pressed("weapon_prev"):
		_equip(posmod(current_index - 1, weapons.size()))
	for i: int in range(weapons.size()):
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			_equip(i)
	if Input.is_action_pressed("fire"):
		_fire(false)
	elif Input.is_action_pressed("alt_fire"):
		_fire(true)

func _equip(index: int) -> void:
	current_index = clampi(index, 0, weapons.size() - 1)
	var weapon: WeaponResource = weapons[current_index]
	var material := StandardMaterial3D.new()
	material.albedo_color = weapon.tint
	material.emission_enabled = true
	material.emission = weapon.tint
	material.emission_energy_multiplier = 1.25
	material.metallic = 0.72
	material.roughness = 0.24
	weapon_model.material_override = material
	var mesh := BoxMesh.new()
	if weapon.weapon_id in [&"flaming_sword", &"sickle", &"drawn_bow"]:
		mesh.size = Vector3(0.04, 0.58, 0.04)
		_rest_z = -0.9
		weapon_model.position = Vector3(0.5, -0.4, _rest_z)
		weapon_model.rotation = Vector3(-0.12, 0.0, -0.48)
	else:
		mesh.size = Vector3(0.15, 0.12, 0.54)
		_rest_z = -0.95
		weapon_model.position = Vector3(0.42, -0.34, _rest_z)
		weapon_model.rotation = Vector3(-0.12, -0.05, 0.08)
	weapon_model.mesh = mesh
	EventBus.weapon_switched.emit(current_index, weapon.display_name)
	EventBus.weapon_context_changed.emit("TIER %d // %s" % [_weapon_tier, weapon.role], weapon.counterplay)

func _fire(alt: bool) -> void:
	if cooldown > 0.0:
		return
	var weapon: WeaponResource = weapons[current_index].duplicate() as WeaponResource
	weapon.damage *= 1.0 + (_weapon_tier - 1) * 0.28
	weapon.radius *= 1.0 + (_weapon_tier - 1) * 0.08
	if alt:
		weapon.damage *= 1.18
		weapon.radius *= 1.12
	if weapon.requires_commission and not IntercessorSystem.has_commission():
		EventBus.weapon_denied.emit("Commission required — press E to Declare")
		EventBus.message_posted.emit("NO AUTHORITY // DECLARE BEFORE REBUKE", &"danger")
		EventBus.audio_requested.emit(&"denied")
		EventBus.combat_feedback.emit(&"denied", camera.global_position + -camera.global_basis.z * 1.2, Color(0.42, 0.08, 0.55), 1.4)
		cooldown = 0.35
		return
	if weapon.glory_cost > 0.0:
		var glory: GloryComponent = get_parent().get_parent().get_parent().get_node("GloryComponent") as GloryComponent
		if glory == null or not glory.spend(weapon.glory_cost * (1.45 if alt else 1.0)):
			EventBus.message_posted.emit("GLORY INSUFFICIENT", &"danger")
			cooldown = 0.3
			return
	cooldown = weapon.cooldown
	recoil = 0.12
	muzzle_light.light_color = weapon.tint
	muzzle_light.light_energy = 4.0
	EventBus.weapon_fired.emit(weapon.weapon_id)
	EventBus.audio_requested.emit(&"purify")
	EventBus.combat_feedback.emit(&"muzzle", camera.global_position + -camera.global_basis.z * 1.2, weapon.tint, 1.0)

	match weapon.weapon_id:
		&"flaming_sword":
			if alt:
				EventBus.projectile_parry_requested.emit(camera.global_position, weapon.radius + 1.5, -camera.global_basis.z)
				EventBus.combat_feedback.emit(&"impact", camera.global_position + -camera.global_basis.z * 1.5, weapon.tint, weapon.radius)
			_melee_sweep(weapon, alt)
		&"sickle":
			_melee_sweep(weapon, alt)
		&"trumpet":
			_area_strike(global_position, weapon)
		&"key_chain":
			EventBus.rebuke_requested.emit(camera.global_position, weapon.radius)
			var chained: Dictionary = _ray_hit(weapon.range)
			if not chained.is_empty():
				EventBus.bind_requested.emit(chained.collider, 7.0 if alt else 4.0)
				EventBus.damage_requested.emit(chained.collider, weapon.damage, weapon.damage_type, chained.position)
		&"measuring_rod":
			for enemy: Node in get_tree().get_nodes_in_group("enemies"):
				if enemy is Node3D and (enemy as Node3D).global_position.distance_to(camera.global_position) <= weapon.radius:
					EventBus.mark_requested.emit(enemy, 4.0 if not alt else 7.0)
			EventBus.message_posted.emit("SURVEY COMPLETE // HOSTILES AND CORRUPTION REVEALED", &"info")
			EventBus.audio_requested.emit(&"declare")
		&"inkhorn":
			if alt:
				var host: Node3D = _nearest_group_member("host", weapon.range)
				if host != null:
					EventBus.seal_requested.emit(host, 10.0)
				else:
					EventBus.message_posted.emit("INKHORN // NO HOST ALLY IN RANGE", &"info")
			else:
				var marked: Dictionary = _ray_hit(weapon.range)
				if not marked.is_empty():
					EventBus.mark_requested.emit(marked.collider, 8.0)
					EventBus.message_posted.emit("TARGET SEALED FOR THE HOST", &"info")
		&"chariot":
			_area_strike(get_parent().get_parent().get_parent().global_position, weapon)
			EventBus.player_impulse_requested.emit(10.0 if alt else 6.0)
		&"live_coal", &"bowl_of_wrath", &"millstone":
			var impact: Dictionary = _ray_hit(weapon.range)
			var position: Vector3 = camera.global_position + -camera.global_basis.z * weapon.range
			if not impact.is_empty():
				position = impact.position
			_area_strike(position, weapon)
			if weapon.damage_type != &"kinetic":
				EventBus.purification_requested.emit(position, weapon.radius, 0.72)
			if weapon.weapon_id in [&"live_coal", &"bowl_of_wrath"]:
				_spawn_zone(position, weapon, alt)
		&"censer":
			var censer_hit: Dictionary = _ray_hit(weapon.range)
			var censer_position: Vector3 = camera.global_position + -camera.global_basis.z * weapon.range
			if not censer_hit.is_empty():
				censer_position = censer_hit.position
			var converted: float = IntercessorSystem.convert_fervency(28.0 if alt else 12.0)
			weapon.damage += converted * 1.8
			weapon.radius += converted * 0.035
			_area_strike(censer_position, weapon)
			EventBus.purification_requested.emit(censer_position, weapon.radius, 0.4 + converted * 0.012)
			EventBus.message_posted.emit("CENSER BURST // %.0f FERVENCY CONVERTED" % converted, &"holy")
		&"drawn_bow":
			var hit: Dictionary = _ray_hit(weapon.range)
			var field_position: Vector3 = camera.global_position + -camera.global_basis.z * weapon.range
			if not hit.is_empty():
				EventBus.damage_requested.emit(hit.collider, weapon.damage, weapon.damage_type, hit.position)
				_apply_impulse(hit.collider, hit.position, weapon)
				EventBus.slow_requested.emit(hit.collider, 3.5 if alt else 1.8, 0.48 if alt else 0.72)
				field_position = hit.position
			if alt:
				field_position.y = 0.04
				EventBus.slippery_field_requested.emit(field_position, maxf(2.5, weapon.radius * 1.8), 6.0)
		_:
			pass

func _melee_sweep(weapon: WeaponResource, alt: bool) -> void:
	var origin: Vector3 = camera.global_position
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node3D:
			continue
		var target := enemy as Node3D
		var to_enemy: Vector3 = target.global_position - origin
		if to_enemy.length() <= weapon.range:
			var facing: float = (-camera.global_basis.z).dot(to_enemy.normalized())
			if facing > (0.1 if alt else 0.48):
				EventBus.damage_requested.emit(enemy, weapon.damage * (0.75 if alt else 1.0), weapon.damage_type, target.global_position)
				_apply_impulse(enemy, target.global_position, weapon)
	EventBus.purification_requested.emit(origin + -camera.global_basis.z * 2.0, weapon.radius, 0.45)

func _area_strike(position: Vector3, weapon: WeaponResource) -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy is Node3D:
			var target := enemy as Node3D
			var distance: float = target.global_position.distance_to(position)
			if distance <= weapon.radius:
				var falloff: float = 1.0 - distance / maxf(weapon.radius, 0.01) * 0.5
				EventBus.damage_requested.emit(enemy, weapon.damage * falloff, weapon.damage_type, target.global_position)
				_apply_impulse(enemy, target.global_position, weapon)
	EventBus.combat_feedback.emit(&"impact", position, weapon.tint, weapon.radius)

func _apply_impulse(target: Node, position: Vector3, weapon: WeaponResource) -> void:
	if weapon.impulse <= 0.0:
		return
	var direction: Vector3 = position - camera.global_position
	EventBus.impulse_requested.emit(target, direction, weapon.impulse)

func _spawn_zone(position: Vector3, weapon: WeaponResource, alt: bool) -> void:
	var zone: JudgmentZone = JUDGMENT_ZONE_SCRIPT.new() as JudgmentZone
	zone.position = position
	zone.radius = weapon.radius * (1.2 if alt else 1.0)
	zone.duration = (4.8 if weapon.weapon_id == &"bowl_of_wrath" else 2.2) * (1.25 if alt else 1.0)
	zone.damage_per_pulse = weapon.damage * 0.18
	zone.damage_type = weapon.damage_type
	zone.tint = weapon.tint
	get_tree().current_scene.add_child(zone)

func _ray_hit(distance: float) -> Dictionary:
	var from: Vector3 = camera.global_position
	var to: Vector3 = from + -camera.global_basis.z * distance
	var query := PhysicsRayQueryParameters3D.create(from, to, 0b0101, [get_parent().get_parent().get_parent()])
	return get_world_3d().direct_space_state.intersect_ray(query)

func _nearest_group_member(group_name: StringName, maximum_distance: float) -> Node3D:
	var nearest: Node3D
	var nearest_distance: float = maximum_distance
	for node: Node in get_tree().get_nodes_in_group(group_name):
		if not node is Node3D:
			continue
		var candidate := node as Node3D
		var distance: float = camera.global_position.distance_to(candidate.global_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest = candidate
	return nearest

func _on_rank_profile_changed(_index: int, _name: String, tier: int, _doctrine: String, _passive: String, _power: float, _resistance: float) -> void:
	_weapon_tier = clampi(tier, 1, 3)
	var weapon: WeaponResource = weapons[current_index] if not weapons.is_empty() else null
	if weapon != null:
		EventBus.weapon_context_changed.emit("TIER %d // %s" % [_weapon_tier, weapon.role], weapon.counterplay)
