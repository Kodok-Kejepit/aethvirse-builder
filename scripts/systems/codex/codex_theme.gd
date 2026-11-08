class_name CodexTheme
extends RefCounted
## Shared "System" look for Codex UI: an elegant card (owner's reference) themed by the
## hero — jade glass with gold trim for dragon heroes, violet glass with silver trim for
## shadow heroes. Titles use a serif face. Colours follow the current hero (sync_hero).

static var BG: Color = Color(0.02, 0.08, 0.06, 0.94)
static var ACCENT: Color = Color(0.52, 0.92, 0.74)
static var TEXT: Color = Color(0.94, 0.91, 0.82)
## Frame lines, titles, ornaments.
static var TRIM: Color = Color(0.9, 0.76, 0.45)
static var dragon_style: bool = true
const SERIF: FontFile = preload("res://assets/ui/fonts/NotoSerif-SemiBold.ttf")
const SERIF_REGULAR: FontFile = preload("res://assets/ui/fonts/NotoSerif-Regular.ttf")


## Picks the palette of the hero being played (call before building UI).
static func sync_hero() -> void:
	var hero: HeroData = HeroData.load_hero(GameState.hero_id)
	dragon_style = hero == null or hero.has_dragon
	if dragon_style:
		BG = Color(0.02, 0.08, 0.06, 0.94)
		ACCENT = Color(0.52, 0.92, 0.74)
		TEXT = Color(0.94, 0.91, 0.82)
		TRIM = Color(0.9, 0.76, 0.45)
	else:
		BG = Color(0.05, 0.03, 0.09, 0.94)
		ACCENT = Color(0.74, 0.55, 1.0)
		TEXT = Color(0.92, 0.9, 0.98)
		TRIM = Color(0.82, 0.84, 0.92)
## Phones show the 1080p canvas on a ~3" tall screen: text and buttons need to be bigger.
const TOUCH_SCALE: float = 1.45


static func ui_scale() -> float:
	var settings: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null(^"Settings")
	if settings != null and settings.call(&"wants_touch_controls"):
		return TOUCH_SCALE
	return 1.0


## Scales a design-time pixel size (font, padding) for the current device.
static func px(value: float) -> int:
	return roundi(value * ui_scale())


static func button_size(width: float, height: float = 50.0) -> Vector2:
	return Vector2(px(width), px(height))


## A card: dark glass with a thin trim line (gold / silver) and a soft glow.
static func panel_style(accent: Color = Color(0, 0, 0, 0)) -> StyleBoxFlat:
	var line: Color = TRIM if accent.a == 0.0 else accent
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(BG.r * 1.3, BG.g * 1.3, BG.b * 1.3, 0.72)
	style.border_color = Color(line, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(14)
	style.shadow_color = Color(line, 0.12)
	style.shadow_size = 6
	return style


static func _tab_style(selected: bool) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = Color(TRIM, 0.16) if selected else Color(0, 0, 0, 0)
	s.border_color = TRIM
	s.border_width_bottom = 2 if selected else 0
	s.content_margin_left = px(16)
	s.content_margin_right = px(16)
	s.content_margin_top = px(8)
	s.content_margin_bottom = px(8)
	return s


static func make_theme() -> Theme:
	sync_hero()
	var theme: Theme = Theme.new()
	theme.default_font = SERIF_REGULAR
	theme.set_stylebox(&"panel", &"PanelContainer", panel_style())
	theme.set_color(&"font_color", &"Label", TEXT)
	theme.set_font_size(&"font_size", &"Label", px(22))
	var button: StyleBoxFlat = panel_style()
	button.set_content_margin_all(px(8))
	button.border_width_left = 2
	theme.set_stylebox(&"normal", &"Button", button)
	var hover: StyleBoxFlat = button.duplicate() as StyleBoxFlat
	hover.bg_color = Color(TRIM, 0.18)
	theme.set_stylebox(&"hover", &"Button", hover)
	var pressed: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(TRIM, 0.32)
	pressed.border_color = TRIM
	theme.set_stylebox(&"pressed", &"Button", pressed)
	var disabled: StyleBoxFlat = button.duplicate() as StyleBoxFlat
	disabled.border_color = Color(TRIM, 0.25)
	theme.set_stylebox(&"disabled", &"Button", disabled)
	theme.set_color(&"font_color", &"Button", TEXT)
	theme.set_font_size(&"font_size", &"Button", px(22))
	var tab_panel: StyleBoxFlat = panel_style()
	tab_panel.bg_color = Color(0, 0, 0, 0)
	tab_panel.border_color = Color(TRIM, 0.35)
	theme.set_stylebox(&"panel", &"TabContainer", tab_panel)
	theme.set_stylebox(&"tab_selected", &"TabContainer", _tab_style(true))
	theme.set_stylebox(&"tab_unselected", &"TabContainer", _tab_style(false))
	theme.set_stylebox(&"tab_hovered", &"TabContainer", _tab_style(false))
	theme.set_font(&"font", &"TabContainer", SERIF)
	theme.set_font_size(&"font_size", &"TabContainer", px(22))
	theme.set_color(&"font_selected_color", &"TabContainer", TRIM)
	theme.set_color(&"font_unselected_color", &"TabContainer", Color(TEXT, 0.6))
	theme.set_color(&"font_hovered_color", &"TabContainer", TEXT)
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(ACCENT, 0.25)
	track.content_margin_top = px(4)
	track.content_margin_bottom = px(4)
	theme.set_stylebox(&"slider", &"HSlider", track)
	var fill: StyleBoxFlat = track.duplicate() as StyleBoxFlat
	fill.bg_color = ACCENT
	theme.set_stylebox(&"grabber_area", &"HSlider", fill)
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	return theme
