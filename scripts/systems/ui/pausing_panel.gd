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
const ORNAMENT_DRAGON: Texture2D = preload("res://assets/ui/hud/ornament_dragon.png")
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
	mat.set_shader_parameter(&"base_color", Color(CodexTheme.BG, 0.96))
	mat.set_shader_parameter(&"glow_color", CodexTheme.ACCENT)
	mat.set_shader_parameter(&"trim_color", CodexTheme.TRIM)
	_holo.material = mat
	add_child(_holo)
	if CodexTheme.dragon_style:
		# The owner's line-art dragon, faint, in the bottom-right corner of the card.
		var dragon: TextureRect = TextureRect.new()
		dragon.texture = ORNAMENT_DRAGON
		dragon.modulate = Color(1, 1, 1, 0.42)
		dragon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dragon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		dragon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		dragon.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
		dragon.offset_left = -CodexTheme.px(420)
		dragon.offset_top = -CodexTheme.px(180)
		dragon.offset_right = -CodexTheme.px(14)
		dragon.offset_bottom = -CodexTheme.px(14)
		_holo.add_child(dragon)
	move_child(_holo, _root.get_index())
	# The glass sits behind the panel and follows its rect (incl. the open animation).
	_root.item_rect_changed.connect(_sync_holo)
	_root.visibility_changed.connect(_sync_holo)
	_body = VBoxContainer.new()
	_root.add_child(_body)
	# Header: the title centred in serif capitals over an ornament rule; Close on the right
	# (balanced by an empty slot on the left so the title stays centred).
	var header: HBoxContainer = HBoxContainer.new()
	_body.add_child(header)
	var balance: Control = Control.new()
	balance.custom_minimum_size = CodexTheme.button_size(160)
	header.add_child(balance)
	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override(&"separation", 0)
	header.add_child(title_box)
	var title: Label = Label.new()
	title.text = tr(title_key).to_upper()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override(&"font", CodexTheme.SERIF)
	title.add_theme_font_size_override(&"font_size", CodexTheme.px(34))
	title.add_theme_color_override(&"font_color", CodexTheme.TRIM)
	title_box.add_child(title)
	var rule: Control = Control.new()
	rule.custom_minimum_size = Vector2(0, CodexTheme.px(14))
	rule.draw.connect(func() -> void: _draw_rule(rule))
	title_box.add_child(rule)
	var close_button: Button = Button.new()
	close_button.text = tr(&"STATUS_CLOSE")
	close_button.custom_minimum_size = CodexTheme.button_size(160)
	close_button.pressed.connect(close)
	header.add_child(close_button)


## Ornament under the title: a thin line fading out both ways with a diamond in the middle.
static func _draw_rule(c: Control) -> void:
	var mid: Vector2 = Vector2(c.size.x * 0.5, c.size.y * 0.5)
	var half: float = minf(c.size.x * 0.3, 320.0)
	var trim: Color = CodexTheme.TRIM
	c.draw_polyline_colors(PackedVector2Array([mid - Vector2(half, 0), mid, mid + Vector2(half, 0)]),
		PackedColorArray([Color(trim, 0.0), trim, Color(trim, 0.0)]), 1.2, true)
	var d: float = 5.0
	c.draw_colored_polygon(PackedVector2Array([mid + Vector2(0, -d), mid + Vector2(d * 1.6, 0), mid + Vector2(0, d), mid + Vector2(-d * 1.6, 0)]), trim)


static func wrap_scroll(control: Control) -> ScrollContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(control)
	return scroll
