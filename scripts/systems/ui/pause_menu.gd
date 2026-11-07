class_name PauseMenu
extends PausingPanel
## Esc / P / Start (and the ⏸ touch button): resume, save or load one of 3 slots,
## settings, back to title, quit (PC).

const GROUP: StringName = &"pause_menu"
const TITLE_SCENE: String = "res://scenes/main/boot.tscn"

var _box: VBoxContainer
var _others_open: bool = false


func _init() -> void:
	toggle_action = &"pause_menu"
	title_key = &"PAUSE_TITLE"


func _ready() -> void:
	add_to_group(GROUP)
	super._ready()


## Esc also closes other panels: only toggle the pause menu when none was open.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed(toggle_action) and not is_open() and _others_open:
		_others_open = _any_other_open()
		return
	super._process(delta)
	_others_open = _any_other_open()


func _any_other_open() -> bool:
	for node: Node in get_tree().get_nodes_in_group(PausingPanel.PANEL_GROUP):
		var p: PausingPanel = node as PausingPanel
		if p != null and p != self and p.is_open():
			return true
	return false


func _build_content(body: VBoxContainer) -> void:
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 10)
	body.add_child(PausingPanel.wrap_scroll(_box))


func _on_open() -> void:
	_show_main()


func _clear() -> void:
	for c: Node in _box.get_children():
		c.queue_free()


func _button(text_key: StringName, action: Callable, text_override: String = "") -> Button:
	var b: Button = Button.new()
	b.text = text_override if text_override != "" else tr(text_key)
	b.custom_minimum_size = CodexTheme.button_size(520, 64)
	b.pressed.connect(action)
	_box.add_child(b)
	return b


func _show_main() -> void:
	_clear()
	_button(&"PAUSE_RESUME", close).grab_focus.call_deferred()
	_button(&"PAUSE_SAVE", _show_slots.bind(true))
	_button(&"PAUSE_LOAD", _show_slots.bind(false))
	_button(&"MENU_SETTINGS", _open_settings)
	_button(&"PAUSE_TITLE_SCREEN", _to_title)
	if not OS.has_feature("mobile"):
		_button(&"PAUSE_QUIT", func() -> void: get_tree().quit())


func _show_slots(saving: bool) -> void:
	_clear()
	var head: Label = Label.new()
	head.text = tr(&"PAUSE_SAVE" if saving else &"PAUSE_LOAD")
	head.add_theme_color_override(&"font_color", CodexTheme.ACCENT)
	_box.add_child(head)
	var slots: Array[String] = SaveManager.MANUAL_SLOTS.duplicate()
	if not saving:
		slots.append(SaveManager.AUTOSAVE_SLOT)
	for slot: String in slots:
		var label: String = slot_label(slot, SaveManager.slot_info(slot))
		var b: Button = _button(&"", _use_slot.bind(slot, saving), label)
		b.disabled = not saving and SaveManager.slot_info(slot).is_empty()
	_button(&"PAUSE_BACK", _show_main)


static func slot_label(slot: String, info: Dictionary) -> String:
	var name_key: StringName = &"PAUSE_SLOT_AUTO" if slot == SaveManager.AUTOSAVE_SLOT else StringName("PAUSE_SLOT_%s" % slot.trim_prefix("slot_"))
	var title: String = TranslationServer.translate(name_key)
	if info.is_empty():
		return "%s — %s" % [title, TranslationServer.translate(&"PAUSE_SLOT_EMPTY")]
	var cls: String = info.get("class_id", "")
	var level: int = info.get("level", 1)
	var played: float = info.get("playtime_s", 0.0)
	var saved_at: float = info.get("saved_at", 0.0)
	var when: String = Time.get_datetime_string_from_unix_time(int(saved_at), true)
	return "%s — %s Lv %d · %dh%02dm · %s" % [title, cls.capitalize(), level, int(played / 3600.0), int(fmod(played / 60.0, 60.0)), when]


func _use_slot(slot: String, saving: bool) -> void:
	if saving:
		SaveManager.save_slot(slot)
		_show_slots(true)
		return
	close()
	if SaveManager.load_slot(slot) != OK:
		Codex.notify(tr(&"CODEX_MSG_LOAD_FAILED"), &"warning")


func _open_settings() -> void:
	var panel: SettingsPanel = get_tree().get_first_node_in_group(SettingsPanel.GROUP) as SettingsPanel
	if panel != null:
		panel.open()


func _to_title() -> void:
	SaveManager.autosave()
	close()
	get_tree().paused = false
	GameState.gate_session = null
	get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)
