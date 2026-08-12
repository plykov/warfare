extends CanvasLayer

const GOLD := Color(1.0, 0.73, 0.25)
const PALE := Color(0.92, 0.9, 0.82)
const INK := Color(0.025, 0.03, 0.03, 0.92)
const DANGER := Color(0.94, 0.16, 0.09)
const GREEN := Color(0.2, 0.72, 0.34)

var title_screen: Control
var gameplay: Control
var end_screen: Control
var end_title: Label
var end_copy: Label
var glory_bar: ProgressBar
var fervency_bar: ProgressBar
var purity_bar: ProgressBar
var thin_place_bar: ProgressBar
var pride_bar: ProgressBar
var state_label: Label
var weapon_label: Label
var commission_label: Label
var message_label: Label
var speed_label: Label
var veil_overlay: ColorRect
var mission_select_label: Label
var begin_button: Button
var new_game_plus_button: Button
var objective_title: Label
var objectives_label: Label
var objective_panel: PanelContainer
var weapon_context_label: Label
var encounter_label: Label
var boss_panel: PanelContainer
var boss_title: Label
var boss_bar: ProgressBar
var hit_marker: Label
var pause_overlay: Control
var restoration_label: Label
var mission_record_label: Label
var doctrine_label: Label
var debug_overlay: PanelContainer
var debug_log: Label
var debug_input: LineEdit
var law_label: Label
var _message_time: float = 0.0
var _hit_time: float = 0.0
var _subtitles_enabled: bool = true
var _rebind_pending_action: StringName = &""
var _keybind_buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_title()
	_build_gameplay()
	_build_end_screen()
	_build_pause_overlay()
	_build_debug_console()
	_connect_signals()

func _input(event: InputEvent) -> void:
	if _rebind_pending_action == &"":
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var action: StringName = _rebind_pending_action
		_rebind_pending_action = &""
		SettingsState.rebind_action(action, (event as InputEventKey).physical_keycode)
		_refresh_keybind_labels()
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	_message_time = maxf(0.0, _message_time - delta)
	if _message_time <= 0.0:
		message_label.modulate.a = move_toward(message_label.modulate.a, 0.0, delta * 2.0)
	_hit_time = maxf(0.0, _hit_time - delta)
	if hit_marker != null:
		hit_marker.modulate.a = clampf(_hit_time * 7.0, 0.0, 1.0)
	if GameState.paused:
		return
	if Input.is_action_just_pressed("pray"):
		IntercessorSystem.start_prayer()
	if Input.is_action_just_released("pray"):
		IntercessorSystem.stop_prayer()
	if Input.is_action_just_pressed("declare"):
		IntercessorSystem.declare()
	if Input.is_action_just_pressed("legislate"):
		EventBus.legislation_commit_requested.emit(&"GARDEN")
	if Input.is_action_just_pressed("law_next"):
		EventBus.law_selection_requested.emit(1)
	if Input.is_action_just_pressed("law_prev"):
		EventBus.law_selection_requested.emit(-1)
	if Input.is_action_just_pressed("reveal") and GameState.is_playing():
		_post_message("MEASURING SIGHT // BLACK IS CORRUPT, GREEN IS HELD", &"info")

