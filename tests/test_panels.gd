extends GutTest
## Codex / Inventory windows: split tabs, one window at a time, pause restored.

var codex: CodexPanel
var bag: InventoryPanel
var fake_player: Node3D


func before_each() -> void:
	fake_player = Node3D.new()
	add_child_autofree(fake_player)
	GameState.player = fake_player
	codex = CodexPanel.new()
	bag = InventoryPanel.new()
	add_child_autofree(codex)
	add_child_autofree(bag)
	get_tree().paused = false


func after_each() -> void:
	codex.close()
	bag.close()
	get_tree().paused = false
	GameState.player = null


func test_codex_has_no_inventory_or_shadow_tab() -> void:
	assert_false(codex.has_tab(&"CODEX_TAB_INVENTORY"), "inventory has its own window")
	assert_false(codex.has_tab(&"CODEX_TAB_SHADOWS"), "shadow army only for the shadow job line")
	assert_true(codex.has_tab(&"CODEX_TAB_STATUS"))


func test_only_one_window_open_and_pause_restored() -> void:
	bag.open()
	assert_true(bag.is_open())
	assert_true(get_tree().paused)
	codex.open()
	assert_true(codex.is_open())
	assert_false(bag.is_open(), "opening the Codex closes the bag")
	codex.close()
	assert_false(get_tree().paused, "closing restores the state from before the first window")


func test_select_inventory_tab_opens_bag() -> void:
	codex.select_tab(&"CODEX_TAB_INVENTORY")
	assert_true(bag.is_open())
