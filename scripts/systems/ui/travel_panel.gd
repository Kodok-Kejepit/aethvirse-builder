class_name TravelPanel
extends PausingPanel
## Fast travel list (opened from a waystone): every unlocked waystone, grouped by region.

const GROUP: StringName = &"travel_panel"

var _list: VBoxContainer


func _init() -> void:
	title_key = &"TRAVEL_TITLE"


func _ready() -> void:
	add_to_group(GROUP)
	super._ready()


func _build_content(body: VBoxContainer) -> void:
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 8)
	body.add_child(PausingPanel.wrap_scroll(_list))


func _on_open() -> void:
	for child: Node in _list.get_children():
		child.queue_free()
	var last_region: StringName = &""
	for row: Array in WorldTravel.unlocked_list():
		var region: RegionData = row[0]
		var wid: StringName = row[1]
		if region.id != last_region:
			last_region = region.id
			var header: Label = Label.new()
			header.text = "%s  (Lv %d–%d)" % [tr(region.display_name), region.level_min, region.level_max]
			header.add_theme_font_size_override(&"font_size", CodexTheme.px(26))
			header.add_theme_color_override(&"font_color", CodexTheme.ACCENT)
			_list.add_child(header)
		var button: Button = Button.new()
		button.text = tr(Waystone.name_key(wid))
		button.custom_minimum_size = CodexTheme.button_size(420)
		button.pressed.connect(_go.bind(wid))
		_list.add_child(button)


func _go(waystone_id: StringName) -> void:
	close()
	WorldTravel.travel(get_tree(), waystone_id)