func _build_title() -> void:
	title_screen = Control.new()
	title_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(title_screen)
	var art := TextureRect.new()
	art.texture = load("res://assets/ariel-key-art.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(art)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.46)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title_screen.add_child(shade)

	var panel := VBoxContainer.new()
	panel.position = Vector2(80, 72)
	panel.size = Vector2(610, 680)
	panel.add_theme_constant_override("separation", 16)
	title_screen.add_child(panel)
	var eyebrow := _label("SERAPH-CLASS UNIT // ARIEL", 18, GOLD)
	panel.add_child(eyebrow)
	var title := _label("GARDEN\nRECLAIMED", 76, PALE)
	title.add_theme_constant_override("line_spacing", -12)
	panel.add_child(title)
	var rule := ColorRect.new()
	rule.custom_minimum_size = Vector2(340, 3)
	rule.color = GOLD
	panel.add_child(rule)
	var thesis := _label("YOU CANNOT DIE.\nTHE GROUND CAN.", 28, PALE)
	panel.add_child(thesis)
	var copy := _label("An unbroken territorial FPS. Hold the Thin Place, move like Quake, and force the black tide back through commissioned fire.", 18, Color(0.82, 0.82, 0.76))
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	copy.custom_minimum_size = Vector2(520, 82)
	panel.add_child(copy)
	var selector := HBoxContainer.new()
	selector.custom_minimum_size = Vector2(520, 44)
	selector.add_theme_constant_override("separation", 10)
	panel.add_child(selector)
	var previous := Button.new()
	previous.text = "‹"
	previous.custom_minimum_size = Vector2(48, 42)
	previous.pressed.connect(func() -> void: GameState.select_relative(-1))
	selector.add_child(previous)
	mission_select_label = _label("", 15, PALE)
	mission_select_label.custom_minimum_size = Vector2(404, 42)
	mission_select_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mission_select_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selector.add_child(mission_select_label)
	var next := Button.new()
	next.text = "›"
	next.custom_minimum_size = Vector2(48, 42)
	next.pressed.connect(func() -> void: GameState.select_relative(1))
	selector.add_child(next)
	begin_button = Button.new()
	begin_button.text = "BEGIN COMMISSION"
	begin_button.custom_minimum_size = Vector2(330, 58)
	begin_button.add_theme_font_size_override("font_size", 19)
	begin_button.add_theme_color_override("font_color", Color(0.06, 0.045, 0.02))
	begin_button.add_theme_stylebox_override("normal", _box(GOLD, Color.TRANSPARENT, 0))
	begin_button.add_theme_stylebox_override("hover", _box(Color(1.0, 0.85, 0.48), Color.TRANSPARENT, 0))
	begin_button.pressed.connect(GameState.start_game)
	panel.add_child(begin_button)
	var accessibility := Button.new()
	accessibility.text = "ACCESSIBILITY & SETTINGS"
	accessibility.custom_minimum_size = Vector2(330, 44)
	accessibility.pressed.connect(func() -> void: pause_overlay.visible = true)
	panel.add_child(accessibility)
	## M15 — New Game+. Hidden until every mission (core + M16 trials) has
	## been cleared once; see GameState.ng_plus_available().
	new_game_plus_button = Button.new()
	new_game_plus_button.text = "BEGIN NEW GAME+"
	new_game_plus_button.custom_minimum_size = Vector2(330, 44)
	new_game_plus_button.visible = false
	new_game_plus_button.pressed.connect(func() -> void:
		if GameState.begin_new_game_plus():
			_post_message("NEW GAME+ %d // EVERY GROUND ASKS AGAIN, HARDER" % GameState.ng_plus_cycle, &"danger")
	)
	panel.add_child(new_game_plus_button)
	var controls := _label("WASD + MOUSE  •  SPACE ASCEND  •  SHIFT DASH\nQ PRAY  •  E DECLARE  •  R LEGISLATE  •  1–0 [ ] ARMAMENTS", 15, Color(0.72, 0.72, 0.67))
	panel.add_child(controls)

	var dossier := PanelContainer.new()
	dossier.position = Vector2(1120, 74)
	dossier.size = Vector2(400, 245)
	dossier.add_theme_stylebox_override("panel", _box(INK, GOLD, 1))
	title_screen.add_child(dossier)
	var dossier_stack := VBoxContainer.new()
	dossier_stack.add_theme_constant_override("separation", 10)
	dossier.add_child(dossier_stack)
	dossier_stack.add_child(_label("RESTORATION LEDGER", 20, GOLD))
	restoration_label = _label("GARDENS HELD 0 / 12", 17, PALE)
	dossier_stack.add_child(restoration_label)
	mission_record_label = _label("NO PRIOR COMMISSION RECORD", 14, Color(0.76, 0.78, 0.74))
	mission_record_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dossier_stack.add_child(mission_record_label)

func _build_gameplay() -> void:
	gameplay = Control.new()
	gameplay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameplay.visible = false
	add_child(gameplay)

	veil_overlay = ColorRect.new()
	veil_overlay.color = Color(0.035, 0.02, 0.045, 0.0)
	veil_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gameplay.add_child(veil_overlay)

	objective_panel = PanelContainer.new()
	objective_panel.position = Vector2(500, 26)
	objective_panel.size = Vector2(600, 175)
	objective_panel.add_theme_stylebox_override("panel", _box(INK, GOLD, 1))
	gameplay.add_child(objective_panel)
	var objective_stack := VBoxContainer.new()
	objective_stack.add_theme_constant_override("separation", 6)
	objective_panel.add_child(objective_stack)
	objective_title = _label("COMMISSION 01 // RECLAIM THE GARDEN", 18, PALE)
	objective_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_stack.add_child(objective_title)
	objectives_label = _label("RECLAIM THE GARDEN", 13, Color(0.78, 0.8, 0.75))
	objectives_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_stack.add_child(objectives_label)
	purity_bar = _bar(GREEN)
	purity_bar.show_percentage = true
	objective_stack.add_child(purity_bar)

	var left_panel := PanelContainer.new()
	left_panel.position = Vector2(28, 650)
	left_panel.size = Vector2(375, 216)
	left_panel.add_theme_stylebox_override("panel", _box(INK, Color(0.35, 0.37, 0.33), 1))
	gameplay.add_child(left_panel)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 5)
	left_panel.add_child(left)
	state_label = _label("SERAPH // RADIANT", 19, GOLD)
	left.add_child(state_label)
	doctrine_label = _label("TIER 1 // SENT ONE", 12, Color(0.72, 0.74, 0.7))
	doctrine_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(doctrine_label)
	left.add_child(_label("GLORY", 13, PALE))
	glory_bar = _bar(GOLD)
	left.add_child(glory_bar)
	left.add_child(_label("THIN PLACE", 13, PALE))
	thin_place_bar = _bar(Color(0.3, 0.68, 1.0))
	left.add_child(thin_place_bar)
	left.add_child(_label("PRIDE", 13, PALE))
	pride_bar = _bar(Color(0.72, 0.18, 0.55))
	pride_bar.value = 0.0
	left.add_child(pride_bar)
	speed_label = _label("VELOCITY 000", 13, Color(0.7, 0.72, 0.7))
	left.add_child(speed_label)

	var right_panel := PanelContainer.new()
	right_panel.position = Vector2(1190, 650)
	right_panel.size = Vector2(382, 216)
	right_panel.add_theme_stylebox_override("panel", _box(INK, Color(0.35, 0.37, 0.33), 1))
	gameplay.add_child(right_panel)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right_panel.add_child(right)
	right.add_child(_label("INTERCESSOR // OFF-MAP", 19, GOLD))
	right.add_child(_label("FERVENCY", 13, PALE))
	fervency_bar = _bar(Color(0.65, 0.45, 1.0))
	right.add_child(fervency_bar)
	commission_label = _label("NO COMMISSION HELD", 14, Color(0.62, 0.62, 0.58))
	right.add_child(commission_label)
	law_label = _label("LAW [Z/C] // GROUND HOLDS // 55F", 12, Color(0.55, 0.78, 1.0))
	law_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(law_label)
	right.add_child(_label("HOLD Q  PRAY / REGEN\nPRESS E  DECLARE / REBUKE\nPRESS R  ENACT / SELECTED LAW", 13, Color(0.74, 0.74, 0.7)))

	weapon_label = _label("01 // FLAMING SWORD", 20, PALE)
	weapon_label.position = Vector2(590, 818)
	weapon_label.size = Vector2(420, 40)
	weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gameplay.add_child(weapon_label)
	weapon_context_label = _label("PURIFYING MELEE // CLEAVE DEMONS", 12, Color(0.72, 0.74, 0.7))
	weapon_context_label.position = Vector2(500, 853)
	weapon_context_label.size = Vector2(600, 28)
	weapon_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gameplay.add_child(weapon_context_label)

	encounter_label = _label("WAVE 01 // BREACH", 14, DANGER)
	encounter_label.position = Vector2(28, 28)
	encounter_label.size = Vector2(380, 30)
	gameplay.add_child(encounter_label)

	message_label = _label("", 22, PALE)
	message_label.position = Vector2(390, 218)
	message_label.size = Vector2(820, 50)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gameplay.add_child(message_label)

	var cross_h := ColorRect.new()
	cross_h.color = Color(1.0, 0.78, 0.3, 0.82)
	cross_h.position = Vector2(792, 449)
	cross_h.size = Vector2(16, 2)
	gameplay.add_child(cross_h)
	var cross_v := ColorRect.new()
	cross_v.color = cross_h.color
	cross_v.position = Vector2(799, 442)
	cross_v.size = Vector2(2, 16)
	gameplay.add_child(cross_v)
	hit_marker = _label("x", 30, PALE)
	hit_marker.position = Vector2(778, 426)
	hit_marker.size = Vector2(44, 44)
	hit_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hit_marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hit_marker.modulate.a = 0.0
	hit_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameplay.add_child(hit_marker)

	boss_panel = PanelContainer.new()
	boss_panel.position = Vector2(500, 575)
	boss_panel.size = Vector2(600, 78)
	boss_panel.visible = false
	boss_panel.add_theme_stylebox_override("panel", _box(INK, DANGER, 2))
	gameplay.add_child(boss_panel)
	var boss_stack := VBoxContainer.new()
	boss_panel.add_child(boss_stack)
	boss_title = _label("TERRITORIAL PRINCE", 15, DANGER)
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_stack.add_child(boss_title)
	boss_bar = _bar(DANGER)
	boss_stack.add_child(boss_bar)

