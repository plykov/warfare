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
	_test_settings_validation()
	_test_campaign_records()
	_test_legacy_save_migration()
	_test_weapon_identity_catalog()
	_test_boss_catalog()
	_test_pause_lifecycle()
	_test_garden_snapshot_round_trip()
	_test_v2_save_migration()
	_test_rank_doctrine_profiles()
	_test_debug_console_commands()
	_test_sevenfold_authority_gate()
	_test_three_law_legislation()
	_test_projectile_parry()
	_test_faction_combat_profiles()
	_test_support_authority_interactions()
	_test_chapter_arena_recipes()
	await get_tree().process_frame
	if failures.is_empty():
		print("GARDEN RECLAIMED TESTS: 25 passed")
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

func _test_settings_validation() -> void:
	SettingsState._reset_for_test()
	_assert(SettingsState.set_value(&"mouse_sensitivity", 99.0), "Known settings must accept updates")
	_assert(is_equal_approx(float(SettingsState.get_value(&"mouse_sensitivity")), 2.5), "Aim sensitivity must clamp to its accessible range")
	_assert(not SettingsState.set_value(&"unknown_setting", true), "Unknown settings must not enter the persisted schema")

func _test_campaign_records() -> void:
	GameState._reset_for_test()
	MissionDirector.current_purity = 0.71
	GameState.phase = GameState.Phase.PLAYING
	GameState.elapsed = 42.5
	EventBus.mission_outcome_requested.emit(true, "TEST RECORD")
	var record: Dictionary = GameState.mission_records.get("0", {})
	_assert(int(record.get("attempts", 0)) == 1, "Every mission outcome must increment attempts")
	_assert(int(record.get("clears", 0)) == 1, "Successful outcomes must increment clears")
	_assert(is_equal_approx(float(record.get("best_time", 0.0)), 42.5), "Successful outcomes must retain the best time")
	_assert(is_equal_approx(float(record.get("best_purity", 0.0)), 0.71), "Successful outcomes must retain peak completion purity")
	GameState._reset_for_test()

func _test_legacy_save_migration() -> void:
	GameState._reset_for_test()
	GameState._apply_progress_data({"selected_mission": 1, "unlocked_count": 3, "completed": ["0", "1"]})
	_assert(GameState.completed.size() == 2, "Version 1 completion keys must survive migration")
	_assert(GameState.mission_records.has("0"), "Version 1 clears must seed replay records")
	_assert(int((GameState.mission_records["1"] as Dictionary).get("clears", 0)) == 1, "Migrated clears must remain cleared")
	GameState._reset_for_test()

func _test_weapon_identity_catalog() -> void:
	var seen: Dictionary = {}
	for path: String in WeaponManager.WEAPON_PATHS:
		var weapon := load(path) as WeaponResource
		_assert(weapon != null, "Every manifestation resource must load")
		if weapon == null:
			continue
		seen[weapon.weapon_id] = true
		_assert(not weapon.role.is_empty(), "Every manifestation must declare a tactical role")
		_assert(not weapon.counterplay.is_empty(), "Every manifestation must explain its counterplay")
		_assert(not weapon.secondary_name.is_empty(), "Every manifestation must name its alternate expression")
	_assert(seen.size() == 12, "All twelve carried manifestations must remain distinct")

func _test_boss_catalog() -> void:
	var bosses: int = 0
	for path: String in GameState.MISSION_PATHS:
		var mission := load(path) as MissionResource
		if mission.boss_kind != &"":
			bosses += 1
			_assert(not mission.boss_name.is_empty(), "Boss commissions must name their territorial prince")
			_assert(mission.boss_trigger_seconds > 0.0 or mission.boss_trigger_purity > 0.0, "Boss commissions must define a deterministic trigger")
	_assert(bosses == 3, "The v0.2 campaign must contain three escalating boss commissions")

func _test_pause_lifecycle() -> void:
	GameState._reset_for_test()
	GameState.phase = GameState.Phase.PLAYING
	GameState.elapsed = 12.0
	GameState.set_paused(true)
	_assert(GameState.paused and get_tree().paused, "Pause must suspend the full scene tree")
	GameState._process(3.0)
	_assert(is_equal_approx(GameState.elapsed, 12.0), "Paused commissions must not consume mission time")
	GameState.set_paused(false)
	_assert(not GameState.paused and not get_tree().paused, "Resume must restore the active commission")
	GameState._reset_for_test()

