class_name Prologue
extends Control
## New game prologue "The Weakest": a few text pages on black, one at a time. Tap / any
## key shows the next page; Skip ends it. Emits `finished` once.

signal finished

const PAGES: Array[StringName] = [&"PROLOGUE_1", &"PROLOGUE_2", &"PROLOGUE_3", &"PROLOGUE_4"]
const FADE_S: float = 0.7
## A page stays at least this long before a tap moves on (no accidental double skips).
const MIN_PAGE_S: float = 0.6
const GOLD: Color = Color(0.95, 0.8, 0.5)

var page: int = -1
var _text: Label = null
var _title: Label = null
var _shown_at: float = 0.0
var _done: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg: ColorRect = ColorRect.new()
	bg.color = Color(0.015, 0.02, 0.04)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_title = _label(CodexTheme.SERIF, 22, GOLD)
	_title.text = tr(&"PROLOGUE_TITLE")
	add_child(_title)
	_title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_title.offset_top = CodexTheme.px(60)
	_text = _label(CodexTheme.SERIF_REGULAR, 30, Color(0.92, 0.9, 0.85))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_text)
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text.offset_left = CodexTheme.px(120)
	_text.offset_right = -CodexTheme.px(120)
	var skip: Button = Button.new()
	skip.text = tr(&"PROLOGUE_SKIP")
	skip.flat = true
	skip.add_theme_color_override(&"font_color", GOLD.darkened(0.2))
	skip.add_theme_font_size_override(&"font_size", CodexTheme.px(22))
	skip.pressed.connect(finish)
	add_child(skip)
	skip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, CodexTheme.px(36))
	next_page()


func _label(font: Font, size_px: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override(&"font", font)
	l.add_theme_font_size_override(&"font_size", CodexTheme.px(size_px))
	l.add_theme_color_override(&"font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func next_page() -> void:
	if _done:
		return
	page += 1
	if page >= PAGES.size():
		finish()
		return
	_shown_at = Time.get_ticks_msec() / 1000.0
	_text.text = tr(PAGES[page])
	_text.modulate.a = 0.0
	create_tween().tween_property(_text, ^"modulate:a", 1.0, FADE_S)


func finish() -> void:
	if _done:
		return
	_done = true
	var tween: Tween = create_tween()
	tween.tween_property(self, ^"modulate:a", 0.0, FADE_S)
	tween.tween_callback(func() -> void:
		finished.emit()
		queue_free())


func _gui_input(event: InputEvent) -> void:
	_advance_on(event)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey or event is InputEventJoypadButton:
		_advance_on(event)


func _advance_on(event: InputEvent) -> void:
	var press: bool = (event is InputEventMouseButton or event is InputEventScreenTouch \
		or event is InputEventKey or event is InputEventJoypadButton) and event.is_pressed() and not event.is_echo()
	if press and Time.get_ticks_msec() / 1000.0 - _shown_at >= MIN_PAGE_S:
		get_viewport().set_input_as_handled()
		next_page()
