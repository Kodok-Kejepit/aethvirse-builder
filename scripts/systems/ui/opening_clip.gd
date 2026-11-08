class_name OpeningClip
extends CanvasLayer
## The prologue clip (owner: "how the city died and why the hero lived"): an in-engine
## camera sequence over Ashfall with letterbox bars and narration, played once on a new
## game after the text prologue. The world is paused meanwhile; any key / tap or Skip ends it.

signal finished

## Set by Boot when a new game starts; the region plays the clip once it has loaded.
static var pending: bool = false

const START_DELAY_S: float = 2.2
const FADE_S: float = 0.8
const BAR_SHARE: float = 0.11
const GOLD: Color = Color(0.95, 0.8, 0.5)
## Shots in Ashfall world space: camera from → to, the point it looks at, narration key,
## seconds. The last shot is relative to the hero ("hero" = true).
const SHOTS: Array[Dictionary] = [
	{"from": Vector3(0, 42, 70), "to": Vector3(0, 34, 44), "look": Vector3(0, 14, -160), "text": &"CLIP_1", "time": 6.0},
	{"from": Vector3(96, 9, 46), "to": Vector3(112, 8, 26), "look": Vector3(152, 9, -6), "text": &"CLIP_2", "time": 6.0},
	{"from": Vector3(5, 2.6, -64), "to": Vector3(5, 2.4, -92), "look": Vector3(0, 4, -220), "text": &"CLIP_3", "time": 6.5},
	{"from": Vector3(16, 7, 34), "to": Vector3(9, 4.5, 22), "look": Vector3(0, 1, 0), "text": &"CLIP_4", "time": 6.5},
	{"from": Vector3(2.4, 1.9, 3.2), "to": Vector3(1.1, 1.65, 2.0), "look": Vector3(0, 1.45, 0), "text": &"CLIP_5", "time": 6.0, "hero": true},
]

var _camera: Camera3D = null
var _previous: Camera3D = null
var _caption: Label = null
var _black: ColorRect = null
var _hidden: Array[CanvasLayer] = []
var _done: bool = false
var _was_paused: bool = false


## Plays the clip if a new game asked for it (not in capture / test runs).
static func play_if_pending(scene_root: Node) -> void:
	if not pending:
		return
	pending = false
	if "--skip-opening" in OS.get_cmdline_user_args():
		return
	scene_root.get_tree().create_timer(START_DELAY_S).timeout.connect(func() -> void:
		if is_instance_valid(scene_root) and scene_root.is_inside_tree():
			scene_root.add_child(OpeningClip.new()))


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_was_paused = get_tree().paused
	get_tree().paused = true
	_hide_hud()
	_build_ui()
	_previous = get_viewport().get_camera_3d()
	_camera = Camera3D.new()
	_camera.fov = 55.0
	_camera.far = 900.0
	get_tree().current_scene.add_child(_camera)
	_camera.make_current()
	_camera.add_child(_ash())
	_run()


func _run() -> void:
	for shot: Dictionary in SHOTS:
		if _done:
			return
		await _play_shot(shot)
	if _done:
		return
	_caption.text = ""
	await _fade(1.0)
	_caption.text = tr(&"CLIP_6")
	_caption.modulate.a = 0.0
	await _tween_alpha(_caption, 1.0, FADE_S)
	await get_tree().create_timer(2.6, true, false, true).timeout
	finish()


func _play_shot(shot: Dictionary) -> void:
	var base: Vector3 = Vector3.ZERO
	if shot.get("hero", false) and GameState.player != null:
		var hero: Node3D = GameState.player as Node3D
		base = hero.global_position
	var from: Vector3 = shot["from"] + base
	var to: Vector3 = shot["to"] + base
	var look: Vector3 = shot["look"] + base
	var seconds: float = shot["time"]
	var key: StringName = shot["text"]
	_camera.global_position = from
	_camera.look_at(look)
	_caption.text = tr(key)
	_caption.modulate.a = 0.0
	await _fade(0.0)
	var t: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	t.tween_method(func(k: float) -> void:
		if is_instance_valid(_camera):
			_camera.global_position = from.lerp(to, k)
			_camera.look_at(look), 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE)
	t.tween_property(_caption, ^"modulate:a", 1.0, FADE_S)
	await get_tree().create_timer(seconds - FADE_S, true, false, true).timeout
	if _done:
		return
	await _fade(1.0)


func _fade(alpha: float) -> void:
	await _tween_alpha(_black, alpha, FADE_S)


func _tween_alpha(node: CanvasItem, alpha: float, seconds: float) -> void:
	var t: Tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	t.tween_property(node, ^"modulate:a", alpha, seconds)
	await t.finished


func finish() -> void:
	if _done:
		return
	_done = true
	if is_instance_valid(_previous):
		_previous.make_current()
	if is_instance_valid(_camera):
		_camera.queue_free()
	for l: CanvasLayer in _hidden:
		if is_instance_valid(l):
			l.visible = true
	get_tree().paused = _was_paused
	Codex.notify(tr(&"CODEX_MSG_AWAKEN"), &"secret")
	finished.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventJoypadButton or event is InputEventScreenTouch) \
			and event.is_pressed() and not event.is_echo():
		get_viewport().set_input_as_handled()
		finish()


func _hide_hud() -> void:
	for n: Node in get_tree().current_scene.find_children("*", "CanvasLayer", true, false):
		var l: CanvasLayer = n
		if l != self and l.visible:
			l.visible = false
			_hidden.append(l)


func _build_ui() -> void:
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	for top: bool in [true, false]:
		var bar: ColorRect = ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bar)
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.anchor_top = 0.0 if top else 1.0 - BAR_SHARE
		bar.anchor_bottom = BAR_SHARE if top else 1.0
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_black)
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption = Label.new()
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_override(&"font", CodexTheme.SERIF_REGULAR)
	_caption.add_theme_font_size_override(&"font_size", CodexTheme.px(26))
	_caption.add_theme_color_override(&"font_color", Color(0.95, 0.93, 0.88))
	_caption.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0.9))
	_caption.add_theme_constant_override(&"shadow_offset_y", 2)
	root.add_child(_caption)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.anchor_top = 1.0 - BAR_SHARE - 0.16
	_caption.anchor_bottom = 1.0 - BAR_SHARE
	_caption.offset_top = 0.0
	_caption.offset_bottom = 0.0
	_caption.offset_left = CodexTheme.px(120)
	_caption.offset_right = -CodexTheme.px(120)
	var skip: Button = Button.new()
	skip.text = tr(&"PROLOGUE_SKIP")
	skip.flat = true
	skip.add_theme_color_override(&"font_color", GOLD)
	skip.pressed.connect(finish)
	root.add_child(skip)
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, CodexTheme.px(24))


## Grey ash drifting down around the camera.
static func _ash() -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = 160
	p.lifetime = 6.0
	p.preprocess = 6.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14, 2, 14)
	p.position = Vector3(0, 6, -6)
	p.direction = Vector3(0.2, -1, 0)
	p.spread = 25.0
	p.gravity = Vector3(0, -0.6, 0)
	p.initial_velocity_min = 0.3
	p.initial_velocity_max = 0.9
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.albedo_color = Color(0.75, 0.73, 0.7, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = mat
	p.mesh = quad
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	return p
