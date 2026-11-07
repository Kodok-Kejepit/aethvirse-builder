class_name LootDropper
extends RefCounted
## What a defeated enemy drops (besides XP/gold): equipment by tier, materials, mystery boxes.

const RULES: LootRules = preload("res://data/balancing/loot_rules.tres")
const HERB_CHANCE: float = 0.3
const SCRAP_CHANCE: float = 0.2
const BOX_CHANCE: PackedFloat32Array = [0.02, 0.2, 0.5]
const POTION_CHANCE: float = 0.08


## Returns ItemStacks to spawn as pickups.
static func roll(level: int, tier: EnemyScaling.Tier, db: ItemDatabase, rng: RandomNumberGenerator) -> Array[ItemStack]:
	var out: Array[ItemStack] = []
	if rng.randf() < RULES.equip_drop_chance[tier]:
		var gen: EquipmentGenerator = EquipmentGenerator.new(db, rng)
		out.append(gen.generate(level, RULES.roll_rarity(tier, rng)))
	if rng.randf() < HERB_CHANCE:
		out.append(ItemStack.make(&"herb", rng.randi_range(1, 2), db.get_item(&"herb")))
	if rng.randf() < SCRAP_CHANCE:
		out.append(ItemStack.make(&"scrap_metal", 1, db.get_item(&"scrap_metal")))
	if rng.randf() < POTION_CHANCE:
		out.append(ItemStack.make(&"potion_small", 1, db.get_item(&"potion_small")))
	if rng.randf() < BOX_CHANCE[tier]:
		out.append(ItemStack.make(&"mystery_box", 1, db.get_item(&"mystery_box")))
	return out
