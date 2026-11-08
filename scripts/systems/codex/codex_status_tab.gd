class_name CodexStatusTab
extends HBoxContainer
## Codex → Status: level, XP, primary stats with point allocation, derived stats,
## the hero on a 3D stage, and skills with skill-point level ups. Clicking a skill's
## icon previews it on the stage.

const STATS_ORDER: Array[StatBlock.Stat] = [StatBlock.Stat.STR, StatBlock.Stat.AGI,
	StatBlock.Stat.INT, StatBlock.Stat.VIT, StatBlock.Stat.SEN]

const STAT_KEYS: Dictionary[int, StringName] = {
	StatBlock.Stat.STR: &"STAT_STR_NAME", StatBlock.Stat.AGI: &"STAT_AGI_NAME", StatBlock.Stat.INT: &"STAT_INT_NAME",
	StatBlock.Stat.VIT: &"STAT_VIT_NAME", StatBlock.Stat.SEN: &"STAT_SEN_NAME",
}

var _left: VBoxContainer
var _header: VBoxContainer
var _job_box: VBoxContainer
var _stats_box: GridContainer
var _derived: GridContainer
var _skills_box: VBoxContainer
var _stage: HeroStage
## "hero:class:weapon" the stage was built for (rebuilt only when it changes).
var _stage_key: String = ""
var _refresh_queued: bool = false


func _init() -> void:
	add_theme_constant_override(&"separation", CodexTheme.px(20))
	_left = VBoxContainer.new()
	_left.custom_minimum_size = Vector2(CodexTheme.px(480), 0)
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.add_theme_constant_override(&"separation", CodexTheme.px(12))
	var left_scroll: ScrollContainer = PausingPanel.wrap_scroll(_left)
	left_scroll.custom_minimum_size.x = CodexTheme.px(500)
	left_scroll.size_flags_horizontal = Control.SIZE_FILL
	left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(left_scroll)
	_header = VBoxContainer.new()
	_left.add_child(_card(_header))
	_stats_box = GridContainer.new()
	_stats_box.columns = 4
	_stats_box.add_theme_constant_override(&"h_separation", CodexTheme.px(14))
	_stats_box.add_theme_constant_override(&"v_separation", CodexTheme.px(4))
	_left.add_child(_card(_titled(&"STATUS_STATS", _stats_box)))
	_derived = GridContainer.new()
	_derived.columns = 4
	_derived.add_theme_constant_override(&"h_separation", CodexTheme.px(18))
	_left.add_child(_card(_titled(&"STATUS_DERIVED", _derived)))
	_job_box = VBoxContainer.new()
	_left.add_child(_card(_job_box))
	# The hero in a framed "CHARACTER PROFILE" card (owner's reference).
	var profile: VBoxContainer = VBoxContainer.new()
	profile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	profile.size_flags_stretch_ratio = 0.8
	var caption: Label = _label(tr(&"STATUS_PROFILE").to_upper(), 18, CodexTheme.TRIM)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override(&"font", CodexTheme.SERIF)
	profile.add_child(caption)
	_stage = HeroStage.new()
	_stage.custom_minimum_size = Vector2(CodexTheme.px(400), CodexTheme.px(540))
	_stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var frame: PanelContainer = _card(_stage)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	profile.add_child(frame)
	add_child(profile)
	_stage.set_framing(5.6, 0.95)
	_skills_box = VBoxContainer.new()
	_skills_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_skills_box.add_theme_constant_override(&"separation", CodexTheme.px(8))
	var skills_scroll: ScrollContainer = PausingPanel.wrap_scroll(_skills_box)
	skills_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(skills_scroll)


