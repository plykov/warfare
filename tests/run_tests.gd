extends Node

var failures: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	await get_tree().process_frame
	_test_glory_never_kills()
	_test_veiled_hysteresis()
	_test_corruption_painting()
	_test_commission_gate()
	_test_rank_identity()
	_test_mission_catalog()
	_test_campaign_unlock_and_rank()
	_test_objective_primitives()
	_test_mission_objective_composition()
	await get_tree().process_frame
	if failures.is_empty():
		print("GARDEN RECLAIMED TESTS: 9 passed")
		AudioDirector.shutdown()
		await get_tree().process_frame
		get_tree().quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		AudioDirector.shutdown()
		await get_tree().process_frame
		get_tree().quit(1)

func _test_glory_never_kills() -> void:
	var component := GloryComponent.new()
	get_tree().root.add_child(component)
	GameState.phase = GameState.Phase.PLAYING
	component.take_damage(10000.0, &"TEST")
	_assert(component.glory == 0.0, "10k damage must clamp Glory to zero")
	_assert(component.is_veiled, "10k damage must Veil rather than kill")
	_assert(is_instance_valid(component), "Glory damage must not free the player component")
	component.queue_free()

func _test_veiled_hysteresis() -> void:
	var component := GloryComponent.new()
	get_tree().root.add_child(component)
	component.take_damage(100.0, &"TEST")
	component.restore(24.9)
	_assert(component.is_veiled, "Veiled must persist below 25 Glory")
	component.restore(0.1)
	_assert(not component.is_veiled, "Veiled must exit at 25 Glory")
	component.queue_free()

func _test_corruption_painting() -> void:
	CorruptionDirector.initialize(Vector3.ZERO)
	CorruptionDirector.corrupt(Vector3.ZERO, 2.0, 1.0)
	var before: float = CorruptionDirector.sample(Vector3.ZERO)
	CorruptionDirector.purify(Vector3.ZERO, 2.0, 0.5)
	var after: float = CorruptionDirector.sample(Vector3.ZERO)
	_assert(after < before, "Purification must reduce corruption")

func _test_commission_gate() -> void:
	IntercessorSystem._reset_for_test()
	_assert(not IntercessorSystem.has_commission(), "Commission must begin empty")
	GameState.phase = GameState.Phase.PLAYING
	_assert(IntercessorSystem.declare(), "Declaration must succeed at full Fervency")
	_assert(IntercessorSystem.has_commission(), "Declaration must create a Rebuke window")

func _test_rank_identity() -> void:
	RankSystem.rank_index = 4
	_assert(RankSystem.has_ascent(), "Seraph rank must unlock Ascent")
	_assert(RankSystem.has_ophanim_dash(), "Seraph rank must retain Ophanim Dash")

func _test_mission_catalog() -> void:
	_assert(GameState.MISSION_PATHS.size() == 8, "Campaign must contain exactly eight missions")
	var allowed := [&"PURIFY_ZONE", &"RESTORE_THIN_PLACE", &"BIND_TARGET", &"SURVIVE_WAVES", &"ESCORT_HOST", &"BREAK_IDOL"]
	for i: int in range(GameState.MISSION_PATHS.size()):
		var mission := load(GameState.MISSION_PATHS[i]) as MissionResource
		_assert(mission != null, "Mission %d must load" % (i + 1))
		if mission == null:
			continue
		_assert(mission.chapter == i + 1, "Mission chapter ordering must be stable")
		for objective_id: String in mission.objective_ids:
			_assert(StringName(objective_id) in allowed, "Mission objectives must use one of the six primitives")

func _test_campaign_unlock_and_rank() -> void:
	GameState._reset_for_test()
	GameState.phase = GameState.Phase.PLAYING
	EventBus.mission_outcome_requested.emit(true, "TEST COMPLETE")
	_assert(GameState.unlocked_count == 2, "Completing mission 1 must unlock mission 2")
	_assert(GameState.completed.has("0"), "Completed mission must be recorded")
	GameState.return_to_title()
	_assert(GameState.select_mission(1), "Unlocked mission must be selectable")
	GameState.start_game()
	_assert(RankSystem.rank_index == 1, "Mission 2 must manifest the Watcher rank")
	GameState._reset_for_test()

func _test_objective_primitives() -> void:
	_assert(PurifyZoneObjective.new(0.6).is_complete({"purity": 0.61}), "PurifyZone must honor its threshold")
	_assert(RestoreThinPlaceObjective.new(80.0).is_complete({"thin_state": &"ACTIVE", "thin_integrity": 81.0}), "RestoreThinPlace must require active integrity")
	_assert(BindTargetObjective.new().is_complete({"bound_target": true}), "BindTarget must track a successful bind")
	_assert(SurviveWavesObjective.new(30.0).is_complete({"elapsed": 31.0}), "SurviveWaves must track elapsed time")
	_assert(EscortHostObjective.new().is_complete({"host_arrived": true}), "EscortHost must track Host arrival")
	_assert(BreakIdolObjective.new().is_complete({"synthetics_defeated": 1}), "BreakIdol must track kinetic Synthetic defeat")

func _test_mission_objective_composition() -> void:
	for i: int in range(GameState.MISSION_PATHS.size()):
		var mission := load(GameState.MISSION_PATHS[i]) as MissionResource
		EventBus.mission_selected.emit(i, mission)
		_assert(MissionDirector.objectives.size() == mission.objective_ids.size(), "Mission %d must instantiate every objective" % (i + 1))
	GameState._reset_for_test()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
