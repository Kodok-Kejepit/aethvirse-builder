class_name JournalCompletion
extends CanvasLayer
## A region's Mystery Journal page is complete: the Codex says so, rewrites itself
## ("system update" overlay) and carries the Vanguard to the next region, whose page the
## journal then shows. Runs once per region (flag RegionJournal.flag_for).

const NOTICE_DELAY_S: float = 2.5
const UPDATE_S: float = 3.5
const GOLD: Color = Color(0.95, 0.8, 0.5)

var region_id: StringName = &""
var _bar: ProgressBar = null
var _line: Label = null


## Called after a secret is found. Starts the sequence if `region` just became complete.
static func check(tracker: SecretTracker, region: StringName) -> bool:
	if region == &"" or GameState.has_flag(RegionJournal.flag_for(region)):
		return false
	if not RegionJournal.is_complete(tracker.db, region, tracker.state()):
		return false
	GameState.set_flag(RegionJournal.flag_for(region))
	var node: JournalCompletion = JournalCompletion.new()
	node.region_id = region
	# Lives under the tracker (the region scene): the travel at the end replaces both.
	tracker.add_child(node)
	return true


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var region: RegionData = RegionData.load_region(region_id)
	Codex.notify(tr(&"JOURNAL_PAGE_DONE") % tr(region.display_name if region != null else &""), &"secret")
	AudioManager.play_ui(&"ding")
	await get_tree().create_timer(NOTICE_DELAY_S).timeout
	_show_update()
	var tween: Tween = create_tween()
	tween.tween_property(_bar, ^"value", 100.0, UPDATE_S)
	await tween.finished
	var next: StringName = RegionJournal.next_region(region_id)
	if next == &"":
		_line.text = tr(&"JOURNAL_ALL_DONE")
		await get_tree().create_timer(NOTICE_DELAY_S).timeout
		queue_free()
		return
	_line.text = tr(&"SYSTEM_UPDATE_DONE")
	await get_tree().create_timer(1.0).timeout
	var entry: StringName = RegionJournal.entry_waystone(next)
	WorldTravel.unlock(entry)
	WorldTravel.travel(get_tree(), entry)
	queue_free()


func _show_update() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", CodexTheme.panel_style(GOLD))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(CodexTheme.px(620), CodexTheme.px(150))
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", CodexTheme.px(12))
	panel.add_child(box)
	var title: Label = Label.new()
	title.text = tr(&"SYSTEM_UPDATE_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override(&"font", CodexTheme.SERIF)
	title.add_theme_font_size_override(&"font_size", CodexTheme.px(30))
	title.add_theme_color_override(&"font_color", GOLD)
	box.add_child(title)
	_line = Label.new()
	_line.text = tr(&"SYSTEM_UPDATE_LINE")
	_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line.add_theme_font_size_override(&"font_size", CodexTheme.px(20))
	box.add_child(_line)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, CodexTheme.px(10))
	box.add_child(_bar)
