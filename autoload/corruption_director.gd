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
var _corruption_pattern: StringName = &"EDGE_RING"
var _corruption_seed: int = 1
var _dirty_cells: Dictionary = {}
var _held_zones: Dictionary = {}
var last_spread_evaluated: int = 0

func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)
	EventBus.purification_requested.connect(purify)
	EventBus.corruption_requested.connect(corrupt)
	EventBus.entered_veiled.connect(func() -> void: _is_veiled = true)
	EventBus.exited_veiled.connect(func() -> void: _is_veiled = false)
	EventBus.law_enacted.connect(_on_law_enacted)
	EventBus.zone_laws_changed.connect(_on_zone_laws_changed)
	EventBus.mission_selected.connect(_on_mission_selected)
	EventBus.restoration_state_changed.connect(_on_restoration_state_changed)
	EventBus.campaign_snapshot_requested.connect(_on_campaign_snapshot_requested)
	EventBus.campaign_garden_state_loaded.connect(_on_campaign_garden_state_loaded)

func initialize(field_origin: Vector3 = Vector3.ZERO) -> void:
	origin = field_origin
	cells.resize(GRID_WIDTH * GRID_HEIGHT)
	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			cells[_index(x, y)] = initial_value_for_cell(_corruption_pattern, x, y, _corruption_seed, _corruption_bias, _restoration_bonus)
	# The central Thin Place begins consecrated.
	purify(Vector3.ZERO, 8.0, 1.0)
	_seed_dirty_frontier()
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
	if _dirty_cells.is_empty():
		last_spread_evaluated = 0
		return
	var source: PackedFloat32Array = cells.duplicate()
	var rate: float = NATURAL_SPREAD * (VEILED_SPREAD_MULTIPLIER if _is_veiled else 1.0) * SettingsState.difficulty_multiplier() * GameState.ng_plus_multiplier()
	var candidates: Array = _dirty_cells.keys()
	_dirty_cells.clear()
	last_spread_evaluated = candidates.size()
	for value: Variant in candidates:
		var idx: int = int(value)
		var x: int = idx % GRID_WIDTH
		var y: int = idx / GRID_WIDTH
		if _zone_holds(zone_at_cell(x, y)) and source[idx] < 0.18:
			continue
		var strongest: float = source[idx]
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var nx: int = x + offset.x
			var ny: int = y + offset.y
			if nx >= 0 and nx < GRID_WIDTH and ny >= 0 and ny < GRID_HEIGHT:
				strongest = maxf(strongest, source[_index(nx, ny)])
		var next_value: float = minf(1.0, source[idx] + (strongest - source[idx]) * rate)
		if next_value - source[idx] > 0.00001:
			cells[idx] = next_value
			_mark_cell_and_neighbors(x, y)

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
				var next_value: float = clampf(cells[idx] + amount * falloff, 0.0, 1.0)
				if not is_equal_approx(next_value, cells[idx]):
					cells[idx] = next_value
					_mark_cell_and_neighbors(x, y)

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

func zone_id_for_world(world_position: Vector3) -> StringName:
	var cell: Vector2i = world_to_cell(world_position)
	return zone_at_cell(cell.x, cell.y)

func zone_at_cell(x: int, y: int) -> StringName:
	var dx: int = x - GRID_WIDTH / 2
	var dy: int = y - GRID_HEIGHT / 2
	if abs(dx) <= 2 and abs(dy) <= 2:
		return &"ANCHOR"
	if abs(dx) > abs(dy):
		return &"EAST" if dx > 0 else &"WEST"
	return &"SOUTH" if dy > 0 else &"NORTH"

func dirty_cell_count() -> int:
	return _dirty_cells.size()

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

