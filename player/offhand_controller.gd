class_name OffhandController
extends Node

const POSE_IDLE: StringName = &"idle"
const POSE_PRAYING: StringName = &"praying"
const POSE_DECLARE: StringName = &"declare"
const POSE_LEGISLATE: StringName = &"legislate"
const POSE_DEFLECT: StringName = &"deflect"

const IDLE_ARM_POSITION := Vector3(-0.82, -0.82, -0.26)
const IDLE_ARM_ROTATION := Vector3.ZERO
const IDLE_HAND_ROTATION := Vector3(-0.1, 0.08, 0.12)

var current_pose: StringName = POSE_IDLE
var pulse_remaining: float = 0.0
var _persistent_pose: StringName = POSE_IDLE
var _arms: ViewmodelArms
var _palm_glow: MeshInstance3D
var _palm_material: StandardMaterial3D
var _palm_light: OmniLight3D
var _glow_color := Color(1.0, 0.72, 0.22)
var _elapsed: float = 0.0
var _initialized: bool = false

func _ready() -> void:
	set_process(false)

func initialize(arms: ViewmodelArms) -> void:
	if _initialized:
		return
	_arms = arms
	_build_palm_glow()
	EventBus.prayer_started.connect(_on_prayer_started)
	EventBus.prayer_stopped.connect(_on_prayer_stopped)
	EventBus.declaration_issued.connect(_on_declaration_issued)
	EventBus.declaration_denied.connect(_on_declaration_denied)
	EventBus.law_enacted.connect(_on_law_enacted)
	EventBus.combat_feedback.connect(_on_combat_feedback)
	_initialized = true
	set_process(true)

func _process(delta: float) -> void:
	if not _initialized:
		return
	_elapsed += delta
	if pulse_remaining > 0.0:
		pulse_remaining = maxf(0.0, pulse_remaining - delta)
		if pulse_remaining <= 0.0:
			_set_offhand_pose(_persistent_pose)

	var pose: Dictionary = pose_transform_for(current_pose)
	var target_position: Vector3 = pose.position
	var target_arm_rotation: Vector3 = pose.arm_rotation
	var target_hand_rotation: Vector3 = pose.hand_rotation
	if current_pose == POSE_IDLE:
		target_position += Vector3(0.0, sin(_elapsed * 1.7) * 0.009, 0.0)
		target_arm_rotation.z += sin(_elapsed * 1.25) * 0.012
	elif current_pose == POSE_PRAYING:
		target_position += Vector3(0.0, sin(_elapsed * 2.2) * 0.006, 0.0)

	var blend: float = minf(1.0, delta * 12.0)
	_arms.left_arm.position = _arms.left_arm.position.lerp(target_position, blend)
	_arms.left_arm.rotation = _lerp_rotation(_arms.left_arm.rotation, target_arm_rotation, blend)
	_arms.offhand_anchor.rotation = _lerp_rotation(_arms.offhand_anchor.rotation, target_hand_rotation, blend)

	var pulse_ratio: float = clampf(pulse_remaining / 0.42, 0.0, 1.0)
	var target_energy: float = 0.45 if current_pose == POSE_PRAYING else pulse_ratio * 2.8
	_palm_light.light_energy = move_toward(_palm_light.light_energy, target_energy, delta * 16.0)
	_palm_light.light_color = _glow_color
	_palm_material.emission = _glow_color
	_palm_material.emission_energy_multiplier = 0.65 + _palm_light.light_energy * 0.9
	_palm_glow.scale = Vector3.ONE * (1.0 + _palm_light.light_energy * 0.08)

