class_name ItemActions
extends RefCounted
## Economy actions on the inventory: open mystery boxes, sell, salvage, upgrade, craft.
## Pure-ish (inventory + gold + rng in, results out) so they are easy to test.

const RULES: LootRules = preload("res://data/balancing/loot_rules.tres")
const SALVAGE_SCRAP: PackedInt32Array = [1, 2, 3, 5, 8, 12]

enum UpgradeResult { SUCCESS, FAILED, FAILED_DOWNGRADED, MAXED, NO_GOLD, NOT_EQUIPMENT }


## Opens one box. Returns the tier sequence (for the reveal) and adds the item.
static func open_mystery_box(inv: Inventory, box: ItemStack, level: int, rng: RandomNumberGenerator) -> Dictionary:
	var steps: Array[int] = RULES.roll_mystery_box(rng)
	var final_tier: int = steps[steps.size() - 1]
	var gen: EquipmentGenerator = EquipmentGenerator.new(inv.db, rng)
	var item: ItemStack = gen.generate(level, mini(final_tier, ItemData.Rarity.MYTHIC))
	inv.remove(box.item_id)
	inv.add_stack(item)
	return {"steps": steps, "item": item}


static func sell_price(inv: Inventory, stack: ItemStack) -> int:
	var item: ItemData = inv.db.get_item(stack.item_id)
	if item == null or not item.can_sell:
		return 0
	return roundi(item.sell_price * ItemStats.multiplier(stack, item) * maxi(stack.item_level, 1) / 2.0 + item.sell_price)


static func sell(inv: Inventory, stack: ItemStack) -> int:
	var price: int = sell_price(inv, stack)
	if price <= 0:
		return 0
	if stack.count > 1:
		stack.count -= 1
		inv.changed.emit()
	else:
		inv.stacks.erase(stack)
		inv.changed.emit()
	GameState.gold += price
	return price


## Breaks equipment into scrap metal (more for higher rarity).
static func salvage(inv: Inventory, stack: ItemStack) -> int:
	var item: ItemData = inv.db.get_item(stack.item_id)
	if item == null or not item.is_equipment() or not stack in inv.stacks or not item.can_sell:
		return 0
	var scrap: int = SALVAGE_SCRAP[clampi(ItemStats.rarity_of(stack, item), 0, SALVAGE_SCRAP.size() - 1)]
	inv.stacks.erase(stack)
	inv.add(&"scrap_metal", scrap)
	return scrap


static func upgrade(stack: ItemStack, item: ItemData, rng: RandomNumberGenerator) -> UpgradeResult:
	if item == null or not item.is_equipment():
		return UpgradeResult.NOT_EQUIPMENT
	if stack.upgrade >= RULES.upgrade_max:
		return UpgradeResult.MAXED
	var target: int = stack.upgrade + 1
	var cost: int = RULES.upgrade_cost(target)
	if GameState.gold < cost:
		return UpgradeResult.NO_GOLD
	GameState.gold -= cost
	if rng.randf() < RULES.upgrade_chance(target):
		stack.upgrade = target
		return UpgradeResult.SUCCESS
	if target >= RULES.upgrade_risk_from:
		stack.upgrade = maxi(stack.upgrade - 1, 0)
		return UpgradeResult.FAILED_DOWNGRADED
	return UpgradeResult.FAILED


static func can_craft(inv: Inventory, recipe: RecipeData) -> bool:
	if GameState.gold < recipe.gold_cost:
		return false
	for id: StringName in recipe.inputs:
		if inv.count_of(id) < recipe.inputs[id]:
			return false
	return true


static func craft(inv: Inventory, recipe: RecipeData) -> bool:
	if not can_craft(inv, recipe):
		return false
	for id: StringName in recipe.inputs:
		inv.remove(id, recipe.inputs[id])
	GameState.gold -= recipe.gold_cost
	inv.add(recipe.output, recipe.output_count)
	EventBus.item_crafted.emit(recipe.output)
	return true