func _mark_cell_and_neighbors(x: int, y: int) -> void:
	for offset: Vector2i in [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var nx: int = x + offset.x
		var ny: int = y + offset.y
		if nx >= 0 and nx < GRID_WIDTH and ny >= 0 and ny < GRID_HEIGHT:
			_dirty_cells[_index(nx, ny)] = true

func _seed_dirty_frontier() -> void:
	_dirty_cells.clear()
	for y: int in range(GRID_HEIGHT):
		for x: int in range(GRID_WIDTH):
			var value: float = cells[_index(x, y)]
			for offset: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				var nx: int = x + offset.x
				var ny: int = y + offset.y
				if nx < GRID_WIDTH and ny < GRID_HEIGHT and absf(value - cells[_index(nx, ny)]) >= 0.035:
					_mark_cell_and_neighbors(x, y)
					_mark_cell_and_neighbors(nx, ny)

func _zone_holds(zone_id: StringName) -> bool:
	return _held_zones.has(&"GARDEN") or _held_zones.has(zone_id)

static func initial_value_for_cell(pattern: StringName, x: int, y: int, seed: int, bias: float = 0.0, restoration: float = 0.0) -> float:
	var fx: float = float(x) / float(GRID_WIDTH - 1) * 2.0 - 1.0
	var fz: float = float(y) / float(GRID_HEIGHT - 1) * 2.0 - 1.0
	var edge: float = minf(minf(float(x), float(GRID_WIDTH - 1 - x)), minf(float(y), float(GRID_HEIGHT - 1 - y)))
	var value: float = 0.18 + bias - restoration + clampf(1.0 - edge / 6.5, 0.0, 1.0) * 0.7
	match pattern:
		&"EAST_BREACH":
			value += exp(-fz * fz * 12.0) * clampf(fx, 0.0, 1.0) * 0.34
		&"TWIN_FRONTS":
			value += maxf(_source_strength(fx, fz, -0.55, -0.4, 0.48), _source_strength(fx, fz, 0.55, 0.35, 0.42))
		&"SHATTERED":
			value += pow(absf(sin((fx * 2.7 + fz * 4.1) * PI)), 8.0) * 0.34
		&"ALTAR_RING":
			var altar_distance: float = Vector2(fx, fz + 0.42).length()
			value += clampf(1.0 - absf(altar_distance - 0.48) / 0.16, 0.0, 1.0) * 0.4
		&"SPIRAL":
			var polar: float = atan2(fz, fx) + Vector2(fx, fz).length() * 8.0
			value += pow(maxf(0.0, cos(polar)), 6.0) * 0.32
		&"CROSSFIRE":
			value += maxf(exp(-fx * fx * 24.0), exp(-fz * fz * 24.0)) * 0.28
		&"SIEGE":
			var ring_distance: float = Vector2(fx, fz).length()
			value += clampf(1.0 - absf(ring_distance - 0.7) / 0.14, 0.0, 1.0) * 0.42
		_:
			pass
	var hash_value: float = sin(float(x * 127 + y * 311 + seed * 73)) * 43758.5453
	var noise: float = fposmod(hash_value, 1.0) - 0.5
	return clampf(value + noise * 0.1, 0.0, 1.0)

static func _source_strength(x: float, y: float, source_x: float, source_y: float, strength: float) -> float:
	return exp(-Vector2(x - source_x, y - source_y).length_squared() * 8.0) * strength

func _on_game_started() -> void:
	_mission_active = true

func _on_law_enacted(zone_id: StringName, law_id: StringName) -> void:
	if law_id == &"GROUND_HOLDS":
		_held_zones[zone_id] = true
		_ground_holds = _held_zones.has(&"GARDEN")

func _on_zone_laws_changed(laws: Dictionary) -> void:
	_held_zones.clear()
	for zone_value: Variant in laws:
		var zone_id := StringName(zone_value)
		var enacted: Array = laws[zone_value] as Array
		if &"GROUND_HOLDS" in enacted or "GROUND_HOLDS" in enacted:
			_held_zones[zone_id] = true
	_ground_holds = _held_zones.has(&"GARDEN")

func _on_mission_selected(_index: int, mission: Resource) -> void:
	var mission_data := mission as MissionResource
	if mission_data != null:
		_corruption_bias = mission_data.corruption_bias
		_corruption_pattern = StringName(mission_data.corruption_pattern)
		_corruption_seed = mission_data.corruption_seed
	initialize(Vector3.ZERO)

func _on_restoration_state_changed(completed_count: int) -> void:
	_restoration_bonus = minf(0.12, completed_count * 0.018)

func _on_campaign_snapshot_requested(mission_index: int) -> void:
	EventBus.corruption_snapshot_ready.emit(mission_index, cells.duplicate(), purity())

func _on_campaign_garden_state_loaded(_mission_index: int, state: Dictionary) -> void:
	var stored_cells: Variant = state.get("cells", [])
	if stored_cells is Array and (stored_cells as Array).size() == GRID_WIDTH * GRID_HEIGHT:
		cells = PackedFloat32Array(stored_cells as Array)
	var laws: Dictionary = state.get("laws", {}) as Dictionary
	_on_zone_laws_changed(laws)
	_seed_dirty_frontier()
	_emit_state()

func _reset_for_test() -> void:
	_mission_active = false
	_is_veiled = false
	_ground_holds = false
	_held_zones.clear()
	_dirty_cells.clear()
	last_spread_evaluated = 0
	_corruption_bias = 0.0
	_corruption_pattern = &"EDGE_RING"
	_corruption_seed = 1
	_restoration_bonus = 0.0
	initialize(Vector3.ZERO)
