class_name CodexShadowTab
extends VBoxContainer
## Codex → Shadow Army (shadow job line only): bound soldiers, slots, release.


func _init() -> void:
	add_theme_constant_override(&"separation", 10)


func refresh() -> void:
	for child: Node in get_children():
		child.queue_free()
	var level: int = GameState.progression.level if GameState.progression != null else 1
	var army: ShadowArmy = GameState.shadows
	var header: Label = Label.new()
	header.text = tr(&"SHADOW_HEADER") % [army.soldiers.size(), ShadowArmy.slots_for_level(level)]
	header.add_theme_font_size_override(&"font_size", CodexTheme.px(26))
	header.add_theme_color_override(&"font_color", CodexTheme.ACCENT)
	add_child(header)
	if army.soldiers.is_empty():
		var empty: Label = Label.new()
		empty.text = tr(&"SHADOW_EMPTY")
		empty.modulate = Color(1, 1, 1, 0.6)
		add_child(empty)
		return
	for i: int in army.soldiers.size():
		var s: Dictionary = army.soldiers[i]
		var tier: int = s["tier"]
		var soldier_name: String = s["name"]
		var soldier_level: int = s["level"]
		var soldier_rank: int = s.get("rank", 0)
		var xp: int = s.get("xp", 0)
		var next_xp: int = ShadowArmy.RANK_XP[mini(soldier_rank + 1, ShadowArmy.RANK_XP.size() - 1)]
		var row: HBoxContainer = HBoxContainer.new()
		var label: Label = Label.new()
		var xp_text: String = "MAX" if soldier_rank >= ShadowArmy.RANK_MARSHAL else "%d/%d" % [xp, next_xp]
		label.text = "%s  ·  %s  ·  %s  ·  Lv %d  ·  XP %s" % [soldier_name, tr(StringName("SHADOW_RANK_%d" % soldier_rank)),
			tr(StringName("SHADOW_TIER_%d" % clampi(tier, 0, 2))), soldier_level, xp_text]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var release: Button = Button.new()
		release.text = tr(&"SHADOW_RELEASE")
		release.custom_minimum_size = CodexTheme.button_size(160)
		release.pressed.connect(func() -> void:
			army.release(i)
			refresh())
		row.add_child(release)
		add_child(row)
