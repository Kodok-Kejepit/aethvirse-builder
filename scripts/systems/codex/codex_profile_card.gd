class_name CodexProfileCard
extends RefCounted
## Codex → Status header in the owner's "SYSTEM NOTIFICATION / CHARACTER PROFILE" style
## (reference cards for the assassin and the mage): name, level, HP and MP bars, STR / AGI /
## INT with a word rating, class and a class status. Colours follow CodexTheme (per hero).

const HP_COLOR: Color = Color(0.82, 0.2, 0.2)
const MP_SHADOW: Color = Color(0.55, 0.35, 0.95)
const MP_LIGHT: Color = Color(0.25, 0.55, 1.0)
const RATED: Array[StatBlock.Stat] = [StatBlock.Stat.STR, StatBlock.Stat.AGI, StatBlock.Stat.INT]
## Signature state of each class (shown as STATUS).
const STATUS_KEYS: Dictionary[StringName, StringName] = {
	&"vanguard": &"PROFILE_STATUS_VANGUARD", &"phantom": &"PROFILE_STATUS_PHANTOM",
	&"arcanist": &"PROFILE_STATUS_ARCANIST", &"ranger": &"PROFILE_STATUS_RANGER",
}


static func build(box: VBoxContainer, player: Player, stats: StatsComponent, level: int) -> void:
	var notice: Label = _label(tr_key(&"PROFILE_NOTICE"), 15, CodexTheme.TRIM)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(notice)
	var title: Label = _label(tr_key(&"PROFILE_TITLE"), 30, CodexTheme.TRIM)
	title.add_theme_font_override(&"font", CodexTheme.SERIF)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(HSeparator.new())
	var hero: HeroData = HeroData.load_hero(GameState.hero_id)
	box.add_child(_label(tr_key(&"PROFILE_NAME") % tr_key(StringName(hero.display_name)).to_upper(), 22, Color.WHITE))
	box.add_child(_label("Lv %d" % level, 20, CodexTheme.ACCENT))
	box.add_child(_bar("HP", player.health.current, player.health.max_health, HP_COLOR))
	var mp_color: Color = MP_SHADOW if hero.codex_style == &"violet" else MP_LIGHT
	box.add_child(_bar("MP", roundi(player.mana.current), roundi(player.mana.max_mana), mp_color))
	box.add_child(_ratings(stats))
	box.add_child(HSeparator.new())
	box.add_child(_label(tr_key(&"PROFILE_CLASS") % stats.class_data.display_name.to_upper(), 20, Color.WHITE))
	var status_key: StringName = STATUS_KEYS.get(GameState.class_id, &"PROFILE_STATUS_VANGUARD")
	box.add_child(_label(tr_key(&"PROFILE_STATUS") % tr_key(status_key), 20, CodexTheme.ACCENT))


static func tr_key(key: StringName) -> String:
	return TranslationServer.translate(key)


## "Rendah / Sedang / Tinggi / Sangat Tinggi" from a stat's share of the hero's best stat.
static func rating_key(value: float, best: float) -> StringName:
	var share: float = value / maxf(best, 1.0)
	if share >= 0.9:
		return &"RATING_TOP"
	if share >= 0.7:
		return &"RATING_HIGH"
	if share >= 0.45:
		return &"RATING_MID"
	return &"RATING_LOW"


static func _ratings(stats: StatsComponent) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", CodexTheme.px(26))
	var best: float = 0.0
	for stat: StatBlock.Stat in RATED:
		best = maxf(best, stats.primary.get_stat(stat))
	for stat: StatBlock.Stat in RATED:
		var value: float = stats.primary.get_stat(stat)
		var cell: VBoxContainer = VBoxContainer.new()
		cell.add_child(_label(StatBlock.NAMES[stat], 16, CodexTheme.TRIM))
		cell.add_child(_label("%s  %d" % [tr_key(rating_key(value, best)), roundi(value)], 18, Color.WHITE))
		row.add_child(cell)
	return row


static func _bar(caption: String, value: int, maximum: int, color: Color) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", CodexTheme.px(10))
	var name_l: Label = _label(caption, 18, CodexTheme.TRIM)
	name_l.custom_minimum_size = Vector2(CodexTheme.px(42), 0)
	row.add_child(name_l)
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = maxf(float(maximum), 1.0)
	bar.value = value
	bar.show_percentage = false
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.custom_minimum_size = Vector2(0, CodexTheme.px(14))
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.03, 0.02, 0.04)
	bg.border_color = CodexTheme.TRIM.darkened(0.3)
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(6)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(6)
	bar.add_theme_stylebox_override(&"background", bg)
	bar.add_theme_stylebox_override(&"fill", fill)
	row.add_child(bar)
	var num: Label = _label("%d / %d" % [value, maximum], 16, Color.WHITE)
	num.custom_minimum_size = Vector2(CodexTheme.px(110), 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(num)
	return row


static func _label(text: String, size_px: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", CodexTheme.px(size_px))
	l.add_theme_color_override(&"font_color", color)
	return l