func _build_end_screen() -> void:
	end_screen = Control.new()
	end_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_screen.visible = false
	add_child(end_screen)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	end_screen.add_child(shade)
	end_title = _label("", 58, GOLD)
	end_title.position = Vector2(300, 275)
	end_title.size = Vector2(1000, 90)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_screen.add_child(end_title)
	end_copy = _label("", 21, PALE)
	end_copy.position = Vector2(400, 385)
	end_copy.size = Vector2(800, 120)
	end_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_screen.add_child(end_copy)

func _build_pause_overlay() -> void:
	pause_overlay = Control.new()
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.visible = false
	add_child(pause_overlay)
	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.88)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.add_child(shade)
	var panel := PanelContainer.new()
	panel.position = Vector2(500, 92)
	panel.size = Vector2(600, 716)
	panel.add_theme_stylebox_override("panel", _box(INK, GOLD, 2))
	pause_overlay.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	stack.custom_minimum_size = Vector2(580, 0)
	scroll.add_child(stack)
	var heading := _label("COMMISSION SUSPENDED", 36, GOLD)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(heading)
	var guidance := _label("Changes save immediately. Esc resumes the commission.", 14, PALE)
	guidance.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(guidance)
	_add_slider_setting(stack, "AIM SENSITIVITY", &"mouse_sensitivity", 0.35, 2.5, 0.05)
	_add_slider_setting(stack, "FIELD OF VIEW", &"fov", 70.0, 110.0, 1.0)
	_add_slider_setting(stack, "MASTER VOLUME", &"master_volume", 0.0, 1.0, 0.05)
	_add_slider_setting(stack, "SCREEN SHAKE", &"screen_shake", 0.0, 1.0, 0.05)
	_add_slider_setting(stack, "UI SCALE", &"ui_scale", 0.85, 1.25, 0.05)
	_add_toggle_setting(stack, "HIGH-CONTRAST CORRUPTION", &"high_contrast")
	_add_toggle_setting(stack, "COLORBLIND-SAFE PALETTE", &"colorblind_safe")
	_add_toggle_setting(stack, "REDUCED FLASH", &"reduced_flash")
	_add_toggle_setting(stack, "SUBTITLES / FIELD MESSAGES", &"subtitles")
	_add_difficulty_setting(stack)
	var controls := _label("WASD MOVE  |  MOUSE AIM / FIRE  |  SPACE ASCEND  |  SHIFT DASH\nQ PRAY  |  E DECLARE  |  R LEGISLATE  |  F SURVEY\n1-0, [ and ] SELECT ALL TWELVE MANIFESTATIONS", 14, Color(0.76, 0.78, 0.73))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(controls)
	_build_keybind_rows(stack)
	var resume := Button.new()
	resume.text = "RETURN"
	resume.custom_minimum_size = Vector2(0, 50)
	resume.pressed.connect(func() -> void:
		if GameState.is_playing():
			EventBus.pause_requested.emit(false)
		else:
			pause_overlay.visible = false
	)
	stack.add_child(resume)

