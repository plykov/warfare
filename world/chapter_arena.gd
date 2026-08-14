class_name ChapterArena
extends Node3D

const CHAPTER_LABELS: PackedStringArray = [
	"FOUNDATION COURT", "WATCHER STEPS", "BROKEN CAUSEWAY", "REBUKE SHARDS",
	"ALTAR TERRACES", "MANY-VOICED RING", "HEAVENLY BATTLEMENT", "SEVENFOLD ASCENT",
	"COVENANT GAUNTLET"
]
const CHAPTER_TINTS: Array[Color] = [
	Color(0.26, 0.34, 0.24), Color(0.18, 0.34, 0.38), Color(0.42, 0.25, 0.16), Color(0.31, 0.18, 0.4),
	Color(0.48, 0.25, 0.08), Color(0.18, 0.25, 0.45), Color(0.38, 0.16, 0.36), Color(0.5, 0.22, 0.14),
	Color(0.12, 0.38, 0.3)
]
const ARENA_WALL_MODEL: PackedScene = preload("res://assets/models/arena/castle_wall_half_modular.glb")
const ARENA_COLUMN_MODEL: PackedScene = preload("res://assets/models/arena/castle_tower_square_mid.glb")
const ARENA_PLATFORM_MODEL: PackedScene = preload("res://assets/models/arena/castle_tower_square_base_border.glb")
const MODEL_WALL: StringName = &"wall"
const MODEL_COLUMN: StringName = &"column"
const MODEL_PLATFORM: StringName = &"platform"

static var _detail_noise_texture: NoiseTexture2D
static var _detail_normal_texture: NoiseTexture2D
static var _arena_model_cache: Dictionary = {}

var chapter_index: int = 0

func _ready() -> void:
	EventBus.mission_selected.connect(_on_mission_selected)
	rebuild(0)

func rebuild(index: int) -> void:
	chapter_index = clampi(index, 0, CHAPTER_LABELS.size() - 1)
	for child: Node in get_children():
		child.queue_free()
	var tint: Color = CHAPTER_TINTS[chapter_index]
	for definition: Dictionary in recipe_for(chapter_index):
		_add_structure(definition.position, definition.size, tint, float(definition.get("glow", 0.0)))
	EventBus.message_posted.emit("ARENA FORMED // %s" % CHAPTER_LABELS[chapter_index], &"info")

## M22 — every mission authors a 1-based `chapter` field (MissionResource).
## RankSystem and ChapterLandmark already select by this field, clamped
## against their own roster size; ChapterArena now follows the same pattern
## instead of the raw mission-catalog index, so post-campaign challenge
## trials (chapter 9+) land on the dedicated Covenant Gauntlet recipe rather
## than clamping into the core campaign's finale chapter.
static func chapter_index_for(mission: Resource) -> int:
	var mission_data := mission as MissionResource
	if mission_data == null:
		return 0
	return clampi(mission_data.chapter - 1, 0, CHAPTER_LABELS.size() - 1)

