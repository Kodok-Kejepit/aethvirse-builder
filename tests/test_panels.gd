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


func test_codex_holds_the_inventory_but_no_shadow_tab() -> void:
	assert_true(codex.has_tab(&"CODEX_TAB_INVENTORY"), "owner: the inventory lives in the Codex")
	assert_false(codex.has_tab(&"CODEX_TAB_SHADOWS"), "shadow army only for the shadow job line")
	assert_true(codex.has_tab(&"CODEX_TAB_STATUS"))


func test_inventory_key_opens_the_codex_on_the_inventory() -> void:
	bag.open()
	assert_true(codex.is_open())
	assert_eq(codex._tabs.current_tab, codex._tab_index(&"CODEX_TAB_INVENTORY"))
	assert_true(get_tree().paused)
	bag.open()
	assert_false(codex.is_open(), "the same key closes it again")
	assert_false(get_tree().paused, "pause restored")


func test_map_shortcut_opens_the_map_tab() -> void:
	codex.open_on(&"CODEX_TAB_MAP")
	assert_true(codex.is_open())
	assert_eq(codex._tabs.current_tab, codex._tab_index(&"CODEX_TAB_MAP"))
	codex.open_on(&"CODEX_TAB_STATUS")
	assert_true(codex.is_open(), "another tab keeps it open")
	assert_eq(codex._tabs.current_tab, codex._tab_index(&"CODEX_TAB_STATUS"))
