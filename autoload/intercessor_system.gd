extends Node

const MAX_FERVENCY: float = 100.0
const PRAYER_DRAIN_PER_SECOND: float = 7.0
const PRAYER_GLORY_PER_SECOND: float = 13.0
const REST_PER_SECOND: float = 4.0
const DECLARE_COST: float = 24.0
const TOKEN_DURATION: float = 11.0
const LEGISLATE_COST: float = 55.0
const HOST_COST: float = 34.0
const HOST_COOLDOWN: float = 24.0

var fervency: float = MAX_FERVENCY
var is_praying: bool = false
var tokens: Dictionary = {}
var zone_laws: Dictionary = {}
var _host_cooldown: float = 0.0

func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)
	EventBus.threat_density_changed.connect(_on_threat_density_changed)

func _process(delta: float) -> void:
	if not GameState.is_playing():
		return
	_host_cooldown = maxf(0.0, _host_cooldown - delta)
	if is_praying and fervency > 0.0:
		fervency = maxf(0.0, fervency - PRAYER_DRAIN_PER_SECOND * delta)
		EventBus.glory_regen_requested.emit(PRAYER_GLORY_PER_SECOND * delta, &"PRAYER")
		if fervency <= 0.0:
			stop_prayer()
	else:
		fervency = minf(MAX_FERVENCY, fervency + REST_PER_SECOND * delta)

	var expired: Array[StringName] = []
	for token_id: StringName in tokens:
		tokens[token_id] = float(tokens[token_id]) - delta
		if float(tokens[token_id]) <= 0.0:
			expired.append(token_id)
	for token_id: StringName in expired:
		tokens.erase(token_id)

	var commission_remaining: float = float(tokens.get(&"REBuke", 0.0))
	EventBus.commission_state_changed.emit(commission_remaining > 0.0, commission_remaining)
	EventBus.fervency_changed.emit(fervency, MAX_FERVENCY)

func start_prayer() -> void:
	if is_praying or fervency <= 0.0 or not GameState.is_playing():
		return
	is_praying = true
	EventBus.prayer_started.emit()
	EventBus.message_posted.emit("INTERCESSOR // PRAYER CHANNEL OPEN", &"holy")

func stop_prayer() -> void:
	if not is_praying:
		return
	is_praying = false
	EventBus.prayer_stopped.emit()

func declare() -> bool:
	if fervency < DECLARE_COST or not GameState.is_playing():
		EventBus.declaration_denied.emit()
		EventBus.message_posted.emit("DECLARATION DENIED // FERVENCY LOW", &"danger")
		return false
	fervency -= DECLARE_COST
	tokens[&"REBuke"] = TOKEN_DURATION
	EventBus.declaration_issued.emit(&"REBuke", TOKEN_DURATION)
	EventBus.message_posted.emit("THE WORD IS GIVEN // REBUKE COMMISSIONED", &"holy")
	EventBus.audio_requested.emit(&"declare")
	return true

func has_commission(token_id: StringName = &"REBuke") -> bool:
	return float(tokens.get(token_id, 0.0)) > 0.0

func consume_commission(token_id: StringName = &"REBuke") -> bool:
	if not has_commission(token_id):
		return false
	tokens.erase(token_id)
	return true

func legislate(zone_id: StringName, law_id: StringName) -> bool:
	if fervency < LEGISLATE_COST or not GameState.is_playing():
		EventBus.law_denied.emit()
		EventBus.message_posted.emit("LEGISLATION DENIED // FERVENCY LOW", &"danger")
		return false
	fervency -= LEGISLATE_COST
	var laws: Array = zone_laws.get(zone_id, [])
	if law_id not in laws:
		laws.append(law_id)
	zone_laws[zone_id] = laws
	EventBus.law_enacted.emit(zone_id, law_id)
	EventBus.message_posted.emit("LAW ENACTED // GROUND HOLDS", &"holy")
	EventBus.audio_requested.emit(&"legislate")
	return true

func has_law(zone_id: StringName, law_id: StringName) -> bool:
	return law_id in zone_laws.get(zone_id, [])

func _on_game_started() -> void:
	EventBus.fervency_changed.emit(fervency, MAX_FERVENCY)

func _on_threat_density_changed(value: float, position: Vector3) -> void:
	if value < 11.0 or not is_praying or fervency < HOST_COST or _host_cooldown > 0.0 or not GameState.is_playing():
		return
	fervency -= HOST_COST
	_host_cooldown = HOST_COOLDOWN
	EventBus.host_requested.emit(position)
	EventBus.message_posted.emit("PRAYER ANSWERED // THE HOST DRAWS NEAR", &"holy")

func _reset_for_test() -> void:
	fervency = MAX_FERVENCY
	is_praying = false
	tokens.clear()
	zone_laws.clear()
	_host_cooldown = 0.0
