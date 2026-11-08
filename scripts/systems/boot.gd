extends Control
## Opening screen: full-screen animated key art (fade in, slow push-in, FX ramp-up).
## No text on screen; the art carries the title. Any key / click / tap after the fade-in
## continues to the game scene.

const FADE_IN_S: float = 1.6
const PUSH_IN_S: float = 7.0
const FX_DELAY_S: float = 0.8
const FX_RAMP_S: float = 1.8
const START_ZOOM: float = 1.12
const END_ZOOM: float = 1.0
const FADE_OUT_S: float = 0.6
const NEXT_SCENE: String = "res://scenes/main/game.tscn"
const LOAD_WATCHDOG_S: float = 10.0
const CLASSES: Array[StringName] = [&"vanguard", &"phantom", &"arcanist", &"ranger"]

@onready var _art: ColorRect = %OpeningArt
@onready var _sparks: CPUParticles2D = %Sparks

var _material: ShaderMaterial
var _can_continue: bool = false
var _leaving: bool = false


func _ready() -> void:
	AudioManager.set_area_music(&"menu")
	_material = _art.material as ShaderMaterial
	resized.connect(_on_resized)
	_on_resized()
	_play_intro()


func _on_resized() -> void:
	_material.set_shader_parameter(&"rect_size", size)
	_sparks.position = Vector2(size.x * 0.5, size.y)
	_sparks.emission_rect_extents = Vector2(size.x * 0.5, 4.0)


func _play_intro() -> void:
	_material.set_shader_parameter(&"reveal", 0.0)
	_material.set_shader_parameter(&"zoom", START_ZOOM)
	_material.set_shader_parameter(&"fx_strength", 0.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_method(_set_param.bind(&"reveal"), 0.0, 1.0, FADE_IN_S) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_param.bind(&"zoom"), START_ZOOM, END_ZOOM, PUSH_IN_S) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_param.bind(&"fx_strength"), 0.0, 1.0, FX_RAMP_S).set_delay(FX_DELAY_S)
	get_tree().create_timer(FADE_IN_S).timeout.connect(func() -> void:
		_can_continue = true
		if "--skip-opening" in OS.get_cmdline_user_args():
			_leave())


## _input (not _unhandled_input): GUI must never swallow the "tap anywhere" on touch screens.
func _input(event: InputEvent) -> void:
	if not _can_continue or _leaving or not _is_continue_event(event):
		return
	get_viewport().set_input_as_handled()
	_leave()


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	var latest: String = SaveManager.latest_slot()
	if latest.is_empty() or "--new" in OS.get_cmdline_user_args():
		_show_class_menu()
	elif "--skip-opening" in OS.get_cmdline_user_args() and not "--new" in OS.get_cmdline_user_args():
		_fade_then(_continue.bind(latest))
	else:
		_show_menu(latest)


## Continue / New Game. Always offers a way out even if a save is broken.
func _show_menu(latest: String) -> void:
	var menu: VBoxContainer = VBoxContainer.new()
	menu.theme = CodexTheme.make_theme()
	menu.add_theme_constant_override(&"separation", 12)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	menu.offset_left = -260
	menu.offset_right = 260
	menu.offset_top = -284
	menu.offset_bottom = -24
	add_child(menu)
	var info: Dictionary = SaveManager.slot_info(latest)
	var cls: String = info.get("class_id", "")
	var level: int = info.get("level", 1)
	var continue_button: Button = _menu_button(menu, "%s   (%s)" % [tr(&"MENU_CONTINUE"), tr(&"MENU_CONTINUE_INFO") % [cls.capitalize(), level]])
	continue_button.pressed.connect(func() -> void: _fade_then(_continue.bind(latest)))
	_menu_button(menu, tr(&"MENU_NEW_GAME")).pressed.connect(func() -> void:
		menu.queue_free()
		_show_class_menu())
	_menu_button(menu, tr(&"MENU_SETTINGS")).pressed.connect(_open_settings)
	continue_button.grab_focus()