static func _card(content: Control) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(CodexTheme.BG.r * 1.4, CodexTheme.BG.g * 1.4, CodexTheme.BG.b * 1.4, 0.78)
	style.border_color = Color(CodexTheme.TRIM, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(CodexTheme.px(12))
	card.add_theme_stylebox_override(&"panel", style)
	card.add_child(content)
	return card


func _titled(key: StringName, content: Control) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	var title: Label = _label(tr(key).to_upper(), 18, CodexTheme.TRIM)
	title.add_theme_font_override(&"font", CodexTheme.SERIF)
	box.add_child(title)
	box.add_child(content)
	return box


static func _label(text: String, size_px: int, color: Color = CodexTheme.TEXT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", CodexTheme.px(size_px))
	l.add_theme_color_override(&"font_color", color)
	return l


## Rebuilds once at the end of the frame, however many changes asked for it (a skill
## "+" used to rebuild the whole tab twice per click).
func refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_rebuild.call_deferred()


func refresh_now() -> void:
	_refresh_queued = true
	_rebuild()


func _rebuild() -> void:
	if not _refresh_queued or not is_inside_tree():
		_refresh_queued = false
		return
	_refresh_queued = false
	var player: Player = GameState.player as Player
	if player == null or GameState.progression == null:
		return
	var prog: Progression = GameState.progression
	var stats: StatsComponent = player.stats
	_fill_header(stats, prog)
	_fill_job(stats, prog)
	_fill_stats(stats, prog)
	_fill_derived(stats.derived)
	_fill_skills(stats, prog)
	_sync_stage(player)


func _sync_stage(player: Player) -> void:
	var weapon: ItemData = GameState.inventory.get_equipped_item(ItemData.Slot.WEAPON) if GameState.inventory != null else null
	var weapon_id: StringName = weapon.id if weapon != null else &""
	var key: String = "%s:%s:%s" % [GameState.hero_id, GameState.class_id, weapon_id]
	if key == _stage_key:
		return
	_stage_key = key
	_stage.show_hero(GameState.hero_id, GameState.class_id, weapon_id == HeroStage.MYTHIC_SWORD)
	_stage.model.rotation.y = player.visual.rotation.y + PI if player.visual != null else PI

func _fill_header(stats: StatsComponent, prog: Progression) -> void:
	_clear(_header)
	var top: HBoxContainer = HBoxContainer.new()
	var name_l: Label = _label(stats.class_data.display_name, 30, Color.WHITE)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(name_l)
	top.add_child(_label("%s %d" % [tr(&"STATUS_LEVEL"), prog.level], 30, CodexTheme.ACCENT))
	_header.add_child(top)
	var bar: ProgressBar = ProgressBar.new()
	bar.max_value = maxf(prog.xp_to_next(), 1.0)
	bar.value = prog.xp
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, CodexTheme.px(14))
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.05, 0.1)
	bg.set_corner_radius_all(3)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = CodexTheme.ACCENT
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override(&"background", bg)
	bar.add_theme_stylebox_override(&"fill", fill)
	_header.add_child(bar)
	_header.add_child(_label("XP %d / %d" % [prog.xp, prog.xp_to_next()], 16, Color(CodexTheme.TEXT, 0.7)))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", CodexTheme.px(24))
	for pair: Array in [[tr(&"STATUS_POINTS"), str(prog.free_points)], [tr(&"STATUS_SKILL_POINTS"), str(prog.skill_points)],
			[tr(&"STATUS_GUILD_RANK"), "%s (%d)" % [GuildRank.NAMES[GuildRank.current()], GameState.guild_points]],
			["Codex Point", str(GameState.codex_points)]]:
		var k: String = pair[0]
		var v: String = pair[1]
		var cell: HBoxContainer = HBoxContainer.new()
		cell.add_child(_label(k, 18, Color(CodexTheme.TEXT, 0.7)))
		cell.add_child(_label(v, 18, Color.WHITE))
		grid.add_child(cell)
	_header.add_child(grid)


