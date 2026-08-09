extends Node

const GRID_WIDTH: int = 25
const GRID_HEIGHT: int = 19
const CELL_SIZE: float = 2.5
const TICK_RATE: float = 0.22
const NATURAL_SPREAD: float = 0.016
const VEILED_SPREAD_MULTIPLIER: float = 3.2

var cells: PackedFloat32Array = PackedFloat32Array()
var origin: Vector3 = Vector3.ZERO
var _tick: float = 0.0
var _is_veiled: bool = false
var _mission_active: bool = false
var _ground_holds: bool = false
var _corruption_bias: float = 0.0
var _restoration_bonus: float = 0.0

func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)
	EventBus.purification_requested.connect(purify)
	EventBus.corruption_requested.connect(corrupt)
	EventBus.entered_veiled.connect(func() -> void: _is_veiled = true)
	EventBus.exited_veiled.connect(func() -> void: _is_veiled = false)
	EventBus.law_enacted.connect(_on_law_enacted)
	EventBus.mission_selected.connect(_on_mission_selected)
	EventBus.restoration_state_changed.connect(_on_restoration_state_changed)

func initialize(field_origin: Vector3 = Vector3.ZERO) -> void:
	origin = field_origin
	cells.resize(GRID_WIDTH * GRID_HEIGHT)
	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var edge: float = minf(minf(float(x), float(GRID_WIDTH - 1 - x)), minf(float(y), float(GRID_HEIGHT - 1 - y)))
			var radial: float = clampf(1.0 - edge / 7.0, 0.0, 1.0)
			cells[_index(x, y)] = clampf(0.2 + _corruption_bias - _restoration_bonus + radial * 0.76 + randf_range(-0.08, 0.08), 0.0, 1.0)
	# The central Thin Place begins consecrated.
	purify(Vector3.ZERO, 8.0, 1.0)
	_emit_state()

func _process(delta: float) -> void:
	if not _mission_active or not GameState.is_playing() or cells.is_empty():
		return
	_tick += delta
	if _tick < TICK_RATE:
		return
	_tick = 0.0
	_spread()
	_emit_state()

func _spread() -> void:
	var source: PackedFloat32Array = cells.duplicate()
	var rate: float = NATURAL_SPREAD * (VEILED_SPREAD_MULTIPLIER if _is_veiled else 1.0)
	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var idx: int = _index(x, y)
			if _ground_holds and source[idx] < 0.18:
				continue
			var strongest: float = source[idx]
			for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var nx: int = x + offset.x
				var ny: int = y + offset.y
				if nx >= 0 and nx < GRID_WIDTH and ny >= 0 and ny < GRID_HEIGHT:
					strongest = maxf(strongest, source[_index(nx, ny)])
			if strongest > source[idx]:
				cells[idx] = minf(1.0, source[idx] + (strongest - source[idx]) * rate)

func purify(world_position: Vector3, radius: float, amount: float) -> void:
	if cells.is_empty():
		return
	_paint(world_position, radius, -absf(amount))

func corrupt(world_position: Vector3, radius: float, amount: float) -> void:
	if cells.is_empty():
		return
	_paint(world_position, radius, absf(amount))

func _paint(world_position: Vector3, radius: float, amount: float) -> void:
	var center: Vector2i = world_to_cell(world_position)
	var cell_radius: int = ceili(radius / CELL_SIZE)
	for y: int in range(maxi(0, center.y - cell_radius), mini(GRID_HEIGHT, center.y + cell_radius + 1)):
		for x: int in range(maxi(0, center.x - cell_radius), mini(GRID_WIDTH, center.x + cell_radius + 1)):
			var pos: Vector3 = cell_to_world(x, y)
			var distance: float = Vector2(pos.x - world_position.x, pos.z - world_position.z).length()
			if distance <= radius:
				var falloff: float = 1.0 - distance / maxf(radius, 0.01)
				var idx: int = _index(x, y)
				cells[idx] = clampf(cells[idx] + amount * falloff, 0.0, 1.0)

func world_to_cell(world_position: Vector3) -> Vector2i:
	var local: Vector3 = world_position - origin
	return Vector2i(
		clampi(floori(local.x / CELL_SIZE + GRID_WIDTH * 0.5), 0, GRID_WIDTH - 1),
		clampi(floori(local.z / CELL_SIZE + GRID_HEIGHT * 0.5), 0, GRID_HEIGHT - 1)
	)

func cell_to_world(x: int, y: int) -> Vector3:
	return origin + Vector3(
		(float(x) - (GRID_WIDTH - 1) * 0.5) * CELL_SIZE,
		0.0,
		(float(y) - (GRID_HEIGHT - 1) * 0.5) * CELL_SIZE
	)

func sample(world_position: Vector3) -> float:
	var cell: Vector2i = world_to_cell(world_position)
	return cells[_index(cell.x, cell.y)]

func purity() -> float:
	if cells.is_empty():
		return 0.0
	var total: float = 0.0
	for value: float in cells:
		total += 1.0 - value
	return total / float(cells.size())

func anchor_corruption() -> float:
	return sample(Vector3.ZERO)

func _emit_state() -> void:
	EventBus.corruption_field_changed.emit(cells.duplicate(), GRID_WIDTH, GRID_HEIGHT, purity(), anchor_corruption())

func _index(x: int, y: int) -> int:
	return y * GRID_WIDTH + x

func _on_game_started() -> void:
	_mission_active = true

func _on_law_enacted(zone_id: StringName, law_id: StringName) -> void:
	if zone_id == &"GARDEN" and law_id == &"GROUND_HOLDS":
		_ground_holds = true

func _on_mission_selected(_index: int, mission: Resource) -> void:
	var mission_data := mission as MissionResource
	if mission_data != null:
		_corruption_bias = mission_data.corruption_bias
	initialize(Vector3.ZERO)

func _on_restoration_state_changed(completed_count: int) -> void:
	_restoration_bonus = minf(0.12, completed_count * 0.018)

func _reset_for_test() -> void:
	_mission_active = false
	_is_veiled = false
	_ground_holds = false
	_corruption_bias = 0.0
	_restoration_bonus = 0.0
	initialize(Vector3.ZERO)
