extends Node

const MAX_PRIDE: float = 100.0
var pride: float = 0.0

func _ready() -> void:
	EventBus.law_denied.connect(_on_uncommissioned_act)
	EventBus.weapon_denied.connect(_on_weapon_denied)
	EventBus.campaign_pride_loaded.connect(_on_campaign_pride_loaded)
	EventBus.pride_override_requested.connect(_on_pride_override_requested)

func add(amount: float) -> void:
	pride = clampf(pride + amount, 0.0, MAX_PRIDE)
	EventBus.pride_changed.emit(pride, MAX_PRIDE)
	if pride >= MAX_PRIDE:
		pride = 35.0
		RankSystem.strip_rank()

func _on_uncommissioned_act() -> void:
	add(8.0)

func _on_weapon_denied(reason: String) -> void:
	if "commission" in reason.to_lower():
		add(2.0)

func _on_campaign_pride_loaded(value: float) -> void:
	pride = clampf(value, 0.0, MAX_PRIDE)
	EventBus.pride_changed.emit(pride, MAX_PRIDE)

func _on_pride_override_requested(value: float) -> void:
	pride = clampf(value, 0.0, MAX_PRIDE)
	EventBus.pride_changed.emit(pride, MAX_PRIDE)

func _reset_for_test() -> void:
	pride = 0.0