## Current job + Job Change offers (§8). Hidden jobs only appear once their mission is done.
func _fill_job(stats: StatsComponent, prog: Progression) -> void:
	_clear(_job_box)
	var current: JobData = stats.current_job()
	var label: Label = Label.new()
	label.text = tr(&"JOB_LABEL") % (current.display_name if current != null else tr(&"JOB_NONE"))
	label.add_theme_color_override(&"font_color", CodexTheme.ACCENT)
	_job_box.add_child(label)
	var offers: Array[JobData] = JobRegistry.options(stats.class_data.id, GameState.job_id, prog.level, GameState.has_flag)
	if offers.is_empty():
		return
	var title: Label = Label.new()
	title.text = tr(&"JOB_CHANGE_TITLE")
	_job_box.add_child(title)
	for job: JobData in offers:
		var button: Button = Button.new()
		var trial: bool = JobTrial.needs_trial(job)
		button.text = tr(&"JOB_TRIAL_START" if trial else &"JOB_CHANGE_TO") % job.display_name
		button.tooltip_text = job.description + ("\n" + tr(&"JOB_TRIAL_HINT") if trial else "")
		button.custom_minimum_size = CodexTheme.button_size(300, 56)
		button.pressed.connect(_on_job_pressed.bind(stats, job))
		_job_box.add_child(button)


func _on_job_pressed(stats: StatsComponent, job: JobData) -> void:
	if JobTrial.needs_trial(job):
		if GameState.gate_session != null:
			Codex.notify(tr(&"JOB_TRIAL_NOT_IN_GATE"), &"warning")
			return
		var panel: CodexPanel = get_tree().get_first_node_in_group(CodexPanel.GROUP) as CodexPanel
		if panel != null:
			panel.close()
		Codex.notify(tr(&"JOB_TRIAL_BEGIN") % job.display_name, &"anomaly")
		JobTrial.start(get_tree(), stats.player, job)
		return
	if stats.change_job(job.id):
		Codex.notify(tr(&"JOB_CHANGED") % job.display_name, &"reward")
		AudioManager.play_ui(&"level_up")
	refresh()


func _fill_stats(stats: StatsComponent, prog: Progression) -> void:
	_clear(_stats_box)
	for stat: StatBlock.Stat in STATS_ORDER:
		_stats_box.add_child(_label(StatBlock.NAMES[stat], 22, CodexTheme.ACCENT))
		var name_l: Label = _label(tr(STAT_KEYS[stat]), 16, Color(CodexTheme.TEXT, 0.65))
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_stats_box.add_child(name_l)
		var value: Label = _label(str(roundi(stats.primary.get_stat(stat))), 24, Color.WHITE)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size = Vector2(CodexTheme.px(60), 0)
		_stats_box.add_child(value)
		_stats_box.add_child(_plus_button(prog.free_points <= 0, func() -> void:
			stats.allocate(stat)
			refresh()))


func _fill_derived(d: DerivedStats) -> void:
	_clear(_derived)
	var rows: Array[Array] = [
		["HP", str(d.max_hp)], ["MP", str(d.max_mp)],
		["ATK", "%.0f" % d.attack], ["M.ATK", "%.0f" % d.magic_attack],
		["DEF", "%.0f" % d.defense], ["CRIT", "%.1f%%" % (d.crit_chance * 100.0)],
		["CRIT DMG", "%.0f%%" % (d.crit_damage * 100.0)], ["ASPD", "%.2f" % d.attack_speed],
		["MSPD", "%.2f" % d.move_speed], ["CDR", "%.0f%%" % (d.cooldown_reduction * 100.0)],
	]
	for row: Array in rows:
		var k: String = row[0]
		var v: String = row[1]
		_derived.add_child(_label(k, 17, Color(CodexTheme.TEXT, 0.65)))
		var value: Label = _label(v, 19, Color.WHITE)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.custom_minimum_size = Vector2(CodexTheme.px(70), 0)
		_derived.add_child(value)


func _fill_skills(stats: StatsComponent, prog: Progression) -> void:
	_clear(_skills_box)
	var head: HBoxContainer = HBoxContainer.new()
	var title: Label = _label(tr(&"STATUS_SKILLS"), 26, CodexTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_label("%s %d" % [tr(&"STATUS_SKILL_POINTS"), prog.skill_points], 20, Color.WHITE))
	_skills_box.add_child(head)
	for skill: SkillData in stats.all_skills():
		_skills_box.add_child(_skill_row(stats, prog, skill))


