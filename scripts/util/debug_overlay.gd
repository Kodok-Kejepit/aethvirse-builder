extends CanvasLayer
## F3 debug overlay: FPS, draw calls, memory, loaded chunks, player position and state.
## Removes itself in release builds.

const REFRESH_INTERVAL_S: float = 0.25
const BYTES_PER_MB: float = 1048576.0
## Touch index of the third simultaneous finger (0-based): a 3-finger tap toggles on mobile.
const TOGGLE_TOUCH_INDEX: int = 2

@onready var _label: Label = %StatsLabel

var _elapsed: float = 0.0


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var capture: DebugCapture = DebugCapture.new()
	add_child(capture)
	capture.overlay_requested.connect(func() -> void: visible = true)
	capture.start(OS.get_cmdline_user_args())


func _unhandled_input(event: InputEvent) -> void:
	var touch: InputEventScreenTouch = event as InputEventScreenTouch
	var touch_toggle: bool = touch != null and touch.pressed and touch.index == TOGGLE_TOUCH_INDEX
	if event.is_action_pressed(&"debug_toggle_overlay") or touch_toggle:
		visible = not visible
		_elapsed = REFRESH_INTERVAL_S
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_elapsed += delta
	if _elapsed < REFRESH_INTERVAL_S:
		return
	_elapsed = 0.0
	_label.text = _build_text()


func _build_text() -> String:
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var draw_calls: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var primitives: float = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var static_mb: float = Performance.get_monitor(Performance.MEMORY_STATIC) / BYTES_PER_MB
	var vram_mb: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / BYTES_PER_MB
	return "\n".join([
		"FPS %d  |  preset %s  |  %s" % [fps, Settings.get_preset_name(), RenderingServer.get_current_rendering_method()],
		"Draw calls %d  |  Tris %d" % [draw_calls, primitives],
		"RAM %.1f MB  |  VRAM %.1f MB" % [static_mb, vram_mb],
		"Chunks loaded %d" % WorldStreamer.get_loaded_chunk_count(),
		"Pos %s" % _player_position_text(),
		"State %s" % _player_state_text(),
	])


func _player_position_text() -> String:
	var player: Node3D = GameState.player
	if player == null or not is_instance_valid(player):
		return "-"
	var p: Vector3 = player.global_position
	return "(%.1f, %.1f, %.1f)" % [p.x, p.y, p.z]


func _player_state_text() -> String:
	var player: Node3D = GameState.player
	if player == null or not is_instance_valid(player) or not player.has_method(&"get_debug_state"):
		return "-"
	return str(player.call(&"get_debug_state"))