func _add_slider_setting(parent: VBoxContainer, title: String, key: StringName, minimum: float, maximum: float, step: float) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := _label(title, 15, PALE)
	label.custom_minimum_size = Vector2(250, 36)
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(280, 36)
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(SettingsState.get_value(key))
	slider.value_changed.connect(func(value: float) -> void: EventBus.setting_update_requested.emit(key, value))
	row.add_child(slider)

func _add_toggle_setting(parent: VBoxContainer, title: String, key: StringName) -> void:
	var toggle := CheckButton.new()
	toggle.text = title
	toggle.button_pressed = bool(SettingsState.get_value(key))
	toggle.toggled.connect(func(value: bool) -> void: EventBus.setting_update_requested.emit(key, value))
	parent.add_child(toggle)

## M13 — difficulty select. NOVICE/SKILLED/EXPERT drive corruption spread
## rate and encounter pressure via SettingsState.difficulty_multiplier();
## see corruption_director.gd and encounter_director.gd.
func _add_difficulty_setting(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)
	var label := _label("DIFFICULTY", 15, PALE)
	label.custom_minimum_size = Vector2(250, 36)
	row.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size = Vector2(280, 36)
	var current: StringName = StringName(SettingsState.get_value(&"difficulty"))
	for i: int in range(SettingsState.DIFFICULTY_ORDER.size()):
		var tier: StringName = SettingsState.DIFFICULTY_ORDER[i]
		option.add_item(String(tier).to_upper(), i)
		if tier == current:
			option.selected = i
	option.item_selected.connect(func(index: int) -> void:
		EventBus.setting_update_requested.emit(&"difficulty", SettingsState.DIFFICULTY_ORDER[index])
	)
	row.add_child(option)