func _skill_row(stats: StatsComponent, prog: Progression, skill: SkillData) -> Control:
	var level: int = GameState.skill_levels.get(skill.id, 0)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", CodexTheme.px(12))
	row.add_child(_skill_icon(skill))
	var text: VBoxContainer = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override(&"separation", 0)
	var tag: String = " · ULT" if skill.is_ultimate else (" · " + tr(&"STATUS_PASSIVE") if skill.is_passive() else "")
	text.add_child(_label(skill.display_name + tag, 21, Color.WHITE if level > 0 else Color(1, 1, 1, 0.45)))
	if level <= 0:
		text.add_child(_label(tr(&"STATUS_LOCKED") % skill.unlock_level, 16, Color(1, 1, 1, 0.45)))
	else:
		var meta: String = "Lv %d/%d" % [level, skill.max_level]
		if not skill.is_passive():
			meta += "   ·   MP %d   ·   CD %.0fs" % [stats.mp_cost(skill), skill.cooldown_s]
		text.add_child(_label(meta, 16, CodexTheme.ACCENT))
		var desc: Label = _label(skill.description, 16, Color(CodexTheme.TEXT, 0.7))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(desc)
	row.add_child(text)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_child(_plus_button(level <= 0 or level >= skill.max_level or prog.skill_points <= 0, func() -> void:
		stats.level_up_skill(skill.id)
		refresh()))
	if level > 0 and not skill.is_passive():
		_add_slot_buttons(buttons, stats, skill)
	row.add_child(buttons)
	return _card(row)


## Skill icon = preview button (▶ plays the skill on the stage).
func _skill_icon(skill: SkillData) -> Button:
	var icon: Button = Button.new()
	icon.custom_minimum_size = Vector2(CodexTheme.px(56), CodexTheme.px(56))
	var tex: Texture2D = SkillIcons.icon_for(skill)
	if tex != null:
		icon.icon = tex
		icon.expand_icon = true
		icon.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		icon.text = skill.display_name.substr(0, 2).to_upper()
	icon.tooltip_text = tr(&"STATUS_PREVIEW")
	icon.add_theme_font_size_override(&"font_size", CodexTheme.px(20))
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var st: StyleBoxFlat = StyleBoxFlat.new()
		st.bg_color = skill.icon_color.darkened(0.35 if state == &"normal" else 0.15)
		st.border_color = skill.icon_color.lightened(0.2) if state == &"normal" else Color.WHITE
		st.set_border_width_all(2)
		st.set_corner_radius_all(6)
		icon.add_theme_stylebox_override(state, st)
	icon.pressed.connect(func() -> void: _stage.preview_skill(skill))
	var play: Label = _label("▶", 13, Color(1, 1, 1, 0.85))
	play.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	play.offset_left = -CodexTheme.px(16)
	play.offset_top = -CodexTheme.px(18)
	icon.add_child(play)
	return icon


## Buttons that put an active skill into a slot (1–4, or U for ultimates).
func _add_slot_buttons(row: HBoxContainer, stats: StatsComponent, skill: SkillData) -> void:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(CodexTheme.px(8), 0)
	row.add_child(spacer)
	var slots: Array[int] = [0, 1, 2, 3]
	if skill.is_ultimate:
		slots = [GameState.ULTIMATE_SLOT]
	for slot: int in slots:
		var button: Button = Button.new()
		button.text = "U" if slot == GameState.ULTIMATE_SLOT else str(slot + 1)
		button.toggle_mode = true
		button.button_pressed = slot < GameState.skill_slots.size() and GameState.skill_slots[slot] == skill.id
		button.tooltip_text = tr(&"SKILL_SLOT_BUTTON") % (slot + 1)
		button.custom_minimum_size = CodexTheme.button_size(46, 50)
		button.pressed.connect(func() -> void:
			stats.assign_slot(skill.id, slot)
			refresh())
		row.add_child(button)


static func _plus_button(disabled: bool, on_press: Callable) -> Button:
	var plus: Button = Button.new()
	plus.text = "+"
	plus.custom_minimum_size = CodexTheme.button_size(50, 50)
	plus.disabled = disabled
	plus.pressed.connect(on_press)
	return plus


static func _clear(box: Node) -> void:
	for child: Node in box.get_children():
		child.queue_free()
