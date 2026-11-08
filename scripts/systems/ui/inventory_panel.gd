class_name InventoryPanel
extends PausingPanel
## The I key (Back / bag button): the inventory now lives in the Codex (owner: everything
## the System keeps is in one place). This panel only listens for the key and opens the
## Codex on its Inventory tab (again to close).

const GROUP: StringName = &"inventory_panel"


func _init() -> void:
	toggle_action = &"inventory"
	title_key = &"CODEX_TAB_INVENTORY"


func _ready() -> void:
	add_to_group(GROUP)
	super._ready()


func toggle() -> void:
	open()


func open() -> void:
	var codex: CodexPanel = get_tree().get_first_node_in_group(CodexPanel.GROUP) as CodexPanel
	if codex != null:
		codex.open_on(&"CODEX_TAB_INVENTORY")
