extends GutTest

const R := ComboTracker.Rank


func test_rank_thresholds() -> void:
	assert_eq(ComboTracker.rank_for_count(0), R.NONE)
	assert_eq(ComboTracker.rank_for_count(1), R.D)
	assert_eq(ComboTracker.rank_for_count(5), R.C)
	assert_eq(ComboTracker.rank_for_count(10), R.B)
	assert_eq(ComboTracker.rank_for_count(20), R.A)
	assert_eq(ComboTracker.rank_for_count(35), R.S)
	assert_eq(ComboTracker.rank_for_count(60), R.SSS)


func test_hits_within_timeout_chain() -> void:
	var t: ComboTracker = ComboTracker.new(3.0)
	for i: int in 6:
		t.register_hit(float(i))
	assert_eq(t.count, 6)
	assert_eq(t.get_rank(5.0), R.C)


func test_timeout_resets_count() -> void:
	var t: ComboTracker = ComboTracker.new(3.0)
	t.register_hit(0.0)
	t.register_hit(1.0)
	t.register_hit(10.0)
	assert_eq(t.count, 1)
	assert_eq(t.best, 2)
	assert_eq(t.get_rank(20.0), R.NONE)


func test_break_combo() -> void:
	var t: ComboTracker = ComboTracker.new(3.0)
	t.register_hit(0.0)
	t.break_combo()
	assert_eq(t.count, 0)
