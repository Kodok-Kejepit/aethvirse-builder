class_name TouchActionButton
extends Control
## Round on-screen button that presses an input action while a finger is on it.

enum Glyph { JUMP, DODGE, ATTACK, HEAVY, LOCK, SKILL, STATUS, INTERACT, BAG, GEAR, PAUSE }

@export var action: StringName = &"jump"
## Also held while the finger stays (dash button: tap = dash, keep holding = sprint).
@export var extra_action: StringName = &""
@export var glyph: Glyph = Glyph.JUMP
@export var radius: float = 75.0
@export var fill_color: Color = Color(0.3, 0.6, 1.0, 0.22)
@export var pressed_color: Color = Color(0.45, 0.8, 1.0, 0.5)
@export var line_color: Color = Color(0.7, 0.9, 1.0, 0.85)
## For SKILL buttons: slot index (0–3, 4 = ultimate). Shows cooldown and skill color.
@export var skill_slot: int = -1
@export var label_text: String = ""
## Only visible (and pressable) while an interaction prompt is shown.
@export var contextual_interact: bool = false

var _touch_index: int = -1


func _ready() -> void:
	if contextual_interact:
		visible = false
		EventBus.interaction_prompt_changed.connect(func(text: String) -> void: visible = text != "")


func contains_point(point: Vector2) -> bool:
	var xform: Transform2D = get_global_transform()
	return point.distance_to(xform * (size * 0.5)) <= radius * xform.get_scale().x


## Called by MobileControls on touch start. Returns true if this button took the touch.
func try_press(index: int, point: Vector2) -> bool:
	if _touch_index != -1 or not is_visible_in_tree() or not contains_point(point):
		return false
	_touch_index = index
	Input.action_press(action)
	if extra_action != &"":
		Input.action_press(extra_action)
	queue_redraw()
	return true


func release(index: int) -> void:
	if index != _touch_index:
		return
	_touch_index = -1
	Input.action_release(action)
	if extra_action != &"":
		Input.action_release(extra_action)
	queue_redraw()


func _process(_delta: float) -> void:
	if skill_slot >= 0:
		queue_redraw()


func _draw() -> void:
	var center: Vector2 = size * 0.5
	if skill_slot >= 0:
		_draw_skill(center)
		return
	draw_circle(center, radius, pressed_color if _touch_index != -1 else fill_color)
	draw_arc(center, radius, 0.0, TAU, 64, line_color, 3.0, true)
	var s: float = radius * 0.32
	match glyph:
		Glyph.JUMP:
			_chevron(center + Vector2(0.0, s * 0.35), s)
		Glyph.DODGE:
			_chevron_right(center + Vector2(-s * 0.4, 0.0), s)
			_chevron_right(center + Vector2(s * 0.4, 0.0), s)
		Glyph.ATTACK:
			draw_line(center + Vector2(-s, s), center + Vector2(s, -s), line_color, 6.0, true)
		Glyph.HEAVY:
			draw_line(center + Vector2(-s, s), center + Vector2(s, -s), line_color, 10.0, true)
			draw_line(center + Vector2(-s * 0.5, -s * 0.2), center + Vector2(s * 0.2, s * 0.5), line_color, 6.0, true)
		Glyph.LOCK:
			draw_arc(center, s, 0.0, TAU, 32, line_color, 4.0, true)
			draw_circle(center, s * 0.25, line_color)
		Glyph.INTERACT:
			draw_circle(center, s * 0.35, line_color)
			draw_arc(center, s * 0.9, 0.0, TAU, 32, line_color, 3.0, true)
		Glyph.STATUS:
			for i: int in 3:
				var y: float = (float(i) - 1.0) * s * 0.7
				draw_line(center + Vector2(-s, y), center + Vector2(s, y), line_color, 4.0, true)
		Glyph.BAG:
			draw_rect(Rect2(center + Vector2(-s, -s * 0.4), Vector2(s * 2.0, s * 1.4)), line_color, false, 4.0)
			draw_arc(center + Vector2(0.0, -s * 0.4), s * 0.5, PI, TAU, 16, line_color, 4.0, true)
		Glyph.PAUSE:
			for dx: float in [-0.3, 0.3]:
				draw_line(center + Vector2(dx * s, -s * 0.55), center + Vector2(dx * s, s * 0.55), line_color, 7.0, true)
		Glyph.GEAR:
			draw_arc(center, s * 0.55, 0.0, TAU, 24, line_color, 4.0, true)
			for i: int in 8:
				var dir: Vector2 = Vector2.RIGHT.rotated(TAU * float(i) / 8.0)
				draw_line(center + dir * s * 0.6, center + dir * s, line_color, 5.0, true)


func _chevron(at: Vector2, s: float) -> void:
	draw_polyline(PackedVector2Array([at + Vector2(-s, 0.0), at + Vector2(0.0, -s), at + Vector2(s, 0.0)]), line_color, 5.0, true)


func _chevron_right(at: Vector2, s: float) -> void:
	draw_polyline(PackedVector2Array([at + Vector2(-s * 0.5, -s), at + Vector2(s * 0.5, 0.0), at + Vector2(-s * 0.5, s)]), line_color, 5.0, true)


func _draw_skill(center: Vector2) -> void:
	var player: Player = GameState.player as Player
	var skill: SkillData = player.skills.get_slot_skill(skill_slot) if player != null and is_instance_valid(player) else null
	var learned: bool = skill != null and GameState.skill_levels.get(skill.id, 0) > 0
	var base: Color = Color(skill.icon_color, 0.45) if learned else Color(0.2, 0.2, 0.25, 0.3)
	if learned and not player.mana.can_pay(player.stats.mp_cost(skill)):
		base = Color(0.25, 0.3, 0.6, 0.45)
	draw_circle(center, radius, pressed_color if _touch_index != -1 else base)
	if learned:
		var ratio: float = player.skills.get_cooldown_ratio(skill)
		if ratio > 0.0:
			draw_arc(center, radius * 0.5, -PI / 2.0, -PI / 2.0 + TAU * ratio, 32, Color(0, 0, 0, 0.6), radius, false)
	var ring: Color = Color(1.0, 0.85, 0.35, 0.9) if skill != null and skill.is_ultimate else line_color
	draw_arc(center, radius, 0.0, TAU, 48, ring, 3.0, true)
	var icon: Texture2D = SkillIcons.icon_for(skill) if learned else null
	if icon != null:
		var side: float = radius * 1.35
		draw_texture_rect(icon, Rect2(center - Vector2(side, side) * 0.5, Vector2(side, side)), false, Color(1, 1, 1, 0.95))
		return
	var text: String = label_text
	if learned:
		text = "".join(Array(skill.display_name.split(" ")).map(func(w: String) -> String: return w.left(1)))
	draw_string(ThemeDB.fallback_font, center + Vector2(-radius, 10.0), text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 28, line_color)