static func recipe_for(index: int) -> Array[Dictionary]:
	match clampi(index, 0, CHAPTER_LABELS.size() - 1):
		0:
			return [
				_box(Vector3(-10, 0.25, -7), Vector3(5, 0.5, 4)), _box(Vector3(10, 0.25, -7), Vector3(5, 0.5, 4)),
				_box(Vector3(-10, 0.65, -10), Vector3(3, 1.3, 2)), _box(Vector3(10, 0.65, -10), Vector3(3, 1.3, 2))
			]
		1:
			return _paired_steps(Vector3(-13, 0, -7), Vector3(13, 0, -7))
		2:
			return [
				_box(Vector3(-15, 0.3, 2), Vector3(4, 0.6, 4)), _box(Vector3(-12, 0.7, 2), Vector3(3, 1.4, 3)),
				_box(Vector3(-9, 1.1, 2), Vector3(3, 2.2, 2)), _box(Vector3(-6.5, 1.1, 2), Vector3(2, 2.2, 2), 1.0),
				_box(Vector3(15, 0.3, 2), Vector3(4, 0.6, 4)), _box(Vector3(12, 0.7, 2), Vector3(3, 1.4, 3)),
				_box(Vector3(9, 1.1, 2), Vector3(3, 2.2, 2)), _box(Vector3(6.5, 1.1, 2), Vector3(2, 2.2, 2), 1.0)
			]
		3:
			return [
				_box(Vector3(-16, 0.6, -8), Vector3(2.2, 1.2, 6), 0.8), _box(Vector3(-11, 0.35, -12), Vector3(5, 0.7, 3)),
				_box(Vector3(-7, 0.7, -12), Vector3(3, 1.4, 3)), _box(Vector3(16, 0.6, -8), Vector3(2.2, 1.2, 6), 0.8),
				_box(Vector3(11, 0.35, -12), Vector3(5, 0.7, 3)), _box(Vector3(7, 0.7, -12), Vector3(3, 1.4, 3)),
				_box(Vector3(-13, 1.8, 11), Vector3(1.4, 3.6, 1.4), 1.0), _box(Vector3(13, 1.8, 11), Vector3(1.4, 3.6, 1.4), 1.0),
				_box(Vector3(0, 0.25, -15), Vector3(6, 0.5, 2))
			]
		4:
			return [
				_box(Vector3(0, 0.25, -12), Vector3(12, 0.5, 4)), _box(Vector3(0, 0.7, -14), Vector3(8, 1.4, 3)),
				_box(Vector3(0, 1.2, -16), Vector3(4, 2.4, 3), 1.0), _box(Vector3(-8, 0.45, -12), Vector3(3, 0.9, 3)),
				_box(Vector3(8, 0.45, -12), Vector3(3, 0.9, 3)), _box(Vector3(-14, 0.65, 5), Vector3(3, 1.3, 5)),
				_box(Vector3(14, 0.65, 5), Vector3(3, 1.3, 5))
			]
		5:
			var ring: Array[Dictionary] = []
			for i: int in range(8):
				var angle: float = TAU * float(i) / 8.0
				ring.append(_box(Vector3(cos(angle) * 14.0, 0.45 + (i % 2) * 0.35, sin(angle) * 10.5), Vector3(3.4, 0.9 + (i % 2) * 0.7, 3.4), 0.65))
			return ring
		6:
			return [
				_box(Vector3(-14, 0.7, -12), Vector3(10, 1.4, 3)), _box(Vector3(14, 0.7, -12), Vector3(10, 1.4, 3)),
				_box(Vector3(-18, 1.5, -12), Vector3(2, 3, 6), 1.0), _box(Vector3(18, 1.5, -12), Vector3(2, 3, 6), 1.0),
				_box(Vector3(-9, 0.3, -8), Vector3(4, 0.6, 3)), _box(Vector3(9, 0.3, -8), Vector3(4, 0.6, 3)),
				_box(Vector3(0, 0.35, -17), Vector3(8, 0.7, 3)), _box(Vector3(0, 0.85, -19), Vector3(5, 1.7, 2), 0.8),
				_box(Vector3(0, 1.7, -21), Vector3(2, 3.4, 2), 1.0)
			]
		7:
			var ascent: Array[Dictionary] = []
			for i: int in range(7):
				var height: float = 0.45 + i * 0.24
				ascent.append(_box(Vector3(-15.0 + i * 5.0, height * 0.5, -15.0 + (i % 2) * 3.2), Vector3(3.4, height, 3.4), 0.32 + i * 0.06))
			ascent.append(_box(Vector3(0, 1.35, -20), Vector3(5, 2.7, 4), 0.7))
			ascent.append(_box(Vector3(0, 0.3, -17), Vector3(4, 0.6, 3)))
			return ascent
		_:
			return _covenant_gauntlet()

