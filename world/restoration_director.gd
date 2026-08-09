class_name RestorationDirector
extends Node3D

var _growth: MultiMeshInstance3D
var _multimesh: MultiMesh
var _legacy_growth: MultiMeshInstance3D
var _legacy_multimesh: MultiMesh
var _persisted: bool = false

func _ready() -> void:
	_build_growth_field()
	_build_legacy_field()
	EventBus.corruption_field_changed.connect(_on_corruption_field_changed)
	EventBus.campaign_garden_state_loaded.connect(_on_campaign_garden_state_loaded)
	EventBus.campaign_legacy_garden_loaded.connect(_on_campaign_legacy_garden_loaded)

static func _build_blade_mesh(height: float, width: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for angle: float in [0.0, PI * 0.5]:
		var right := Vector3(cos(angle), 0.0, sin(angle)) * width * 0.5
		var facing := Vector3(-sin(angle), 0.0, cos(angle))
		var bend := facing * width * 0.32
		var base_a := -right
		var base_b := right
		var tip_a := -right * 0.15 + bend + Vector3.UP * height
		var tip_b := right * 0.15 + bend + Vector3.UP * height

		surface.set_normal(facing)
		surface.add_vertex(base_a)
		surface.add_vertex(base_b)
		surface.add_vertex(tip_b)
		surface.add_vertex(base_a)
		surface.add_vertex(tip_b)
		surface.add_vertex(tip_a)

		surface.set_normal(-facing)
		surface.add_vertex(base_b)
		surface.add_vertex(base_a)
		surface.add_vertex(tip_a)
		surface.add_vertex(base_b)
		surface.add_vertex(tip_a)
		surface.add_vertex(tip_b)
	return surface.commit()

func _build_growth_field() -> void:
	_growth = MultiMeshInstance3D.new()
	_growth.name = "RestorationGrowth"
	_multimesh = MultiMesh.new()
	_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_multimesh.use_colors = true
	_multimesh.instance_count = CorruptionDirector.GRID_WIDTH * CorruptionDirector.GRID_HEIGHT
	var blade := _build_blade_mesh(0.48, 0.1)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color(0.018, 0.055, 0.012)
	material.emission_energy_multiplier = 0.45
	material.roughness = 0.92
	blade.surface_set_material(0, material)
	_multimesh.mesh = blade
	_growth.multimesh = _multimesh
	add_child(_growth)
	for index: int in range(_multimesh.instance_count):
		var variation: float = 0.5 + sin(index * 2.417) * 0.5
		_multimesh.set_instance_color(index, Color(0.08 + variation * 0.08, 0.3 + variation * 0.22, 0.055 + variation * 0.06, 1.0))
		_set_growth_transform(index, 0.0)

func _build_legacy_field() -> void:
	_legacy_growth = MultiMeshInstance3D.new()
	_legacy_growth.name = "LegacyGardenMemory"
	_legacy_multimesh = MultiMesh.new()
	_legacy_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_legacy_multimesh.use_colors = true
	_legacy_multimesh.instance_count = CorruptionDirector.GRID_WIDTH * CorruptionDirector.GRID_HEIGHT
	var flower := _build_blade_mesh(0.76, 0.16)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color(0.12, 0.24, 0.035)
	material.emission_energy_multiplier = 1.1
	material.roughness = 0.74
	flower.surface_set_material(0, material)
	_legacy_multimesh.mesh = flower
	_legacy_growth.multimesh = _legacy_multimesh
	add_child(_legacy_growth)
	for index: int in range(_legacy_multimesh.instance_count):
		var variation: float = 0.5 + sin(index * 1.913) * 0.5
		_legacy_multimesh.set_instance_color(index, Color(0.2 + variation * 0.14, 0.5 + variation * 0.28, 0.08 + variation * 0.08, 0.9))
		_set_legacy_transform(index, 0.0, 0)

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

func _set_legacy_transform(index: int, growth: float, source_count: int) -> void:
	var x: int = index % CorruptionDirector.GRID_WIDTH
	var y: int = index / CorruptionDirector.GRID_WIDTH
	var base: Vector3 = CorruptionDirector.cell_to_world(x, y)
	var offset := Vector3(cos(index * 9.731) * 0.9, 0.2 + growth * 0.22, sin(index * 5.117) * 0.9)
	var basis := Basis(Vector3.UP, fmod(index * 0.923, TAU))
	var height: float = maxf(0.001, growth * (1.0 + minf(source_count, 6) * 0.08))
	basis = basis.scaled(Vector3(0.45 + growth * 0.55, height, 0.45 + growth * 0.55))
	_legacy_multimesh.set_instance_transform(index, Transform3D(basis, base + offset))

func _on_campaign_garden_state_loaded(_mission_index: int, state: Dictionary) -> void:
	_persisted = state.has("cells")

func _on_campaign_legacy_garden_loaded(_mission_index: int, state: Dictionary) -> void:
	var cells: Array = state.get("cells", []) as Array
	var source_count: int = int(state.get("source_count", 0))
	var bloom_count: int = 0
	for index: int in range(_legacy_multimesh.instance_count):
		var growth: float = 0.0
		if index < cells.size():
			growth = smoothstep(0.25, 0.82, 1.0 - clampf(float(cells[index]), 0.0, 1.0))
		_set_legacy_transform(index, growth, source_count)
		if growth > 0.55:
			bloom_count += 1
	var mean_purity: float = clampf(float(state.get("mean_purity", 0.0)), 0.0, 1.0)
	EventBus.restoration_legacy_changed.emit(source_count, bloom_count, mean_purity)
	if source_count > 0:
		EventBus.message_posted.emit("GARDEN MEMORY // %d PRIOR COMMISSION%s STILL BLOOM" % [source_count, "S" if source_count != 1 else ""], &"holy")
