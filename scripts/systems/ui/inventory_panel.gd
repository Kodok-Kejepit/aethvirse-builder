class_name InventoryPanel
extends PausingPanel
## Bag window (I / Back / bag button): equipment, items, crafting. Split from the Codex so
## each window stays readable on phones.

const GROUP: StringName = &"inventory_panel"

var _inventory: CodexInventoryTab


func _init() -> void:
	toggle_action = &"inventory"
	title_key = &"CODEX_TAB_INVENTORY"


func _ready() -> void:
	add_to_group(GROUP)
	super._ready()
	EventBus.player_stats_changed.connect(func() -> void:
		if is_open():
			_inventory.refresh())


func _build_content(body: VBoxContainer) -> void:
	_inventory = CodexInventoryTab.new()
	var scroll: ScrollContainer = PausingPanel.wrap_scroll(_inventory)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)


func _on_open() -> void:
	_inventory.refresh()
