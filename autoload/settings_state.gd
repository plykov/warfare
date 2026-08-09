extends Node

const SETTINGS_PATH := "user://garden_reclaimed_settings.cfg"
const DEFAULTS := {
	&"mouse_sensitivity": 1.0,
	&"master_volume": 0.8,
	&"screen_shake": 0.75,
	&"high_contrast": false,
	&"reduced_flash": false,
	&"subtitles": true,
	&"ui_scale": 1.0
}

var values: Dictionary = DEFAULTS.duplicate(true)
var persistence_enabled: bool = true

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_settings()
	EventBus.setting_update_requested.connect(set_value)
	call_deferred("_emit")

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
		&"master_volume": return clampf(float(value), 0.0, 1.0)
		&"screen_shake": return clampf(float(value), 0.0, 1.0)
		&"ui_scale": return clampf(float(value), 0.85, 1.25)
		&"high_contrast", &"reduced_flash", &"subtitles": return bool(value)
	return value

func _emit() -> void:
	EventBus.settings_changed.emit(values.duplicate(true))

func _save_settings() -> void:
	if not persistence_enabled:
		return
	var config := ConfigFile.new()
	for key: Variant in values.keys():
		config.set_value("accessibility", String(key), values[key])
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

func _reset_for_test() -> void:
	persistence_enabled = false
	values = DEFAULTS.duplicate(true)
	_emit()
