class_name WeaponViewmodelCatalog
extends RefCounted

const SOURCE_SCENES: Dictionary = {
	&"flaming_sword": preload("res://assets/models/weapons/kaykit_adventurers/sword_2handed.gltf"),
	&"live_coal": preload("res://assets/models/weapons/kaykit_adventurers/smokebomb.gltf"),
	&"trumpet": preload("res://assets/models/weapons/kaykit_adventurers/wand.gltf"),
	&"bowl_of_wrath": preload("res://assets/models/weapons/kaykit_adventurers/mug_full.gltf"),
	&"sickle": preload("res://assets/models/weapons/kaykit_adventurers/axe_1handed.gltf"),
	&"key_chain": preload("res://assets/models/weapons/kaykit_adventurers/arrow_bundle.gltf"),
	&"censer": preload("res://assets/models/weapons/kaykit_adventurers/shield_badge.gltf"),
	&"chariot": preload("res://assets/models/weapons/kaykit_adventurers/shield_spikes.gltf"),
	&"measuring_rod": preload("res://assets/models/weapons/kaykit_adventurers/staff.gltf"),
	&"inkhorn": preload("res://assets/models/weapons/kaykit_adventurers/spellbook_open.gltf"),
	&"millstone": preload("res://assets/models/weapons/kaykit_adventurers/shield_round.gltf"),
	&"drawn_bow": preload("res://assets/models/weapons/kaykit_adventurers/crossbow_2handed.gltf")
}

const VISUAL_PROFILES: Dictionary = {
	&"flaming_sword": {
		"position": Vector3(0.5, -0.43, -0.9),
		"rotation": Vector3(-0.12, 0.0, -0.48),
		"scale": Vector3.ONE * 0.27
	},
	&"live_coal": {
		"position": Vector3(0.46, -0.34, -0.86),
		"rotation": Vector3(-0.3, 0.2, 0.08),
		"scale": Vector3.ONE * 0.58
	},
	&"trumpet": {
		"position": Vector3(0.46, -0.39, -0.92),
		"rotation": Vector3(-0.3, 0.12, -0.22),
		"scale": Vector3(0.46, 0.42, 0.46)
	},
	&"bowl_of_wrath": {
		"position": Vector3(0.47, -0.35, -0.9),
		"rotation": Vector3(-0.38, 0.08, 0.14),
		"scale": Vector3.ONE * 0.58
	},
	&"sickle": {
		"position": Vector3(0.5, -0.41, -0.91),
		"rotation": Vector3(-0.14, 0.0, -0.48),
		"scale": Vector3.ONE * 0.38
	},
	&"key_chain": {
		"position": Vector3(0.46, -0.38, -0.88),
		"rotation": Vector3(0.02, 0.0, -0.32),
		"scale": Vector3.ONE * 0.52
	},
	&"censer": {
		"position": Vector3(0.47, -0.35, -0.91),
		"rotation": Vector3(-0.6, 0.18, 0.12),
		"scale": Vector3(0.4, 0.4, 0.62)
	},
	&"chariot": {
		"position": Vector3(0.48, -0.36, -0.96),
		"rotation": Vector3(-0.45, 0.2, 0.08),
		"scale": Vector3(0.38, 0.38, 0.52)
	},
	&"measuring_rod": {
		"position": Vector3(0.49, -0.43, -0.91),
		"rotation": Vector3(-0.1, 0.0, -0.4),
		"scale": Vector3.ONE * 0.25
	},
	&"inkhorn": {
		"position": Vector3(0.48, -0.36, -0.91),
		"rotation": Vector3(-0.55, 0.1, 0.06),
		"scale": Vector3.ONE * 0.48
	},
	&"millstone": {
		"position": Vector3(0.47, -0.36, -0.93),
		"rotation": Vector3(-0.5, 0.18, 0.12),
		"scale": Vector3(0.43, 0.43, 0.62)
	},
	&"drawn_bow": {
		"position": Vector3(0.49, -0.39, -0.95),
		"rotation": Vector3(-0.4, -0.05, -0.12),
		"scale": Vector3.ONE * 0.42
	}
}

static func apply_to(model: MeshInstance3D, weapon_id: StringName) -> float:
	var source_scene: PackedScene = SOURCE_SCENES.get(weapon_id) as PackedScene
	var profile: Dictionary = VISUAL_PROFILES.get(weapon_id, {}) as Dictionary
	assert(source_scene != null, "Missing viewmodel source for %s" % weapon_id)
	assert(not profile.is_empty(), "Missing viewmodel transform for %s" % weapon_id)

	var source_root := source_scene.instantiate()
	var source_mesh := _find_mesh(source_root)
	assert(source_mesh != null, "Viewmodel source has no mesh: %s" % weapon_id)
	model.mesh = source_mesh.mesh
	source_root.free()

	model.position = profile.position
	model.rotation = profile.rotation
	model.scale = profile.scale
	return model.position.z

static func source_path_for(weapon_id: StringName) -> String:
	var source_scene: PackedScene = SOURCE_SCENES.get(weapon_id) as PackedScene
	return source_scene.resource_path if source_scene != null else ""

static func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child: Node in node.get_children():
		var result := _find_mesh(child)
		if result != null:
			return result
	return null
