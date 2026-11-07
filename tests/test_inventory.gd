extends GutTest

var db: ItemDatabase = ItemDatabase.new()
var inv: Inventory


func before_each() -> void:
	inv = Inventory.new(db)


func test_database_loads_items() -> void:
	for id: StringName in [&"rusty_pipe", &"bread", &"rusted_license", &"gravedigger_fang", &"issued_greatsword"]:
		assert_not_null(db.get_item(id), String(id))


func test_stacking() -> void:
	assert_eq(inv.add(&"bread", 25), 0)
	assert_eq(inv.count_of(&"bread"), 25)
	assert_eq(inv.stacks.size(), 2, "max stack 20 → 2 stacks")
	assert_true(inv.remove(&"bread", 22))
	assert_eq(inv.count_of(&"bread"), 3)
	assert_false(inv.remove(&"bread", 10))


func test_unknown_item_is_rejected() -> void:
	assert_eq(inv.add(&"does_not_exist", 2), 2)


func test_equip_and_unequip() -> void:
	inv.add(&"issued_greatsword")
	assert_true(inv.equip(inv.first_stack(&"issued_greatsword")))
	assert_eq(inv.get_equipped_item(ItemData.Slot.WEAPON).id, &"issued_greatsword")
	inv.add(&"rusty_pipe")
	assert_true(inv.equip(inv.first_stack(&"rusty_pipe")), "swapping returns the old weapon to the bag")
	assert_eq(inv.count_of(&"issued_greatsword"), 1)
	assert_true(inv.unequip(ItemData.Slot.WEAPON))


func test_cursed_cannot_be_removed() -> void:
	inv.add(&"gravedigger_fang")
	inv.equip(inv.first_stack(&"gravedigger_fang"))
	assert_false(inv.unequip(ItemData.Slot.WEAPON))
	inv.force_unequip(ItemData.Slot.WEAPON)
	assert_null(inv.get_equipped(ItemData.Slot.WEAPON))


func test_unidentified_names() -> void:
	inv.add(&"rusted_license")
	var stack: ItemStack = inv.first_stack(&"rusted_license")
	assert_false(stack.identified)
	assert_eq(inv.display_name(stack), "??? License")
	inv.identify(stack, &"appraiser")
	assert_string_contains(inv.display_name(stack), "Marrow Kessick")


func test_codex_identification_deletes_data() -> void:
	inv.add(&"rusted_license")
	var stack: ItemStack = inv.first_stack(&"rusted_license")
	inv.identify(stack, &"codex")
	assert_string_contains(inv.display_name(stack), "DATA DELETED")


func test_evolution_transform() -> void:
	inv.add(&"rusty_pipe")
	var stack: ItemStack = inv.first_stack(&"rusty_pipe")
	stack.kills = 299
	inv.transform(stack, &"fanged_pipe")
	assert_eq(stack.item_id, &"fanged_pipe")
	assert_eq(stack.kills, 0)


func test_save_roundtrip() -> void:
	inv.add(&"bread", 4)
	inv.add(&"rusted_license")
	inv.identify(inv.first_stack(&"rusted_license"), &"appraiser")
	inv.add(&"issued_greatsword")
	inv.equip(inv.first_stack(&"issued_greatsword"))
	var data: Dictionary = JSON.parse_string(JSON.stringify(inv.to_dict()))
	var copy: Inventory = Inventory.new(db)
	copy.load_dict(data)
	assert_eq(copy.count_of(&"bread"), 4)
	assert_eq(copy.first_stack(&"rusted_license").identified_by, &"appraiser")
	assert_eq(copy.get_equipped_item(ItemData.Slot.WEAPON).id, &"issued_greatsword")


func test_loot_table_roll() -> void:
	var table: LootTable = load("res://data/loot_tables/mystery_r1_patience.tres") as LootTable
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var drops: Array[Dictionary] = table.roll(rng)
	assert_eq(drops.size(), 2, "1 item + gold")
	for drop: Dictionary in drops:
		var id: StringName = drop["id"]
		assert_true(id == &"gold" or db.has(id), String(id))


func test_all_item_data_valid() -> void:
	for id: StringName in db.all_ids():
		var item: ItemData = db.get_item(id)
		assert_ne(item.display_name, "", String(id))
		assert_gt(item.max_stack, 0, String(id))
		if item.evolves_into != &"":
			assert_true(db.has(item.evolves_into), "%s evolves into a real item" % id)
