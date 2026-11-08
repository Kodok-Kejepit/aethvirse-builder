class_name CodexJournalTab
extends VBoxContainer
## Codex → Mystery Journal: one page per region (RegionJournal). The page opens on the
## region being explored: a cryptic synopsis, how many of its records are uncovered, and
## each entry — resolved, only hinted, or still blank. Finished pages stay readable.
## Never says what finishing a page does: that is for the player to find out.

const GOLD: Color = Color(0.95, 0.8, 0.5)
const DIM: Color = Color(1, 1, 1, 0.45)
const HINTED: Color = Color(0.8, 0.6, 1.0)

var page: StringName = &""
var _notes: TextEdit


func _init() -> void:
	add_theme_constant_override(&"separation", 8)


func refresh() -> void:
	for child: Node in get_children():
		if child != _notes:
			child.queue_free()
	var tracker: SecretTracker = SecretTracker.find(self) if is_inside_tree() else null
	if tracker == null:
		return
	var current: StringName = RegionJournal.current_page()
	if page == &"" or RegionJournal.index_of(page) > RegionJournal.index_of(current):
		page = current
	_page_buttons(tracker, current)
	_page(tracker, page)
	_add_label(tr(&"JOURNAL_UNNAMED"), 24, Color(0.6, 0.55, 0.7))
	_add_label("   " + tr(&"JOURNAL_UNNAMED_NOTE"), 19, DIM)
	_add_label(tr(&"JOURNAL_NOTES"), 24, CodexTheme.ACCENT)
	if _notes == null:
		_notes = TextEdit.new()
		_notes.custom_minimum_size = Vector2(0, 160)
		_notes.text_changed.connect(func() -> void: GameState.secrets.notes = _notes.text)
		add_child(_notes)
	_notes.text = GameState.secrets.notes
	move_child(_notes, get_child_count() - 1)


## Finished pages and the open one; later regions are not listed (no spoilers).
func _page_buttons(tracker: SecretTracker, current: StringName) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", CodexTheme.px(8))
	add_child(row)
	for i: int in RegionJournal.index_of(current) + 1:
		var id: StringName = RegionData.IDS[i]
		var region: RegionData = tracker.db.regions.get(id, null)
		if region == null:
			continue
		var b: Button = Button.new()
		var done: bool = GameState.has_flag(RegionJournal.flag_for(id))
		b.text = tr(region.display_name) + ("  ✓" if done else "")
		b.toggle_mode = true
		b.button_pressed = id == page
		b.pressed.connect(_open_page.bind(id))
		row.add_child(b)


func _open_page(id: StringName) -> void:
	page = id
	refresh()


func _page(tracker: SecretTracker, region_id: StringName) -> void:
	var region: RegionData = tracker.db.regions.get(region_id, null)
	if region == null:
		return
	var state: SecretState = GameState.secrets
	_add_label(tr(&"JOURNAL_PAGE") % tr(region.display_name), 30, GOLD)
	_add_label(tr(StringName("JOURNAL_SYNOPSIS_" + String(region_id).to_upper())), 20, Color(0.92, 0.9, 0.85))
	var entries: Array[Dictionary] = RegionJournal.entries(tracker.db, region_id)
	var p: Vector2i = RegionJournal.progress(tracker.db, region_id, state)
	_add_label(tr(&"JOURNAL_UNCOVERED") % [p.x, p.y], 22, CodexTheme.ACCENT)
	_add_label(_breakdown(entries, state), 18, DIM)
	for kind: SecretData.Kind in RegionJournal.KINDS:
		for entry: Dictionary in entries:
			if entry["kind"] == kind:
				_entry(tracker, entry, state)


func _breakdown(entries: Array[Dictionary], state: SecretState) -> String:
	var parts: PackedStringArray = []
	for kind: SecretData.Kind in RegionJournal.KINDS:
		var done: int = 0
		var total: int = 0
		for entry: Dictionary in entries:
			if entry["kind"] != kind:
				continue
			total += 1
			if RegionJournal.is_resolved(entry, state.found, state.failed):
				done += 1
		if total > 0:
			parts.append("%s %d/%d" % [tr(RegionJournal.KIND_KEYS[kind]), done, total])
	return " · ".join(parts)


func _entry(tracker: SecretTracker, entry: Dictionary, state: SecretState) -> void:
	var list: Array[SecretData] = entry["secrets"]
	var first: SecretData = list[0]
	var hints: Array[StringName] = []
	for secret: SecretData in list:
		var seen: Array = state.hints.get(secret.id, [])
		for h: StringName in seen:
			if not hints.has(h):
				hints.append(h)
	if RegionJournal.is_lost(entry, state.failed):
		_add_label("✕ " + tr(first.display_name) + "  " + tr(&"JOURNAL_LOST"), 22, DIM)
	elif RegionJournal.is_resolved(entry, state.found, state.failed):
		_add_label("✦ " + tr(first.display_name), 22, GOLD)
	elif not hints.is_empty() or tracker.is_found(first.id):
		_add_label("◇ " + tr(&"JOURNAL_UNKNOWN"), 22, HINTED)
	else:
		_add_label("◇ — — —", 22, DIM)
	for h: StringName in hints:
		_add_label("      " + tr(h), 18, CodexTheme.TEXT)


func _add_label(text: String, font_size: int, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override(&"font_size", CodexTheme.px(font_size))
	label.add_theme_color_override(&"font_color", color)
	add_child(label)
