extends Node3D

const PLAYER_SCENE: PackedScene = preload("res://player/player.tscn")
const DEMON_SCRIPT: Script = preload("res://enemies/demon.gd")
const FALLEN_SCRIPT: Script = preload("res://enemies/fallen.gd")
const SYNTHETIC_SCRIPT: Script = preload("res://enemies/synthetic.gd")
const THIN_PLACE_SCRIPT: Script = preload("res://world/thin_place.gd")
const HOST_SCRIPT: Script = preload("res://host/host_member.gd")
const PRINCE_SCRIPT: Script = preload("res://enemies/territorial_prince.gd")
const HOSTILE_PROJECTILE_SCRIPT: Script = preload("res://enemies/hostile_projectile.gd")
const SLIPPERY_FIELD_SCRIPT: Script = preload("res://world/slippery_field.gd")
const CHAPTER_ARENA_SCRIPT: Script = preload("res://world/chapter_arena.gd")
const CORRUPTION_SHADER: Shader = preload("res://world/shaders/corruption.gdshader")

var _tiles: Array[MeshInstance3D] = []
var _blooms: Dictionary = {}
var _spawn_timer: float = 0.0
var _spawned_fallen: bool = false
var _spawned_synthetic: bool = false
var _latest_purity: float = 0.0
var _threat_timer: float = 0.0
var _player: ArielController
var _mission: MissionResource = preload("res://missions/data/mission_01.tres")
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _mission_fog_color: Color = Color(0.08, 0.1, 0.11)
var _encounter_intensity: float = 0.0
var _last_wave: int = 0

func _ready() -> void:
	randomize()
	_build_environment()
	_build_arena()
	var chapter_arena: ChapterArena = CHAPTER_ARENA_SCRIPT.new() as ChapterArena
	chapter_arena.name = "ChapterArena"
	add_child(chapter_arena)
	_build_corruption_tiles()
	_spawn_thin_place()
	_spawn_player()
	EventBus.corruption_field_changed.connect(_on_corruption_changed)
	EventBus.game_started.connect(_on_game_started)
	EventBus.mission_completed.connect(_on_mission_completed)
	EventBus.mission_failed.connect(_on_mission_failed)
	EventBus.host_requested.connect(_on_host_requested)
	EventBus.mission_selected.connect(_on_mission_selected)
	EventBus.encounter_state_changed.connect(_on_encounter_state_changed)
	EventBus.boss_spawn_requested.connect(_on_boss_spawn_requested)
	EventBus.restoration_feedback_changed.connect(_on_restoration_feedback_changed)
	EventBus.sevenfold_granted.connect(_on_sevenfold_granted)
	EventBus.debug_spawn_requested.connect(_on_debug_spawn_requested)
	EventBus.hostile_projectile_requested.connect(_on_hostile_projectile_requested)
	EventBus.slippery_field_requested.connect(_on_slippery_field_requested)
	EventBus.prayer_started.connect(_on_prayer_started)
	EventBus.declaration_issued.connect(_on_declaration_issued)
	EventBus.law_enacted.connect(_on_law_enacted)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event: InputEvent) -> void:
	if GameState.phase == GameState.Phase.TITLE and event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ENTER:
		GameState.start_game()
	elif GameState.phase in [GameState.Phase.COMPLETE, GameState.Phase.FAILED] and event is InputEventKey and event.is_pressed() and (event as InputEventKey).keycode == KEY_ENTER:
		_reset_run()
		get_tree().reload_current_scene()

func _process(delta: float) -> void:
	if not GameState.is_playing():
		return
	_spawn_timer -= delta
	_threat_timer -= delta
	if _threat_timer <= 0.0:
		_threat_timer = 1.0
		EventBus.threat_density_changed.emit(float(get_tree().get_nodes_in_group("enemies").size()), _player.global_position)
	if _spawn_timer <= 0.0:
		_spawn_timer = maxf(0.9, (_mission.spawn_interval - GameState.elapsed * 0.006) * lerpf(1.0, 0.72, _encounter_intensity))
		var enemy_count: int = get_tree().get_nodes_in_group("enemies").size()
		if enemy_count < _mission.enemy_budget:
			_spawn_demon()
	if _mission.fallen_trigger >= 0.0 and _latest_purity >= _mission.fallen_trigger and not _spawned_fallen:
		_spawned_fallen = true
		_spawn_enemy(FALLEN_SCRIPT, _edge_spawn_position())
		EventBus.message_posted.emit("FALLEN SIGNATURE // FORCE ALONE WILL NOT MOVE IT", &"danger")
	if _mission.synthetic_trigger >= 0.0 and _latest_purity >= _mission.synthetic_trigger and not _spawned_synthetic:
		_spawned_synthetic = true
		_spawn_enemy(SYNTHETIC_SCRIPT, _edge_spawn_position())
		EventBus.message_posted.emit("FABRICATED IDOL // SWITCH TO KINETIC [5, 8, 11]", &"danger")

