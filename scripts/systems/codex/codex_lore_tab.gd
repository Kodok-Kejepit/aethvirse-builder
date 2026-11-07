class_name CodexLoreTab
extends VBoxContainer
## Codex → Lore: collected lore fragments.


func _init() -> void:
	add_theme_constant_override(&"separation", 12)


func refresh() -> void:
	for child: Node in get_children():
		child.queue_free()
	var tracker: SecretTracker = SecretTracker.find(self) if is_inside_tree() else null
	if tracker == null or GameState.secrets.lore.is_empty():
		_add(tr(&"LORE_EMPTY"), 22, Color(1, 1, 1, 0.6))
		return
	for id: StringName in GameState.secrets.lore:
		var lore: LoreData = tracker.db.lore.get(id, null)
		if lore == null:
			continue
		_add("%s  ·  %s" % [id, tr(lore.title)], 24, CodexTheme.ACCENT)
		_add(tr(lore.text), 20, CodexTheme.TEXT)


func _add(text: String, font_size: int, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", CodexTheme.px(font_size))
	label.add_theme_color_override(&"font_color", color)
	add_child(label)
