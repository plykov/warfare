class_name GloryComponent
extends Node

const MAX_GLORY: float = 100.0
const VEILED_EXIT_THRESHOLD: float = 25.0

var glory: float = MAX_GLORY
var is_veiled: bool = false

func _ready() -> void:
	EventBus.player_damage_requested.connect(take_damage)
	EventBus.glory_regen_requested.connect(_on_regen_requested)
	EventBus.glory_spend_requested.connect(_on_spend_requested)
	call_deferred("_emit")

func take_damage(amount: float, source: StringName = &"UNKNOWN") -> void:
	if amount <= 0.0 or not GameState.is_playing():
		return
	glory = maxf(0.0, glory - amount)
	EventBus.player_damaged.emit(amount, source)
	EventBus.audio_requested.emit(&"hit")
	if glory <= 0.0 and not is_veiled:
		is_veiled = true
		EventBus.entered_veiled.emit()
		EventBus.audio_requested.emit(&"veiled")
		EventBus.message_posted.emit("VEILED // THE GARDEN IS RECLAIMING ITSELF", &"danger")
	_emit()

func restore(amount: float) -> void:
	if amount <= 0.0:
		return
	glory = minf(MAX_GLORY, glory + amount)
	if is_veiled and glory >= VEILED_EXIT_THRESHOLD:
		is_veiled = false
		EventBus.exited_veiled.emit()
		EventBus.message_posted.emit("GLORY RESTORED // ADVANCE", &"holy")
	_emit()

func spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if glory < amount:
		EventBus.weapon_denied.emit("Insufficient Glory")
		return false
	take_damage(amount, &"ABILITY")
	return true

func _on_regen_requested(amount: float, _source: StringName) -> void:
	restore(amount)

func _on_spend_requested(amount: float, _source: StringName) -> void:
	spend(amount)

func _emit() -> void:
	EventBus.glory_changed.emit(glory, MAX_GLORY)

func _reset_for_test() -> void:
	glory = MAX_GLORY
	is_veiled = false
	_emit()