## M22 — the dedicated post-campaign challenge-trial arena. A rectangular
## testing ground rather than any single chapter's narrative set piece, since
## all eight challenge trials (M16 + M21) share this space: four witness
## towers at the corners, paired gate platforms on the north/south approach
## axis, alternating cover walls on the east/west axis, and four inner
## measuring posts closer to (but still clear of) the central Thin Place.
static func _covenant_gauntlet() -> Array[Dictionary]:
	return [
		_box(Vector3(-16, 2.2, -16), Vector3(3, 4.4, 3), 0.9), _box(Vector3(16, 2.2, -16), Vector3(3, 4.4, 3), 0.9),
		_box(Vector3(-16, 2.2, 16), Vector3(3, 4.4, 3), 0.9), _box(Vector3(16, 2.2, 16), Vector3(3, 4.4, 3), 0.9),
		_box(Vector3(-4, 0.3, -19), Vector3(3.2, 0.6, 3.2), 0.3), _box(Vector3(4, 0.3, -19), Vector3(3.2, 0.6, 3.2), 0.3),
		_box(Vector3(-4, 0.3, 19), Vector3(3.2, 0.6, 3.2), 0.3), _box(Vector3(4, 0.3, 19), Vector3(3.2, 0.6, 3.2), 0.3),
		_box(Vector3(-19, 1.1, -6), Vector3(2, 2.2, 6)), _box(Vector3(19, 1.1, -6), Vector3(2, 2.2, 6)),
		_box(Vector3(-19, 1.1, 6), Vector3(2, 2.2, 6)), _box(Vector3(19, 1.1, 6), Vector3(2, 2.2, 6)),
		_box(Vector3(-8, 1.3, 0), Vector3(1.2, 2.6, 1.2), 0.5), _box(Vector3(8, 1.3, 0), Vector3(1.2, 2.6, 1.2), 0.5),
		_box(Vector3(0, 1.3, -8), Vector3(1.2, 2.6, 1.2), 0.5), _box(Vector3(0, 1.3, 8), Vector3(1.2, 2.6, 1.2), 0.5)
	]