## M14 — key rebinding. Clicking a row's button arms _rebind_pending_action;
## the next physical key press in _input() commits the new binding.
func _build_keybind_rows(parent: VBoxContainer) -> void:
	parent.add_child(_label("CONTROLS // CLICK A KEY TO REBIND", 15, GOLD))
	for action: StringName in SettingsState.REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		parent.add_child(row)
		var label := _label(String(action).to_upper().replace("_", " "), 14, PALE)
		label.custom_minimum_size = Vector2(250, 32)
		row.add_child(label)
		var key_button := Button.new()
		key_button.custom_minimum_size = Vector2(280, 32)
		key_button.text = SettingsState.key_label_for_action(action)
		key_button.pressed.connect(func() -> void:
			_rebind_pending_action = action
			key_button.text = "PRESS A KEY…"
		)
		_keybind_buttons[action] = key_button
		row.add_child(key_button)
	var reset := Button.new()
	reset.text = "RESET CONTROLS TO DEFAULT"
	reset.pressed.connect(func() -> void:
		SettingsState.reset_key_binds()
		_refresh_keybind_labels()
	)
	parent.add_child(reset)

func _refresh_keybind_labels() -> void:
	for action: Variant in _keybind_buttons.keys():
		(_keybind_buttons[action] as Button).text = SettingsState.key_label_for_action(StringName(action))