func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = Color(0.012, 0.02, 0.035)
	_sky_material.sky_horizon_color = Color(0.055, 0.04, 0.075)
	_sky_material.ground_bottom_color = Color(0.008, 0.009, 0.016)
	_sky_material.ground_horizon_color = Color(0.028, 0.026, 0.04)
	_sky_material.sun_angle_max = 30.0
	var sky := Sky.new()
	sky.sky_material = _sky_material
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.12, 0.16, 0.2)
	_environment.ambient_light_energy = 0.82
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.fog_enabled = true
	_environment.fog_sky_affect = 0.42
	_environment.fog_light_color = Color(0.08, 0.1, 0.11)
	_environment.fog_density = 0.012
	world_environment.environment = _environment
	add_child(world_environment)

	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-48.0, -28.0, 0.0)
	moon.light_color = Color(0.56, 0.68, 0.88)
	moon.light_energy = 1.45
	moon.shadow_enabled = true
	add_child(moon)

func _build_arena() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(67.0, 0.6, 52.0)
	floor_collision.shape = floor_shape
	floor_collision.position.y = -0.38
	floor_body.add_child(floor_collision)
	add_child(floor_body)

	for wall_data: Dictionary in [
		{"p": Vector3(0, 2.5, -25.3), "s": Vector3(67, 5, 0.8)},
		{"p": Vector3(0, 2.5, 25.3), "s": Vector3(67, 5, 0.8)},
		{"p": Vector3(-33.1, 2.5, 0), "s": Vector3(0.8, 5, 52)},
		{"p": Vector3(33.1, 2.5, 0), "s": Vector3(0.8, 5, 52)}
	]:
		_add_wall(wall_data.p, wall_data.s)

	# Ruined colonnade: cover that does not obscure the ground-state read.
	for i: int in range(22):
		var angle: float = TAU * float(i) / 22.0
		var radius: float = 17.0 + (i % 3) * 2.8
		var position := Vector3(cos(angle) * radius, 1.6, sin(angle) * radius * 0.72)
		_add_pillar(position, 2.0 + (i % 4) * 0.7)

func _add_wall(position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.position = position
	body.add_child(collision)
	add_child(body)

func _add_pillar(position: Vector3, height: float) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.48
	shape.height = height
	collision.shape = shape
	body.add_child(collision)
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.58
	mesh.height = height
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.22, 0.23, 0.21)
	material.metallic = 0.25
	material.roughness = 0.85
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	add_child(body)

## M18a — every tile shares ONE ShaderMaterial reading the global
## corruption_mask texture CorruptionDirector publishes; ground color no
## longer needs a per-tile CPU write every time the field changes (see
## _on_corruption_changed below, which now only drives the bloom props).
func _build_corruption_tiles() -> void:
	var tile_mesh := BoxMesh.new()
	tile_mesh.size = Vector3(CorruptionDirector.CELL_SIZE - 0.08, 0.12, CorruptionDirector.CELL_SIZE - 0.08)
	var bloom_mesh := PrismMesh.new()
	bloom_mesh.size = Vector3(0.12, 0.55, 0.12)
	var ground_material := ShaderMaterial.new()
	ground_material.shader = CORRUPTION_SHADER
	for y: int in range(CorruptionDirector.GRID_HEIGHT):
		for x: int in range(CorruptionDirector.GRID_WIDTH):
			var index: int = y * CorruptionDirector.GRID_WIDTH + x
			var tile := MeshInstance3D.new()
			tile.mesh = tile_mesh
			tile.position = CorruptionDirector.cell_to_world(x, y) + Vector3(0.0, -0.08, 0.0)
			tile.material_override = ground_material
			add_child(tile)
			_tiles.append(tile)
			if index % 4 == 0:
				var bloom := MeshInstance3D.new()
				bloom.mesh = bloom_mesh
				bloom.position = tile.position + Vector3(randf_range(-0.7, 0.7), 0.28, randf_range(-0.7, 0.7))
				var bloom_material := StandardMaterial3D.new()
				bloom_material.albedo_color = Color(0.28, 0.72, 0.23)
				bloom_material.emission_enabled = true
				bloom_material.emission = Color(0.08, 0.32, 0.05)
				bloom.material_override = bloom_material
				bloom.scale = Vector3.ZERO
				add_child(bloom)
				_blooms[index] = bloom

