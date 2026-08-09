class_name FallenEnemy
extends EnemyBase

var rebuked_remaining: float = 0.0
var _immune_notice_cooldown: float = 0.0
var _shield_shell: MeshInstance3D

func _init() -> void:
	kind = &"FALLEN"
	max_integrity = 150.0
	integrity = max_integrity
	speed = 5.2
	attack_damage = 13.0
	tint = Color(0.18, 0.04, 0.28)
	scale_factor = 1.2
	uses_projectiles = true
	projectile_damage = 11.0
	projectile_speed = 14.0

func _ready() -> void:
	super._ready()
	EventBus.rebuke_requested.connect(_on_rebuke_requested)
	_build_shield_shell()
	_set_shielded_vfx(true)

func _physics_process(delta: float) -> void:
	var was_rebuked: bool = rebuked_remaining > 0.0
	rebuked_remaining = maxf(0.0, rebuked_remaining - delta)
	if was_rebuked and rebuked_remaining <= 0.0:
		_set_shielded_vfx(true)
	_immune_notice_cooldown = maxf(0.0, _immune_notice_cooldown - delta)
	super._physics_process(delta)

func can_take_damage(_damage_type: StringName) -> bool:
	if rebuked_remaining > 0.0:
		return true
	if _immune_notice_cooldown <= 0.0:
		_immune_notice_cooldown = 1.0
		EventBus.message_posted.emit("FALLEN IMMUNE // DECLARE [E], THEN KEY & CHAIN [6]", &"danger")
	EventBus.combat_feedback.emit(&"deflect", global_position + Vector3.UP * 1.2, Color(0.72, 0.58, 0.95), 2.4)
	EventBus.audio_requested.emit(&"deflect")
	return false

func _on_rebuke_requested(position: Vector3, radius: float) -> void:
	if global_position.distance_to(position) <= radius:
		rebuked_remaining = 8.0
		_set_shielded_vfx(false)
		EventBus.message_posted.emit("THE LORD REBUKE YOU // FALLEN EXPOSED", &"holy")

func _build_shield_shell() -> void:
	_shield_shell = MeshInstance3D.new()
	_shield_shell.name = "AuthorityShell"
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.68 * scale_factor
	mesh.height = 2.25 * scale_factor
	_shield_shell.mesh = mesh
	_shield_shell.position.y = 1.05 * scale_factor
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.08, 0.015, 0.14, 0.52)
	material.emission_enabled = true
	material.emission = Color(0.34, 0.04, 0.62)
	material.emission_energy_multiplier = 2.8
	material.metallic = 0.75
	material.roughness = 0.18
	_shield_shell.material_override = material
	add_child(_shield_shell)

func _set_shielded_vfx(shielded: bool) -> void:
	if _shield_shell != null:
		_shield_shell.visible = shielded
	EventBus.fallen_guard_changed.emit(self, shielded)