func _build_debug_console() -> void:
	debug_overlay = PanelContainer.new()
	debug_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	debug_overlay.position = Vector2(160, 100)
	debug_overlay.size = Vector2(1280, 300)
	debug_overlay.visible = false
	debug_overlay.add_theme_stylebox_override("panel", _box(Color(0.01, 0.012, 0.012, 0.97), Color(0.3, 0.85, 1.0), 2))
	add_child(debug_overlay)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	debug_overlay.add_child(stack)
	stack.add_child(_label("AGENT FIELD CONSOLE // TYPE help", 18, Color(0.3, 0.85, 1.0)))
	debug_log = _label("Console ready.", 14, PALE)
	debug_log.custom_minimum_size = Vector2(0, 150)
	debug_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(debug_log)
	debug_input = LineEdit.new()
	debug_input.placeholder_text = "set_rank 8"
	debug_input.custom_minimum_size = Vector2(0, 46)
	debug_input.text_submitted.connect(func(command: String) -> void:
		EventBus.debug_command_submitted.emit(command)
		debug_input.clear()
	)
	stack.add_child(debug_input)

func _connect_signals() -> void:
	EventBus.game_started.connect(_on_game_started)
	EventBus.game_phase_changed.connect(_on_phase_changed)
	EventBus.glory_changed.connect(func(value: float, maximum: float) -> void: _set_bar(glory_bar, value, maximum))
	EventBus.fervency_changed.connect(func(value: float, maximum: float) -> void: _set_bar(fervency_bar, value, maximum))
	EventBus.pride_changed.connect(func(value: float, maximum: float) -> void: _set_bar(pride_bar, value, maximum))
	EventBus.thin_place_changed.connect(_on_thin_place_changed)
	EventBus.mission_progress_changed.connect(_on_progress_changed)
	EventBus.weapon_switched.connect(func(index: int, name: String) -> void: weapon_label.text = "%02d // %s" % [index + 1, name])
	EventBus.weapon_context_changed.connect(func(role: String, counterplay: String) -> void: weapon_context_label.text = "%s // %s" % [role.to_upper(), counterplay.to_upper()])
	EventBus.hit_confirmed.connect(_on_hit_confirmed)
	EventBus.encounter_state_changed.connect(_on_encounter_state_changed)
	EventBus.boss_state_changed.connect(_on_boss_state_changed)
	EventBus.pause_changed.connect(func(paused: bool) -> void: pause_overlay.visible = paused)
	EventBus.settings_changed.connect(_on_settings_changed)
	EventBus.commission_state_changed.connect(_on_commission_changed)
	EventBus.law_selection_changed.connect(_on_law_selection_changed)
	EventBus.intercessor_spoke.connect(_on_intercessor_spoke)
	EventBus.entered_veiled.connect(_on_veiled)
	EventBus.exited_veiled.connect(_on_radiant)
	EventBus.rank_changed.connect(func(_index: int, name: String) -> void: state_label.text = "%s // RADIANT" % name)
	EventBus.rank_profile_changed.connect(_on_rank_profile_changed)
	EventBus.ariel_spoke.connect(_on_ariel_spoke)
	EventBus.debug_console_toggled.connect(_on_debug_console_toggled)
	EventBus.debug_output.connect(_on_debug_output)
	EventBus.player_moved.connect(func(speed: float) -> void: speed_label.text = "VELOCITY %03d // STRAFE-JUMP UNCAPPED" % roundi(speed * 10.0))
	EventBus.message_posted.connect(_post_message)
	EventBus.mission_selected.connect(_on_mission_selected)
	EventBus.objective_state_changed.connect(_on_objective_state_changed)
	EventBus.campaign_changed.connect(_on_campaign_changed)
	EventBus.campaign_records_changed.connect(_on_records_changed)
	_on_campaign_changed(GameState.selected_mission, GameState.unlocked_count, GameState.completed)
	_on_settings_changed(SettingsState.values)

func _on_game_started() -> void:
	title_screen.visible = false
	gameplay.visible = true
	end_screen.visible = false

func _on_phase_changed(phase: StringName) -> void:
	if phase == &"COMPLETE":
		_show_end(true)
	elif phase == &"FAILED":
		_show_end(false)

func _show_end(success: bool) -> void:
	end_screen.visible = true
	end_title.text = "THE GARDEN HOLDS" if success else "THE GARDEN IS RECLAIMED"
	end_title.add_theme_color_override("font_color", GOLD if success else DANGER)
	end_copy.text = ("ARIEL remains. The ground remembers.\nThe next commission is now available.\n\nPRESS ENTER TO RETURN TO CAMPAIGN" if success else "ARIEL remains alive, but the objective is lost.\nThere is no respawn — only ground to reclaim.\n\nPRESS ENTER TO RETURN TO CAMPAIGN")

	end_copy.text += "\nTIME %02d:%02d  //  PURITY %d%%" % [floori(GameState.elapsed / 60.0), floori(fmod(GameState.elapsed, 60.0)), roundi(MissionDirector.current_purity * 100.0)]