func _spawn_thin_place() -> void:
	var thin_place: ThinPlace = THIN_PLACE_SCRIPT.new() as ThinPlace
	thin_place.name = "ThinPlace"
	thin_place.position = Vector3.ZERO
	add_child(thin_place)

func _spawn_player() -> void:
	_player = PLAYER_SCENE.instantiate() as ArielController
	_player.position = Vector3(0.0, 0.1, 8.0)
	add_child(_player)

func _on_game_started() -> void:
	_spawned_fallen = false
	_spawned_synthetic = false
	_spawn_timer = _mission.spawn_interval
	_encounter_intensity = 0.0
	_last_wave = 0
	for i: int in range(_mission.starting_demons):
		_spawn_demon()
	EventBus.message_posted.emit("%s // THE GROUND IS THE LIFE BAR" % _mission.display_title(), &"holy")

func _spawn_demon() -> void:
	_spawn_enemy(DEMON_SCRIPT, _edge_spawn_position())

func _spawn_enemy(script: Script, position: Vector3) -> void:
	var enemy: EnemyBase = script.new() as EnemyBase
	enemy.max_integrity *= _mission.enemy_power
	enemy.integrity = enemy.max_integrity
	enemy.attack_damage *= _mission.enemy_power
	enemy.speed *= lerpf(1.0, _mission.enemy_power, 0.35)
	enemy.position = position
	add_child(enemy)

func _on_boss_spawn_requested(kind: StringName, title: String, power: float) -> void:
	var boss: TerritorialPrince = PRINCE_SCRIPT.new() as TerritorialPrince
	boss.configure(kind, title, power)
	boss.position = _edge_spawn_position()
	add_child(boss)

func _on_encounter_state_changed(wave: int, intensity: float, _label: String) -> void:
	_encounter_intensity = intensity
	if wave > _last_wave and _last_wave > 0 and GameState.is_playing():
		_spawn_demon()
	_last_wave = wave

func _edge_spawn_position() -> Vector3:
	var side: int = randi() % 4
	match side:
		0: return Vector3(randf_range(-28.0, 28.0), 0.1, -21.0)
		1: return Vector3(randf_range(-28.0, 28.0), 0.1, 21.0)
		2: return Vector3(-28.0, 0.1, randf_range(-19.0, 19.0))
		_: return Vector3(28.0, 0.1, randf_range(-19.0, 19.0))

func _on_corruption_changed(values: PackedFloat32Array, _width: int, _height: int, purity: float, _anchor: float) -> void:
	_latest_purity = purity
	# Tile color/emission is now read straight off CorruptionDirector's
	# published shader texture (world/shaders/corruption.gdshader) — only
	# the bloom props still need a per-cell CPU update.
	for index: int in range(mini(values.size(), _tiles.size())):
		if _blooms.has(index):
			var corruption: float = values[index]
			var bloom: MeshInstance3D = _blooms[index]
			var growth: float = clampf((0.5 - corruption) * 2.0, 0.0, 1.0)
			bloom.scale = Vector3(1.0, growth, 1.0) * growth

func _on_mission_completed() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	EventBus.combat_feedback.emit(&"restoration_burst", Vector3.ZERO, Color(0.42, 1.0, 0.22), 10.0)
	EventBus.message_posted.emit("THE GARDEN HOLDS // COMMISSION FULFILLED", &"holy")

func _on_mission_failed(_reason: String) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_mission_selected(_index: int, mission: Resource) -> void:
	var mission_data := mission as MissionResource
	if mission_data == null:
		return
	_mission = mission_data
	_mission_fog_color = mission_data.fog_color
	if _environment != null:
		_environment.fog_light_color = mission_data.fog_color
		_environment.ambient_light_color = mission_data.fog_color.lightened(0.28)
	if _sky_material != null:
		_sky_material.sky_top_color = Color(0.012, 0.02, 0.035).lerp(mission_data.fog_color.darkened(0.58), 0.34)
		_sky_material.sky_horizon_color = Color(0.055, 0.04, 0.075).lerp(mission_data.fog_color.darkened(0.34), 0.46)

