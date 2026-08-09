class_name RestorationDirector
extends Node3D

var _growth: MultiMeshInstance3D
var _multimesh: MultiMesh
var _persisted: bool = false

func _ready() -> void:
	_build_growth_field()
	EventBus.corruption_field_changed.connect(_on_corruption_field_changed)
	EventBus.campaign_garden_state_loaded.connect(_on_campaign_garden_state_loaded)

func _build_growth_field() -> void:
	_growth = MultiMeshInstance3D.new()
	_growth.name = "RestorationGrowth"
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.instance_count = CorruptionDirector.GRID_WIDTH * CorruptionDirector.GRID_HEIGHT
	var blade := PrismMesh.new()
	blade.size = Vector3(0.1, 0.48, 0.1)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color(0.018, 0.055, 0.012)
	material.emission_energy_multiplier = 0.45
	material.roughness = 0.92
	blade.material = material
	_multimesh.mesh = blade
	_growth.multimesh = _multimesh
	add_child(_growth)
	for index: int in range(_multimesh.instance_count):
		var variation: float = 0.5 + sin(index * 2.417) * 0.5
		_multimesh.set_instance_color(index, Color(0.08 + variation * 0.08, 0.3 + variation * 0.22, 0.055 + variation * 0.06, 1.0))
		_set_growth_transform(index, 0.0)

func _on_corruption_field_changed(values: PackedFloat32Array, width: int, height: int, purity: float, _anchor: float) -> void:
	var bloom_count: int = 0
	for index: int in range(mini(values.size(), _multimesh.instance_count)):
		var growth: float = smoothstep(0.25, 0.82, 1.0 - values[index])
		_set_growth_transform(index, growth)
		if growth > 0.55:
			bloom_count += 1
	EventBus.restoration_feedback_changed.emit(purity, bloom_count, _persisted)

func _set_growth_transform(index: int, growth: float) -> void:
	var x: int = index % CorruptionDirector.GRID_WIDTH
	var y: int = index / CorruptionDirector.GRID_WIDTH
	var base: Vector3 = CorruptionDirector.cell_to_world(x, y)
	var offset := Vector3(sin(index * 12.9898) * 0.72, 0.15 * growth, cos(index * 7.233) * 0.72)
	var basis := Basis(Vector3.UP, fmod(index * 1.618, TAU))
	basis = basis.scaled(Vector3(0.35 + growth * 0.65, maxf(0.001, growth), 0.35 + growth * 0.65))
	_multimesh.set_instance_transform(index, Transform3D(basis, base + offset))

func _on_campaign_garden_state_loaded(_mission_index: int, state: Dictionary) -> void:
	_persisted = state.has("cells")
