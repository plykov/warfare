class_name RankManifestation
extends Node3D

const MANIFESTATION_LAYER: int = 16

var _rank: int = 0
var _body_material: StandardMaterial3D
var _fire_material: StandardMaterial3D
var _eye_material: StandardMaterial3D

func _ready() -> void:
	EventBus.rank_changed.connect(_on_rank_changed)
	_rebuild(RankSystem.rank_index)

func _process(delta: float) -> void:
	for child: Node in get_children():
		if child is OmniLight3D:
			(child as OmniLight3D).light_energy = 0.6 + _rank * 0.33 + sin(Time.get_ticks_msec() * 0.004) * 0.12
		elif child is MeshInstance3D and child.name.begins_with("Ophanim"):
			(child as MeshInstance3D).rotate_y(delta * (0.55 + _rank * 0.08))

func _on_rank_changed(index: int, _display_name: String) -> void:
	_rebuild(index)

func _rebuild(index: int) -> void:
	_rank = clampi(index, 0, 7)
	for child: Node in get_children():
		child.queue_free()
	_build_materials()
	_add_body()
	_add_rank_armor()
	if _rank >= 3:
		_add_wings(4 if _rank == 3 else 6)
	if _rank >= 3:
		_add_ophanim()
	_add_eyes(_eye_count_for_rank())
	var light := OmniLight3D.new()
	light.name = "ManifestationFire"
	light.position = Vector3(0.0, 1.25, 0.0)
	light.light_color = Color(1.0, 0.48 + _rank * 0.035, 0.12)
	light.omni_range = 2.5 + _rank * 0.6
	light.light_energy = 0.6 + _rank * 0.33
	light.layers = 1 << (MANIFESTATION_LAYER - 1)
	add_child(light)

func _build_materials() -> void:
	_body_material = StandardMaterial3D.new()
	_body_material.albedo_color = Color(0.78, 0.76, 0.67).lerp(Color(0.72, 0.47, 0.16), _rank / 12.0)
	_body_material.metallic = minf(0.85, 0.18 + _rank * 0.1)
	_body_material.roughness = maxf(0.18, 0.68 - _rank * 0.065)
	_fire_material = StandardMaterial3D.new()
	_fire_material.albedo_color = Color(1.0, 0.62, 0.16)
	_fire_material.emission_enabled = true
	_fire_material.emission = Color(1.0, 0.24 + _rank * 0.045, 0.025)
	_fire_material.emission_energy_multiplier = 0.8 + _rank * 0.48
	_eye_material = StandardMaterial3D.new()
	_eye_material.albedo_color = Color(1.0, 0.82, 0.28)
	_eye_material.emission_enabled = true
	_eye_material.emission = Color(1.0, 0.42, 0.03)
	_eye_material.emission_energy_multiplier = 3.5

func _add_body() -> void:
	var body := MeshInstance3D.new()
	body.name = "LinenBody"
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.34
	mesh.height = 1.5
	body.mesh = mesh
	body.material_override = _body_material
	body.position.y = 1.0
	_set_manifestation_layer(body)
	add_child(body)

func _add_rank_armor() -> void:
	var plate_count: int = maxi(1, _rank + 1)
	for i: int in range(plate_count):
		var plate := MeshInstance3D.new()
		plate.name = "BurnishedPlate%02d" % i
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.58 - i * 0.025, 0.09, 0.18)
		plate.mesh = mesh
		plate.material_override = _body_material
		plate.position = Vector3(0.0, 0.72 + i * 0.12, -0.3)
		_set_manifestation_layer(plate)
		add_child(plate)

func _add_wings(count: int) -> void:
	for i: int in range(count):
		var pair_index: int = i / 2
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var wing := MeshInstance3D.new()
		wing.name = "Wing%02d" % i
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.15, 1.15 + pair_index * 0.16, 0.52)
		wing.mesh = mesh
		wing.material_override = _fire_material if _rank >= 4 else _body_material
		wing.position = Vector3(side * (0.52 + pair_index * 0.12), 1.22 - pair_index * 0.22, 0.2 + pair_index * 0.12)
		wing.rotation = Vector3(0.0, side * 0.18, side * (0.62 + pair_index * 0.17))
		_set_manifestation_layer(wing)
		add_child(wing)

func _add_ophanim() -> void:
	for side: float in [-1.0, 1.0]:
		var wheel := MeshInstance3D.new()
		wheel.name = "Ophanim%s" % ("L" if side < 0.0 else "R")
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.32
		mesh.outer_radius = 0.38
		wheel.mesh = mesh
		wheel.material_override = _fire_material
		wheel.position = Vector3(side * 0.78, 0.78, 0.08)
		wheel.rotation.z = PI * 0.5
		_set_manifestation_layer(wheel)
		add_child(wheel)

func _add_eyes(count: int) -> void:
	for i: int in range(count):
		var eye := MeshInstance3D.new()
		eye.name = "Eye%02d" % i
		var mesh := SphereMesh.new()
		mesh.radius = 0.035
		mesh.height = 0.07
		eye.mesh = mesh
		eye.material_override = _eye_material
		var angle: float = TAU * float(i) / maxf(1.0, count)
		eye.position = Vector3(cos(angle) * 0.38, 0.82 + (i % 4) * 0.19, sin(angle) * 0.26)
		_set_manifestation_layer(eye)
		add_child(eye)

func _eye_count_for_rank() -> int:
	match _rank:
		0: return 0
		1: return 2
		2: return 4
		3: return 8
		4: return 12
		5: return 24
		6: return 32
		_: return 48

func _set_manifestation_layer(mesh: VisualInstance3D) -> void:
	mesh.layers = 1 << (MANIFESTATION_LAYER - 1)
