class_name ChapterLandmark
extends Node3D

var _accent: StandardMaterial3D
var _metal: StandardMaterial3D
var _eye: StandardMaterial3D

func _ready() -> void:
	EventBus.mission_selected.connect(_on_mission_selected)

func _process(delta: float) -> void:
	for child: Node in get_children():
		if child is MeshInstance3D and (child.name.begins_with("Wheel") or child.name.begins_with("Cloud")):
			(child as MeshInstance3D).rotate_y(delta * 0.35)

func _on_mission_selected(_index: int, mission: Resource) -> void:
	var mission_data := mission as MissionResource
	if mission_data != null:
		_rebuild(mission_data.chapter, mission_data.accent_color)

func _rebuild(chapter: int, accent_color: Color) -> void:
	for child: Node in get_children():
		child.queue_free()
	_accent = _material(accent_color.darkened(0.34), accent_color, 1.7, 0.55)
	_metal = _material(Color(0.12, 0.13, 0.14), Color.BLACK, 0.0, 0.78)
	_eye = _material(Color(1.0, 0.78, 0.2), accent_color.lightened(0.2), 4.0, 0.1)
	match chapter:
		1: _build_guardian_gate()
		2: _build_watchers()
		3: _build_delayed_gate()
		4: _build_broken_mirror()
		5: _build_altar()
		6: _build_living_circle()
		7: _build_war_arches()
		_: _build_seven_spires()

func _build_guardian_gate() -> void:
	_add_spire(Vector3(-3.0, 2.2, 0.0), 4.4)
	_add_spire(Vector3(3.0, 2.2, 0.0), 4.4)
	_add_box("Lintel", Vector3(0.0, 4.1, 0.0), Vector3(6.4, 0.32, 0.45), _metal)
	_add_box("TurningSword", Vector3(0.0, 2.1, 0.0), Vector3(0.15, 3.3, 0.15), _accent, Vector3(0.0, 0.0, 0.48))

func _build_watchers() -> void:
	for x: float in [-4.5, -1.5, 1.5, 4.5]:
		_add_spire(Vector3(x, 1.8, 0.0), 3.6)
		_add_eye(Vector3(x, 3.25, -0.38))

func _build_delayed_gate() -> void:
	_add_spire(Vector3(-4.2, 2.5, 0.0), 5.0)
	_add_spire(Vector3(4.2, 2.5, 0.0), 5.0)
	for x: float in [-2.6, -1.3, 0.0, 1.3, 2.6]:
		_add_box("DelayBar", Vector3(x, 2.0, 0.0), Vector3(0.22, 4.0, 0.3), _accent)

func _build_broken_mirror() -> void:
	for i: int in range(7):
		var x: float = (i - 3) * 0.9
		var height: float = 2.2 + (i % 3) * 0.8
		_add_box("MirrorShard", Vector3(x, height * 0.5, 0.0), Vector3(0.55, height, 0.12), _accent, Vector3(0.0, 0.0, (i - 3) * 0.08))

func _build_altar() -> void:
	_add_box("AltarStep", Vector3(0.0, 0.25, 0.0), Vector3(6.0, 0.5, 3.0), _metal)
	_add_box("Altar", Vector3(0.0, 1.0, 0.0), Vector3(3.2, 1.2, 1.8), _metal)
	_add_wheel("WheelAltar", Vector3(0.0, 1.85, 0.0), 0.75, _accent, Vector3(PI * 0.5, 0.0, 0.0))

func _build_living_circle() -> void:
	for i: int in range(6):
		var angle: float = TAU * i / 6.0
		_add_box("WingPillar", Vector3(cos(angle) * 3.4, 1.8, sin(angle) * 1.5), Vector3(0.22, 3.6, 0.8), _accent, Vector3(0.0, -angle, angle * 0.12))
		_add_eye(Vector3(cos(angle) * 3.4, 2.3, sin(angle) * 1.5 - 0.42))

func _build_war_arches() -> void:
	for side: float in [-1.0, 1.0]:
		_add_spire(Vector3(side * 4.0, 2.7, 0.0), 5.4)
		_add_box("CrossedAuthority", Vector3(side * 1.8, 3.4, 0.0), Vector3(0.28, 5.2, 0.28), _accent, Vector3(0.0, 0.0, side * 0.72))

func _build_seven_spires() -> void:
	for i: int in range(7):
		var x: float = (i - 3) * 1.45
		var height: float = 3.2 + (3 - abs(i - 3)) * 0.48
		_add_spire(Vector3(x, height * 0.5, 0.0), height)
		_add_eye(Vector3(x, height - 0.55, -0.36))
	# Horizontal cloud-ring over the seven spires; never a figure-mounted halo.
	_add_wheel("CloudCovenant", Vector3(0.0, 4.4, 0.0), 2.4, _accent, Vector3.ZERO)

func _material(albedo: Color, emission: Color, emission_energy: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = albedo
	material.metallic = metallic
	material.roughness = 0.32
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material

func _add_spire(position: Vector3, height: float) -> void:
	var instance := MeshInstance3D.new()
	instance.name = "Spire"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.12
	mesh.bottom_radius = 0.48
	mesh.height = height
	instance.mesh = mesh
	instance.material_override = _metal
	instance.position = position
	add_child(instance)

func _add_box(node_name: String, position: Vector3, size: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	add_child(instance)

func _add_eye(position: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.name = "WatchingEye"
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	instance.mesh = mesh
	instance.material_override = _eye
	instance.position = position
	add_child(instance)

func _add_wheel(node_name: String, position: Vector3, radius: float, material: Material, rotation: Vector3) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.84
	mesh.outer_radius = radius
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	add_child(instance)
