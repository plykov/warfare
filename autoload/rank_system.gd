extends Node

const RANKS: PackedStringArray = [
	"MESSENGER", "WATCHER", "POWERS", "CHERUB",
	"SERAPH", "LIVING CREATURE", "ARCHANGEL", "ONE OF THE SEVEN"
]

var rank_index: int = 0

func _ready() -> void:
	EventBus.mission_selected.connect(_on_mission_selected)
	call_deferred("_announce")

func _announce() -> void:
	EventBus.rank_changed.emit(rank_index, RANKS[rank_index])

func has_ophanim_dash() -> bool:
	return rank_index >= 3

func has_ascent() -> bool:
	return rank_index >= 4

func strip_rank() -> void:
	rank_index = maxi(0, rank_index - 1)
	_announce()
	EventBus.message_posted.emit("PRIDE HAS DIMMED YOUR COMMISSION", &"danger")

func _on_mission_selected(_index: int, mission: Resource) -> void:
	var mission_data := mission as MissionResource
	if mission_data == null:
		return
	rank_index = clampi(mission_data.chapter - 1, 0, RANKS.size() - 1)
	_announce()

func _reset_for_test() -> void:
	rank_index = 0
