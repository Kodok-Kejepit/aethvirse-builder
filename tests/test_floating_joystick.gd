extends GutTest


func test_value_scales_with_radius() -> void:
	var v: Vector2 = FloatingJoystick.compute_value(Vector2(100, 100), Vector2(150, 100), 100.0)
	assert_almost_eq(v, Vector2(0.5, 0.0), Vector2.ONE * 0.001)


func test_value_is_clamped() -> void:
	var v: Vector2 = FloatingJoystick.compute_value(Vector2.ZERO, Vector2(0, 500), 100.0)
	assert_almost_eq(v, Vector2(0.0, 1.0), Vector2.ONE * 0.001)


func test_zero_radius_is_safe() -> void:
	assert_eq(FloatingJoystick.compute_value(Vector2.ZERO, Vector2.ONE, 0.0), Vector2.ZERO)
