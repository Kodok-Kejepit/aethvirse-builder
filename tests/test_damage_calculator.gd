extends GutTest


func test_formula_matches_spec() -> void:
	# (100 × 1.5 − 20 × 0.5) × 1.5 × 1.5 × 1 × 1 = 140 × 2.25 = 315
	assert_eq(DamageCalculator.compute(100.0, 1.5, 20.0, 1.5, 1.5, 1.0, 1.0), 315)


func test_minimum_damage_is_one() -> void:
	assert_eq(DamageCalculator.compute(1.0, 1.0, 999.0, 1.0, 1.0, 1.0, 1.0), 1)


func test_variance_range() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	for i: int in 200:
		var v: float = DamageCalculator.roll_variance(rng)
		assert_between(v, 0.95, 1.05)


func test_resolve_applies_element_and_forced_crit() -> void:
	var attacker: CombatStats = CombatStats.new()
	attacker.attack = 100.0
	attacker.crit_chance = 0.0
	attacker.crit_damage = 2.0
	var defender: CombatStats = CombatStats.new()
	defender.defense = 0.0
	defender.element = Element.Type.ICE
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var info: DamageInfo = DamageCalculator.resolve(attacker, defender, 1.0, Element.Type.FIRE, rng, true)
	assert_true(info.is_crit)
	# 100 × 2 (crit) × 1.5 (fire vs ice) = 300 ± 5%
	assert_between(info.amount, 285, 315)


func test_crit_roll_respects_chance() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	assert_false(DamageCalculator.roll_crit(rng, 0.0))
	assert_true(DamageCalculator.roll_crit(rng, 1.0))