static func _paired_steps(left: Vector3, right: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for origin: Vector3 in [left, right]:
		var side: float = signf(origin.x)
		for step: int in range(4):
			result.append(_box(origin + Vector3(-side * step * 1.65, 0.2 + step * 0.28, -step * 0.8), Vector3(3.2, 0.4 + step * 0.56, 3.0), 0.35 + step * 0.16))
	return result

static func _box(position: Vector3, size: Vector3, glow: float = 0.0) -> Dictionary:
	return {"position": position, "size": size, "glow": glow}

static func _shared_detail_texture() -> NoiseTexture2D:
	if _detail_noise_texture == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
		noise.frequency = 0.075
		var texture := NoiseTexture2D.new()
		texture.noise = noise
		texture.width = 64
		texture.height = 64
		texture.seamless = true
		texture.generate_mipmaps = true
		var range_ramp := Gradient.new()
		range_ramp.set_color(0, Color(0.78, 0.78, 0.78))
		range_ramp.set_color(1, Color.WHITE)
		texture.color_ramp = range_ramp
		_detail_noise_texture = texture
	return _detail_noise_texture

static func _shared_normal_texture() -> NoiseTexture2D:
	if _detail_normal_texture == null:
		var texture := NoiseTexture2D.new()
		texture.noise = _shared_detail_texture().noise
		texture.width = 64
		texture.height = 64
		texture.seamless = true
		texture.generate_mipmaps = true
		texture.as_normal_map = true
		texture.bump_strength = 0.7
		_detail_normal_texture = texture
	return _detail_normal_texture

static func _first_mesh_instance(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D:
		return root as MeshInstance3D
	for child: Node in root.get_children():
		var match := _first_mesh_instance(child)
		if match != null:
			return match
	return null

static func _model_kind_for_size(size: Vector3) -> StringName:
	var horizontal_max := maxf(size.x, size.z)
	var horizontal_min := minf(size.x, size.z)
	if size.y >= horizontal_max * 1.05:
		return MODEL_COLUMN
	if horizontal_max >= horizontal_min * 1.55:
		return MODEL_WALL
	if size.y <= horizontal_min * 0.7:
		return MODEL_PLATFORM
	return MODEL_WALL

static func _model_scene_for(kind: StringName) -> PackedScene:
	match kind:
		MODEL_COLUMN:
			return ARENA_COLUMN_MODEL
		MODEL_PLATFORM:
			return ARENA_PLATFORM_MODEL
		_:
			return ARENA_WALL_MODEL

static func _model_profile(kind: StringName) -> Dictionary:
	if _arena_model_cache.has(kind):
		return _arena_model_cache[kind]
	var root := _model_scene_for(kind).instantiate()
	var mesh_instance := _first_mesh_instance(root)
	assert(mesh_instance != null and mesh_instance.mesh != null, "Imported arena scene must contain a MeshInstance3D")
	var profile := {
		"mesh": mesh_instance.mesh,
		"bounds": mesh_instance.mesh.get_aabb(),
	}
	_arena_model_cache[kind] = profile
	root.free()
	return profile

static func _uv_scale_for(kind: StringName) -> Vector3:
	match kind:
		MODEL_COLUMN:
			return Vector3(3.25, 3.25, 3.25)
		MODEL_PLATFORM:
			return Vector3(6.0, 6.0, 6.0)
		_:
			return Vector3(4.5, 4.5, 4.5)

static func _model_visual_for_size(size: Vector3) -> MeshInstance3D:
	var kind := _model_kind_for_size(size)
	var profile := _model_profile(kind)
	var bounds: AABB = profile.bounds
	var visual := MeshInstance3D.new()
	visual.name = "Arena%sModel" % String(kind).capitalize()
	visual.mesh = profile.mesh
	var local_target_size := size
	if kind == MODEL_WALL and size.x >= size.z:
		# The wall prop's long authored axis is Z. Rotate it when the recipe's
		# long horizontal axis is X, then scale in the prop's local axes.
		visual.rotation.y = PI * 0.5
		local_target_size = Vector3(size.z, size.y, size.x)
	visual.scale = local_target_size / bounds.size
	# Kenney's modular pieces sit on Y=0. Recenter the scaled authored AABB so
	# the visual occupies the same box as the unchanged collision shape.
	visual.position = -(visual.basis * bounds.get_center())
	visual.set_meta(&"arena_model_kind", kind)
	visual.set_meta(&"arena_natural_bounds", bounds)
	return visual

func _add_structure(at: Vector3, size: Vector3, tint: Color, glow: float) -> void:
	var body := StaticBody3D.new()
	body.add_to_group("arena_structures")
	body.collision_layer = 1
	body.position = at
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	var visual := _model_visual_for_size(size)
	var model_kind: StringName = visual.get_meta(&"arena_model_kind", MODEL_WALL)
	var material := StandardMaterial3D.new()
	material.albedo_color = tint.darkened(0.48)
	material.metallic = 0.28
	material.roughness = 0.78
	material.roughness_texture = _shared_detail_texture()
	material.detail_enabled = true
	material.detail_albedo = _shared_detail_texture()
	material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	material.normal_enabled = true
	material.normal_texture = _shared_normal_texture()
	material.normal_scale = 0.36
	material.uv1_scale = _uv_scale_for(model_kind)
	material.emission_enabled = glow > 0.0
	material.emission = tint.darkened(0.2)
	material.emission_energy_multiplier = glow * 0.7
	visual.material_override = material
	body.add_child(visual)
	add_child(body)

func _on_mission_selected(_index: int, mission: Resource) -> void:
	rebuild(chapter_index_for(mission))
