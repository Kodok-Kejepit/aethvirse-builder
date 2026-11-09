extends GutTest
## The System's shop: same stock all day, rare..mythic only, expensive, sold once.

const TUNING: StatTuning = preload("res://data/balancing/stat_tuning.tres")


func before_each() -> void:
	GameState.player = null
	GameState.new_game(&"vanguard", TUNING)


func test_stock_is_stable_for_the_day_and_rare_or_better() -> void:
	var a: Array[Dictionary] = CodexShop.offers()
	var b: Array[Dictionary] = CodexShop.offers()
	assert_eq(a.size(), CodexShop.SLOTS.size())
	for i: int in a.size():
		var sa: ItemStack = a[i]["stack"]
		var sb: ItemStack = b[i]["stack"]
		assert_eq(sa.item_id, sb.item_id)
		assert_gte(sa.rarity, ItemData.Rarity.RARE)
	var mythic: int = a[a.size() - 1]["price"]
	assert_gt(mythic, 10000, "mythic gear is expensive")


func test_buy_needs_gold_and_sells_once() -> void:
	var cost: int = CodexShop.offers()[0]["price"]
	GameState.gold = cost - 1
	assert_false(CodexShop.buy(0), "too poor")
	GameState.gold = cost * 2
	var before: int = GameState.inventory.stacks.size()
	assert_true(CodexShop.buy(0))
	assert_eq(GameState.gold, cost)
	assert_eq(GameState.inventory.stacks.size(), before + 1)
	assert_false(CodexShop.buy(0), "sold out today")
	var sold: bool = CodexShop.offers()[0]["sold"]
	assert_true(sold)


func test_system_reward_reaches_a_target_level() -> void:
	var prog: Progression = GameState.progression
	var need: int = SystemRewards.xp_to_reach(prog, 51)
	prog.add_xp(need)
	assert_eq(prog.level, 51)
	assert_eq(SystemRewards.xp_to_reach(prog, 51), 0)
