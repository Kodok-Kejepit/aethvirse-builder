class_name CodexJournalTab
extends VBoxContainer
## Codex → Mystery Journal: vague region tracker, discovered clues (no answers), own notes.

var _notes: TextEdit


func _init() -> void:
	add_theme_constant_override(&"separation", 10)


func refresh() -> void:
	for child: Node in get_children():
		if child != _notes:
			child.queue_free()
	var tracker: SecretTracker = SecretTracker.find(self) if is_inside_tree() else null
	if tracker == null:
		return
	for region: RegionData in tracker.db.regions.values():
		var p: Vector4i = tracker.region_progress(region.id)
		_add_label(tr(&"JOURNAL_TRACKER") % [tr(region.display_name), p.x, p.y, p.z, p.w], 26, CodexTheme.ACCENT)
	var state: SecretState = GameState.secrets
	if state.hints.is_empty():
		_add_label(tr(&"JOURNAL_NO_HINTS"), 22, Color(1, 1, 1, 0.6))
	for secret_id: StringName in state.hints:
		var secret: SecretData = tracker.db.get_secret(secret_id)
		var solved: bool = tracker.is_found(secret_id)
		var title: String = tr(secret.display_name) + "  " + tr(&"JOURNAL_SOLVED") if solved and secret != null else tr(&"JOURNAL_UNKNOWN")
		_add_label(title, 24, Color(0.8, 0.6, 1.0))
		var list: Array = state.hints[secret_id]
		for hint: StringName in list:
			_add_label("   • " + tr(hint), 20, CodexTheme.TEXT)
	_add_label(tr(&"JOURNAL_NOTES"), 24, CodexTheme.ACCENT)
	if _notes == null:
		_notes = TextEdit.new()
		_notes.custom_minimum_size = Vector2(0, 160)
		_notes.text_changed.connect(func() -> void: GameState.secrets.notes = _notes.text)
		add_child(_notes)
	_notes.text = state.notes
	move_child(_notes, get_child_count() - 1)


func _add_label(text: String, font_size: int, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", CodexTheme.px(font_size))
	label.add_theme_color_override(&"font_color", color)
	add_child(label)
