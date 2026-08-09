class_name ThinPlace
extends Node3D

const MAX_INTEGRITY: float = 100.0
const PRESENCE_RADIUS: float = 6.0

var integrity: float = MAX_INTEGRITY
var state: StringName = &"ACTIVE"
var player_position: Vector3 = Vector3(999.0, 999.0, 999.0)
var anchor_corruption: float = 0.0
var _contested_cooldown: float = 0.0
var _material: StandardMaterial3D
var _light: OmniLight3D
var _rings: Array[MeshInstance3D] = []

func _ready() -> void:
	add_to_group("thin_place")
	EventBus.thin_place_damage_requested.connect(_take_damage)
	EventBus.player_position_changed.connect(func(value: Vector3) -> void: player_position = value)
	EventBus.corruption_field_changed.connect(_on_field_changed)
	EventBus.mission_selected.connect(_on_mission_selected)
	_build_visual()
	_emit()

func _process(delta: float) -> void:
	if not GameState.is_playing():
		return
	_contested_cooldown = maxf(0.0, _contested_cooldown - delta)
	var distance: float = global_position.distance_to(player_position)
	if distance <= PRESENCE_RADIUS:
		if state != &"SEVERED":
			EventBus.glory_regen_requested.emit(9.0 * delta, &"THIN_PLACE")
		if IntercessorSystem.is_praying:
			integrity = minf(MAX_INTEGRITY, integrity + (18.0 if state == &"SEVERED" else 7.0) * delta)
	if integrity <= 0.0:
		_set_state(&"SEVERED")
	elif _contested_cooldown > 0.0 or anchor_corruption > 0.62:
		_set_state(&"CONTESTED")
	else:
		if state == &"SEVERED" and integrity >= 30.0:
			EventBus.thin_place_restored.emit()
		_set_state(&"ACTIVE")
	_update_visual(delta)
	_emit()

func _take_damage(amount: float) -> void:
	if not GameState.is_playing():
		return
	integrity = maxf(0.0, integrity - amount)
	_contested_cooldown = 2.0
	if state == &"ACTIVE":
		EventBus.thin_place_contested.emit()

func _set_state(value: StringName) -> void:
	if state == value:
		return
	var old: StringName = state
	state = value
	if state == &"SEVERED" and old != &"SEVERED":
		EventBus.thin_place_severed.emit()
		EventBus.message_posted.emit("THIN PLACE SEVERED // PRAY WITHIN THE RING", &"danger")

func _on_field_changed(_values: PackedFloat32Array, _width: int, _height: int, _purity: float, anchor: float) -> void:
	anchor_corruption = anchor

func _on_mission_selected(_index: int, mission: Resource) -> void:
	var mission_data := mission as MissionResource
	if mission_data == null:
		return
	integrity = clampf(mission_data.starting_thin_integrity, 0.0, MAX_INTEGRITY)
	state = &"SEVERED" if integrity <= 0.0 else (&"CONTESTED" if integrity < 60.0 else &"ACTIVE")
	_emit()

func _emit() -> void:
	EventBus.thin_place_changed.emit(integrity, state)

func _build_visual() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(0.92, 0.78, 0.28)
	_material.emission_enabled = true
	_material.emission = Color(1.0, 0.62, 0.1)
	_material.emission_energy_multiplier = 3.5
	_material.metallic = 0.65
	for i: int in range(3):
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 1.25 + i * 0.52
		mesh.outer_radius = 1.3 + i * 0.52
		ring.mesh = mesh
		ring.material_override = _material
		ring.position.y = 0.09 + i * 0.08
		add_child(ring)
		_rings.append(ring)
	_light = OmniLight3D.new()
	_light.position.y = 2.2
	_light.omni_range = 13.0
	_light.light_color = Color(1.0, 0.61, 0.18)
	_light.light_energy = 5.0
	add_child(_light)

func _update_visual(delta: float) -> void:
	var holy: Color = Color(1.0, 0.65, 0.18)
	var threatened: Color = Color(0.9, 0.12, 0.05)
	var severed: Color = Color(0.12, 0.02, 0.16)
	var target: Color = holy if state == &"ACTIVE" else (threatened if state == &"CONTESTED" else severed)
	_material.emission = _material.emission.lerp(target, minf(1.0, delta * 6.0))
	_light.light_color = _material.emission
	_light.light_energy = 5.0 if state == &"ACTIVE" else (2.5 if state == &"CONTESTED" else 0.3)
	for i: int in range(_rings.size()):
		_rings[i].rotation.y += delta * (0.55 + i * 0.24) * (-1.0 if i % 2 == 0 else 1.0)
