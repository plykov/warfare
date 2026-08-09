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
var _rank_index: int = 0

func _ready() -> void:
	EventBus.game_started.connect(_on_game_started)
	EventBus.threat_density_changed.connect(_on_threat_density_changed)
	EventBus.campaign_snapshot_requested.connect(_on_campaign_snapshot_requested)
	EventBus.campaign_garden_state_loaded.connect(_on_campaign_garden_state_loaded)
	EventBus.rank_profile_changed.connect(_on_rank_profile_changed)
	EventBus.sevenfold_requested.connect(_on_sevenfold_requested)
	EventBus.fervency_override_requested.connect(_on_fervency_override_requested)
	EventBus.token_grant_requested.connect(_on_token_grant_requested)

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
	var threshold: float = 8.0 if _rank_index >= 6 else 11.0
	var cost: float = HOST_COST * (0.72 if _rank_index >= 6 else 1.0)
	if value < threshold or not is_praying or fervency < cost or _host_cooldown > 0.0 or not GameState.is_playing():
		return
	fervency -= cost
	_host_cooldown = HOST_COOLDOWN
	EventBus.host_requested.emit(position)
	EventBus.message_posted.emit("PRAYER ANSWERED // THE HOST DRAWS NEAR", &"holy")

func _on_campaign_snapshot_requested(mission_index: int) -> void:
	EventBus.laws_snapshot_ready.emit(mission_index, zone_laws.duplicate(true))

func _on_campaign_garden_state_loaded(_mission_index: int, state: Dictionary) -> void:
	zone_laws.clear()
	var stored: Variant = state.get("laws", {})
	if stored is Dictionary:
		zone_laws = (stored as Dictionary).duplicate(true)

func _on_rank_profile_changed(index: int, _name: String, _tier: int, _doctrine: String, _passive: String, _power: float, _resistance: float) -> void:
	_rank_index = index

func _on_sevenfold_requested(position: Vector3) -> void:
	if _rank_index < 7:
		EventBus.sevenfold_denied.emit("RANK INSUFFICIENT")
		return
	if not consume_commission():
		EventBus.sevenfold_denied.emit("COMMISSION TOKEN REQUIRED")
		EventBus.weapon_denied.emit("Commission required for Sevenfold Judgment")
		EventBus.message_posted.emit("SEVENTHFOLD DENIED // DECLARE THE WORD", &"danger")
		return
	EventBus.sevenfold_granted.emit(position)
	EventBus.message_posted.emit("SEVENTH JUDGMENT // THE WORD IS FULFILLED", &"holy")
	EventBus.audio_requested.emit(&"victory")

func _on_fervency_override_requested(value: float) -> void:
	fervency = clampf(value, 0.0, MAX_FERVENCY)
	EventBus.fervency_changed.emit(fervency, MAX_FERVENCY)

func _on_token_grant_requested() -> void:
	tokens[&"REBuke"] = TOKEN_DURATION
	EventBus.declaration_issued.emit(&"REBuke", TOKEN_DURATION)

func _reset_for_test() -> void:
	fervency = MAX_FERVENCY
	is_praying = false
	tokens.clear()
	zone_laws.clear()
	_host_cooldown = 0.0