static func pose_transform_for(pose: StringName) -> Dictionary:
	match pose:
		POSE_PRAYING:
			return {
				"position": Vector3(-0.69, -0.7, -0.42),
				"arm_rotation": Vector3(0.08, -0.08, -0.12),
				"hand_rotation": Vector3(-0.48, 0.02, -0.06)
			}
		POSE_DECLARE:
			return {
				"position": Vector3(-0.62, -0.57, -0.54),
				"arm_rotation": Vector3(0.22, -0.12, -0.2),
				"hand_rotation": Vector3(-0.78, 0.02, -0.12)
			}
		POSE_LEGISLATE:
			return {
				"position": Vector3(-0.76, -0.52, -0.57),
				"arm_rotation": Vector3(0.12, -0.2, 0.05),
				"hand_rotation": Vector3(-0.9, 0.18, 0.18)
			}
		POSE_DEFLECT:
			return {
				"position": Vector3(-0.54, -0.49, -0.39),
				"arm_rotation": Vector3(-0.16, -0.05, -0.32),
				"hand_rotation": Vector3(-1.02, -0.12, -0.2)
			}
		_:
			return {
				"position": IDLE_ARM_POSITION,
				"arm_rotation": IDLE_ARM_ROTATION,
				"hand_rotation": IDLE_HAND_ROTATION
			}

func _set_offhand_pose(pose: StringName) -> void:
	current_pose = pose

func _play_offhand_pulse(pose: StringName, color: Color, duration: float = 0.42) -> void:
	current_pose = pose
	pulse_remaining = maxf(pulse_remaining, duration)
	_glow_color = color

func _on_prayer_started() -> void:
	_persistent_pose = POSE_PRAYING
	_glow_color = Color(0.55, 0.72, 1.0)
	if pulse_remaining <= 0.0:
		_set_offhand_pose(POSE_PRAYING)

func _on_prayer_stopped() -> void:
	_persistent_pose = POSE_IDLE
	if pulse_remaining <= 0.0:
		_set_offhand_pose(POSE_IDLE)

func _on_declaration_issued(_token_id: StringName, _duration: float) -> void:
	_play_offhand_pulse(POSE_DECLARE, Color(1.0, 0.76, 0.2))

func _on_declaration_denied() -> void:
	_play_offhand_pulse(POSE_DEFLECT, Color(0.58, 0.16, 0.72), 0.3)

func _on_law_enacted(_zone_id: StringName, _law_id: StringName) -> void:
	_play_offhand_pulse(POSE_LEGISLATE, Color(0.35, 0.82, 1.0), 0.5)

func _on_combat_feedback(kind: StringName, _position: Vector3, tint: Color, _strength: float) -> void:
	if kind in [&"deflect", &"synthetic_ricochet"]:
		_play_offhand_pulse(POSE_DEFLECT, tint, 0.34)

func _build_palm_glow() -> void:
	_palm_material = StandardMaterial3D.new()
	_palm_material.albedo_color = Color(0.95, 0.82, 0.42)
	_palm_material.emission_enabled = true
	_palm_material.emission = _glow_color
	_palm_material.emission_energy_multiplier = 0.65

	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.034
	glow_mesh.height = 0.025
	glow_mesh.radial_segments = 10
	glow_mesh.rings = 4
	_palm_glow = MeshInstance3D.new()
	_palm_glow.name = "PalmGlow"
	_palm_glow.mesh = glow_mesh
	_palm_glow.material_override = _palm_material
	_palm_glow.position = Vector3(0.0, 0.035, -0.045)
	_palm_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arms.offhand_anchor.add_child(_palm_glow)

	_palm_light = OmniLight3D.new()
	_palm_light.name = "PalmLight"
	_palm_light.position = Vector3(0.0, 0.07, -0.08)
	_palm_light.omni_range = 0.9
	_palm_light.light_energy = 0.0
	_palm_light.shadow_enabled = false
	_arms.offhand_anchor.add_child(_palm_light)

func _lerp_rotation(from: Vector3, to: Vector3, weight: float) -> Vector3:
	return Vector3(
		lerp_angle(from.x, to.x, weight),
		lerp_angle(from.y, to.y, weight),
		lerp_angle(from.z, to.z, weight)
	)
