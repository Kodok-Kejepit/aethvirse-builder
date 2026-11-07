extends GutTest


func test_starts_day1_at_8() -> void:
	var c: WorldClock = WorldClock.new()
	assert_eq(c.day(), 1)
	assert_eq(c.format(), "08:00")


func test_one_real_second_is_one_game_minute() -> void:
	var c: WorldClock = WorldClock.new()
	c.advance(90.0)
	assert_eq(c.format(), "09:30")


func test_day_rollover() -> void:
	var c: WorldClock = WorldClock.new()
	c.advance(16.0 * 60.0)
	assert_eq(c.day(), 2)
	assert_eq(c.format(), "00:00")


func test_night() -> void:
	var c: WorldClock = WorldClock.new()
	c.set_time_of_day(21, 0)
	assert_true(c.is_night())
	c.set_time_of_day(12, 0)
	assert_false(c.is_night())
	c.set_time_of_day(3, 33)
	assert_true(c.is_night())


func test_set_time_moves_forward_only() -> void:
	var c: WorldClock = WorldClock.new()
	c.set_time_of_day(6, 0)
	assert_eq(c.day(), 2, "06:00 is already past on day 1 at 08:00 → next day")
	c.set_time_of_day(23, 15)
	assert_eq(c.day(), 2)
	assert_eq(c.format(), "23:15")


func test_is_between_wraps_midnight() -> void:
	var c: WorldClock = WorldClock.new()
	c.set_time_of_day(0, 30)
	assert_true(c.is_between(0, 1))
	assert_true(c.is_between(22, 2))
	assert_false(c.is_between(6, 18))


func test_weather_changes_after_duration() -> void:
	var w: WeatherSystem = WeatherSystem.new()
	w.rng.seed = 3
	w.table.weights = {&"clear": 1.0, &"rain": 1.0}
	w.update(0.0)
	var first: StringName = w.current
	var changed: bool = w.update(w.change_at + 1.0)
	assert_true(changed)
	assert_ne(w.current, first, "excludes the current weather")


func test_locked_weather_stays() -> void:
	var w: WeatherSystem = WeatherSystem.new()
	w.force(WeatherSystem.RAIN, 0.0, true)
	assert_false(w.update(99999.0))
	assert_true(w.is_wet())


func test_weather_table_pick_respects_weights() -> void:
	var t: WeatherTable = WeatherTable.new()
	t.weights = {&"clear": 0.0, &"rain": 5.0}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	for i: int in 20:
		assert_eq(t.pick(rng), &"rain")
