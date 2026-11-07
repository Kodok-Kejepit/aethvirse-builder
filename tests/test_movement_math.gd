extends GutTest

var data: PlayerMovementData = PlayerMovementData.new()


func test_camera_relative_forward_with_zero_yaw_is_negative_z() -> void:
	var dir: Vector3 = MovementMath.camera_relative(Vector2(0.0, -1.0), 0.0)
	assert_almost_eq(dir, Vector3(0.0, 0.0, -1.0), Vector3.ONE * 0.001)


func test_camera_relative_follows_camera_yaw() -> void:
	# Camera turned 90 degrees left: "forward" now points to world -X.
	var dir: Vector3 = MovementMath.camera_relative(Vector2(0.0, -1.0), PI / 2.0)
	assert_almost_eq(dir, Vector3(-1.0, 0.0, 0.0), Vector3.ONE * 0.001)


func test_camera_relative_diagonal_is_clamped() -> void:
	var dir: Vector3 = MovementMath.camera_relative(Vector2(1.0, -1.0), 0.0)
	assert_almost_eq(dir.length(), 1.0, 0.001)


func test_approach_keeps_vertical_velocity() -> void:
	var v: Vector3 = MovementMath.approach_horizontal(Vector3(0.0, -3.0, 0.0), Vector3(10.0, 0.0, 0.0), 5.0, 1.0)
	assert_almost_eq(v, Vector3(5.0, -3.0, 0.0), Vector3.ONE * 0.001)


func test_approach_does_not_overshoot() -> void:
	var v: Vector3 = MovementMath.approach_horizontal(Vector3.ZERO, Vector3(2.0, 0.0, 0.0), 100.0, 1.0)
	assert_almost_eq(v, Vector3(2.0, 0.0, 0.0), Vector3.ONE * 0.001)


func test_ground_speed_walk_run_sprint() -> void:
	assert_eq(MovementMath.ground_speed(0.0, data, false), 0.0)
	assert_eq(MovementMath.ground_speed(0.3, data, false), data.walk_speed)
	assert_eq(MovementMath.ground_speed(1.0, data, false), data.run_speed)
	assert_eq(MovementMath.ground_speed(1.0, data, true), data.sprint_speed)


func test_jump_velocity_reaches_height() -> void:
	var g: float = 9.8
	var v: float = MovementMath.jump_velocity(1.4, g)
	assert_almost_eq(v * v / (2.0 * g), 1.4, 0.001)


func test_yaw_for_direction() -> void:
	assert_almost_eq(MovementMath.yaw_for_direction(Vector3.FORWARD), 0.0, 0.001)
	assert_almost_eq(MovementMath.yaw_for_direction(Vector3.RIGHT), -PI / 2.0, 0.001)


func test_dodge_speed_eases_from_start_to_end() -> void:
	assert_almost_eq(MovementMath.dodge_speed_at(0.0, data), data.dodge_speed, 0.001)
	assert_almost_eq(MovementMath.dodge_speed_at(data.dodge_duration_s, data), data.dodge_end_speed, 0.001)
	var mid: float = MovementMath.dodge_speed_at(data.dodge_duration_s * 0.5, data)
	assert_between(mid, data.dodge_end_speed, data.dodge_speed)
