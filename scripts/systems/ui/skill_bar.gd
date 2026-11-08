extends Control
## Bottom skill bar: 4 skills + ultimate with cooldown sweep, MP availability and key hints.

const SLOT_SIZE: float = 84.0
const GAP: float = 14.0
const KEY_HINTS: Array[String] = ["1", "2", "3", "4", "T"]
const COOLDOWN_SHADE: Color = Color(0, 0, 0, 0.6)
const EMPTY_COLOR: Color = Color(0.15, 0.17, 0.22, 0.6)
const NO_MP_TINT: Color = Color(0.4, 0.5, 1.0, 1.0)
const BORDER: Color = Color(0.6, 0.85, 1.0, 0.8)
const ULT_BORDER: Color = Color(1.0, 0.85, 0.35, 1.0)


func _ready() -> void:
	visible = not Settings.wants_touch_controls()


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var player: Player = GameState.player as Player
	if player == null or not is_instance_valid(player):
		return
	var font: Font = ThemeDB.fallback_font
	for slot: int in GameState.SLOT_COUNT:
		var x: float = slot * (SLOT_SIZE + GAP) + (GAP * 2.0 if slot == GameState.ULTIMATE_SLOT else 0.0)
		var rect: Rect2 = Rect2(Vector2(x, 0.0), Vector2(SLOT_SIZE, SLOT_SIZE))
		var skill: SkillData = player.skills.get_slot_skill(slot)
		_draw_slot(rect, skill, player, font, slot)


func _draw_slot(rect: Rect2, skill: SkillData, player: Player, font: Font, slot: int) -> void:
	if skill == null or GameState.skill_levels.get(skill.id, 0) <= 0:
		draw_rect(rect, EMPTY_COLOR)
		draw_string(font, rect.position + Vector2(6, rect.size.y - 8), KEY_HINTS[slot], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		return
	var color: Color = skill.icon_color
	if not player.mana.can_pay(player.stats.mp_cost(skill)):
		color = color * NO_MP_TINT
	var icon: Texture2D = SkillIcons.icon_for(skill)
	if icon != null:
		var dim: Color = Color.WHITE if color == skill.icon_color else Color(0.55, 0.6, 1.0)
		draw_texture_rect(icon, rect, false, dim)
	else:
		draw_rect(rect, Color(color, 0.85))
		var initials: String = "".join(Array(skill.display_name.split(" ")).map(func(w: String) -> String: return w.left(1)))
		draw_string(font, rect.position + Vector2(0, rect.size.y * 0.6), initials, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 30)
	var ratio: float = player.skills.get_cooldown_ratio(skill)
	if ratio > 0.0:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * ratio)), COOLDOWN_SHADE)
		var remaining: float = player.skills.get_cooldown_remaining(skill)
		draw_string(font, rect.position + Vector2(0, rect.size.y * 0.95), "%.0f" % ceilf(remaining), HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 24)
	if icon == null:
		draw_rect(rect, ULT_BORDER if skill.is_ultimate else BORDER, false, 2.0)
	draw_string(font, rect.position + Vector2(6, 20), KEY_HINTS[slot], HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
