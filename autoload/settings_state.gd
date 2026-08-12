extends Node

const SETTINGS_PATH := "user://garden_reclaimed_settings.cfg"
const DEFAULTS := {
	&"mouse_sensitivity": 1.0,
	&"fov": 92.0,
	&"master_volume": 0.8,
	&"screen_shake": 0.75,
	&"high_contrast": false,
	&"reduced_flash": false,
	&"subtitles": true,
	&"ui_scale": 1.0,
	&"difficulty": &"skilled"
}

## M13 — difficulty select. Mirrors the player-efficiency profiles the
## balance sim already proves are fair (tests/balance_sim.gd); this just
## exposes the same three tiers to the player as a real setting instead of
## leaving them as an internal test fixture.
const DIFFICULTY_MULTIPLIERS := {
	&"novice": 0.75,
	&"skilled": 1.0,
	&"expert": 1.3
}
const DIFFICULTY_ORDER: Array[StringName] = [&"novice", &"skilled", &"expert"]

## M14 — key rebinding. Only single-key keyboard actions are rebindable;
## mouse-bound actions (fire, alt_fire, weapon_next/prev) and the numbered
## weapon row are left on their fixed defaults.
const REBINDABLE_ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right",
	&"jump", &"dash", &"pray", &"declare", &"legislate", &"reveal",
	&"ultimate", &"law_prev", &"law_next"
]

var values: Dictionary = DEFAULTS.duplicate(true)
var key_binds: Dictionary = {}
var persistence_enabled: bool = true
var _default_key_binds: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_default_key_binds()
	_load_settings()
	_apply_key_binds()
	EventBus.setting_update_requested.connect(set_value)
	call_deferred("_emit")

func difficulty_multiplier() -> float:
	return float(DIFFICULTY_MULTIPLIERS.get(values.get(&"difficulty"), 1.0))

func rebind_action(action: StringName, physical_keycode: int) -> bool:
	if action not in REBINDABLE_ACTIONS or not InputMap.has_action(action):
		return false
	for existing_event: InputEvent in InputMap.action_get_events(action):
		if existing_event is InputEventKey:
			InputMap.action_erase_event(action, existing_event)
	var event := InputEventKey.new()
	event.physical_keycode = physical_keycode
	InputMap.action_add_event(action, event)
	key_binds[action] = physical_keycode
	_save_settings()
	EventBus.keybind_changed.emit(action, physical_keycode)
	return true

func key_label_for_action(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string((event as InputEventKey).physical_keycode)
	return "—"

func reset_key_binds() -> void:
	key_binds.clear()
	for action: StringName in _default_key_binds.keys():
		for existing_event: InputEvent in InputMap.action_get_events(action):
			if existing_event is InputEventKey:
				InputMap.action_erase_event(action, existing_event)
		var event := InputEventKey.new()
		event.physical_keycode = int(_default_key_binds[action])
		InputMap.action_add_event(action, event)
		EventBus.keybind_changed.emit(action, int(_default_key_binds[action]))
	_save_settings()

func _capture_default_key_binds() -> void:
	for action: StringName in REBINDABLE_ACTIONS:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				_default_key_binds[action] = (event as InputEventKey).physical_keycode
				break

func set_value(key: StringName, value: Variant) -> bool:
	if not DEFAULTS.has(key):
		return false
	var normalized: Variant = _normalize(key, value)
	if values.get(key) == normalized:
		return true
	values[key] = normalized
	_save_settings()
	_emit()
	return true

func get_value(key: StringName) -> Variant:
	return values.get(key, DEFAULTS.get(key))

func reset_defaults() -> void:
	values = DEFAULTS.duplicate(true)
	_save_settings()
	_emit()

func _normalize(key: StringName, value: Variant) -> Variant:
	match key:
		&"mouse_sensitivity": return clampf(float(value), 0.35, 2.5)
		&"fov": return clampf(float(value), 70.0, 110.0)
		&"master_volume": return clampf(float(value), 0.0, 1.0)
		&"screen_shake": return clampf(float(value), 0.0, 1.0)
		&"ui_scale": return clampf(float(value), 0.85, 1.25)
		&"high_contrast", &"reduced_flash", &"subtitles": return bool(value)
		&"difficulty": return value if StringName(value) in DIFFICULTY_ORDER else &"skilled"
	return value

func _emit() -> void:
	EventBus.settings_changed.emit(values.duplicate(true))

func _save_settings() -> void:
	if not persistence_enabled:
		return
	var config := ConfigFile.new()
	for key: Variant in values.keys():
		config.set_value("accessibility", String(key), values[key])
	for action: Variant in key_binds.keys():
		config.set_value("keybinds", String(action), key_binds[action])
	config.save(SETTINGS_PATH)

func _load_settings() -> void:
	if not persistence_enabled:
		return
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	for key: Variant in DEFAULTS.keys():
		if config.has_section_key("accessibility", String(key)):
			values[key] = _normalize(key, config.get_value("accessibility", String(key), DEFAULTS[key]))
	if config.has_section("keybinds"):
		for action_key: String in config.get_section_keys("keybinds"):
			if StringName(action_key) in REBINDABLE_ACTIONS:
				key_binds[StringName(action_key)] = int(config.get_value("keybinds", action_key))

func _apply_key_binds() -> void:
	for action: Variant in key_binds.keys():
		var physical_keycode: int = int(key_binds[action])
		for existing_event: InputEvent in InputMap.action_get_events(StringName(action)):
			if existing_event is InputEventKey:
				InputMap.action_erase_event(StringName(action), existing_event)
		var event := InputEventKey.new()
		event.physical_keycode = physical_keycode
		InputMap.action_add_event(StringName(action), event)

func _reset_for_test() -> void:
	persistence_enabled = false
	values = DEFAULTS.duplicate(true)
	key_binds.clear()
	_emit()
