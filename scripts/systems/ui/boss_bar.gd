extends Control
## Big boss HP bar with name, level and title (§6). Hidden when no boss is engaged.

const BAR_HEIGHT: float = 22.0
const FILL: Color = Color(0.85, 0.15, 0.25)
const BACK: Color = Color(0.05, 0.05, 0.1, 0.85)

var _name: String = ""
var _ratio: float = 1.0


func _ready() -> void:
	visible = false
	EventBus.boss_started.connect(func(boss: Node3D) -> void:
		var enemy: Enemy = boss as Enemy
		_name = String(boss.name)
		if enemy != null:
			_name = "%s  Lv %d" % [enemy.data.display_name, enemy.data.level]
		_ratio = 1.0
		visible = true
		queue_redraw())
	EventBus.boss_health_changed.connect(func(current: int, maximum: int) -> void:
		_ratio = float(current) / float(maximum) if maximum > 0 else 0.0
		queue_redraw())
	EventBus.boss_ended.connect(func(_boss: Node3D, _defeated: bool) -> void: visible = false)


func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(0, 26), _name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 28)
	var bar: Rect2 = Rect2(Vector2(0, 36), Vector2(size.x, BAR_HEIGHT))
	draw_rect(bar, BACK)
	draw_rect(Rect2(bar.position, Vector2(size.x * _ratio, BAR_HEIGHT)), FILL)
	for t: float in BossPhases.THRESHOLDS:
		draw_line(Vector2(size.x * t, bar.position.y), Vector2(size.x * t, bar.end.y), Color(1, 1, 1, 0.5), 2.0)
