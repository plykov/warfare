class_name ViewmodelArms
extends Node3D

const LINEN_COLOR := Color(0.78, 0.76, 0.67)
const ARIEL_BRONZE := Color(0.72, 0.47, 0.16)
const TEAL_GEM := Color(0.08, 0.58, 0.62)

var right_arm: Node3D
var right_hand_anchor: Node3D
var left_arm: Node3D
var offhand_anchor: Node3D

var _linen_material: StandardMaterial3D
var _bronze_material: StandardMaterial3D
var _gem_material: StandardMaterial3D

func _ready() -> void:
	_build_materials()
	_build_right_arm()
	_build_left_arm()

func _build_materials() -> void:
	_linen_material = StandardMaterial3D.new()
	_linen_material.albedo_color = LINEN_COLOR.lerp(ARIEL_BRONZE, 0.18)
	_linen_material.metallic = 0.14
	_linen_material.roughness = 0.72

	_bronze_material = StandardMaterial3D.new()
	_bronze_material.albedo_color = LINEN_COLOR.lerp(ARIEL_BRONZE, 0.82)
	_bronze_material.metallic = 0.78
	_bronze_material.roughness = 0.26

	_gem_material = StandardMaterial3D.new()
	_gem_material.albedo_color = TEAL_GEM
	_gem_material.metallic = 0.38
	_gem_material.roughness = 0.2
	_gem_material.emission_enabled = true
	_gem_material.emission = TEAL_GEM
	_gem_material.emission_energy_multiplier = 1.6

func _build_right_arm() -> void:
	right_arm = Node3D.new()
	right_arm.name = "RightArm"
	right_arm.position = Vector3(0.82, -0.82, -0.28)
	add_child(right_arm)

	_add_capsule_segment(
		right_arm,
		"RightForearm",
		Vector3.ZERO,
		Vector3(-0.25, 0.28, -0.35),
		0.115,
		_linen_material
	)
	_add_cylinder_segment(
		right_arm,
		"RightGauntlet",
		Vector3(-0.22, 0.25, -0.31),
		Vector3(-0.31, 0.38, -0.51),
		0.125,
		0.095,
		_bronze_material
	)

	right_hand_anchor = Node3D.new()
	right_hand_anchor.name = "RightHandAnchor"
	right_hand_anchor.position = Vector3(-0.32, 0.41, -0.56)
	right_hand_anchor.rotation = Vector3(-0.12, 0.0, -0.2)
	right_arm.add_child(right_hand_anchor)
	_add_capsule_segment(
		right_hand_anchor,
		"RightHand",
		Vector3(0.0, -0.04, 0.04),
		Vector3(0.0, 0.055, -0.09),
		0.078,
		_linen_material
	)
	_add_box(
		right_hand_anchor,
		"RightKnucklePlate",
		Vector3(0.145, 0.085, 0.035),
		Vector3(0.0, 0.045, -0.075),
		Vector3(-0.15, 0.0, 0.0),
		_bronze_material
	)
	_add_gem(right_hand_anchor, "RightCuffGem", Vector3(0.0, -0.09, 0.035))

func _build_left_arm() -> void:
	left_arm = Node3D.new()
	left_arm.name = "LeftArm"
	left_arm.position = Vector3(-0.82, -0.82, -0.26)
	add_child(left_arm)

	_add_capsule_segment(
		left_arm,
		"LeftForearm",
		Vector3.ZERO,
		Vector3(0.24, 0.31, -0.3),
		0.115,
		_linen_material
	)
	_add_cylinder_segment(
		left_arm,
		"LeftGauntlet",
		Vector3(0.21, 0.28, -0.27),
		Vector3(0.31, 0.41, -0.44),
		0.125,
		0.095,
		_bronze_material
	)

	offhand_anchor = Node3D.new()
	offhand_anchor.name = "OffhandAnchor"
	offhand_anchor.position = Vector3(0.33, 0.46, -0.49)
	offhand_anchor.rotation = Vector3(-0.1, 0.08, 0.12)
	left_arm.add_child(offhand_anchor)
	_add_box(
		offhand_anchor,
		"OpenPalm",
		Vector3(0.155, 0.17, 0.065),
		Vector3.ZERO,
		Vector3(-0.12, 0.0, 0.0),
		_linen_material
	)
	_add_box(
		offhand_anchor,
		"LeftKnucklePlate",
		Vector3(0.15, 0.09, 0.035),
		Vector3(0.0, 0.035, -0.05),
		Vector3(-0.12, 0.0, 0.0),
		_bronze_material
	)
	for finger_index: int in range(4):
		var finger_x: float = -0.055 + finger_index * 0.037
		_add_capsule_segment(
			offhand_anchor,
			"Finger%02d" % finger_index,
			Vector3(finger_x, 0.075, 0.0),
			Vector3(finger_x, 0.19 + absf(finger_index - 1.5) * -0.012, -0.018),
			0.018,
			_linen_material
		)
	_add_capsule_segment(
		offhand_anchor,
		"Thumb",
		Vector3(0.068, 0.035, 0.0),
		Vector3(0.13, 0.09, -0.012),
		0.022,
		_linen_material
	)
	_add_gem(offhand_anchor, "LeftCuffGem", Vector3(0.0, -0.11, 0.035))

func _add_capsule_segment(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(start.distance_to(finish), radius * 2.0)
	mesh.radial_segments = 12
	mesh.rings = 4
	return _add_oriented_mesh(parent, node_name, mesh, start, finish, material)

func _add_cylinder_segment(parent: Node3D, node_name: String, start: Vector3, finish: Vector3, top_radius: float, bottom_radius: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = start.distance_to(finish)
	mesh.radial_segments = 12
	return _add_oriented_mesh(parent, node_name, mesh, start, finish, material)

func _add_oriented_mesh(parent: Node3D, node_name: String, mesh: PrimitiveMesh, start: Vector3, finish: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.material_override = material
	visual.position = (start + finish) * 0.5
	visual.quaternion = Quaternion(Vector3.UP, (finish - start).normalized())
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	return visual

func _add_box(parent: Node3D, node_name: String, size: Vector3, at: Vector3, rotation: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.material_override = material
	visual.position = at
	visual.rotation = rotation
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	return visual

func _add_gem(parent: Node3D, node_name: String, at: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.028
	mesh.height = 0.04
	mesh.radial_segments = 10
	mesh.rings = 4
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = mesh
	visual.material_override = _gem_material
	visual.position = at
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(visual)
	return visual
