class_name CharacterSelect
extends Control
## New Game: pick a class and a character on one screen. The chosen character stands on a
## lit stage in 3D, slowly turning, cycling through idle / attack / skill poses with the
## class weapon in hand (sword classes show the Mythic Starfall). Dragon heroes call their
## spirit dragon on the skill pose.

signal confirmed(class_id: StringName, hero_id: StringName)

const CLASSES: Array[StringName] = [&"vanguard", &"phantom", &"arcanist", &"ranger"]
const POSES: Array[StringName] = [&"idle", &"slash", &"victory", &"cast", &"run"]
const POSE_S: float = 2.6

var class_id: StringName = &"vanguard"
var hero_id: StringName = HeroData.DEFAULT_ID

var _stage: HeroStage
var _pose_i: int = 0
var _pose_t: float = 0.0
var _class_buttons: Dictionary[StringName, Button] = {}
var _hero_buttons: Dictionary[StringName, Button] = {}
var _info: Label
var _weapon_label: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = CodexTheme.make_theme()
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.07, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_stage = HeroStage.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.weapon_shown.connect(func(item: ItemData) -> void:
		_weapon_label.text = "%s — %s" % [item.display_name, tr(&"RARITY_5")] if item != null else "")
	add_child(_stage)
	_build_ui()
	_select_class(class_id)


func _process(delta: float) -> void:
	if _stage.model == null:
		return
	_pose_t += delta
	if _pose_t >= POSE_S:
		_pose_t = 0.0
		_pose_i = (_pose_i + 1) % POSES.size()
		_apply_pose()


func _apply_pose() -> void:
	var pose: StringName = POSES[_pose_i]
	_stage.model.forced_pose = pose
	if pose == &"cast" and _stage.model.has_dragon():
		_stage.model.summon_dragon(false)


func _rebuild_model() -> void:
	_stage.show_hero(hero_id, class_id, true)
	_pose_i = 0
	_pose_t = 0.0
	_apply_pose()


# --- UI ----------------------------------------------------------------------------------

func _build_ui() -> void:
	var title: Label = Label.new()
	title.text = tr(&"MENU_CREATE_TITLE")
	title.add_theme_font_size_override(&"font_size", CodexTheme.px(40))
	title.add_theme_color_override(&"font_color", CodexTheme.ACCENT)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.offset_top = 24
	title.offset_left = -400
	title.offset_right = 400
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var left: VBoxContainer = _column(Control.PRESET_LEFT_WIDE, 40, &"MENU_PICK_CLASS")
	for id: StringName in CLASSES:
		var data: ClassData = load("res://data/classes/%s.tres" % id) as ClassData
		var b: Button = _card_button(left, data.display_name)
		b.pressed.connect(_select_class.bind(id))
		_class_buttons[id] = b
	var right: VBoxContainer = _column(Control.PRESET_RIGHT_WIDE, -40, &"MENU_PICK_HERO")
	for id: StringName in HeroData.IDS:
		var hero: HeroData = HeroData.load_hero(id)
		var b2: Button = _card_button(right, tr(hero.display_name))
		b2.pressed.connect(_select_hero.bind(id))
		_hero_buttons[id] = b2
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override(&"font_size", CodexTheme.px(20))
	_info.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_info.offset_left = -430
	_info.offset_right = 430
	_info.offset_top = -210
	_info.offset_bottom = -120
	add_child(_info)
	_weapon_label = Label.new()
	_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_weapon_label.add_theme_color_override(&"font_color", ItemData.RARITY_COLORS[ItemData.Rarity.MYTHIC])
	_weapon_label.add_theme_font_size_override(&"font_size", CodexTheme.px(20))
	_weapon_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_weapon_label.offset_left = -430
	_weapon_label.offset_right = 430
	_weapon_label.offset_top = -245
	_weapon_label.offset_bottom = -212
	add_child(_weapon_label)
	var start: Button = Button.new()
	start.text = tr(&"MENU_START")
	start.custom_minimum_size = CodexTheme.button_size(320, 70)
	start.add_theme_font_size_override(&"font_size", CodexTheme.px(30))
	start.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	start.offset_left = -CodexTheme.px(160)
	start.offset_right = CodexTheme.px(160)
	start.offset_top = -CodexTheme.px(100)
	start.offset_bottom = -CodexTheme.px(28)
	start.pressed.connect(func() -> void: confirmed.emit(class_id, hero_id))
	add_child(start)
	start.grab_focus.call_deferred()


func _column(preset: Control.LayoutPreset, x: float, title_key: StringName) -> VBoxContainer:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", CodexTheme.px(10))
	box.set_anchors_and_offsets_preset(preset)
	var w: float = CodexTheme.px(360)
	if x > 0.0:
		box.offset_left = x
		box.offset_right = x + w
	else:
		box.offset_left = x - w
		box.offset_right = x
	box.offset_top = 140
	box.offset_bottom = -140
	var head: Label = Label.new()
	head.text = tr(title_key)
	head.add_theme_color_override(&"font_color", CodexTheme.ACCENT)
	head.add_theme_font_size_override(&"font_size", CodexTheme.px(26))
	box.add_child(head)
	add_child(box)
	return box


func _card_button(parent: Control, text: String) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(0, CodexTheme.px(70))
	b.add_theme_font_size_override(&"font_size", CodexTheme.px(26))
	parent.add_child(b)
	return b


func _select_class(id: StringName) -> void:
	class_id = id
	for k: StringName in _class_buttons:
		_class_buttons[k].button_pressed = k == id
	_refresh()


func _select_hero(id: StringName) -> void:
	hero_id = id
	_refresh()


func _refresh() -> void:
	for k: StringName in _hero_buttons:
		_hero_buttons[k].button_pressed = k == hero_id
	var data: ClassData = load("res://data/classes/%s.tres" % class_id) as ClassData
	var hero: HeroData = HeroData.load_hero(hero_id)
	_info.text = "%s\n%s" % [data.description, tr(hero.description)]
	_weapon_label.text = ""
	_rebuild_model()
