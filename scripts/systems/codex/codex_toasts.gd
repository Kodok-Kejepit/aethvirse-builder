extends CanvasLayer
## Slide-in Codex notifications (top right). Queued; a few visible at once.

const MAX_VISIBLE: int = 4
const SHOW_S: float = 3.2
const SLIDE_S: float = 0.25
const TOAST_WIDTH: float = 520.0
const KIND_COLORS: Dictionary[StringName, Color] = {
	&"info": Color(0.45, 0.8, 1.0), &"level_up": Color(1.0, 0.85, 0.35), &"quest": Color(0.5, 1.0, 0.7),
	&"secret": Color(0.8, 0.55, 1.0), &"warning": Color(1.0, 0.4, 0.4), &"anomaly": Color(1.0, 0.3, 0.6),
	&"reward": Color(1.0, 0.75, 0.3),
}

@onready var _stack: VBoxContainer = %ToastStack


func _ready() -> void:
	layer = 50
	EventBus.codex_message.connect(_on_message)


func _on_message(text: String, kind: StringName) -> void:
	while _stack.get_child_count() >= MAX_VISIBLE:
		var oldest: Node = _stack.get_child(0)
		_stack.remove_child(oldest)
		oldest.queue_free()
	var accent: Color = KIND_COLORS.get(kind, Color.WHITE)
	var toast: PanelContainer = _make_toast(text, accent)
	_stack.add_child(toast)
	toast.position.x = TOAST_WIDTH
	var tween: Tween = toast.create_tween()
	tween.tween_property(toast, ^"modulate:a", 1.0, SLIDE_S).from(0.0)
	tween.tween_interval(SHOW_S)
	tween.tween_property(toast, ^"modulate:a", 0.0, SLIDE_S)
	tween.tween_callback(toast.queue_free)


static func _make_toast(text: String, accent: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(TOAST_WIDTH, 0)
	panel.add_theme_stylebox_override(&"panel", CodexTheme.panel_style(accent))
	var label: Label = Label.new()
	label.text = "[ SYSTEM ]  " + text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override(&"font_color", accent.lightened(0.4))
	label.add_theme_font_size_override(&"font_size", 22)
	panel.add_child(label)
	return panel
