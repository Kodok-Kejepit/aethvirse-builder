class_name EndingPanel
extends PausingPanel
## Vael's last question (MYSTERY_BIBLE §5.8) after The Unwritten falls, then the epilogue.
## Ending C needs Will ≥ 12 — this build uses secrets found as the stand-in for Will.
## Ending B needs the shadow resonance (20+ shadows bound).

const GROUP: StringName = &"ending_panel"
const WILL_NEEDED: int = 12
const RESONANCE_NEEDED: int = 20

var _box: VBoxContainer


func _init() -> void:
	title_key = &"ENDING_TITLE"
	requires_player = false


func _ready() -> void:
	add_to_group(GROUP)
	super._ready()


static func will() -> int:
	return GameState.secrets.found.size()


static func ending_for(choice: int) -> StringName:
	match choice:
		2:
			return &"b" if GameState.shadows.soldiers.size() >= RESONANCE_NEEDED else &"a"
		3:
			return &"c" if will() >= WILL_NEEDED else &"a"
	return &"a"


func _build_content(body: VBoxContainer) -> void:
	_box = VBoxContainer.new()
	_box.add_theme_constant_override(&"separation", 12)
	body.add_child(PausingPanel.wrap_scroll(_box))


func _on_open() -> void:
	_show_question()


func _clear() -> void:
	for c: Node in _box.get_children():
		c.queue_free()


func _line(text: String, size: int = 26) -> void:
	var l: Label = Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override(&"font_size", CodexTheme.px(size))
	_box.add_child(l)


func _show_question() -> void:
	_clear()
	_line(tr(&"ENDING_VAEL_ASKS"), 32)
	for i: int in 4:
		var b: Button = Button.new()
		b.text = tr(StringName("ENDING_CHOICE_%d" % (i + 1)))
		b.custom_minimum_size = CodexTheme.button_size(700, 60)
		if i == 3 and will() < WILL_NEEDED:
			b.text = "~~" + b.text + "~~  " + tr(&"ENDING_GLITCH")
			b.disabled = true
		b.pressed.connect(_choose.bind(i))
		_box.add_child(b)


func _choose(choice: int) -> void:
	var ending: StringName = ending_for(choice)
	GameState.set_flag(StringName("ending_" + String(ending)))
	GameState.set_flag(&"ending_seen")
	_clear()
	_line(tr(StringName("ENDING_%s_TITLE" % String(ending).to_upper())), 34)
	_line(tr(StringName("ENDING_%s_TEXT" % String(ending).to_upper())))
	# Story: the known world ends here; the last seal waits beyond the map, at [ ??? ].
	_line(tr(&"ENDING_LAST_SEAL"))
	var back: Button = Button.new()
	back.text = tr(&"ENDING_RETURN")
	back.custom_minimum_size = CodexTheme.button_size(420, 60)
	back.pressed.connect(func() -> void:
		close()
		WorldTravel.travel(get_tree(), &"r1_camp"))
	_box.add_child(back)
	SaveManager.autosave()


## Watches for The Unwritten's fall in the Hollow Throne and opens the question once.
static func watch(node: Node) -> void:
	if GameState.has_flag(&"unwritten_defeated") and not GameState.has_flag(&"ending_seen"):
		var panel: EndingPanel = node.get_tree().get_first_node_in_group(GROUP) as EndingPanel
		if panel == null:
			panel = EndingPanel.new()
			node.get_tree().current_scene.add_child(panel)
		if not panel.is_open():
			panel.open()
