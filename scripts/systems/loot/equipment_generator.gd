class_name EquipmentGenerator
extends RefCounted
## Builds random equipment: base (per slot) + rarity + level-scaled affixes.

const RULES: LootRules = preload("res://data/balancing/loot_rules.tres")
## stat, display name, base value, value per item level, is_suffix
const AFFIXES: Array[Array] = [
	["crit", "Keen", 0.01, 0.0006, false],
	["str", "Brutal", 1.0, 0.35, false],
	["agi", "Swift", 1.0, 0.35, false],
	["int", "Wise", 1.0, 0.35, false],
	["vit", "Sturdy", 1.0, 0.35, false],
	["sen", "Watchful", 1.0, 0.3, false],
	["lifesteal", "of Thirst", 0.01, 0.0004, true],
	["vit", "of the Bear", 1.5, 0.4, true],
	["sen", "of the Hawk", 1.5, 0.35, true],
	["str", "of Ruin", 1.5, 0.4, true],
	["agi", "of Echoes", 1.5, 0.4, true],
]
const ROLL_MIN: float = 0.8
const ROLL_MAX: float = 1.2

var db: ItemDatabase
var rng: RandomNumberGenerator


func _init(database: ItemDatabase, random: RandomNumberGenerator) -> void:
	db = database
	rng = random


func bases() -> Array[ItemData]:
	var out: Array[ItemData] = []
	for id: StringName in db.all_ids():
		var item: ItemData = db.get_item(id)
		if item.is_drop_base:
			out.append(item)
	return out


func generate(level: int, rarity: int) -> ItemStack:
	var pool: Array[ItemData] = bases()
	var base: ItemData = pool[rng.randi() % pool.size()]
	return generate_from(base, level, rarity)


func generate_from(base: ItemData, level: int, rarity: int) -> ItemStack:
	var stack: ItemStack = ItemStack.make(base.id, 1, base)
	stack.rarity = clampi(rarity, ItemData.Rarity.COMMON, ItemData.Rarity.MYTHIC)
	stack.item_level = maxi(level, 1)
	var count: int = RULES.affix_count[stack.rarity]
	var used: Array[int] = []
	var has_prefix: bool = false
	var has_suffix: bool = false
	while stack.affixes.size() < count and used.size() < AFFIXES.size():
		var index: int = rng.randi() % AFFIXES.size()
		if index in used:
			continue
		used.append(index)
		var a: Array = AFFIXES[index]
		var stat: String = a[0]
		var affix_name: String = a[1]
		var base_value: float = a[2]
		var per_level: float = a[3]
		var is_suffix: bool = a[4]
		var value: float = (base_value + per_level * stack.item_level) * rng.randf_range(ROLL_MIN, ROLL_MAX)
		# Only the first prefix / suffix gives the item its name; the rest are stats only.
		var shown: bool = (is_suffix and not has_suffix) or (not is_suffix and not has_prefix)
		has_suffix = has_suffix or is_suffix
		has_prefix = has_prefix or not is_suffix
		stack.affixes.append({"stat": stat, "value": value, "name": affix_name if shown else "", "suffix": is_suffix})
	return stack
