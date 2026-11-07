extends GutTest
## Numbers checked against ascendant-dev/docs/ASCENDANT_Balancing.xlsx.

var tuning: StatTuning = preload("res://data/balancing/stat_tuning.tres")
var vanguard: ClassData = preload("res://data/classes/vanguard.tres")


func test_xp_curve_matches_formula() -> void:
	assert_eq(Progression.xp_needed(1, tuning), 100)
	assert_eq(Progression.xp_needed(2, tuning), roundi(100.0 * pow(2.0, 1.8)))
	assert_eq(Progression.xp_needed(10, tuning), roundi(100.0 * pow(10.0, 1.8)))
	assert_eq(Progression.xp_needed(100, tuning), 0, "cap")


func test_level_up_grants_points() -> void:
	var p: Progression = Progression.new(tuning)
	var gained: int = p.add_xp(100)
	assert_eq(gained, 1)
	assert_eq(p.level, 2)
	assert_eq(p.free_points, 5)
	assert_eq(p.skill_points, 1)


func test_multi_level_up_and_leftover() -> void:
	var p: Progression = Progression.new(tuning)
	var needed: int = Progression.xp_needed(1, tuning) + Progression.xp_needed(2, tuning)
	p.add_xp(needed + 7)
	assert_eq(p.level, 3)
	assert_eq(p.xp, 7)


func test_allocate_points() -> void:
	var p: Progression = Progression.new(tuning)
	p.add_xp(100)
	assert_true(p.allocate(StatBlock.Stat.STR, 3))
	assert_eq(p.free_points, 2)
	assert_false(p.allocate(StatBlock.Stat.STR, 5), "not enough points")
	assert_eq(p.primary_stats(vanguard).strength, 12.0 + 2.0 + 3.0, "base + growth + allocated")


func test_vanguard_level1_derived_matches_sheet() -> void:
	var d: DerivedStats = DerivedStats.compute(1, vanguard.base_stats, tuning, 0.0)
	assert_eq(d.max_hp, 330, "100 + 11×20 + 1×10")
	assert_eq(d.max_mp, 83, "50 + 3×10 + 1×3")
	assert_almost_eq(d.attack, 27.0, 0.001, "12×2 + 6×0.5")
	assert_almost_eq(d.defense, 14.6, 0.001, "11×1 + 12×0.3")
	assert_almost_eq(d.crit_chance, 0.064, 0.0001)
	assert_almost_eq(d.crit_damage, 1.52, 0.0001)
	assert_almost_eq(d.attack_speed, 1.012, 0.0001)


func test_enemy_scaling_level1_normal_matches_sheet() -> void:
	var r: EnemyScaling.Result = EnemyScaling.compute(1, EnemyScaling.Tier.NORMAL, vanguard, tuning)
	assert_eq(r.max_health, 155)
	assert_eq(r.attack, 35.0)
	assert_eq(r.defense, 2.0)
	assert_eq(r.xp, 6)


func test_elite_and_boss_multipliers() -> void:
	var n: EnemyScaling.Result = EnemyScaling.compute(10, EnemyScaling.Tier.NORMAL, vanguard, tuning)
	var e: EnemyScaling.Result = EnemyScaling.compute(10, EnemyScaling.Tier.ELITE, vanguard, tuning)
	var b: EnemyScaling.Result = EnemyScaling.compute(10, EnemyScaling.Tier.BOSS, vanguard, tuning)
	assert_almost_eq(float(e.max_health) / float(n.max_health), 4.0, 0.05)
	assert_almost_eq(float(b.max_health) / float(n.max_health), 40.0, 0.05)
	assert_gt(b.xp, e.xp)


func test_serialization_roundtrip() -> void:
	var p: Progression = Progression.new(tuning)
	p.add_xp(500)
	p.allocate(StatBlock.Stat.SEN, 2)
	var q: Progression = Progression.new(tuning)
	q.load_dict(p.to_dict())
	assert_eq(q.level, p.level)
	assert_eq(q.xp, p.xp)
	assert_eq(q.free_points, p.free_points)
	assert_eq(q.allocated.sense, 2.0)
