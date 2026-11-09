extends GutTest
## Tracker against the real R1 data with a fake world state.

const TUNING: StatTuning = preload("res://data/balancing/stat_tuning.tres")

var tracker: SecretTracker


func before_each() -> void:
	GameState.player = null
	GameState.new_game(&"vanguard", TUNING)
	tracker = SecretTracker.new()
	add_child_autofree(tracker)
	tracker.set_physics_process(false)


func test_area_secret_completes_and_rewards() -> void:
	EventBus.secret_area_entered.emit(&"sec_r1_01_pump_room")
	tracker.evaluate_all()
	assert_true(tracker.is_found(&"SEC-R1-01"))
	assert_true(GameState.inventory.has(&"potion_large"))


func test_marrow_streak_starts_sealed_mission() -> void:
	watch_signals(EventBus)
	for day: int in [1, 2, 3]:
		GameState.secrets.record_daily(&"marrow_fed_streak", day)
	tracker.evaluate_all()
	assert_true(tracker.is_found(&"SM-R1-01:1"))
	assert_signal_emitted(EventBus, "secret_found")
	assert_true(GameState.has_flag(&"sm_r1_01_s1"))


func test_event_secret_needs_conditions() -> void:
	assert_false(tracker.complete(&"MC-R1-02"), "apartment 404 not found yet")
	GameState.set_flag(&"r1_wall_404_broken")
	tracker.evaluate_all()
	assert_true(tracker.complete(&"MC-R1-02"))
	assert_true(GameState.inventory.has(&"rusty_coin", 30))


func test_attacking_marrow_fails_the_chain() -> void:
	GameState.set_flag(&"marrow_attacked")
	for day: int in [1, 2, 3]:
		GameState.secrets.record_daily(&"marrow_fed_streak", day)
	tracker.evaluate_all()
	assert_false(tracker.is_found(&"SM-R1-01:1"))
	assert_true(tracker.is_failed(&"SM-R1-01:1"))


func test_codex_identification_fails_stage_3() -> void:
	GameState.secrets.found[&"SM-R1-01:2"] = true
	GameState.inventory.add(&"rusted_license")
	GameState.inventory.identify(GameState.inventory.first_stack(&"rusted_license"), &"codex")
	tracker.evaluate_all()
	assert_true(tracker.is_failed(&"SM-R1-01:3"))


func test_region_progress() -> void:
	EventBus.secret_area_entered.emit(&"sec_r1_01_pump_room")
	tracker.evaluate_all()
	var p: Vector4i = tracker.region_progress(&"r1_ashfall")
	assert_eq(p, Vector4i(1, 13, 0, 3), "counted from the secrets that exist")
