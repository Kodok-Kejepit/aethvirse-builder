class_name ItemStats
extends RefCounted
## Effective numbers of one equipped stack: base × rarity multiplier × (1 + upgrade bonus) + affixes.

const RULES: LootRules = preload("res://data/balancing/loot_rules.tres")


static func rarity_of(stack: ItemStack, item: ItemData) -> int:
	return stack.rarity if stack.rarity >= 0 else item.rarity


## Generated drops scale by their rolled rarity; hand-authored items use their written numbers.
## Upgrades apply to both.
static func multiplier(stack: ItemStack, _item: ItemData) -> float:
	var rarity_mult: float = 1.0
	if stack.rarity >= 0 and stack.rarity < RULES.stat_multiplier.size():
		rarity_mult = RULES.stat_multiplier[stack.rarity]
	return rarity_mult * (1.0 + RULES.upgrade_bonus(stack.upgrade))


static func attack(stack: ItemStack, item: ItemData, player_level: int) -> float:
	var level: int = stack.item_level if stack.item_level > 0 else player_level
	return item.attack_at(level) * multiplier(stack, item)


static func defense(stack: ItemStack, item: ItemData) -> float:
	var base: float = item.defense + item.defense_per_level * maxi(stack.item_level, 1)
	return base * multiplier(stack, item)


static func bonus(stack: ItemStack, item: ItemData, key: StringName) -> float:
	var total: float = item.stat_bonuses.get(key, 0.0) * multiplier(stack, item)
	for affix: Dictionary in stack.affixes:
		var stat: String = affix["stat"]
		if StringName(stat) == key:
			var value: float = affix["value"]
			total += value * (1.0 + RULES.upgrade_bonus(stack.upgrade))
	return total
