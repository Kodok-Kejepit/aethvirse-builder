extends GutTest

var stamina: StaminaComponent


func before_each() -> void:
	stamina = StaminaComponent.new()
	stamina.max_stamina = 100.0
	stamina.regen_per_second = 50.0
	stamina.regen_delay_s = 0.5
	stamina.exhausted_recover_ratio = 0.3
	add_child_autofree(stamina)
	stamina.set_physics_process(false)


func test_starts_full() -> void:
	assert_eq(stamina.current, 100.0)


func test_spend_reduces_and_delays_regen() -> void:
	assert_true(stamina.try_spend(20.0))
	assert_eq(stamina.current, 80.0)
	stamina.tick(0.4)
	assert_eq(stamina.current, 80.0, "still in regen delay")
	stamina.tick(0.2)
	stamina.tick(0.2)
	assert_almost_eq(stamina.current, 90.0, 0.01)


func test_depletion_exhausts_until_recover_ratio() -> void:
	watch_signals(stamina)
	assert_true(stamina.try_spend(150.0))
	assert_eq(stamina.current, 0.0)
	assert_true(stamina.exhausted)
	assert_signal_emitted(stamina, "depleted")
	assert_false(stamina.try_spend(1.0))
	stamina.tick(0.5)  # regen delay
	stamina.tick(0.5)  # +25 -> 25%, still exhausted
	assert_true(stamina.exhausted, "still exhausted below 30%")
	stamina.tick(0.2)  # +10 -> 35%
	assert_false(stamina.exhausted, "recovered after reaching 30%")


func test_drain_over_time() -> void:
	assert_true(stamina.drain(10.0, 1.0))
	assert_eq(stamina.current, 90.0)
