class_name KeybindList
extends VBoxContainer
## Settings → Controls: one row per rebindable action with two binding buttons.
## Click a button, then press a key or mouse button (Esc = cancel, Backspace = clear).
## A key moves to the new action if another action had it.

## "action:slot" -> binding button.
var _buttons: Dictionary[String, Button] = {}
var _listen_action: StringName = &""
var _listen_slot: int = -1
## Frame in which the list last consumed a key, so the panel ignores that Esc.
var _consumed_frame: int = -1


func _ready() -> void:
	add_theme_constant_override(&"separation", CodexTheme.px(6))
	for action: StringName in Keybinds.ACTIONS:
		_add_row(action)
	var reset: Button = Button.new()
	reset.text = tr(&"SET_KEYS_RESET")
	reset.custom_minimum_size = Vector2(CodexTheme.px(320), CodexTheme.px(48))
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.pressed.connect(func() -> void:
		Settings.reset_keybinds()
		refresh())
	add_child(reset)
	refresh()


func is_capturing() -> bool:
	return _listen_action != &"" or _consumed_frame == Engine.get_process_frames()


func _add_row(action: StringName) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", CodexTheme.px(12))
	var label: Label = Label.new()
	label.text = tr(StringName("ACT_" + String(action).to_upper()))
	label.custom_minimum_size = Vector2(CodexTheme.px(320), 0)
	row.add_child(label)
	for slot: int in Keybinds.SLOTS:
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(CodexTheme.px(200), CodexTheme.px(44))
		b.pressed.connect(_listen.bind(action, slot))
		row.add_child(b)
		_buttons[_key(action, slot)] = b
	add_child(row)


static func _key(action: StringName, slot: int) -> String:
	return "%s:%d" % [action, slot]


func refresh() -> void:
	for action: StringName in Keybinds.ACTIONS:
		var codes: PackedStringArray = Settings.keybinds.get(action, PackedStringArray())
		for slot: int in Keybinds.SLOTS:
			_buttons[_key(action, slot)].text = Keybinds.label(codes[slot]) if slot < codes.size() else "—"
	if _listen_action != &"":
		_buttons[_key(_listen_action, _listen_slot)].text = tr(&"SET_KEYS_PRESS")


func _listen(action: StringName, slot: int) -> void:
	_listen_action = action
	_listen_slot = slot
	refresh()


func _input(event: InputEvent) -> void:
	if _listen_action == &"" or not Keybinds.is_bindable(event):
		return
	get_viewport().set_input_as_handled()
	_consumed_frame = Engine.get_process_frames()
	var key: InputEventKey = event as InputEventKey
	if key != null and key.physical_keycode == KEY_ESCAPE:
		_stop()
		return
	var code: String = "" if key != null and key.physical_keycode in [KEY_BACKSPACE, KEY_DELETE] else Keybinds.encode(event)
	Keybinds.assign(Settings.keybinds, _listen_action, _listen_slot, code)
	Settings.apply_keybinds()
	_stop()


func _stop() -> void:
	_listen_action = &""
	_listen_slot = -1
	refresh()
