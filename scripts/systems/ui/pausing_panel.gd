class_name PausingPanel
extends CanvasLayer
## Full-screen "System" window that pauses the game while open (Codex, Inventory, Settings).
## Only one PausingPanel is open at a time; opening one closes the others.

const PANEL_GROUP: StringName = &"pausing_panel"

## Input action that toggles this panel (edge-detected so touch buttons work too).
var toggle_action: StringName = &""
var title_key: StringName = &""
## Opening requires a spawned player (gameplay panels). Settings can open anywhere.
var requires_player: bool = true

const HOLO_SHADER: Shader = preload("res://assets/shaders/codex_holo.gdshader")
const OPEN_S: float = 0.18

var _root: PanelContainer
var _holo: ColorRect
var _body: VBoxContainer
var _toggle_was_down: bool = false
var _was_paused: bool = false
var _mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE


func _ready() -> void:
	add_to_group(PANEL_GROUP)
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_frame()
	_build_content(_body)
	_root.visible = false


func _process(_delta: float) -> void:
	_process_holo()
	if toggle_action == &"":
		return
	var down: bool = Input.is_action_pressed(toggle_action)
	var toggled: bool = down and not _toggle_was_down
	_toggle_was_down = down
	if _holds_keys():
		return
	if toggled or (is_open() and Input.is_action_just_pressed(&"ui_cancel")):
		toggle()


## True while the panel captures raw keys itself (e.g. waiting for a new key binding).
func _holds_keys() -> bool:
	return false


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func open() -> void:
	if is_open() or (requires_player and GameState.player == null):
		return
	var restore_pause: bool = get_tree().paused
	var restore_mouse: Input.MouseMode = Input.mouse_mode
	for other: Node in get_tree().get_nodes_in_group(PANEL_GROUP):
		var panel: PausingPanel = other as PausingPanel
		if panel != null and panel != self and panel.is_open():
			restore_pause = panel._was_paused
			restore_mouse = panel._mouse_mode
			panel._root.visible = false
	_was_paused = restore_pause
	_mouse_mode = restore_mouse
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_root.visible = true
	_play_open()
	_on_open()
	AudioManager.play_ui(&"ding")


func close() -> void:
	if not is_open():
		return
	_root.visible = false
	get_tree().paused = _was_paused
	Input.mouse_mode = _mouse_mode


func is_open() -> bool:
	return _root != null and _root.visible


func _sync_holo() -> void:
	_holo.visible = _root.visible
	_holo.position = _root.position
	_holo.size = _root.size
	_holo.pivot_offset = _root.pivot_offset
	_holo.scale = _root.scale
	_holo.modulate = _root.modulate
	(_holo.material as ShaderMaterial).set_shader_parameter(&"rect_size", _root.size)


func _process_holo() -> void:
	if _root.visible and (_holo.modulate != _root.modulate or _holo.scale != _root.scale):
		_sync_holo()


## Hologram "power on": quick fade + vertical unfold.
func _play_open() -> void:
	_root.pivot_offset = _root.size * 0.5
	_root.modulate = Color(1, 1, 1, 0.0)
	_root.scale = Vector2(1.0, 0.92)
	var t: Tween = create_tween().set_parallel(true).set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(_root, ^"modulate:a", 1.0, OPEN_S)
	t.tween_property(_root, ^"scale", Vector2.ONE, OPEN_S).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func _clear_style() -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.set_content_margin_all(CodexTheme.px(18))
	return s


## Override: add the panel's widgets under `body`.
func _build_content(_body_box: VBoxContainer) -> void:
	pass


## Override: refresh contents every time the panel opens.
func _on_open() -> void:
	pass


func _build_frame() -> void:
	var ui: float = CodexTheme.ui_scale()
	var margin: float = 100.0 if ui <= 1.0 else 16.0
	_root = PanelContainer.new()
	_root.theme = CodexTheme.make_theme()
	_root.add_theme_stylebox_override(&"panel", _clear_style())
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.offset_left = margin
	_root.offset_top = 70.0 if ui <= 1.0 else 16.0
	_root.offset_right = -margin
	_root.offset_bottom = -_root.offset_top
	add_child(_root)
	_holo = ColorRect.new()
	_holo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = HOLO_SHADER
	_holo.material = mat
	add_child(_holo)
	move_child(_holo, _root.get_index())
	# The glass sits behind the panel and follows its rect (incl. the open animation).
	_root.item_rect_changed.connect(_sync_holo)
	_root.visibility_changed.connect(_sync_holo)
	_body = VBoxContainer.new()
	_root.add_child(_body)
	var header: HBoxContainer = HBoxContainer.new()
	_body.add_child(header)
	var title: Label = Label.new()
	title.text = tr(title_key)
	title.add_theme_font_size_override(&"font_size", CodexTheme.px(34))
	title.add_theme_color_override(&"font_color", CodexTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_button: Button = Button.new()
	close_button.text = tr(&"STATUS_CLOSE")
	close_button.custom_minimum_size = CodexTheme.button_size(160)
	close_button.pressed.connect(close)
	header.add_child(close_button)


static func wrap_scroll(control: Control) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(control)
	return scroll