func _open_settings() -> void:
	var panel: SettingsPanel = get_tree().get_first_node_in_group(SettingsPanel.GROUP) as SettingsPanel
	if panel == null:
		panel = SettingsPanel.new()
		add_child(panel)
	panel.open()


## New game: pick one of the four starting classes (§8).
func _show_class_menu() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			_choose_class(StringName(arg.trim_prefix("--class=")))
			return
	# One screen: class + character with a live 3D preview.
	var select: CharacterSelect = CharacterSelect.new()
	add_child(select)
	select.confirmed.connect(func(cls: StringName, hero: StringName) -> void:
		GameState.class_id = cls
		GameState.hero_id = hero
		select.queue_free()
		_fade_then(_play_prologue))


## The story opens before the first step in Ashfall (skippable).
func _play_prologue() -> void:
	var prologue: Prologue = Prologue.new()
	add_child(prologue)
	prologue.finished.connect(func() -> void:
		OpeningClip.pending = true
		_start_new())


func _choose_class(class_id: StringName) -> void:
	GameState.class_id = class_id
	for child: Node in get_children():
		if child is VBoxContainer:
			child.queue_free()
	_show_hero_menu()


## New game, step 2: pick the character (appearance). Long hair + dragon or short hair.
func _show_hero_menu() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hero=") or arg.begins_with("--class="):
			_choose_hero(GameState.hero_id)
			return
	var menu: VBoxContainer = VBoxContainer.new()
	menu.theme = CodexTheme.make_theme()
	menu.add_theme_constant_override(&"separation", 10)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	menu.offset_left = -480
	menu.offset_right = 480
	menu.offset_top = -330
	menu.offset_bottom = -24
	add_child(menu)
	var title: Label = Label.new()
	title.text = tr(&"MENU_PICK_HERO")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 30)
	menu.add_child(title)
	var first: Button = null
	for hero_id: StringName in HeroData.IDS:
		var hero: HeroData = HeroData.load_hero(hero_id)
		var button: Button = _menu_button(menu, "%s — %s" % [tr(hero.display_name), tr(hero.description)])
		button.add_theme_font_size_override(&"font_size", 24)
		button.custom_minimum_size = Vector2(960, 86)
		button.pressed.connect(_choose_hero.bind(hero_id))
		if first == null:
			first = button
	first.grab_focus()


func _choose_hero(hero_id: StringName) -> void:
	GameState.hero_id = hero_id
	_fade_then(_start_new)


func _menu_button(parent: Control, text: String) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(520, 76)
	button.add_theme_font_size_override(&"font_size", 32)
	parent.add_child(button)
	return button


func _fade_then(next: Callable) -> void:
	for child: Node in get_children():
		if child is VBoxContainer:
			child.queue_free()
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_method(_set_param.bind(&"reveal"), 1.0, 0.0, FADE_OUT_S)
	tween.tween_property(_sparks, ^"modulate:a", 0.0, FADE_OUT_S)
	tween.chain().tween_callback(next)


func _start_new() -> void:
	GameState.progression = null
	LoadingScreen.go(get_tree(), NEXT_SCENE)


func _continue(slot: String) -> void:
	# Watchdog: if loading has not left this scene after a while, start fresh instead.
	get_tree().create_timer(LOAD_WATCHDOG_S).timeout.connect(func() -> void:
		if is_inside_tree():
			Codex.notify(tr(&"CODEX_MSG_LOAD_FAILED"), &"warning")
			_start_new())
	if SaveManager.load_slot(slot) != OK:
		Codex.notify(tr(&"CODEX_MSG_LOAD_FAILED"), &"warning")
		_start_new()


static func _is_continue_event(event: InputEvent) -> bool:
	if event.is_action(&"debug_toggle_overlay") or event.is_echo():
		return false
	if event is InputEventKey or event is InputEventMouseButton \
			or event is InputEventScreenTouch or event is InputEventJoypadButton:
		return event.is_pressed()
	return false


func _set_param(value: float, param: StringName) -> void:
	_material.set_shader_parameter(param, value)
