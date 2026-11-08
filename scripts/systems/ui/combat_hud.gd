extends Control
## Combo counter + rank, perfect-dodge and down notices.

const NOTICE_S: float = 1.2
const RANK_COLORS: Dictionary[int, Color] = {
	ComboTracker.Rank.D: Color(0.7, 0.75, 0.85), ComboTracker.Rank.C: Color(0.5, 0.85, 1.0),
	ComboTracker.Rank.B: Color(0.45, 1.0, 0.6), ComboTracker.Rank.A: Color(1.0, 0.85, 0.3),
	ComboTracker.Rank.S: Color(1.0, 0.5, 0.25), ComboTracker.Rank.SSS: Color(1.0, 0.3, 0.7),
}

@onready var _count: Label = %ComboCount
@onready var _rank: Label = %ComboRank
@onready var _notice: Label = %Notice
@onready var _level: Label = %LevelLabel

var _notice_tween: Tween


func _ready() -> void:
	EventBus.combo_changed.connect(_on_combo)
	EventBus.perfect_dodge.connect(func() -> void: _show_notice(tr(&"HUD_PERFECT_DODGE"), Color(0.5, 0.9, 1.0)))
	EventBus.player_died.connect(func() -> void: _show_notice(tr(&"HUD_DOWN"), Color(1.0, 0.35, 0.35)))
	EventBus.level_up.connect(func(new_level: int) -> void:
		_show_notice("%s  Lv %d" % [tr(&"HUD_LEVEL_UP"), new_level], Color(1.0, 0.85, 0.35)))
	EventBus.skill_combo_triggered.connect(func(combo_name: String) -> void:
		_show_notice(combo_name.to_upper(), Color(0.75, 0.5, 1.0)))
	EventBus.player_stats_changed.connect(_refresh_level)
	_on_combo(0, ComboTracker.Rank.NONE)
	_notice.modulate.a = 0.0
	_refresh_level.call_deferred()
	_add_frame.call_deferred()


## Portrait frame behind the HP / MP bars (drawn first, so the bars sit on top).
func _add_frame() -> void:
	var frame: PlayerFrame = PlayerFrame.new()
	frame.name = "PlayerFrame"
	get_parent().add_child(frame)
	get_parent().move_child(frame, 0)


func _refresh_level() -> void:
	if GameState.progression != null:
		_level.text = "Lv %d" % GameState.progression.level


func _on_combo(count: int, rank: int) -> void:
	_count.visible = count > 1
	_rank.visible = count > 1
	_count.text = "%d %s" % [count, tr(&"HUD_HITS")]
	_rank.text = ComboTracker.RANK_NAMES.get(rank as ComboTracker.Rank, "")
	_rank.modulate = RANK_COLORS.get(rank, Color.WHITE)
	if count > 1:
		_count.pivot_offset = _count.size * 0.5
		_count.scale = Vector2.ONE * 1.15
		create_tween().tween_property(_count, ^"scale", Vector2.ONE, 0.1)


func _show_notice(text: String, color: Color) -> void:
	_notice.text = text
	_notice.modulate = color
	if _notice_tween != null:
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_property(_notice, ^"modulate:a", 0.0, NOTICE_S).set_delay(0.4)
