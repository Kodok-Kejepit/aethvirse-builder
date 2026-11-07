class_name LootRules
extends Resource
## Rarity / affix / mystery box / upgrade numbers (Balancing sheets "Loot_Rarity" and "Upgrade").

## Rarity weights per enemy tier (index = ItemData.Rarity COMMON..MYTHIC).
@export var weights_normal: PackedFloat32Array = [700, 220, 65, 13, 2, 0]
@export var weights_elite: PackedFloat32Array = [300, 350, 250, 85, 14, 1]
@export var weights_boss: PackedFloat32Array = [0, 100, 450, 330, 110, 10]
@export var stat_multiplier: PackedFloat32Array = [1.0, 1.15, 1.35, 1.6, 2.0, 2.6]
@export var affix_count: PackedInt32Array = [0, 1, 2, 3, 4, 5]
## Chance that a defeated enemy drops a piece of equipment.
@export var equip_drop_chance: PackedFloat32Array = [0.08, 0.6, 1.0]

@export_group("Mystery box")
## Initial tier chances COMMON(=Common) RARE EPIC LEGENDARY MYTHIC ??? and per-tier upgrade chance.
@export var box_tiers: PackedInt32Array = [0, 2, 3, 4, 5, 6]
@export var box_initial: PackedFloat32Array = [0.55, 0.3, 0.12, 0.025, 0.005, 0.0]
@export var box_upgrade: PackedFloat32Array = [0.4, 0.25, 0.15, 0.1, 0.05, 0.0]

@export_group("Upgrade")
@export var upgrade_base_cost: float = 100.0
@export var upgrade_cost_growth: float = 1.35
## Success chance to reach +1 .. +15.
@export var upgrade_success: PackedFloat32Array = [1, 1, 1, 1, 1, 0.9, 0.85, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1]
## From this target level on, failing drops the item one level.
@export var upgrade_risk_from: int = 11
@export var upgrade_max: int = 15
@export var upgrade_bonus_per_level: float = 0.04


func weights_for(tier: EnemyScaling.Tier) -> PackedFloat32Array:
	match tier:
		EnemyScaling.Tier.ELITE:
			return weights_elite
		EnemyScaling.Tier.BOSS:
			return weights_boss
	return weights_normal


func roll_rarity(tier: EnemyScaling.Tier, rng: RandomNumberGenerator) -> int:
	return weighted_index(weights_for(tier), rng)


static func weighted_index(weights: PackedFloat32Array, rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += w
	var pick: float = rng.randf() * total
	for i: int in weights.size():
		pick -= weights[i]
		if pick < 0.0:
			return i
	return weights.size() - 1


## Returns the final ItemData.Rarity (6 = UNKNOWN "???") after the opening upgrades.
func roll_mystery_box(rng: RandomNumberGenerator) -> Array[int]:
	var index: int = weighted_index(box_initial, rng)
	var steps: Array[int] = [box_tiers[index]]
	while index < box_tiers.size() - 1 and rng.randf() < box_upgrade[index]:
		index += 1
		steps.append(box_tiers[index])
	return steps


func upgrade_cost(target_level: int) -> int:
	return roundi(upgrade_base_cost * pow(upgrade_cost_growth, target_level - 1))


func upgrade_chance(target_level: int) -> float:
	return upgrade_success[clampi(target_level, 1, upgrade_max) - 1]


## Total stat bonus at an upgrade level: +4%/level, +8%/level beyond +10 (sheet "Upgrade").
func upgrade_bonus(level: int) -> float:
	return level * upgrade_bonus_per_level + maxi(0, level - 10) * upgrade_bonus_per_level
