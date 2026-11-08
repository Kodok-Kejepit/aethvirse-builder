class_name SettingsPanel
extends PausingPanel
## Settings window (F10, Codex → System, main menu, ⚙ on touch). Changes apply instantly and
## are written to user://settings.cfg when the window closes.

const GROUP: StringName = &"settings_panel"
const VOLUME_KEYS: Dictionary[StringName, StringName] = {
	&"Master": &"SET_VOL_MASTER", &"BGM": &"SET_VOL_BGM", &"SFX": &"SET_VOL_SFX",
	&"Voice": &"SET_VOL_VOICE", &"UI": &"SET_VOL_UI",
}
const LANGUAGE_KEYS: Array[StringName] = [&"SET_LANG_AUTO", &"SET_LANG_EN", &"SET_LANG_ID"]

var _list: VBoxContainer
var _keys: KeybindList = null


func _init() -> void:
	toggle_action = &"settings"
	title_key = &"SET_TITLE"
	requires_player = false


func _ready() -> void:
	add_to_group(GROUP)
	super._ready()


func _build_content(body: VBoxContainer) -> void:
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", CodexTheme.px(10))
	var scroll: ScrollContainer = PausingPanel.wrap_scroll(_list)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)


func _on_open() -> void:
	rebuild()


func close() -> void:
	if is_open():
		Settings.save_to()
	super.close()


func rebuild() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	_section(&"SET_GRAPHICS")
	_option(&"SET_PRESET", _preset_names(), _preset_index(), func(i: int) -> void:
		Settings.preset_choice = Settings.AUTO if i == 0 else i - 1)
	var caps: PackedStringArray = [tr(&"SET_FPS_PRESET")]
	for cap: int in Settings.FPS_CAPS.slice(1):
		caps.append("%d FPS" % cap)
	_option(&"SET_FPS", caps, maxi(Settings.FPS_CAPS.find(Settings.fps_cap), 0), func(i: int) -> void:
		Settings.fps_cap = Settings.FPS_CAPS[i])
	_section(&"SET_AUDIO")
	for bus: StringName in VOLUME_KEYS:
		_slider(VOLUME_KEYS[bus], 0.0, 1.0, Settings.volumes[bus], func(v: float) -> void:
			Settings.volumes[bus] = v)
	_section(&"SET_CONTROLS")
	_slider(&"SET_SENSITIVITY", 0.2, 3.0, Settings.mouse_sensitivity, func(v: float) -> void:
		Settings.mouse_sensitivity = v)
	_toggle(&"SET_INVERT_Y", Settings.invert_y, func(on: bool) -> void: Settings.invert_y = on)
	_option(&"SET_AIM", PackedStringArray([tr(&"SET_AIM_CAMERA"), tr(&"SET_AIM_MOVE")]), Settings.aim_mode, func(i: int) -> void:
		Settings.aim_mode = i)
	_slider(&"SET_CAMERA_DISTANCE", 2.5, 8.0, Settings.camera_distance, func(v: float) -> void:
		Settings.camera_distance = v)
	if Settings.wants_touch_controls():
		_slider(&"SET_TOUCH_SCALE", Settings.TOUCH_SCALE_RANGE.x, Settings.TOUCH_SCALE_RANGE.y,
			Settings.touch_button_scale, func(v: float) -> void: Settings.touch_button_scale = v)
		_slider(&"SET_TOUCH_OPACITY", 0.3, 1.0, Settings.touch_opacity, func(v: float) -> void:
			Settings.touch_opacity = v)
		var arrange: Button = Button.new()
		arrange.text = tr(&"SET_TOUCH_ARRANGE")
		arrange.custom_minimum_size = CodexTheme.button_size(320)
		arrange.pressed.connect(_arrange_buttons)
		_row(&"SET_TOUCH_LAYOUT", arrange, false)
	if not Settings.wants_touch_controls():
		_toggle(&"SET_MOUSE_ATTACK", Settings.mouse_attack, func(on: bool) -> void: Settings.mouse_attack = on)
		_section(&"SET_KEYS")
		_keys = KeybindList.new()
		_list.add_child(_keys)
	_section(&"SET_GAME")
	var langs: PackedStringArray = []
	for key: StringName in LANGUAGE_KEYS:
		langs.append(tr(key))
	_option(&"SET_LANGUAGE", langs, maxi(Settings.LANGUAGES.find(Settings.language), 0), func(i: int) -> void:
		Settings.language = Settings.LANGUAGES[i]
		rebuild.call_deferred())
	_toggle(&"SET_DAMAGE_NUMBERS", Settings.show_damage_numbers, func(on: bool) -> void:
		Settings.show_damage_numbers = on)


