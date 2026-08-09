extends Node

signal game_started
signal game_phase_changed(phase: StringName)
signal pause_requested(paused: bool)
signal pause_changed(paused: bool)
signal setting_update_requested(key: StringName, value: Variant)
signal settings_changed(values: Dictionary)
signal player_position_changed(position: Vector3)
signal player_damage_requested(amount: float, source: StringName)
signal player_damaged(amount: float, source: StringName)
signal player_moved(speed: float)
signal player_dashed
signal player_landed
signal glory_changed(value: float, maximum: float)
signal glory_regen_requested(amount: float, source: StringName)
signal glory_spend_requested(amount: float, source: StringName)
signal entered_veiled
signal exited_veiled

signal prayer_started
signal prayer_stopped
signal declaration_issued(token_id: StringName, duration: float)
signal declaration_denied
signal commission_state_changed(active: bool, remaining: float)
signal law_enacted(zone_id: StringName, law_id: StringName)
signal law_denied
signal law_selection_requested(delta: int)
signal law_selection_changed(index: int, law_id: StringName, label: String, description: String, cost: float)
signal legislation_commit_requested(zone_id: StringName)
signal zone_laws_changed(laws: Dictionary)
signal fervency_changed(value: float, maximum: float)

signal thin_place_contested
signal thin_place_severed
signal thin_place_restored
signal thin_place_damage_requested(amount: float)
signal thin_place_changed(integrity: float, state: StringName)

signal purification_requested(position: Vector3, radius: float, amount: float)
signal corruption_requested(position: Vector3, radius: float, amount: float)
signal corruption_field_changed(values: PackedFloat32Array, width: int, height: int, purity: float, anchor_corruption: float)
signal zone_purified(zone_id: StringName)

signal damage_requested(target: Node, amount: float, damage_type: StringName, hit_position: Vector3)
signal rebuke_requested(position: Vector3, radius: float)
signal bind_requested(target: Node, duration: float)
signal mark_requested(target: Node, duration: float)
signal target_bound(kind: StringName)
signal enemy_defeated(kind: StringName, position: Vector3)
signal enemy_attack_landed(kind: StringName)
signal weapon_fired(weapon_id: StringName)
signal weapon_switched(index: int, display_name: String)
signal weapon_context_changed(role: String, counterplay: String)
signal weapon_denied(reason: String)
signal combat_feedback(kind: StringName, position: Vector3, tint: Color, strength: float)
signal hit_confirmed(defeated: bool, damage_type: StringName)
signal impulse_requested(target: Node, direction: Vector3, strength: float)
signal hostile_projectile_requested(origin: Vector3, direction: Vector3, speed: float, damage: float, kind: StringName)
signal projectile_parry_requested(position: Vector3, radius: float, direction: Vector3)
signal projectile_deflected(kind: StringName)
signal enemy_ai_state_changed(kind: StringName, state: StringName)
signal seal_requested(target: Node, duration: float)
signal target_sealed(kind: StringName)
signal slippery_field_requested(position: Vector3, radius: float, duration: float)
signal slow_requested(target: Node, duration: float, scale: float)
signal player_impulse_requested(strength: float)

signal mission_progress_changed(purity: float, target: float)
signal mission_selected(index: int, mission: Resource)
signal objective_state_changed(labels: PackedStringArray, completed: PackedByteArray)
signal mission_outcome_requested(success: bool, reason: String)
signal mission_completed
signal mission_failed(reason: String)
signal campaign_changed(selected: int, unlocked_count: int, completed: Dictionary)
signal campaign_records_changed(records: Dictionary)
signal restoration_state_changed(completed_count: int)
signal campaign_snapshot_requested(mission_index: int)
signal corruption_snapshot_ready(mission_index: int, cells: PackedFloat32Array, purity: float)
signal laws_snapshot_ready(mission_index: int, laws: Dictionary)
signal campaign_garden_state_loaded(mission_index: int, state: Dictionary)
signal campaign_pride_loaded(value: float)
signal restoration_feedback_changed(purity: float, bloom_count: int, persisted: bool)
signal encounter_state_changed(wave: int, intensity: float, label: String)
signal boss_spawn_requested(kind: StringName, title: String, power: float)
signal boss_state_changed(title: String, integrity: float, maximum: float, phase: int)
signal boss_defeated(kind: StringName)
signal rank_changed(index: int, display_name: String)
signal rank_profile_changed(index: int, display_name: String, weapon_tier: int, doctrine: String, passive: String, power_scale: float, damage_resistance: float)
signal ariel_spoke(text: String)
signal sevenfold_requested(position: Vector3)
signal sevenfold_granted(position: Vector3)
signal sevenfold_denied(reason: String)
signal pride_changed(value: float, maximum: float)
signal host_requested(position: Vector3)
signal host_arrived
signal host_withdrawn
signal threat_density_changed(value: float, position: Vector3)
signal message_posted(text: String, tone: StringName)
signal audio_requested(kind: StringName)
signal debug_console_toggled(enabled: bool)
signal debug_command_submitted(command: String)
signal debug_output(text: String, tone: StringName)
signal rank_override_requested(index: int)
signal fervency_override_requested(value: float)
signal pride_override_requested(value: float)
signal token_grant_requested
signal debug_spawn_requested(kind: StringName, count: int)
