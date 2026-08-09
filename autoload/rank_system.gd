extends Node

const RANKS: PackedStringArray = [
	"MESSENGER", "WATCHER", "POWERS", "CHERUB",
	"SERAPH", "LIVING CREATURE", "ARCHANGEL", "ONE OF THE SEVEN"
]
const DOCTRINES: PackedStringArray = [
	"SENT ONE", "WATCHFUL SIGHT", "TERRITORIAL AUTHORITY", "OPHANIM MOTION",
	"ALTAR ASCENT", "EYES ALL AROUND", "HOST COMMAND", "SEVENTH JUDGMENT"
]
const PASSIVES: PackedStringArray = [
	"Purification establishes the first ground.",
	"Survey marks nearby threats and hidden pressure.",
	"Borrowed authority reduces incoming Glory loss.",
	"Ophanim Dash crosses the field without turning.",
	"Ascent exchanges Glory for sustained flight.",
	"All-around sight automatically seals nearby threats.",
	"Prayer calls the Host sooner and at lower cost.",
	"A Commission Token authorizes Sevenfold Judgment [X]."
]
const COMMISSION_LINES: PackedStringArray = [
	"FEAR NOT. I GO AS SENT.",
	"THE GROUND IS SEEN; NOTHING IS HIDDEN.",
	"AUTHORITY IS BORROWED. THE COMMISSION DEFINES IT.",
	"THE WHEELS GO STRAIGHT; I DO NOT TURN ASIDE.",
	"ALTAR-FIRE BEARS ME UPWARD.",
	"EYES WITHIN AND AROUND KEEP WATCH.",
	"THE HOST ANSWERS PRAYER, NOT MY GLORY.",
	"I STAND READY. LET THE WORD BE GIVEN."
]

var rank_index: int = 0

func _ready() -> void:
	EventBus.mission_selected.connect(_on_mission_selected)
	EventBus.game_started.connect(_on_game_started)
	EventBus.rank_override_requested.connect(_on_rank_override_requested)
	call_deferred("_announce")

func _announce() -> void:
	EventBus.rank_changed.emit(rank_index, RANKS[rank_index])
	EventBus.rank_profile_changed.emit(rank_index, RANKS[rank_index], weapon_tier(), DOCTRINES[rank_index], PASSIVES[rank_index], power_scale(), damage_resistance())

func weapon_tier() -> int:
	return mini(3, 1 + rank_index / 3)

func power_scale() -> float:
	return 1.0 + (weapon_tier() - 1) * 0.28

func damage_resistance() -> float:
	return minf(0.28, rank_index * 0.04)

func has_ophanim_dash() -> bool:
	return rank_index >= 3

func has_ascent() -> bool:
	return rank_index >= 4

func host_formation_size() -> int:
	if rank_index >= 7:
		return 7
	if rank_index >= 6:
		return 5
	return 3

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

func _on_game_started() -> void:
	EventBus.ariel_spoke.emit(COMMISSION_LINES[rank_index])

func _on_rank_override_requested(index: int) -> void:
	rank_index = clampi(index, 0, RANKS.size() - 1)
	_announce()

func _reset_for_test() -> void:
	rank_index = 0