func _test_garden_snapshot_round_trip() -> void:
	GameState._reset_for_test()
	IntercessorSystem._reset_for_test()
	CorruptionDirector._reset_for_test()
	GameState.phase = GameState.Phase.PLAYING
	CorruptionDirector.corrupt(Vector3(4.0, 0.0, 4.0), 3.0, 0.44)
	var before: float = CorruptionDirector.sample(Vector3(4.0, 0.0, 4.0))
	_assert(IntercessorSystem.legislate(&"GARDEN", &"GROUND_HOLDS"), "A funded campaign law must enact before snapshotting")
	GameState._capture_garden_state()
	var state: Dictionary = GameState.garden_states.get("0", {})
	_assert((state.get("cells", []) as Array).size() == CorruptionDirector.GRID_WIDTH * CorruptionDirector.GRID_HEIGHT, "Garden snapshots must retain every corruption cell")
	_assert((state.get("laws", {}) as Dictionary).has(&"GARDEN"), "Garden snapshots must retain enacted territorial laws")
	CorruptionDirector.purify(Vector3(4.0, 0.0, 4.0), 3.0, 1.0)
	EventBus.campaign_garden_state_loaded.emit(0, state)
	_assert(is_equal_approx(CorruptionDirector.sample(Vector3(4.0, 0.0, 4.0)), before), "Loading a garden snapshot must restore exact local corruption")
	var encoded: String = JSON.stringify({"save_version": 3, "selected_mission": 0, "unlocked_count": 1, "completed": [], "garden_states": GameState.garden_states})
	var decoded: Variant = JSON.parse_string(encoded)
	GameState.garden_states.clear()
	GameState._apply_progress_data(decoded as Dictionary)
	_assert(((GameState.garden_states["0"] as Dictionary).get("cells", []) as Array).size() == CorruptionDirector.GRID_WIDTH * CorruptionDirector.GRID_HEIGHT, "Garden snapshots must survive the JSON save boundary")
	GameState._reset_for_test()
	IntercessorSystem._reset_for_test()

func _test_v2_save_migration() -> void:
	GameState._reset_for_test()
	GameState._apply_progress_data({"save_version": 2, "selected_mission": 2, "unlocked_count": 4, "completed": ["0", "1"], "mission_records": {"0": {"attempts": 2, "clears": 1}}})
	_assert(GameState.unlocked_count == 4, "Version 2 campaign unlocks must survive schema v3 migration")
	_assert(GameState.garden_states.is_empty(), "Version 2 saves must migrate with an empty persistent garden ledger")
	_assert(is_zero_approx(GameState.campaign_pride), "Version 2 saves must receive the safe default Pride value")
	GameState._reset_for_test()

func _test_rank_doctrine_profiles() -> void:
	EventBus.rank_override_requested.emit(0)
	_assert(RankSystem.weapon_tier() == 1, "Messenger must begin at weapon tier 1")
	EventBus.rank_override_requested.emit(3)
	_assert(RankSystem.weapon_tier() == 2 and RankSystem.has_ophanim_dash(), "Cherub must manifest tier 2 weapons and Ophanim motion")
	EventBus.rank_override_requested.emit(7)
	_assert(RankSystem.weapon_tier() == 3, "One of the Seven must manifest weapon tier 3")
	_assert(RankSystem.damage_resistance() > 0.2, "Capstone doctrine must provide a meaningful ward")
	RankSystem._reset_for_test()

func _test_debug_console_commands() -> void:
	GameState.phase = GameState.Phase.PLAYING
	IntercessorSystem._reset_for_test()
	var response: String = DebugConsole.execute("fervency 41")
	_assert("41.0" in response and is_equal_approx(IntercessorSystem.fervency, 41.0), "Console Fervency overrides must be parsed and applied")
	DebugConsole.execute("set_rank 6")
	_assert(RankSystem.rank_index == 5, "Console rank commands must use the documented 1-based ladder")
	_assert("UNKNOWN COMMAND" in DebugConsole.execute("nonsense"), "Console must report unknown commands without side effects")
	GameState._reset_for_test()
	RankSystem._reset_for_test()

