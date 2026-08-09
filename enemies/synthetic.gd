class_name SyntheticEnemy
extends EnemyBase

var _immune_notice_cooldown: float = 0.0

func _init() -> void:
	kind = &"SYNTHETIC"
	max_integrity = 185.0
	integrity = max_integrity
	speed = 2.5
	attack_damage = 18.0
	tint = Color(0.17, 0.19, 0.21)
	scale_factor = 1.35
	spreads_corruption = false

func _ready() -> void:
	super._ready()
	_build_synthetic_shell()

func _physics_process(delta: float) -> void:
	_immune_notice_cooldown = maxf(0.0, _immune_notice_cooldown - delta)
	super._physics_process(delta)

func can_take_damage(damage_type: StringName) -> bool:
	if damage_type == &"kinetic":
		return true
	if _immune_notice_cooldown <= 0.0:
		_immune_notice_cooldown = 1.0
		EventBus.message_posted.emit("NO SPIRIT TO PURIFY // USE KINETIC [5, 8, 11]", &"danger")
		EventBus.weapon_context_changed.emit("KINETIC REQUIRED", "SWITCH TO 5 / 8 / 11")
		var feedback_position: Vector3 = global_position if is_inside_tree() else position
		EventBus.combat_feedback.emit(&"synthetic_ricochet", feedback_position + Vector3.UP * 1.2, Color(0.48, 0.86, 1.0), 3.0)
		EventBus.audio_requested.emit(&"synthetic_ricochet")
	return false

func _build_synthetic_shell() -> void:
	var armor_material := StandardMaterial3D.new()
	armor_material.albedo_color = Color(0.12, 0.16, 0.19)
	armor_material.metallic = 0.92
	armor_material.roughness = 0.18
	var core_material := StandardMaterial3D.new()
	core_material.albedo_color = Color(0.18, 0.72, 0.9)
	core_material.emission_enabled = true
	core_material.emission = Color(0.04, 0.52, 0.86)
	core_material.emission_energy_multiplier = 4.2
	for i: int in range(6):
		var plate := MeshInstance3D.new()
		plate.name = "SyntheticArmor%02d" % i
		var plate_mesh := BoxMesh.new()
		plate_mesh.size = Vector3(1.12 - (i % 2) * 0.18, 0.17, 0.54)
		plate.mesh = plate_mesh
		plate.material_override = armor_material
		plate.position = Vector3(0.0, 0.55 + i * 0.27, -0.18 + (i % 2) * 0.16)
		plate.rotation.y = (i % 2) * 0.16 - 0.08
		add_child(plate)
	var core := MeshInstance3D.new()
	core.name = "SyntheticKineticCore"
	var core_mesh := BoxMesh.new()
	core_mesh.size = Vector3(0.34, 0.34, 0.18)
	core.mesh = core_mesh
	core.material_override = core_material
	core.position = Vector3(0.0, 1.26, -0.73)
	core.rotation.z = PI * 0.25
	add_child(core)
