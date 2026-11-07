class_name CodexMapTab
extends VBoxContainer
## Codex → Map: the current region with fog of war and markers, the vague secret tracker,
## exploration per region and a legend.

var _header: Label
var _view: MapView
var _legend: Label


func _init() -> void:
	add_theme_constant_override(&"separation", 8)
	_header = Label.new()
	_header.add_theme_color_override(&"font_color", CodexTheme.ACCENT)
	add_child(_header)
	_view = MapView.new()
	_view.custom_minimum_size = Vector2(0, CodexTheme.px(560))
	_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_view)
	_legend = Label.new()
	_legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legend.modulate = Color(1, 1, 1, 0.75)
	add_child(_legend)


func refresh() -> void:
	var map: RegionMap = RegionMap.current(get_tree())
	if map == null:
		_header.text = tr(&"MAP_NO_REGION")
		return
	var region: RegionData = map.region
	var tracker: SecretTracker = SecretTracker.find(self)
	var prog: Vector4i = tracker.region_progress(region.id) if tracker != null else Vector4i.ZERO
	_header.text = tr(&"JOURNAL_TRACKER") % [tr(region.display_name), prog.x, prog.y, prog.z, prog.w] \
		+ "   ·   " + tr(&"MAP_EXPLORED") % roundi(map.explored_ratio() * 100.0)
	_legend.text = tr(&"MAP_LEGEND")
