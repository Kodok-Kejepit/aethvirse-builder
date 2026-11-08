class_name CodexQuestTab
extends VBoxContainer
## Codex → Seals: every mission is one of the Codex's seals (owner's story: breaking a
## seal opens a page). Active missions with their current objective, then the broken ones.


func _init() -> void:
	add_theme_constant_override(&"separation", 10)


func refresh() -> void:
	for child: Node in get_children():
		child.queue_free()
	var system: QuestSystem = QuestSystem.find(self) if is_inside_tree() else null
	if system == null:
		return
	var log_state: QuestLog = GameState.quests
	_add(tr(&"QUESTS_PAGES") % log_state.completed.size(), 20, Color(0.95, 0.8, 0.5))
	if log_state.active.is_empty() and log_state.completed.is_empty():
		_add(tr(&"QUESTS_NONE"), 22, Color(1, 1, 1, 0.6))
	if not log_state.active.is_empty():
		_add(tr(&"QUESTS_ACTIVE"), 26, CodexTheme.ACCENT)
	for id: StringName in log_state.active:
		var q: QuestData = system.quests.get(id, null)
		if q == null:
			continue
		_add(tr(q.title), 24, Color(0.5, 1.0, 0.7))
		_add("   " + tr(q.description), 20, CodexTheme.TEXT)
		_add("   • " + system.objective_text(q).replace("\n", "\n   "), 22, Color(1.0, 0.9, 0.5))
	if not log_state.completed.is_empty():
		_add(tr(&"QUESTS_DONE"), 26, CodexTheme.ACCENT)
	for id: StringName in log_state.completed:
		var q: QuestData = system.quests.get(id, null)
		if q != null:
			_add("✓ " + tr(q.title), 22, Color(1, 1, 1, 0.6))


func _add(text: String, font_size: int, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", CodexTheme.px(font_size))
	label.add_theme_color_override(&"font_color", color)
	add_child(label)
