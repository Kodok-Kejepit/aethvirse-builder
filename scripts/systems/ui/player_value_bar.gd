extends Control
## Player HP / MP / XP bar with a trailing "recent loss" segment.

enum Source { HEALTH, MANA, XP }

@export var source: Source = Source.HEALTH
@export var fill_color: Color = Color(0.35, 0.85, 0.55, 0.95)
@export var low_color: Color = Color(0.95, 0.3, 0.3, 0.95)
@export var trail_color: Color = Color(1.0, 0.85, 0.4, 0.8)
@export var back_color: Color = Color(0.05, 0.1, 0.2, 0.7)
@export_range(0.0, 1.0) var low_ratio: float = 0.3
@export var trail_speed: float = 0.6

var _ratio: float = 1.0
var _trail: float = 1.0


func _ready() -> void:
	match source:
		Source.HEALTH:
			EventBus.player_health_changed.connect(func(c: int, m: int) -> void: _set_ratio(float(c), float(m)))
		Source.MANA:
			EventBus.player_mana_changed.connect(_set_ratio)
		Source.XP:
			low_ratio = -1.0
			_ratio = 0.0
			_trail = 0.0
			EventBus.xp_gained.connect(func(_a: int) -> void: _refresh_xp.call_deferred())
			EventBus.player_stats_changed.connect(_refresh_xp)
			_refresh_xp.call_deferred()


func _refresh_xp() -> void:
	var prog: Progression = GameState.progression
	if prog != null:
		_set_ratio(float(prog.xp), float(maxi(prog.xp_to_next(), 1)))


func _set_ratio(current: float, maximum: float) -> void:
	_ratio = current / maximum if maximum > 0.0 else 0.0
	if _ratio > _trail or source == Source.XP:
		_trail = _ratio
	queue_redraw()


func _process(delta: float) -> void:
	if _trail > _ratio:
		_trail = maxf(_trail - trail_speed * delta, _ratio)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), back_color)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _trail, size.y)), trail_color)
	draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * _ratio, size.y)), low_color if _ratio <= low_ratio else fill_color)
