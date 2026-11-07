extends Control
## Minimal stamina bar: fades in when stamina is used, fades out when full.

@export var fill_color: Color = Color(0.45, 0.85, 1.0, 0.95)
@export var exhausted_color: Color = Color(1.0, 0.45, 0.4, 0.95)
@export var back_color: Color = Color(0.05, 0.1, 0.2, 0.6)
@export var fade_speed: float = 4.0
@export var hide_delay_s: float = 1.0
## Matches StaminaComponent.exhausted_recover_ratio (bar stays red until then).
@export var recover_ratio: float = 0.3

var _ratio: float = 1.0
var _exhausted: bool = false
var _since_full: float = 0.0


func _ready() -> void:
	modulate.a = 0.0
	EventBus.player_stamina_changed.connect(_on_changed)


func _on_changed(current: float, maximum: float) -> void:
	var ratio: float = current / maximum if maximum > 0.0 else 0.0
	if ratio <= 0.0:
		_exhausted = true
	elif ratio >= recover_ratio:
		_exhausted = false
	_ratio = ratio
	queue_redraw()


func _process(delta: float) -> void:
	_since_full = _since_full + delta if _ratio >= 1.0 else 0.0
	var target_alpha: float = 0.0 if _since_full > hide_delay_s else 1.0
	modulate.a = move_toward(modulate.a, target_alpha, fade_speed * delta)


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(rect, back_color)
	var fill: Rect2 = Rect2(Vector2.ZERO, Vector2(size.x * _ratio, size.y))
	draw_rect(fill, exhausted_color if _exhausted else fill_color)
