class_name FallenEnemy
extends EnemyBase

var rebuked_remaining: float = 0.0
var _immune_notice_cooldown: float = 0.0

func _init() -> void:
	kind = &"FALLEN"
	max_integrity = 150.0
	integrity = max_integrity
	speed = 5.2
	attack_damage = 13.0
	tint = Color(0.18, 0.04, 0.28)
	scale_factor = 1.2

func _ready() -> void:
	super._ready()
	EventBus.rebuke_requested.connect(_on_rebuke_requested)

func _physics_process(delta: float) -> void:
	rebuked_remaining = maxf(0.0, rebuked_remaining - delta)
	_immune_notice_cooldown = maxf(0.0, _immune_notice_cooldown - delta)
	super._physics_process(delta)

func can_take_damage(_damage_type: StringName) -> bool:
	if rebuked_remaining > 0.0:
		return true
	if _immune_notice_cooldown <= 0.0:
		_immune_notice_cooldown = 1.0
		EventBus.message_posted.emit("FALLEN IMMUNE // DECLARE [E], THEN KEY & CHAIN [6]", &"danger")
	return false

func _on_rebuke_requested(position: Vector3, radius: float) -> void:
	if global_position.distance_to(position) <= radius:
		rebuked_remaining = 8.0
		EventBus.message_posted.emit("THE LORD REBUKE YOU // FALLEN EXPOSED", &"holy")
