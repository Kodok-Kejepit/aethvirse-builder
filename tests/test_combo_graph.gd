extends GutTest

var combo: ComboData = preload("res://data/combat/greatsword_combo.tres")


func _chain(inputs: String) -> AttackData:
	var current: AttackData = null
	for c: String in inputs.split(""):
		current = combo.resolve_next(current, c == "H")
	return current


func test_light_chain_has_five_hits() -> void:
	assert_eq(_chain("L").id, &"light_1")
	assert_eq(_chain("LLLLL").id, &"light_5")


func test_chain_restarts_after_finisher() -> void:
	assert_eq(_chain("LLLLLL").id, &"light_1")


func test_branches() -> void:
	assert_eq(_chain("H").id, &"overhead_smash")
	assert_eq(_chain("LH").id, &"rising_cleave")
	assert_eq(_chain("LLH").id, &"whirlwind")
	assert_eq(_chain("LLLH").id, &"ground_slam")
	assert_eq(_chain("LLLLH").id, &"piercing_thrust")


func test_all_attacks_have_sane_timings() -> void:
	for inputs: String in ["L", "LL", "LLL", "LLLL", "LLLLL", "H", "LH", "LLH", "LLLH", "LLLLH"]:
		var a: AttackData = _chain(inputs)
		assert_gt(a.active_s, 0.0, a.id)
		assert_true(a.combo_window_s <= a.get_total_s(), "%s combo window inside attack" % a.id)
		assert_true(a.dodge_cancel_s <= a.get_total_s(), "%s dodge cancel inside attack" % a.id)
		assert_gt(a.damage_multiplier, 0.0, a.id)