func _test_sevenfold_authority_gate() -> void:
	GameState.phase = GameState.Phase.PLAYING
	IntercessorSystem._reset_for_test()
	EventBus.rank_override_requested.emit(7)
	var granted := [false]
	EventBus.sevenfold_granted.connect(func(_position: Vector3) -> void: granted[0] = true, CONNECT_ONE_SHOT)
	EventBus.sevenfold_requested.emit(Vector3.ZERO)
	_assert(not granted[0], "Sevenfold Judgment must remain locked without a Commission Token")
	EventBus.token_grant_requested.emit()
	EventBus.sevenfold_requested.emit(Vector3.ZERO)
	_assert(granted[0], "One of the Seven must be able to spend a Commission Token on Sevenfold Judgment")
	_assert(not IntercessorSystem.has_commission(), "Sevenfold Judgment must consume its Commission Token")
	GameState._reset_for_test()
	RankSystem._reset_for_test()
	IntercessorSystem._reset_for_test()

func _test_three_law_legislation() -> void:
	GameState.phase = GameState.Phase.PLAYING
	IntercessorSystem._reset_for_test()
	_assert(IntercessorSystem.LAW_IDS.size() == 3, "The territorial law selector must expose all three authored laws")
	EventBus.law_selection_requested.emit(1)
	_assert(IntercessorSystem.selected_law == 1, "Law selection must cycle without immediately spending Fervency")
	EventBus.legislation_commit_requested.emit(&"GARDEN")
	_assert(IntercessorSystem.has_law(&"GARDEN", &"NO_UNCLEAN_ENTRY"), "Committing the selected law must enact No Unclean Entry")
	_assert(is_equal_approx(IntercessorSystem.fervency, 55.0), "Each territorial law must spend its authored Fervency cost")
	var revealed_fallen := FallenEnemy.new()
	get_tree().root.add_child(revealed_fallen)
	EventBus.zone_laws_changed.emit({&"GARDEN": [&"NO_HIDDEN_THING"]})
	_assert(is_inf(revealed_fallen.marked_remaining), "No Hidden Thing must permanently reveal Fallen within the legislated garden")
	revealed_fallen.queue_free()
	GameState._reset_for_test()
	IntercessorSystem._reset_for_test()

func _test_projectile_parry() -> void:
	var projectile := HostileProjectile.new()
	projectile.configure(Vector3.ZERO, Vector3.FORWARD, 10.0, 9.0, &"FALLEN")
	get_tree().root.add_child(projectile)
	EventBus.projectile_parry_requested.emit(Vector3.ZERO, 2.0, Vector3.RIGHT)
	_assert(projectile.holy, "Flaming Sword parry must convert a hostile projectile into holy ordnance")
	_assert(projectile.direction.is_equal_approx(Vector3.RIGHT), "A parried projectile must follow the player's return direction")
	_assert(is_equal_approx(projectile.speed, 14.0), "Deflection must accelerate the returned projectile")
	projectile.queue_free()

func _test_faction_combat_profiles() -> void:
	var fallen := FallenEnemy.new()
	var synthetic := SyntheticEnemy.new()
	var demon := EnemyBase.new()
	_assert(fallen.uses_projectiles, "Fallen enemies must provide the campaign's ranged projectile pressure")
	_assert(not synthetic.spreads_corruption, "Synthetic enemies must remain fabricated rather than corrupting ground")
	_assert(demon.spreads_corruption and not demon.uses_projectiles, "Demons must retain objective pressure as their distinct combat profile")
	fallen.free()
	synthetic.free()
	demon.free()

func _test_support_authority_interactions() -> void:
	GameState.phase = GameState.Phase.PLAYING
	IntercessorSystem._reset_for_test()
	var converted: float = IntercessorSystem.convert_fervency(28.0)
	_assert(is_equal_approx(converted, 28.0) and is_equal_approx(IntercessorSystem.fervency, 72.0), "Censer conversion must consume and report stored prayer exactly")
	var host := HostMember.new()
	get_tree().root.add_child(host)
	EventBus.seal_requested.emit(host, 10.0)
	_assert(float(host.get("_sealed_remaining")) >= 10.0, "Inkhorn ally marking must seal a Host member against withdrawal")
	host.queue_free()
	GameState._reset_for_test()
	IntercessorSystem._reset_for_test()

func _test_chapter_arena_recipes() -> void:
	var fingerprints: Dictionary = {}
	for chapter: int in range(8):
		var recipe: Array[Dictionary] = ChapterArena.recipe_for(chapter)
		_assert(recipe.size() >= 4, "Every campaign chapter must author meaningful traversable geometry")
		fingerprints[JSON.stringify(recipe)] = true
		for definition: Dictionary in recipe:
			var at: Vector3 = definition.position
			_assert(Vector2(at.x, at.z).length() > 4.0, "Chapter geometry must keep the central Thin Place clear")
	_assert(fingerprints.size() == 8, "All eight chapters must form a distinct arena silhouette")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
