class_name HostMember
extends Node3D

const LIFETIME: float = 14.0
const ATTACK_INTERVAL: float = 0.55
const WITHDRAW_COOLDOWN: float = 18.0
const STEER_SPEED: float = 4.6

var _life: float = LIFETIME
var _attack: float = 0.0
var _phase: float = 0.0
var _sealed_remaining: float = 0.0
var withdrawn: bool = false
var _return_remaining: float = 0.0
var _target: Node3D

func _ready() -> void:
	add_to_group("host")
	EventBus.seal_requested.connect(_on_seal_requested)
	_build_visual()

func _process(delta: float) -> void:
	if not GameState.is_playing():
		return
	if withdrawn:
		_return_remaining = maxf(0.0, _return_remaining - delta)
		if _return_remaining <= 0.0:
			_return_to_field()
		return
	_sealed_remaining = maxf(0.0, _sealed_remaining - delta)
	if _sealed_remaining <= 0.0:
		_life -= delta
	_attack -= delta
	_phase += delta
	position.y = 1.4 + sin(_phase * 2.4) * 0.25
	_target = _select_target()
	if _target != null:
		var direction: Vector3 = _target.global_position - global_position
		direction.y = 0.0
		if direction.length() > 5.0:
			position += direction.normalized() * STEER_SPEED * delta
			look_at(global_position + direction.normalized(), Vector3.UP)
	else:
		rotate_y(delta * 0.7)
	if _attack <= 0.0:
		_attack = ATTACK_INTERVAL * (0.62 if _sealed_remaining > 0.0 else 1.0)
		_strike()
	if _life <= 0.0:
		_withdraw()

func _strike() -> void:
	var best: Node3D = _select_target()
	if best != null and global_position.distance_to(best.global_position) <= 16.0:
		EventBus.damage_requested.emit(best, 24.0 if _sealed_remaining > 0.0 else 16.0, &"purify", best.global_position)
		EventBus.purification_requested.emit(best.global_position, 2.5, 0.12)

func _select_target() -> Node3D:
	var best: Node3D
	var best_score: float = -INF
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		if not node is Node3D:
			continue
		var enemy := node as Node3D
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance > 16.0:
			continue
		var marked_bonus: float = 4.0 if enemy.get("marked_remaining") != null and float(enemy.get("marked_remaining")) > 0.0 else 0.0
		var score: float = 18.0 - distance + marked_bonus
		if score > best_score:
			best_score = score
			best = enemy
	return best

func _withdraw() -> void:
	if withdrawn:
		return
	withdrawn = true
	_return_remaining = WITHDRAW_COOLDOWN
	visible = false
	EventBus.host_withdrawn.emit()

func _return_to_field() -> void:
	withdrawn = false
	_life = LIFETIME
	_attack = 0.0
	visible = true
	EventBus.host_returned.emit()
	EventBus.combat_feedback.emit(&"host_return", global_position, Color(1.0, 0.72, 0.22), 7.0)
	EventBus.audio_requested.emit(&"host_return")
	EventBus.message_posted.emit("HOST RETURNED // A COLUMN OF FIRE RE-ENTERS THE FIELD", &"holy")

func _on_seal_requested(target: Node, duration: float) -> void:
	if target != self:
		return
	_sealed_remaining = maxf(_sealed_remaining, duration)
	EventBus.target_sealed.emit(&"HOST")
	EventBus.message_posted.emit("INKHORN SEAL // HOST MEMBER HELD IN SERVICE", &"holy")
	EventBus.combat_feedback.emit(&"impact", global_position, Color(1.0, 0.78, 0.28), 3.0)

func _build_visual() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.88, 0.68)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.62, 0.15)
	material.emission_energy_multiplier = 2.8
	material.metallic = 0.45
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.25
	body_mesh.height = 1.2
	body.mesh = body_mesh
	body.material_override = material
	add_child(body)
	for side: float in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wing_mesh := PrismMesh.new()
		wing_mesh.size = Vector3(0.12, 1.15, 0.48)
		wing.mesh = wing_mesh
		wing.material_override = material
		wing.position = Vector3(side * 0.48, 0.15, 0.12)
		wing.rotation.z = side * 0.68
		add_child(wing)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.58, 0.12)
	light.light_energy = 2.2
	light.omni_range = 6.0
	add_child(light)
