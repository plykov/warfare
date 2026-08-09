class_name RankManifestation
extends Node3D

const MANIFESTATION_LAYER: int = 16
const SILHOUETTE_SPANS: PackedFloat32Array = [0.68, 0.86, 1.08, 1.8, 2.7, 3.35, 4.5, 7.4]

var _rank: int = 0
var _body_material: StandardMaterial3D
var _fire_material: StandardMaterial3D
var _eye_material: StandardMaterial3D
var _veiled: bool = false

func _ready() -> void:
	EventBus.rank_changed.connect(_on_rank_changed)
	EventBus.entered_veiled.connect(func() -> void: _veiled = true; _rebuild(_rank))
	EventBus.exited_veiled.connect(func() -> void: _veiled = false; _rebuild(_rank))
	_rebuild(RankSystem.rank_index)

func _process(delta: float) -> void:
	for child: Node in get_children():
		if child is OmniLight3D:
			(child as OmniLight3D).light_energy = 0.6 + _rank * 0.33 + sin(Time.get_ticks_msec() * 0.004) * 0.12
		elif child is MeshInstance3D and child.name.begins_with("Ophanim"):
			(child as MeshInstance3D).rotate_y(delta * (0.55 + _rank * 0.08))

func _on_rank_changed(index: int, _display_name: String) -> void:
	_rebuild(index)

static func silhouette_span_for_rank(index: int) -> float:
	return SILHOUETTE_SPANS[clampi(index, 0, SILHOUETTE_SPANS.size() - 1)]

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
	if _rank >= 6:
		_add_host_mantle()
	if _rank == 7:
		_add_seventh_crown()
	_add_eyes(_eye_count_for_rank())
	var light := OmniLight3D.new()
	light.name = "ManifestationFire"
	light.position = Vector3(0.0, 1.25, 0.0)
	light.light_color = Color(1.0, 0.48 + _rank * 0.035, 0.12)
	light.omni_range = 2.5 + _rank * 0.6 + (2.0 if _rank == 7 else 0.0)
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
	if _veiled:
		_body_material.albedo_color = Color(0.08, 0.075, 0.11)
		_body_material.metallic = 0.05
		_fire_material.albedo_color = Color(0.12, 0.025, 0.18)
		_fire_material.emission = Color(0.08, 0.01, 0.12)
		_fire_material.emission_energy_multiplier = 0.15
		_eye_material.emission = Color(0.14, 0.02, 0.2)
		_eye_material.emission_energy_multiplier = 0.3

func _add_body() -> void:
	var body := MeshInstance3D.new()
	body.name = "LinenBody"
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.34 + _rank * 0.012
	mesh.height = 1.5 + _rank * 0.045
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
	var span: float = silhouette_span_for_rank(_rank)
	for i: int in range(count):
		var pair_index: int = i / 2
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var wing := MeshInstance3D.new()
		wing.name = "Wing%02d" % i
		var mesh := PrismMesh.new()
		var wing_length: float = 1.15 + pair_index * 0.2 + maxf(0.0, span - 1.8) * 0.28
		mesh.size = Vector3(0.15 + _rank * 0.012, wing_length, 0.52 + _rank * 0.035)
		wing.mesh = mesh
		wing.material_override = _fire_material if _rank >= 4 else _body_material
		var spread: float = 0.52 + pair_index * 0.12 + maxf(0.0, span - 1.8) * 0.1
		wing.position = Vector3(side * spread, 1.22 - pair_index * 0.22, 0.2 + pair_index * 0.12)
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

func _add_host_mantle() -> void:
	var radius: float = 1.28 if _rank == 6 else 1.72
	for i: int in range(7):
		var flame := MeshInstance3D.new()
		flame.name = "HostFlame%02d" % i
		var mesh := PrismMesh.new()
		mesh.size = Vector3(0.14, 0.62 + (i % 2) * 0.18, 0.18)
		flame.mesh = mesh
		flame.material_override = _fire_material
		var angle: float = TAU * float(i) / 7.0
		flame.position = Vector3(cos(angle) * radius, 1.7 + sin(angle * 2.0) * 0.24, sin(angle) * radius * 0.34)
		flame.rotation.z = -angle * 0.22
		_set_manifestation_layer(flame)
		add_child(flame)

func _add_seventh_crown() -> void:
	var crown := MeshInstance3D.new()
	crown.name = "SeventhCrown"
	var crown_mesh := TorusMesh.new()
	crown_mesh.inner_radius = 0.82
	crown_mesh.outer_radius = 0.96
	crown.mesh = crown_mesh
	crown.material_override = _fire_material
	crown.position = Vector3(0.0, 2.75, 0.0)
	crown.rotation.x = PI * 0.5
	_set_manifestation_layer(crown)
	add_child(crown)
	for i: int in range(7):
		var rainbow := MeshInstance3D.new()
		rainbow.name = "RainbowBand%02d" % i
		var rainbow_mesh := BoxMesh.new()
		rainbow_mesh.size = Vector3(0.38, 0.13, 0.18)
		rainbow.mesh = rainbow_mesh
		var rainbow_material := StandardMaterial3D.new()
		var rainbow_color := Color.from_hsv(float(i) / 7.0, 0.72, 1.0)
		rainbow_material.albedo_color = rainbow_color
		rainbow_material.emission_enabled = true
		rainbow_material.emission = rainbow_color
		rainbow_material.emission_energy_multiplier = 2.6
		rainbow.material_override = rainbow_material
		var arc: float = PI - PI * float(i) / 6.0
		rainbow.position = Vector3(cos(arc) * 1.02, 2.76 + sin(arc) * 0.94, -0.04)
		rainbow.rotation.z = arc - PI * 0.5
		_set_manifestation_layer(rainbow)
		add_child(rainbow)
	for i: int in range(7):
		var cloud := MeshInstance3D.new()
		cloud.name = "CloudMantle%02d" % i
		var cloud_mesh := SphereMesh.new()
		cloud_mesh.radius = 0.38 + (i % 3) * 0.08
		cloud_mesh.height = cloud_mesh.radius * 1.45
		cloud.mesh = cloud_mesh
		var cloud_material := StandardMaterial3D.new()
		cloud_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		cloud_material.albedo_color = Color(0.68, 0.76, 0.82, 0.5)
		cloud_material.emission_enabled = true
		cloud_material.emission = Color(0.16, 0.21, 0.24)
		cloud_material.emission_energy_multiplier = 0.75
		cloud.material_override = cloud_material
		var cloud_angle: float = TAU * float(i) / 7.0
		cloud.position = Vector3(cos(cloud_angle) * 1.05, 1.48 + sin(cloud_angle * 2.0) * 0.22, sin(cloud_angle) * 0.42)
		_set_manifestation_layer(cloud)
		add_child(cloud)
	for side: float in [-1.0, 1.0]:
		var pillar := MeshInstance3D.new()
		pillar.name = "CommissionPillar%s" % ("L" if side < 0.0 else "R")
		var pillar_mesh := CylinderMesh.new()
		pillar_mesh.top_radius = 0.08
		pillar_mesh.bottom_radius = 0.34
		pillar_mesh.height = 3.7
		pillar.mesh = pillar_mesh
		pillar.material_override = _fire_material
		pillar.position = Vector3(side * 3.15, 1.85, 0.38)
		_set_manifestation_layer(pillar)
		add_child(pillar)

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
