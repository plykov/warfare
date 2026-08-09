class_name ChapterArena
extends Node3D

const CHAPTER_LABELS: PackedStringArray = [
	"FOUNDATION COURT", "WATCHER STEPS", "BROKEN CAUSEWAY", "REBUKE SHARDS",
	"ALTAR TERRACES", "MANY-VOICED RING", "HEAVENLY BATTLEMENT", "SEVENFOLD ASCENT"
]
const CHAPTER_TINTS: Array[Color] = [
	Color(0.26, 0.34, 0.24), Color(0.18, 0.34, 0.38), Color(0.42, 0.25, 0.16), Color(0.31, 0.18, 0.4),
	Color(0.48, 0.25, 0.08), Color(0.18, 0.25, 0.45), Color(0.38, 0.16, 0.36), Color(0.5, 0.22, 0.14)
]

var chapter_index: int = 0

func _ready() -> void:
	EventBus.mission_selected.connect(_on_mission_selected)
	rebuild(0)

func rebuild(index: int) -> void:
	chapter_index = clampi(index, 0, 7)
	for child: Node in get_children():
		child.queue_free()
	var tint: Color = CHAPTER_TINTS[chapter_index]
	for definition: Dictionary in recipe_for(chapter_index):
		_add_structure(definition.position, definition.size, tint, float(definition.get("glow", 0.0)))
	EventBus.message_posted.emit("ARENA FORMED // %s" % CHAPTER_LABELS[chapter_index], &"info")

static func recipe_for(index: int) -> Array[Dictionary]:
	match clampi(index, 0, 7):
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
		_:
			var ascent: Array[Dictionary] = []
			for i: int in range(7):
				var height: float = 0.45 + i * 0.24
				ascent.append(_box(Vector3(-15.0 + i * 5.0, height * 0.5, -15.0 + (i % 2) * 3.2), Vector3(3.4, height, 3.4), 0.32 + i * 0.06))
			ascent.append(_box(Vector3(0, 1.35, -20), Vector3(5, 2.7, 4), 0.7))
			ascent.append(_box(Vector3(0, 0.3, -17), Vector3(4, 0.6, 3)))
			return ascent

static func _paired_steps(left: Vector3, right: Vector3) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for origin: Vector3 in [left, right]:
		var side: float = signf(origin.x)
		for step: int in range(4):
			result.append(_box(origin + Vector3(-side * step * 1.65, 0.2 + step * 0.28, -step * 0.8), Vector3(3.2, 0.4 + step * 0.56, 3.0), 0.35 + step * 0.16))
	return result

static func _box(position: Vector3, size: Vector3, glow: float = 0.0) -> Dictionary:
	return {"position": position, "size": size, "glow": glow}

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
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = tint.darkened(0.48)
	material.metallic = 0.28
	material.roughness = 0.78
	material.emission_enabled = glow > 0.0
	material.emission = tint.darkened(0.2)
	material.emission_energy_multiplier = glow * 0.7
	visual.material_override = material
	body.add_child(visual)
	add_child(body)

func _on_mission_selected(index: int, _mission: Resource) -> void:
	rebuild(index)