func _on_campaign_changed(selected: int, unlocked: int, completed: Dictionary) -> void:
	if mission_select_label == null:
		return
	var mission := load(GameState.MISSION_PATHS[selected]) as MissionResource
	if mission == null:
		return
	var cleared: String = "  ✓ HELD" if completed.has(str(selected)) else ""
	mission_select_label.text = "%02d / %02d  %s%s" % [selected + 1, unlocked, mission.title.to_upper(), cleared]
	begin_button.text = "BEGIN COMMISSION %02d" % (selected + 1)
	var ng_plus_tag: String = "  //  NEW GAME+%d" % GameState.ng_plus_cycle if GameState.ng_plus_cycle > 0 else ""
	restoration_label.text = "GARDENS HELD %d / %d  //  %d%% RESTORED%s" % [completed.size(), GameState.MISSION_PATHS.size(), roundi(float(completed.size()) / GameState.MISSION_PATHS.size() * 100.0), ng_plus_tag]
	new_game_plus_button.visible = GameState.ng_plus_available()
	_on_records_changed(GameState.mission_records)

func _on_records_changed(records: Dictionary) -> void:
	if mission_record_label == null:
		return
	var record: Dictionary = records.get(str(GameState.selected_mission), {})
	if record.is_empty():
		mission_record_label.text = "NO PRIOR COMMISSION RECORD\nFIRST ATTEMPT AWAITS"
		return
	var best: float = float(record.get("best_time", 0.0))
	var best_text: String = "--:--" if best <= 0.0 else "%02d:%02d" % [floori(best / 60.0), floori(fmod(best, 60.0))]
	mission_record_label.text = "ATTEMPTS %d  //  CLEARS %d\nBEST TIME %s  //  BEST PURITY %d%%" % [int(record.get("attempts", 0)), int(record.get("clears", 0)), best_text, roundi(float(record.get("best_purity", 0.0)) * 100.0)]
	var garden: Dictionary = GameState.garden_states.get(str(GameState.selected_mission), {})
	if not garden.is_empty():
		mission_record_label.text += "\nGARDEN MEMORY %d%% // LAWS %d" % [roundi(float(garden.get("purity", 0.0)) * 100.0), (garden.get("laws", {}) as Dictionary).size()]

func _on_encounter_state_changed(wave: int, intensity: float, label: String) -> void:
	encounter_label.text = "WAVE %02d // %s // %d%%" % [wave, label, roundi(intensity * 100.0)]

func _on_boss_state_changed(title: String, integrity: float, maximum: float, phase: int) -> void:
	boss_panel.visible = integrity > 0.0
	boss_title.text = "%s // THRONE PHASE %d" % [title, phase]
	_set_bar(boss_bar, integrity, maximum)

func _on_hit_confirmed(defeated: bool, _damage_type: StringName) -> void:
	_hit_time = 0.22 if defeated else 0.12
	hit_marker.text = "+" if defeated else "x"
	hit_marker.add_theme_color_override("font_color", GOLD if defeated else PALE)

func _on_rank_profile_changed(_index: int, _name: String, tier: int, doctrine: String, passive: String, _power: float, resistance: float) -> void:
	doctrine_label.text = "TIER %d // %s\n%s // WARD %d%%" % [tier, doctrine, passive.to_upper(), roundi(resistance * 100.0)]

func _on_debug_console_toggled(enabled: bool) -> void:
	debug_overlay.visible = enabled
	if enabled:
		debug_input.grab_focus()

func _on_debug_output(text: String, tone: StringName) -> void:
	debug_log.text = text
	debug_log.add_theme_color_override("font_color", DANGER if tone == &"danger" else (GOLD if tone == &"holy" else PALE))

