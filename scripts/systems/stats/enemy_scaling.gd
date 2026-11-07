class_name EnemyScaling
extends RefCounted
## Enemy numbers per level, derived from a reference hero of the same level
## (Balancing sheet "Musuh"): Normal dies in ~N hero hits and kills the hero in ~M hits.

enum Tier { NORMAL, ELITE, BOSS }


class Result:
	var max_health: int = 1
	var attack: float = 1.0
	var defense: float = 0.0
	var xp: int = 0
	var gold: int = 0


static func compute(level: int, tier: Tier, ref_class: ClassData, t: StatTuning) -> Result:
	var hero_stats: StatBlock = ref_class.base_stats.plus(ref_class.growth, float(level - 1)) \
		.plus(ref_class.recommended_split, float(t.free_points_per_level * (level - 1))).rounded()
	var weapon: float = level * t.weapon_atk_per_level
	var hero: DerivedStats = DerivedStats.compute(level, hero_stats, t, weapon)
	var hero_atk: float = hero.magic_attack if ref_class.magic_damage else hero.attack
	var r: Result = Result.new()
	r.defense = roundf(level * t.enemy_def_per_level)
	var avg_hit: float = maxf(1.0, hero_atk - r.defense * t.def_factor) * (1.0 + hero.crit_chance * (hero.crit_damage - 1.0))
	var normal_hp: float = avg_hit * t.hits_to_kill_normal
	var normal_atk: float = hero.max_hp / t.normal_hits_to_kill_hero + hero.defense * t.def_factor
	var kills: float = roundf(t.kills_per_level_base + t.kills_per_level_growth * level)
	var normal_xp: float = Progression.xp_needed(level, t) / maxf(kills, 1.0)
	var normal_gold: float = t.gold_base * pow(t.gold_growth, float(level))
	match tier:
		Tier.ELITE:
			r.max_health = roundi(normal_hp * t.elite_hp_mult)
			r.attack = roundf(normal_atk * t.elite_atk_mult)
			r.xp = roundi(normal_xp * t.elite_xp_mult)
			r.gold = roundi(normal_gold * t.elite_xp_mult)
		Tier.BOSS:
			r.max_health = roundi(normal_hp * t.boss_hp_mult)
			r.attack = roundf(normal_atk * t.boss_atk_mult)
			r.xp = roundi(normal_xp * t.boss_xp_mult)
			r.gold = roundi(normal_gold * t.boss_xp_mult)
		_:
			r.max_health = roundi(normal_hp)
			r.attack = roundf(normal_atk)
			r.xp = roundi(normal_xp)
			r.gold = roundi(normal_gold)
	return r
