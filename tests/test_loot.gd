extends GutTest
## M6: rarity rolls, generated equipment, mystery boxes, upgrade, economy actions.

const RULES: LootRules = preload("res://data/balancing/loot_rules.tres")

var db: ItemDatabase = ItemDatabase.new()
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var inv: Inventory


func before_each() -> void:
	rng.seed = 1234
	inv = Inventory.new(db)
	GameState.gold = 0


func test_sheet_values() -> void:
	assert_eq(RULES.upgrade_cost(1), 100)
	assert_eq(RULES.upgrade_cost(2), 135)
	assert_almost_eq(RULES.upgrade_chance(6), 0.9, 0.0001)
	assert_almost_eq(RULES.upgrade_chance(15), 0.1, 0.0001)
	assert_almost_eq(RULES.upgrade_bonus(10), 0.4, 0.0001, "+4%/level up to +10")
	assert_almost_eq(RULES.upgrade_bonus(12), 0.56, 0.0001, "+8%/level after +10")
	assert_almost_eq(RULES.stat_multiplier[ItemData.Rarity.EPIC], 1.6, 0.0001)


func test_boss_never_drops_common() -> void:
	for i: int in 500:
		assert_ne(RULES.roll_rarity(EnemyScaling.Tier.BOSS, rng), ItemData.Rarity.COMMON)


func test_normal_rarity_distribution_is_mostly_common() -> void:
	var commons: int = 0
	for i: int in 2000:
		if RULES.roll_rarity(EnemyScaling.Tier.NORMAL, rng) == ItemData.Rarity.COMMON:
			commons += 1
	assert_between(commons, 1300, 1500, "~70% (700 / 1000)")


func test_generated_item_has_affixes_by_rarity() -> void:
	var gen: EquipmentGenerator = EquipmentGenerator.new(db, rng)
	for rarity: int in [ItemData.Rarity.COMMON, ItemData.Rarity.RARE, ItemData.Rarity.MYTHIC]:
		var stack: ItemStack = gen.generate(10, rarity)
		assert_eq(stack.affixes.size(), RULES.affix_count[rarity])
		assert_true(db.get_item(stack.item_id).is_drop_base)
		assert_eq(stack.item_level, 10)


func test_rarity_raises_stats() -> void:
	var base: ItemData = db.get_item(&"hunter_greatsword")
	var gen: EquipmentGenerator = EquipmentGenerator.new(db, rng)
	var common: ItemStack = gen.generate_from(base, 10, ItemData.Rarity.COMMON)
	var epic: ItemStack = gen.generate_from(base, 10, ItemData.Rarity.EPIC)
	assert_gt(ItemStats.attack(epic, base, 1), ItemStats.attack(common, base, 1))


func test_generated_items_do_not_stack_and_roundtrip() -> void:
	var gen: EquipmentGenerator = EquipmentGenerator.new(db, rng)
	var stack: ItemStack = gen.generate(5, ItemData.Rarity.RARE)
	stack.upgrade = 3
	assert_true(stack.is_unique_instance())
	inv.add_stack(stack)
	var copy: Inventory = Inventory.new(db)
	var data: Dictionary = JSON.parse_string(JSON.stringify(inv.to_dict()))
	copy.load_dict(data)
	var loaded: ItemStack = copy.stacks[0]
	assert_eq(loaded.upgrade, 3)
	assert_eq(loaded.rarity, ItemData.Rarity.RARE)
	assert_eq(loaded.affixes.size(), stack.affixes.size())
	assert_eq(copy.display_name(loaded), inv.display_name(stack))


func test_mystery_box_tiers_only_go_up() -> void:
	for i: int in 300:
		var steps: Array[int] = RULES.roll_mystery_box(rng)
		for s: int in range(1, steps.size()):
			assert_gt(steps[s], steps[s - 1])


func test_open_mystery_box_gives_equipment() -> void:
	inv.add(&"mystery_box")
	var result: Dictionary = ItemActions.open_mystery_box(inv, inv.first_stack(&"mystery_box"), 5, rng)
	var item: ItemStack = result["item"]
	assert_false(inv.has(&"mystery_box"))
	assert_true(item in inv.stacks)


func test_upgrade_costs_gold_and_raises_level() -> void:
	var base: ItemData = db.get_item(&"hunter_helm")
	var stack: ItemStack = ItemStack.make(base.id, 1, base)
	GameState.gold = 100
	assert_eq(ItemActions.upgrade(stack, base, rng), ItemActions.UpgradeResult.SUCCESS)
	assert_eq(stack.upgrade, 1)
	assert_eq(GameState.gold, 0)
	assert_eq(ItemActions.upgrade(stack, base, rng), ItemActions.UpgradeResult.NO_GOLD)


func test_failed_high_upgrade_downgrades() -> void:
	var base: ItemData = db.get_item(&"hunter_helm")
	var stack: ItemStack = ItemStack.make(base.id, 1, base)
	stack.upgrade = 14
	GameState.gold = 10_000_000
	var downgraded: bool = false
	for i: int in 40:
		var result: ItemActions.UpgradeResult = ItemActions.upgrade(stack, base, rng)
		if result == ItemActions.UpgradeResult.FAILED_DOWNGRADED:
			downgraded = true
			break
		if stack.upgrade == 15:
			stack.upgrade = 14
	assert_true(downgraded, "+15 at 10% fails often and drops a level")


func test_sell_and_salvage() -> void:
	var gen: EquipmentGenerator = EquipmentGenerator.new(db, rng)
	var a: ItemStack = gen.generate(5, ItemData.Rarity.EPIC)
	var b: ItemStack = gen.generate(5, ItemData.Rarity.EPIC)
	inv.add_stack(a)
	inv.add_stack(b)
	assert_gt(ItemActions.sell(inv, a), 0)
	assert_gt(GameState.gold, 0)
	assert_eq(ItemActions.salvage(inv, b), ItemActions.SALVAGE_SCRAP[ItemData.Rarity.EPIC])
	assert_eq(inv.count_of(&"scrap_metal"), ItemActions.SALVAGE_SCRAP[ItemData.Rarity.EPIC])


func test_crafting() -> void:
	var recipe: RecipeData = load("res://data/recipes/potion_small.tres") as RecipeData
	assert_false(ItemActions.can_craft(inv, recipe))
	inv.add(&"herb", 2)
	assert_true(ItemActions.craft(inv, recipe))
	assert_eq(inv.count_of(&"potion_small"), 1)
	assert_eq(inv.count_of(&"herb"), 0)


func test_two_ring_slots() -> void:
	inv.add(&"silver_band")
	inv.add(&"warden_seal")
	inv.equip(inv.first_stack(&"silver_band"))
	inv.equip(inv.first_stack(&"warden_seal"))
	assert_not_null(inv.get_equipped(ItemData.Slot.RING))
	assert_not_null(inv.get_equipped(ItemData.Slot.RING_2))


func test_enemy_drops() -> void:
	var drops: Array[ItemStack] = LootDropper.roll(5, EnemyScaling.Tier.BOSS, db, rng)
	var has_equipment: bool = false
	for d: ItemStack in drops:
		if db.get_item(d.item_id).is_equipment():
			has_equipment = true
	assert_true(has_equipment, "bosses always drop equipment")
