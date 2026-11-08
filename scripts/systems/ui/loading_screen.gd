class_name LoadingScreen
extends CanvasLayer
## Loading overlay for new game / continue / region travel: loads the scene on a worker
## thread while a rift swirls and a tip shows, switches scene, then waits until the
## chunks around the player have streamed in before fading out (no frozen screen, no
## pop-in at the start).

const LAYER: int = 120
const FADE_S: float = 0.35
## After the switch, wait for chunks at most this long before revealing anyway.
const STREAM_WAIT_MAX_S: float = 8.0
const TIPS: Array[StringName] = [&"LOAD_TIP_1", &"LOAD_TIP_2", &"LOAD_TIP_3", &"LOAD_TIP_4", &"LOAD_TIP_5"]

var _path: String = ""
var _root: Control
var _bar: ProgressBar
var _swirl: Control
var _phase: int = 0
var _waited: float = 0.0
var _time: float = 0.0


## Starts loading `scene_path` behind the overlay (call instead of change_scene_to_file).
static func go(tree: SceneTree, scene_path: String) -> LoadingScreen:
	var screen: LoadingScreen = LoadingScreen.new()
	screen._path = scene_path
	tree.root.add_child(screen)
	return screen


func _ready() -> void:
	layer = LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	ResourceLoader.load_threaded_request(_path)
	var t: Tween = create_tween()
	_root.modulate.a = 0.0
	t.tween_property(_root, ^"modulate:a", 1.0, FADE_S)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	_swirl = Control.new()
	_swirl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_swirl.draw.connect(_draw_swirl)
	_root.add_child(_swirl)
	var tip: Label = Label.new()
	tip.text = tr(TIPS[randi() % TIPS.size()])
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override(&"font_size", CodexTheme.px(22))
	tip.add_theme_color_override(&"font_color", Color(0.8, 0.85, 1.0, 0.85))
	tip.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	tip.offset_left = -520
	tip.offset_right = 520
	tip.offset_top = -150
	tip.offset_bottom = -90
	_root.add_child(tip)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_bar.offset_left = -260
	_bar.offset_right = 260
	_bar.offset_top = -70
	_bar.offset_bottom = -62
	_root.add_child(_bar)


func _draw_swirl() -> void:
	# A small rift: rotating arcs in violet and blue, brighter core.
	for i: int in 6:
		var r: float = 26.0 + float(i) * 9.0
		var a0: float = _time * (1.6 - float(i) * 0.18) + float(i) * 0.9
		var col: Color = Color(0.55, 0.35, 1.0).lerp(Color(0.35, 0.75, 1.0), float(i) / 5.0)
		col.a = 0.85 - float(i) * 0.1
		_swirl.draw_arc(Vector2.ZERO, r, a0, a0 + PI * 1.1, 32, col, 3.0, true)
	_swirl.draw_circle(Vector2.ZERO, 10.0 + sin(_time * 4.0) * 2.0, Color(0.85, 0.8, 1.0))


func _process(delta: float) -> void:
	_time += delta
	_swirl.queue_redraw()
	match _phase:
		0:
			var progress: Array = []
			var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(_path, progress)
			var done: float = progress[0] if not progress.is_empty() else 0.0
			_bar.value = done * 0.7
			if status == ResourceLoader.THREAD_LOAD_LOADED:
				var scene: PackedScene = ResourceLoader.load_threaded_get(_path) as PackedScene
				get_tree().paused = false
				get_tree().change_scene_to_packed(scene)
				_phase = 1
			elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				get_tree().change_scene_to_file(_path)
				_phase = 1
		1:
			_waited += delta
			_bar.value = 0.7 + 0.3 * minf(_waited / 2.0, 1.0)
			if (WorldStreamer.is_ready_around_player() and _waited > 0.4) or _waited > STREAM_WAIT_MAX_S:
				_phase = 2
				var t: Tween = create_tween()
				t.tween_property(_root, ^"modulate:a", 0.0, FADE_S)
				t.tween_callback(queue_free)
