extends Node

var enabled: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.debug_command_submitted.connect(execute)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_console"):
		enabled = not enabled
		EventBus.debug_console_toggled.emit(enabled)
		if GameState.is_playing():
			EventBus.pause_requested.emit(enabled)
		get_viewport().set_input_as_handled()

func execute(command: String) -> String:
	var clean := command.strip_edges()
	if clean.is_empty():
		return _respond("", &"info")
	var parts := clean.split(" ", false)
	var verb := parts[0].to_lower()
	match verb:
		"help":
			return _respond("COMMANDS // set_rank 1-8 | fervency 0-100 | pride 0-100 | purify_all | corrupt_anchor | spawn <demon|fallen|synthetic|prince> <count> | token grant", &"info")
		"set_rank":
			if parts.size() < 2 or not parts[1].is_valid_int():
				return _respond("USAGE // set_rank 1-8", &"danger")
			var rank: int = clampi(int(parts[1]) - 1, 0, 7)
			EventBus.rank_override_requested.emit(rank)
			return _respond("RANK OVERRIDE // %d" % (rank + 1), &"holy")
		"fervency":
			if parts.size() < 2 or not parts[1].is_valid_float():
				return _respond("USAGE // fervency 0-100", &"danger")
			var fervency: float = clampf(float(parts[1]), 0.0, 100.0)
			EventBus.fervency_override_requested.emit(fervency)
			return _respond("FERVENCY OVERRIDE // %.1f" % fervency, &"holy")
		"pride":
			if parts.size() < 2 or not parts[1].is_valid_float():
				return _respond("USAGE // pride 0-100", &"danger")
			var pride: float = clampf(float(parts[1]), 0.0, 100.0)
			EventBus.pride_override_requested.emit(pride)
			return _respond("PRIDE OVERRIDE // %.1f" % pride, &"holy")
		"purify_all":
			EventBus.purification_requested.emit(Vector3.ZERO, 100.0, 1.0)
			return _respond("FIELD OVERRIDE // GARDEN PURE", &"holy")
		"corrupt_anchor":
			EventBus.corruption_requested.emit(Vector3.ZERO, 3.5, 1.0)
			return _respond("FIELD OVERRIDE // ANCHOR CONTESTED", &"danger")
		"token":
			if parts.size() >= 2 and parts[1].to_lower() == "grant":
				EventBus.token_grant_requested.emit()
				return _respond("TOKEN OVERRIDE // COMMISSION GRANTED", &"holy")
			return _respond("USAGE // token grant", &"danger")
		"spawn":
			if parts.size() < 2:
				return _respond("USAGE // spawn <demon|fallen|synthetic|prince> <count>", &"danger")
			var kind := StringName(parts[1].to_upper())
			if kind not in [&"DEMON", &"FALLEN", &"SYNTHETIC", &"PRINCE"]:
				return _respond("UNKNOWN HOSTILE // %s" % kind, &"danger")
			var count: int = clampi(int(parts[2]) if parts.size() >= 3 and parts[2].is_valid_int() else 1, 1, 20)
			EventBus.debug_spawn_requested.emit(kind, count)
			return _respond("SPAWN OVERRIDE // %d %s" % [count, kind], &"holy")
		_:
			return _respond("UNKNOWN COMMAND // %s // TYPE help" % verb, &"danger")

func _respond(text: String, tone: StringName) -> String:
	EventBus.debug_output.emit(text, tone)
	return text

func _reset_for_test() -> void:
	enabled = false