## Closes Settings and lets the player drag / resize the touch buttons on the live screen.
func _arrange_buttons() -> void:
	var controls: Node = get_tree().get_first_node_in_group(&"mobile_controls")
	if controls == null:
		return
	close()
	controls.call(&"begin_edit")


func _holds_keys() -> bool:
	return _keys != null and is_instance_valid(_keys) and _keys.is_capturing()


func _preset_names() -> PackedStringArray:
	var names: PackedStringArray = [tr(&"SET_PRESET_AUTO") % QualityPresets.load_profile(Settings.detected_preset()).display_name]
	for p: int in QualityPresets.PROFILE_PATHS:
		names.append(QualityPresets.load_profile(p as QualityPresets.Preset).display_name)
	return names


static func _preset_index() -> int:
	return 0 if Settings.preset_choice == Settings.AUTO else Settings.preset_choice + 1


## Volumes (0..1) read as percent, other sliders as a multiplier / metres.
static func _format(value: float, max_v: float) -> String:
	return "%d%%" % roundi(value * 100.0) if is_equal_approx(max_v, 1.0) else "%.2f" % value


func _section(key: StringName) -> void:
	var label: Label = Label.new()
	label.text = tr(key)
	label.add_theme_font_size_override(&"font_size", CodexTheme.px(26))
	label.add_theme_color_override(&"font_color", CodexTheme.ACCENT)
	_list.add_child(label)


func _row(key: StringName, control: Control, expand: bool = true) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", CodexTheme.px(16))
	var label: Label = Label.new()
	label.text = tr(key)
	label.custom_minimum_size = Vector2(CodexTheme.px(320), 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL if expand else Control.SIZE_SHRINK_BEGIN
	control.custom_minimum_size.y = CodexTheme.px(48)
	row.add_child(control)
	_list.add_child(row)
	return row


func _option(key: StringName, items: PackedStringArray, selected: int, on_pick: Callable) -> void:
	var option: OptionButton = OptionButton.new()
	for item: String in items:
		option.add_item(item)
	option.select(selected)
	option.item_selected.connect(func(i: int) -> void:
		on_pick.call(i)
		Settings.apply_all())
	_row(key, option)


func _slider(key: StringName, min_v: float, max_v: float, value: float, on_change: Callable) -> void:
	var slider: HSlider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = 0.05
	slider.value = value
	var readout: Label = Label.new()
	readout.custom_minimum_size = Vector2(CodexTheme.px(90), 0)
	readout.text = _format(value, max_v)
	slider.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		readout.text = _format(v, max_v)
		Settings.apply_all())
	_row(key, slider).add_child(readout)


func _toggle(key: StringName, on: bool, on_toggle: Callable) -> void:
	var box: Button = Button.new()
	box.toggle_mode = true
	box.button_pressed = on
	box.custom_minimum_size.x = CodexTheme.px(180)
	box.text = tr(&"SET_ON") if on else tr(&"SET_OFF")
	box.toggled.connect(func(pressed: bool) -> void:
		box.text = tr(&"SET_ON") if pressed else tr(&"SET_OFF")
		on_toggle.call(pressed)
		Settings.apply_all())
	_row(key, box, false)
