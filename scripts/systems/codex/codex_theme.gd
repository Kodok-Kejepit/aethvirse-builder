class_name CodexTheme
extends RefCounted
## Shared "System" look for Codex UI (Big Phase 1 placeholder: translucent blue hologram panels).

const BG: Color = Color(0.03, 0.08, 0.16, 0.88)
const ACCENT: Color = Color(0.45, 0.8, 1.0)
const TEXT: Color = Color(0.82, 0.93, 1.0)
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


static func panel_style(accent: Color = ACCENT) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = BG
	style.border_color = accent
	style.set_border_width_all(2)
	style.border_width_left = 6
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	style.shadow_color = Color(accent, 0.25)
	style.shadow_size = 8
	return style


static func make_theme() -> Theme:
	var theme: Theme = Theme.new()
	theme.set_stylebox(&"panel", &"PanelContainer", panel_style())
	theme.set_color(&"font_color", &"Label", TEXT)
	theme.set_font_size(&"font_size", &"Label", px(22))
	var button: StyleBoxFlat = panel_style()
	button.set_content_margin_all(px(8))
	button.border_width_left = 2
	theme.set_stylebox(&"normal", &"Button", button)
	var hover: StyleBoxFlat = button.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.08, 0.2, 0.35, 0.95)
	theme.set_stylebox(&"hover", &"Button", hover)
	var pressed: StyleBoxFlat = hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.12, 0.32, 0.55, 0.98)
	pressed.border_color = Color.WHITE
	theme.set_stylebox(&"pressed", &"Button", pressed)
	var disabled: StyleBoxFlat = button.duplicate() as StyleBoxFlat
	disabled.border_color = Color(ACCENT, 0.3)
	theme.set_stylebox(&"disabled", &"Button", disabled)
	theme.set_color(&"font_color", &"Button", TEXT)
	theme.set_font_size(&"font_size", &"Button", px(22))
	theme.set_stylebox(&"panel", &"TabContainer", panel_style())
	theme.set_font_size(&"font_size", &"TabContainer", px(24))
	theme.set_color(&"font_selected_color", &"TabContainer", ACCENT)
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
