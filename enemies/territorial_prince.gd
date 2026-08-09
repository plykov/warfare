class_name TerritorialPrince
extends EnemyBase

var title: String = "TERRITORIAL PRINCE"
var phase: int = 1
var _surge_timer: float = 5.0

func _init() -> void:
	kind = &"TERRITORIAL_PRINCE"
	max_integrity = 620.0
	integrity = max_integrity
	speed = 3.2
	attack_damage = 20.0
	attack_interval = 1.15
	tint = Color(0.42, 0.03, 0.5)
	scale_factor = 1.9

func configure(boss_kind: StringName, boss_title: String, power: float) -> void:
	kind = boss_kind
	title = boss_title
	max_integrity *= power
	integrity = max_integrity
	attack_damage *= power
	speed *= lerpf(1.0, power, 0.25)

func _ready() -> void:
	super._ready()
	EventBus.boss_state_changed.emit(title, integrity, max_integrity, phase)
	EventBus.message_posted.emit("PRINCIPALITY MANIFEST // %s" % title, &"danger")
	EventBus.audio_requested.emit(&"veiled")

func _physics_process(delta: float) -> void:
	if not GameState.is_playing():
		return
	var ratio: float = integrity / maxf(max_integrity, 1.0)
	var next_phase: int = 3 if ratio <= 0.33 else (2 if ratio <= 0.66 else 1)
	if next_phase != phase:
		phase = next_phase
		speed *= 1.12
		EventBus.message_posted.emit("%s // THRONE PHASE %d" % [title, phase], &"danger")
		EventBus.combat_feedback.emit(&"boss_phase", global_position, tint.lightened(0.25), 8.0)
	_surged(delta)
	super._physics_process(delta)
	EventBus.boss_state_changed.emit(title, integrity, max_integrity, phase)

func _surged(delta: float) -> void:
	_surge_timer -= delta
	if _surge_timer > 0.0:
		return
	_surge_timer = maxf(2.4, 6.5 - phase * 1.15)
	var radius: float = 4.0 + phase * 1.5
	EventBus.corruption_requested.emit(global_position, radius, 0.2 + phase * 0.08)
	EventBus.combat_feedback.emit(&"boss_surge", global_position, tint, radius)
	if phase >= 2:
		EventBus.thin_place_damage_requested.emit(2.0 * phase)

func can_take_damage(damage_type: StringName) -> bool:
	if damage_type in [&"utility", &"mark"]:
		return false
	if phase == 2 and damage_type == &"purify":
		return false
	if phase == 3 and damage_type == &"zone":
		return false
	return true

func _on_damage_requested(target: Node, amount: float, damage_type: StringName, hit_position: Vector3) -> void:
	if target == self and not can_take_damage(damage_type):
		EventBus.message_posted.emit("THRONE SHIFTS // CHANGE MANIFESTATION", &"danger")
	super._on_damage_requested(target, amount, damage_type, hit_position)
	if target == self and integrity > 0.0:
		EventBus.boss_state_changed.emit(title, integrity, max_integrity, phase)

func _defeat() -> void:
	EventBus.boss_defeated.emit(kind)
	EventBus.boss_state_changed.emit(title, 0.0, max_integrity, phase)
	EventBus.purification_requested.emit(global_position, 9.0, 1.0)
	super._defeat()
