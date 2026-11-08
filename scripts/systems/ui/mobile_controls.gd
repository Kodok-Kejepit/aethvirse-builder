extends CanvasLayer
## Routes multitouch: buttons first, left half = floating joystick, right half = camera look.
## Layout editor (Settings → Touch controls → Arrange buttons): drag any button, resize the
## selected one with − / +, Reset or Done; the layout is saved in Settings.

## Fraction of the screen width (from the left) that starts the joystick.
const JOYSTICK_ZONE: float = 0.45

@onready var _joystick: FloatingJoystick = %Joystick
@onready var _buttons: Array[TouchActionButton] = [%AttackButton, %HeavyButton, %JumpButton, %DodgeButton, %LockButton,
	%Skill1Button, %Skill2Button, %Skill3Button, %Skill4Button, %UltimateButton, %StatusButton, %InventoryButton, %SettingsButton, %PauseButton, %InteractButton]

var _joystick_index: int = -1
var _look_index: int = -1
var _defaults: Dictionary[String, Vector2] = {}
var _editing: bool = false
var _selected: TouchActionButton = null
var _drag_index: int = -1
var _drag_from: Vector2 = Vector2.ZERO
var _editor: Control = null
const GROUP: StringName = &"mobile_controls"


func _ready() -> void:
	add_to_group(GROUP)
	visible = Settings.wants_touch_controls()
	set_process_input(visible)
	EventBus.settings_changed.connect(apply_layout)
	apply_layout.call_deferred()


## Button size, opacity and the player's own arrangement from Settings.
func apply_layout() -> void:
	for button: TouchActionButton in _buttons:
		if not _defaults.has(button.name):
			_defaults[button.name] = button.position
		var spec: Vector3 = Settings.touch_layout.get(String(button.name), Vector3(0, 0, 1))
		button.position = _defaults[button.name] + Vector2(spec.x, spec.y)
		button.pivot_offset = button.size * 0.5
		button.scale = Vector2.ONE * Settings.touch_button_scale * spec.z
		button.modulate.a = Settings.touch_opacity
	_joystick.modulate.a = Settings.touch_opacity


## Layout editor ---------------------------------------------------------------------

func begin_edit() -> void:
	visible = true
	set_process_input(true)
	# The world waits while the player arranges the buttons.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	_editing = true
	_selected = null
	_editor = _build_editor()
	add_child(_editor)


func end_edit(save: bool) -> void:
	_editing = false
	_drag_index = -1
	if _editor != null:
		_editor.queue_free()
		_editor = null
	if save:
		Settings.save_to()
	_selected = null
	queue_redraw_selection()
	process_mode = Node.PROCESS_MODE_INHERIT
	get_tree().paused = false
	visible = Settings.wants_touch_controls()
	set_process_input(visible)
	apply_layout()


func _build_editor() -> Control:
	var bar: PanelContainer = PanelContainer.new()
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar.offset_left = -520
	bar.offset_right = 520
	bar.offset_top = 12
	bar.theme = CodexTheme.make_theme()
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	bar.add_child(row)
	var hint: Label = Label.new()
	hint.text = tr(&"TOUCH_EDIT_HINT")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(hint)
	for spec: Array in [["−", func() -> void: _resize(-0.1)], ["+", func() -> void: _resize(0.1)],
			[tr(&"TOUCH_EDIT_RESET"), _reset], [tr(&"TOUCH_EDIT_DONE"), func() -> void: end_edit(true)]]:
		var b: Button = Button.new()
		b.text = spec[0]
		b.custom_minimum_size = Vector2(72, 56)
		var cb: Callable = spec[1]
		b.pressed.connect(cb)
		row.add_child(b)
	return bar


func _resize(step: float) -> void:
	if _selected == null:
		return
	var key: String = String(_selected.name)
	var spec: Vector3 = Settings.touch_layout.get(key, Vector3(0, 0, 1))
	spec.z = clampf(spec.z + step, Settings.TOUCH_BUTTON_SCALE_RANGE.x, Settings.TOUCH_BUTTON_SCALE_RANGE.y)
	Settings.touch_layout[key] = spec
	apply_layout()


func _reset() -> void:
	Settings.touch_layout.clear()
	apply_layout()


func _edit_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed and (_editor == null or not _editor.get_global_rect().has_point(touch.position)):
			_selected = null
			for button: TouchActionButton in _buttons:
				if button.get_global_rect().grow(12.0).has_point(touch.position):
					_selected = button
			if _selected != null:
				_drag_index = touch.index
				_drag_from = touch.position
			queue_redraw_selection()
		elif not touch.pressed and touch.index == _drag_index:
			_drag_index = -1
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag != null and drag.index == _drag_index and _selected != null:
		var key: String = String(_selected.name)
		var spec: Vector3 = Settings.touch_layout.get(key, Vector3(0, 0, 1))
		spec.x += drag.position.x - _drag_from.x
		spec.y += drag.position.y - _drag_from.y
		_drag_from = drag.position
		Settings.touch_layout[key] = spec
		apply_layout()


## The selected button pulses (modulate) so the player sees what − / + will resize.
func queue_redraw_selection() -> void:
	for button: TouchActionButton in _buttons:
		button.self_modulate = Color(1.0, 0.85, 0.4) if button == _selected else Color.WHITE


func _input(event: InputEvent) -> void:
	if _editing:
		_edit_input(event)
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	if touch != null:
		if touch.pressed:
			_on_touch_down(touch.index, touch.position)
		else:
			_on_touch_up(touch.index)
		return
	var drag: InputEventScreenDrag = event as InputEventScreenDrag
	if drag == null:
		return
	if drag.index == _joystick_index:
		_joystick.move_to(drag.position)
	elif drag.index == _look_index:
		EventBus.camera_look_input.emit(drag.relative)


func _on_touch_down(index: int, point: Vector2) -> void:
	for button: TouchActionButton in _buttons:
		if button.try_press(index, point):
			return
	var width: float = get_viewport().get_visible_rect().size.x
	if point.x < width * JOYSTICK_ZONE and _joystick_index == -1:
		_joystick_index = index
		_joystick.begin(point)
	elif _look_index == -1:
		_look_index = index


func _on_touch_up(index: int) -> void:
	for button: TouchActionButton in _buttons:
		button.release(index)
	if index == _joystick_index:
		_joystick_index = -1
		_joystick.end()
	if index == _look_index:
		_look_index = -1
