class_name DialogBox
extends CanvasLayer
## Conversation UI: speaker, typed text, choices. Pauses the game while open.
## Advance with interact / attack / click / tap.

const GROUP: StringName = &"dialog_box"
const CHARS_PER_SECOND: float = 55.0
const ADVANCE_ACTIONS: Array[StringName] = [&"interact", &"attack_light", &"ui_accept"]

signal finished

var _panel: PanelContainer
var _speaker: Label
var _text: Label
var _choices: VBoxContainer
var _queue: Array[String] = []
var _speaker_name: String = ""
var _pending_choices: Array[DialogChoice] = []
var _on_choice: Callable
var _visible_chars: float = 0.0
var _advance_was_down: bool = true
var _was_paused: bool = false
var _mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


static func find(from: Node) -> DialogBox:
	return from.get_tree().get_first_node_in_group(GROUP) as DialogBox


func _ready() -> void:
	add_to_group(GROUP)
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


## Shows lines (already translated) then offers choices; on_choice(choice or null) when done.
func open(speaker: String, lines: Array[String], choices: Array[DialogChoice], on_choice: Callable) -> void:
	_speaker_name = speaker
	_queue = lines.duplicate()
	_pending_choices = choices
	_on_choice = on_choice
	_was_paused = get_tree().paused
	get_tree().paused = true
	# Free the cursor (PC) so choices can be clicked instead of turning the camera.
	_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_panel.visible = true
	_advance_was_down = true
	_next_line()


func _process(delta: float) -> void:
	if not is_open():
		return
	if _visible_chars < _text.text.length():
		_visible_chars += CHARS_PER_SECOND * delta
		_text.visible_characters = int(_visible_chars)
	var down: bool = false
	for action: StringName in ADVANCE_ACTIONS:
		down = down or Input.is_action_pressed(action)
	if down and not _advance_was_down:
		_advance()
	_advance_was_down = down


func _input(event: InputEvent) -> void:
	if not is_open():
		return
	if _choices.get_child_count() > 0:
		# Number keys pick a choice (1 = first … last = leave).
		var key: InputEventKey = event as InputEventKey
		if key != null and key.pressed and not key.echo:
			var n: int = key.keycode - KEY_1
			if n >= 0 and n < _choices.get_child_count():
				(_choices.get_child(n) as Button).emit_signal(&"pressed")
				get_viewport().set_input_as_handled()
		return
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	var click: InputEventMouseButton = event as InputEventMouseButton
	if (touch != null and touch.pressed) or (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT):
		_advance()
		get_viewport().set_input_as_handled()


func _advance() -> void:
	if _choices.get_child_count() > 0:
		return
	if _visible_chars < _text.text.length():
		_visible_chars = _text.text.length()
		_text.visible_characters = -1
		return
	_next_line()


func _next_line() -> void:
	if not _queue.is_empty():
		var line: String = _queue.pop_front()
		_show(line)
		return
	if not _pending_choices.is_empty():
		_show_choices()
		return
	_close(null)


func _show(line: String) -> void:
	_speaker.text = _speaker_name
	_text.text = line
	_visible_chars = 0.0
	_text.visible_characters = 0


func _show_choices() -> void:
	for choice: DialogChoice in _pending_choices:
		var button: Button = Button.new()
		button.text = tr(choice.text) + ("  (%d G)" % choice.gold_cost if choice.gold_cost > 0 else "")
		button.custom_minimum_size = Vector2(0, 52)
		button.pressed.connect(_close.bind(choice))
		_choices.add_child(button)
	var leave: Button = Button.new()
	leave.text = tr(&"DIALOG_LEAVE")
	leave.custom_minimum_size = Vector2(0, 52)
	leave.pressed.connect(_close.bind(null))
	_choices.add_child(leave)
	_pending_choices = []
	for i: int in _choices.get_child_count():
		var b: Button = _choices.get_child(i) as Button
		b.text = "%d.  %s" % [i + 1, b.text]
		b.custom_minimum_size.y = CodexTheme.px(52)
	(_choices.get_child(0) as Button).grab_focus.call_deferred()


func _close(choice: DialogChoice) -> void:
	for child: Node in _choices.get_children():
		child.queue_free()
	_panel.visible = false
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse_mode
	var callback: Callable = _on_choice
	_on_choice = Callable()
	if callback.is_valid():
		callback.call(choice)
	finished.emit()


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.theme = CodexTheme.make_theme()
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_panel.offset_left = 220
	_panel.offset_right = -220
	_panel.offset_top = -330
	_panel.offset_bottom = -40
	add_child(_panel)
	var vbox: VBoxContainer = VBoxContainer.new()
	_panel.add_child(vbox)
	_speaker = Label.new()
	_speaker.add_theme_font_size_override(&"font_size", 28)
	_speaker.add_theme_color_override(&"font_color", CodexTheme.ACCENT)
	vbox.add_child(_speaker)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override(&"font_size", 26)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_text)
	_choices = VBoxContainer.new()
	vbox.add_child(_choices)