func _on_restoration_feedback_changed(purity: float, _bloom_count: int, _persisted: bool) -> void:
	if _environment == null:
		return
	_environment.fog_density = lerpf(0.011, 0.0025, purity)
	_environment.fog_light_color = _mission_fog_color.lerp(Color(0.16, 0.22, 0.14), purity * 0.52)
	_environment.ambient_light_color = _mission_fog_color.lightened(0.22).lerp(Color(0.4, 0.43, 0.29), purity * 0.58)
	_environment.ambient_light_energy = lerpf(0.72, 1.12, purity)
	if _sky_material != null:
		var corrupt_top: Color = Color(0.012, 0.02, 0.035).lerp(_mission_fog_color.darkened(0.58), 0.34)
		var corrupt_horizon: Color = Color(0.055, 0.04, 0.075).lerp(_mission_fog_color.darkened(0.34), 0.46)
		_sky_material.sky_top_color = corrupt_top.lerp(Color(0.26, 0.42, 0.7), purity * 0.84)
		_sky_material.sky_horizon_color = corrupt_horizon.lerp(Color(0.95, 0.56, 0.2), purity * 0.9)
		_sky_material.ground_bottom_color = Color(0.008, 0.009, 0.016).lerp(Color(0.12, 0.1, 0.065), purity * 0.72)
		_sky_material.ground_horizon_color = Color(0.028, 0.026, 0.04).lerp(Color(0.48, 0.29, 0.12), purity * 0.84)

func _on_sevenfold_granted(position: Vector3) -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node3D:
			EventBus.damage_requested.emit(enemy, 190.0, &"sonic", (enemy as Node3D).global_position)
	EventBus.purification_requested.emit(position, 20.0, 1.0)
	EventBus.combat_feedback.emit(&"boss_phase", position, Color(1.0, 0.78, 0.24), 18.0)

func _on_debug_spawn_requested(kind: StringName, count: int) -> void:
	for i: int in range(clampi(count, 1, 20)):
		match kind:
			&"FALLEN": _spawn_enemy(FALLEN_SCRIPT, _edge_spawn_position())
			&"SYNTHETIC": _spawn_enemy(SYNTHETIC_SCRIPT, _edge_spawn_position())
			&"PRINCE": _on_boss_spawn_requested(&"DEBUG_PRINCE", "DEBUG TERRITORIAL PRINCE", 0.8)
			_: _spawn_demon()

func _on_hostile_projectile_requested(origin: Vector3, direction: Vector3, speed: float, damage: float, kind: StringName) -> void:
	var projectile: HostileProjectile = HOSTILE_PROJECTILE_SCRIPT.new() as HostileProjectile
	projectile.configure(origin, direction, speed, damage, kind)
	add_child(projectile)

func _on_slippery_field_requested(position: Vector3, radius: float, duration: float) -> void:
	var field: SlipperyField = SLIPPERY_FIELD_SCRIPT.new() as SlipperyField
	field.configure(position, radius, duration)
	add_child(field)

func _on_host_requested(position: Vector3) -> void:
	var formation_size: int = RankSystem.host_formation_size()
	for i: int in range(formation_size):
		var member: Node3D = HOST_SCRIPT.new() as Node3D
		var ring_radius: float = 3.0 + maxf(0.0, formation_size - 3) * 0.22
		member.position = position + Vector3(cos(TAU * i / float(formation_size)) * ring_radius, 1.0, sin(TAU * i / float(formation_size)) * ring_radius)
		add_child(member)
	EventBus.host_arrived.emit()

func _on_prayer_started() -> void:
	if _player != null:
		EventBus.combat_feedback.emit(&"prayer_column", _player.global_position, Color(0.55, 0.72, 1.0), 4.5)

func _on_declaration_issued(_token_id: StringName, _duration: float) -> void:
	if _player != null:
		EventBus.combat_feedback.emit(&"authority_ring", _player.global_position, Color(1.0, 0.76, 0.2), 4.0)

func _on_law_enacted(_zone_id: StringName, _law_id: StringName) -> void:
	EventBus.combat_feedback.emit(&"law_grid", Vector3.ZERO, Color(0.35, 0.82, 1.0), 3.2)

func _reset_run() -> void:
	GameState.return_to_title()
	IntercessorSystem._reset_for_test()
	MissionDirector._reset_for_test()
	RankSystem._reset_for_test()
	PrideSystem._reset_for_test()
	CorruptionDirector._reset_for_test()
	EncounterDirector._reset_for_test()
