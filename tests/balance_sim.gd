extends Node

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var novice_total: float = 0.0
	var skilled_total: float = 0.0
	var expert_total: float = 0.0
	for path: String in GameState.MISSION_PATHS:
		var mission := load(path) as MissionResource
		var novice := _simulate(mission, 0.48)
		var skilled := _simulate(mission, 0.82)
		var expert := _simulate(mission, 1.16)
		if not _valid(novice) or not _valid(skilled) or not _valid(expert):
			push_error("Balance simulation produced invalid state for commission %d" % mission.chapter)
			get_tree().quit(1)
			return
		if float(expert.purity) <= float(skilled.purity) or float(skilled.purity) <= float(novice.purity):
			push_error("Player competence must produce a monotonic restoration outcome in commission %d" % mission.chapter)
			get_tree().quit(1)
			return
		if float(expert.purity) < mission.target_purity:
			push_error("Expert profile must be able to meet commission %d purity target" % mission.chapter)
			get_tree().quit(1)
			return
		novice_total += float(novice.purity)
		skilled_total += float(skilled.purity)
		expert_total += float(expert.purity)
		print("SIM C%02d // novice %d%% // skilled %d%% // expert %d%% // thin %d" % [mission.chapter, roundi(float(novice.purity) * 100.0), roundi(float(skilled.purity) * 100.0), roundi(float(expert.purity) * 100.0), roundi(float(skilled.thin_integrity))])
	if expert_total - novice_total < 0.8:
		push_error("Campaign balance model is not responsive enough to player competence")
		get_tree().quit(1)
		return
	print("GARDEN RECLAIMED BALANCE SIM: %d commissions x 3 profiles passed" % GameState.MISSION_PATHS.size())
	AudioDirector.shutdown()
	await get_tree().process_frame
	get_tree().quit(0)

func _simulate(mission: MissionResource, competence: float) -> Dictionary:
	var corruption: float = clampf(0.42 + mission.corruption_bias, 0.0, 1.0)
	var thin_integrity: float = mission.starting_thin_integrity
	var duration: float = maxf(75.0, mission.survive_seconds)
	var step: float = 0.2
	var elapsed: float = 0.0
	while elapsed < duration:
		var wave: float = 1.0 + floorf(elapsed / 24.0) * 0.08
		var pressure: float = mission.enemy_power * (0.62 + float(mission.enemy_budget) / 38.0) * wave
		var restoration: float = competence * (0.0022 + mission.chapter * 0.000035)
		var spread: float = pressure * 0.00125
		corruption = clampf(corruption + (spread - restoration) * step * 5.0, 0.0, 1.0)
		var defense: float = clampf(competence * 0.72, 0.0, 0.92)
		thin_integrity += (competence * 0.22 - pressure * (1.0 - defense) * 0.12) * step
		thin_integrity = clampf(thin_integrity, 0.0, 100.0)
		elapsed += step
	return {"purity": 1.0 - corruption, "thin_integrity": thin_integrity}

func _valid(result: Dictionary) -> bool:
	return is_finite(float(result.get("purity", NAN))) and is_finite(float(result.get("thin_integrity", NAN))) and float(result.purity) >= 0.0 and float(result.purity) <= 1.0 and float(result.thin_integrity) >= 0.0 and float(result.thin_integrity) <= 100.0
