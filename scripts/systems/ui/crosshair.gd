class_name Crosshair
extends Control
## Small aim dot in the screen centre on PC while the mouse drives the camera
## (attacks go where the camera looks). Hidden on touch screens and with a free cursor.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)


func _process(_delta: float) -> void:
	var show_it: bool = not Settings.wants_touch_controls() and Settings.aim_mode == 0 \
		and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and GameState.player != null
	if show_it != visible:
		visible = show_it


func _draw() -> void:
	draw_circle(Vector2.ZERO, 3.0, Color(1, 1, 1, 0.85))
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 24, Color(CodexTheme.ACCENT, 0.6), 1.5)