func _on_settings_changed(values: Dictionary) -> void:
	_subtitles_enabled = bool(values.get(&"subtitles", true))
	var ui_scale: float = float(values.get(&"ui_scale", 1.0))
	for screen: Control in [title_screen, gameplay, end_screen]:
		screen.scale = Vector2.ONE * ui_scale

func _on_mission_selected(_index: int, mission: Resource) -> void:
	var mission_data := mission as MissionResource
	if mission_data == null:
		return
	objective_title.text = mission_data.display_title()

func _on_objective_state_changed(labels: PackedStringArray, completed: PackedByteArray) -> void:
	if objectives_label == null:
		return
	var lines := PackedStringArray()
	for i: int in range(labels.size()):
		var mark: String = "✓" if i < completed.size() and completed[i] == 1 else "◇"
		lines.append("%s %s" % [mark, labels[i]])
	objectives_label.text = "\n".join(lines)
	if objective_panel != null and message_label != null:
		objective_panel.size.y = maxf(175.0, 105.0 + labels.size() * 22.0)
		message_label.position.y = objective_panel.position.y + objective_panel.size.y + 16.0

func _on_thin_place_changed(value: float, state: StringName) -> void:
	_set_bar(thin_place_bar, value, 100.0)
	if state != &"ACTIVE":
		thin_place_bar.modulate = DANGER
	else:
		thin_place_bar.modulate = Color.WHITE

func _on_progress_changed(purity: float, target: float) -> void:
	purity_bar.max_value = 1.0
	purity_bar.value = purity
	purity_bar.tooltip_text = "%d%% reclaimed / %d%% required" % [roundi(purity * 100.0), roundi(target * 100.0)]

func _on_commission_changed(active: bool, remaining: float) -> void:
	commission_label.text = "COMMISSION // REBUKE %.1fs" % remaining if active else "NO COMMISSION HELD"
	commission_label.add_theme_color_override("font_color", GOLD if active else Color(0.62, 0.62, 0.58))

func _on_law_selection_changed(_index: int, _law_id: StringName, label: String, description: String, cost: float) -> void:
	law_label.text = "LAW [Z/C] // %s // %dF\n%s" % [label, roundi(cost), description.to_upper()]

func _on_intercessor_spoke(text: String) -> void:
	_post_message("INTERCESSOR // %s" % text.to_upper(), &"holy")
	_message_time = 5.2

func _on_ariel_spoke(text: String) -> void:
	_post_message("ARIEL // %s" % text.to_upper(), &"holy")
	_message_time = 4.8

func _on_veiled() -> void:
	veil_overlay.color = Color(0.03, 0.01, 0.045, 0.66)
	state_label.text = "%s // VEILED" % RankSystem.RANKS[RankSystem.rank_index]
	state_label.add_theme_color_override("font_color", DANGER)

func _on_radiant() -> void:
	veil_overlay.color = Color(0.03, 0.01, 0.045, 0.0)
	state_label.text = "%s // RADIANT" % RankSystem.RANKS[RankSystem.rank_index]
	state_label.add_theme_color_override("font_color", GOLD)

func _post_message(text: String, tone: StringName) -> void:
	if not _subtitles_enabled and tone == &"info":
		return
	message_label.text = text
	message_label.modulate = Color.WHITE
	message_label.add_theme_color_override("font_color", DANGER if tone == &"danger" else (GOLD if tone == &"holy" else PALE))
	_message_time = 3.8

func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _bar(color: Color) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = 100.0
	bar.value = 100.0
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", _box(Color(0.03, 0.035, 0.032), Color(0.24, 0.25, 0.23), 1))
	bar.add_theme_stylebox_override("fill", _box(color, Color.TRANSPARENT, 0))
	return bar

func _set_bar(bar: ProgressBar, value: float, maximum: float) -> void:
	bar.max_value = maximum
	bar.value = value

func _box(color: Color, border_color: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border_color
	box.set_border_width_all(border_width)
	box.content_margin_left = 14.0
	box.content_margin_right = 14.0
	box.content_margin_top = 10.0
	box.content_margin_bottom = 10.0
	return box
