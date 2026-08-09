extends Node

var enabled: bool = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_console"):
		enabled = not enabled
		EventBus.message_posted.emit("DEBUG // %s // G adds Glory, K corrupts anchor" % ("ON" if enabled else "OFF"), &"info")
	if not enabled or not event is InputEventKey or not event.is_pressed():
		return
	var key := event as InputEventKey
	if key.physical_keycode == KEY_G:
		EventBus.glory_regen_requested.emit(25.0, &"DEBUG")
	elif key.physical_keycode == KEY_K:
		EventBus.corruption_requested.emit(Vector3.ZERO, 4.0, 0.3)

func _reset_for_test() -> void:
	enabled = false
