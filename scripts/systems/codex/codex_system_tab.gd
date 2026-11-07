class_name CodexSystemTab
extends VBoxContainer
## Codex → System: settings, save to / load from the 3 manual slots, load the autosave.


func _init() -> void:
	add_theme_constant_override(&"separation", 14)


func refresh() -> void:
	for child: Node in get_children():
		child.queue_free()
	var settings_button: Button = Button.new()
	settings_button.text = tr(&"MENU_SETTINGS")
	settings_button.custom_minimum_size = CodexTheme.button_size(300)
	settings_button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	settings_button.pressed.connect(func() -> void:
		var panel: SettingsPanel = get_tree().get_first_node_in_group(SettingsPanel.GROUP) as SettingsPanel
		if panel != null:
			panel.open())
	add_child(settings_button)
	for i: int in SaveManager.MANUAL_SLOTS.size():
		_add_row(SaveManager.MANUAL_SLOTS[i], tr(&"SAVE_SLOT") % (i + 1), true)
	_add_row(SaveManager.AUTOSAVE_SLOT, tr(&"SAVE_AUTOSAVE"), false)


func _add_row(slot: String, title: String, can_save: bool) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	var label: Label = Label.new()
	label.custom_minimum_size = Vector2(CodexTheme.px(600), 0)
	label.text = "%s   %s" % [title, describe(SaveManager.slot_info(slot))]
	row.add_child(label)
	if can_save:
		var save_button: Button = Button.new()
		save_button.text = tr(&"SAVE_SAVE")
		save_button.custom_minimum_size = CodexTheme.button_size(150)
		save_button.pressed.connect(func() -> void:
			SaveManager.save_slot(slot)
			refresh())
		row.add_child(save_button)
	var load_button: Button = Button.new()
	load_button.text = tr(&"SAVE_LOAD")
	load_button.custom_minimum_size = CodexTheme.button_size(150)
	load_button.disabled = not SaveManager.has_slot(slot)
	load_button.pressed.connect(func() -> void: SaveManager.load_slot(slot))
	row.add_child(load_button)
	add_child(row)


func describe(info: Dictionary) -> String:
	if info.is_empty():
		return tr(&"SAVE_EMPTY")
	var cls: String = info.get("class_id", "?")
	var level: int = info.get("level", 1)
	var playtime: float = info.get("playtime_s", 0.0)
	var minutes: int = floori(playtime / 60.0)
	var time_text: String = "%dh %02dm" % [floori(minutes / 60.0), minutes % 60]
	return tr(&"SAVE_INFO") % [cls.capitalize(), level, time_text]
