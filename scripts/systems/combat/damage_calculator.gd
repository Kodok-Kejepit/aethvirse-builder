class_name DamageCalculator
extends RefCounted
## damage = (ATK × skill_mult − DEF × 0.5) × crit × element × reaction × variance, min 1  (§6)

const DEF_FACTOR: float = 0.5
const VARIANCE_MIN: float = 0.95
const VARIANCE_MAX: float = 1.05
const MIN_DAMAGE: int = 1


static func compute(atk: float, skill_mult: float, def: float, crit_mult: float,
		element_mult: float, reaction_mult: float, variance: float) -> int:
	var base: float = atk * skill_mult - def * DEF_FACTOR
	var total: float = base * crit_mult * element_mult * reaction_mult * variance
	return maxi(MIN_DAMAGE, roundi(total))


static func roll_variance(rng: RandomNumberGenerator) -> float:
	return rng.randf_range(VARIANCE_MIN, VARIANCE_MAX)


static func roll_crit(rng: RandomNumberGenerator, chance: float) -> bool:
	return rng.randf() < clampf(chance, 0.0, 1.0)


## Full roll for an attacker/defender pair. `bonus_mult` covers counters and similar bonuses.
static func resolve(attacker: CombatStats, defender: CombatStats, skill_mult: float,
		attack_element: Element.Type, rng: RandomNumberGenerator,
		force_crit: bool = false, bonus_mult: float = 1.0, reaction_mult: float = 1.0) -> DamageInfo:
	var info: DamageInfo = DamageInfo.new()
	info.element = attack_element
	info.is_crit = force_crit or roll_crit(rng, attacker.crit_chance)
	var crit_mult: float = attacker.crit_damage if info.is_crit else 1.0
	var element_mult: float = Element.multiplier(attack_element, defender.element)
	info.amount = compute(attacker.attack * bonus_mult, skill_mult, defender.defense,
		crit_mult, element_mult, reaction_mult, roll_variance(rng))
	return info
