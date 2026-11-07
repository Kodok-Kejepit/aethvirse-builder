class_name DerivedStats
extends RefCounted
## Secondary stats computed from level + primary stats (§8, Balancing sheet "Hero").

var max_hp: int = 0
var max_mp: int = 0
var attack: float = 0.0
var magic_attack: float = 0.0
var defense: float = 0.0
var crit_chance: float = 0.0
var crit_damage: float = 1.5
var attack_speed: float = 1.0
var move_speed: float = 1.0
var cooldown_reduction: float = 0.0
var mp_regen: float = 0.0


static func compute(level: int, s: StatBlock, t: StatTuning, weapon_attack: float) -> DerivedStats:
	var d: DerivedStats = DerivedStats.new()
	d.max_hp = roundi(t.hp_base + s.vitality * t.hp_per_vit + level * t.hp_per_level)
	d.max_mp = roundi(t.mp_base + s.intelligence * t.mp_per_int + level * t.mp_per_level)
	d.attack = s.strength * t.atk_per_str + s.agility * t.atk_per_agi + weapon_attack
	d.magic_attack = s.intelligence * t.matk_per_int + weapon_attack
	d.defense = s.vitality * t.def_per_vit + s.strength * t.def_per_str
	d.crit_chance = minf(t.crit_cap, t.crit_base + s.sense * t.crit_per_sen + s.agility * t.crit_per_agi)
	d.crit_damage = t.crit_dmg_base + s.sense * t.crit_dmg_per_sen
	d.attack_speed = t.aspd_base + s.agility * t.aspd_per_agi
	d.move_speed = minf(t.mspd_cap, 1.0 + s.agility * t.mspd_per_agi)
	d.cooldown_reduction = minf(t.cdr_cap, s.intelligence * t.cdr_per_int)
	d.mp_regen = t.mp_regen_base + s.intelligence * t.mp_regen_per_int
	return d


## CombatStats for the damage formula. Magic classes use M.ATK as their main attack.
func to_combat_stats(magic: bool, element: Element.Type = Element.Type.PHYSICAL) -> CombatStats:
	var c: CombatStats = CombatStats.new()
	c.attack = magic_attack if magic else attack
	c.defense = defense
	c.crit_chance = crit_chance
	c.crit_damage = crit_damage
	c.element = element
	return c
