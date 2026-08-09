class_name ArielController
extends CharacterBody3D

# Published Quake 3 values scaled from roughly 32 units per metre.
const QU: float = 1.0 / 32.0
const GROUND_SPEED: float = 320.0 * QU
const GROUND_ACCEL: float = 10.0
const AIR_ACCEL: float = 1.0
const FRICTION: float = 6.0
const STOP_SPEED: float = 100.0 * QU
const JUMP_VELOCITY: float = 8.2
const GRAVITY: float = 25.0
const OPHANIM_DASH_SPEED: float = 18.0
const OPHANIM_DASH_COOLDOWN: float = 1.15
const ASCENT_GLORY_PER_SECOND: float = 9.0
const BASE_MOUSE_SENSITIVITY: float = 0.0018

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var glory: GloryComponent = $GloryComponent

var _dash_cooldown: float = 0.0
var _was_grounded: bool = false
var _veiled_speed_scale: float = 1.0
var _mouse_sensitivity: float = 1.0
var _screen_shake: float = 0.75
var _shake_remaining: float = 0.0
var _head_rest: Vector3

func _ready() -> void:
	add_to_group("player")
	EventBus.game_started.connect(_on_game_started)
	EventBus.entered_veiled.connect(func() -> void: _veiled_speed_scale = 0.8)
	EventBus.exited_veiled.connect(func() -> void: _veiled_speed_scale = 1.0)
	EventBus.player_dashed.connect(_on_chariot_impulse)
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.combat_feedback.connect(_on_combat_feedback)
	_on_settings_changed(SettingsState.values)
	_head_rest = head.position
	camera.set_cull_mask_value(16, false)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and GameState.is_playing():
		var motion := event as InputEventMouseMotion
		rotate_y(-motion.relative.x * BASE_MOUSE_SENSITIVITY * _mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x - motion.relative.y * BASE_MOUSE_SENSITIVITY * _mouse_sensitivity, deg_to_rad(-88.0), deg_to_rad(88.0))

func _physics_process(delta: float) -> void:
	if not GameState.is_playing():
		return
	_shake_remaining = maxf(0.0, _shake_remaining - delta)
	head.position = _head_rest + (Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * _shake_remaining * _screen_shake if _shake_remaining > 0.0 else Vector3.ZERO)
	_dash_cooldown = maxf(0.0, _dash_cooldown - delta)
	var input: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish_direction: Vector3 = (global_basis * Vector3(input.x, 0.0, input.y)).normalized()
	var wish_speed: float = GROUND_SPEED * input.length() * _veiled_speed_scale
	var grounded: bool = is_on_floor()

	if grounded:
		_apply_friction(delta)
		_accelerate(wish_direction, wish_speed, GROUND_ACCEL, delta)
		if Input.is_action_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	else:
		_accelerate(wish_direction, wish_speed, AIR_ACCEL, delta)
		velocity.y -= GRAVITY * delta
		if RankSystem.has_ascent() and Input.is_action_pressed("jump") and glory.glory > 0.0:
			velocity.y = move_toward(velocity.y, 7.0, 22.0 * delta)
			glory.spend(ASCENT_GLORY_PER_SECOND * delta)

	if Input.is_action_just_pressed("dash") and RankSystem.has_ophanim_dash() and _dash_cooldown <= 0.0:
		var dash_direction: Vector3 = wish_direction if wish_direction.length_squared() > 0.1 else -global_basis.z
		velocity.x = dash_direction.x * OPHANIM_DASH_SPEED
		velocity.z = dash_direction.z * OPHANIM_DASH_SPEED
		_dash_cooldown = OPHANIM_DASH_COOLDOWN
		EventBus.player_dashed.emit()
		EventBus.audio_requested.emit(&"declare")

	move_and_slide()
	if is_on_floor() and not _was_grounded:
		EventBus.player_landed.emit()
	_was_grounded = is_on_floor()
	EventBus.player_position_changed.emit(global_position)
	EventBus.player_moved.emit(Vector2(velocity.x, velocity.z).length())
	if not glory.is_veiled:
		EventBus.purification_requested.emit(global_position, 3.4, delta * 0.22)

func _apply_friction(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var speed: float = horizontal.length()
	if speed < 0.001:
		return
	var control: float = maxf(speed, STOP_SPEED)
	var drop: float = control * FRICTION * delta
	var new_speed: float = maxf(0.0, speed - drop) / speed
	velocity.x *= new_speed
	velocity.z *= new_speed

# Q3 PM_Accelerate. Do not cap air velocity: the projection creates bhop gain.
func _accelerate(wish_direction: Vector3, wish_speed: float, acceleration: float, delta: float) -> void:
	if wish_direction == Vector3.ZERO:
		return
	var current_speed: float = velocity.dot(wish_direction)
	var add_speed: float = wish_speed - current_speed
	if add_speed <= 0.0:
		return
	var acceleration_speed: float = acceleration * wish_speed * delta
	acceleration_speed = minf(acceleration_speed, add_speed)
	velocity += wish_direction * acceleration_speed

func _on_chariot_impulse() -> void:
	if GameState.is_playing():
		velocity += -global_basis.z * 4.0

func _on_game_started() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_settings_changed(values: Dictionary) -> void:
	_mouse_sensitivity = float(values.get(&"mouse_sensitivity", 1.0))
	_screen_shake = float(values.get(&"screen_shake", 0.75))

func _on_combat_feedback(kind: StringName, position: Vector3, _tint: Color, strength: float) -> void:
	if kind in [&"impact", &"boss_phase", &"boss_surge"]:
		var distance_scale: float = 1.0 / maxf(1.0, global_position.distance_to(position) * 0.18)
		_shake_remaining = maxf(_shake_remaining, minf(0.16, strength * 0.012) * distance_scale)
