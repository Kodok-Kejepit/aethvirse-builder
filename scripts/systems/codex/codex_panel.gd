class_name CodexPanel
extends PausingPanel
## The Codex (C / Select / ☰): tabbed "System" window — status & stat points, inventory,
## quests, journal, lore, log, map, system (owner: everything the System keeps lives here).
## I opens it on the inventory, M on the map. Tabs for systems that do not exist yet are
## shown sealed; the Shadow Army tab only exists for the shadow job line.

const SEALED_TABS: Array[StringName] = [&"CODEX_TAB_ACHIEVEMENTS"]
const GROUP: StringName = &"codex_panel"

var _tabs: TabContainer
var _status: CodexStatusTab
var _log: RichTextLabel
var _system: CodexSystemTab
var _journal: CodexJournalTab
var _quests: CodexQuestTab
var _lore: CodexLoreTab
var _shadows: CodexShadowTab
var _map: CodexMapTab
var _inventory: CodexInventoryTab
var _map_was_down: bool = false


func _init() -> void:
	toggle_action = &"codex"
	title_key = &"CODEX_TITLE"


func _ready() -> void:
	add_to_group(GROUP)
	super._ready()
	EventBus.player_stats_changed.connect(func() -> void:
		if is_open():
			_status.refresh()
			_inventory.refresh())


func _process(delta: float) -> void:
	super._process(delta)
	# M: straight to the map (again to close).
	var down: bool = Input.is_action_pressed(&"map")
	if down and not _map_was_down:
		open_on(&"CODEX_TAB_MAP")
	_map_was_down = down


## Opens on a tab, or closes when already showing it.
func open_on(key: StringName) -> void:
	if is_open() and _tab_index(key) == _tabs.current_tab:
		close()
		return
	open()
	select_tab(key)


func _on_open() -> void:
	_status.refresh()
	_inventory.refresh()
	_refresh_log()
	_system.refresh()
	_journal.refresh()
	_quests.refresh()
	_lore.refresh()
	_map.refresh()
	_refresh_shadow_tab()


## The Shadow Army tab only exists for the shadow job line (Necromancer → Shadow Sovereign).
func _refresh_shadow_tab() -> void:
	var index: int = _tab_index(&"CODEX_TAB_SHADOWS")
	var shown: bool = JobRegistry.has_shadow_army(GameState.job_id)
	_tabs.set_tab_hidden(index, not shown)
	if shown:
		_shadows.refresh()
	elif _tabs.current_tab == index:
		_tabs.current_tab = 0

func select_tab(key: StringName) -> void:
	var index: int = _tab_index(key)
	if index != -1 and not _tabs.is_tab_hidden(index):
		_tabs.current_tab = index


func has_tab(key: StringName) -> bool:
	var index: int = _tab_index(key)
	return index != -1 and not _tabs.is_tab_hidden(index)


func _tab_index(key: StringName) -> int:
	for i: int in _tabs.get_tab_count():
		if _tabs.get_tab_title(i) == tr(key):
			return i
	return -1


func _build_content(body: VBoxContainer) -> void:
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_tabs)
	_status = CodexStatusTab.new()
	_add_tab(_status, &"CODEX_TAB_STATUS")
	_inventory = CodexInventoryTab.new()
	_add_tab(_inventory, &"CODEX_TAB_INVENTORY")
	_quests = CodexQuestTab.new()
	_add_tab(_quests, &"CODEX_TAB_QUESTS")
	_journal = CodexJournalTab.new()
	_add_tab(_journal, &"CODEX_TAB_JOURNAL")
	_lore = CodexLoreTab.new()
	_add_tab(_lore, &"CODEX_TAB_LORE")
	_log = RichTextLabel.new()
	_log.scroll_following = true
	_log.add_theme_font_size_override(&"normal_font_size", CodexTheme.px(22))
	_add_tab(_log, &"CODEX_TAB_LOG")
	_map = CodexMapTab.new()
	_add_tab(_map, &"CODEX_TAB_MAP")
	_shadows = CodexShadowTab.new()
	_add_tab(_shadows, &"CODEX_TAB_SHADOWS")
	_tabs.set_tab_hidden(_tabs.get_tab_count() - 1, true)
	for key: StringName in SEALED_TABS:
		var sealed: Label = Label.new()
		sealed.text = tr(&"CODEX_SEALED")
		sealed.modulate = Color(1, 1, 1, 0.6)
		_add_tab(sealed, key)
	_system = CodexSystemTab.new()
	_add_tab(_system, &"CODEX_TAB_SYSTEM")


func _add_tab(control: Control, key: StringName) -> void:
	# The Status tab scrolls its own columns (the hero stage stays put in the middle).
	if control is CodexStatusTab:
		control.name = String(key)
		_tabs.add_child(control)
		_tabs.set_tab_title(_tabs.get_tab_count() - 1, tr(key))
		return
	var scroll: ScrollContainer = PausingPanel.wrap_scroll(control)
	scroll.name = String(key)
	_tabs.add_child(scroll)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, tr(key))


func _refresh_log() -> void:
	_log.clear()
	if Codex.history.is_empty():
		_log.append_text(tr(&"CODEX_LOG_EMPTY"))
		return
	for i: int in range(Codex.history.size() - 1, -1, -1):
		var entry: Dictionary = Codex.history[i]
		var time_s: float = entry["time"]
		var text: String = entry["text"]
		var total: int = int(time_s)
		_log.append_text("[%02d:%02d]  %s\n" % [floori(total / 60.0), total % 60, text])
