class_name MovementMath
extends RefCounted
## Pure movement helpers (unit tested).


## Converts a 2D move input (x = right, y = back) into a world direction relative to camera yaw.
static func camera_relative(input: Vector2, camera_yaw: float) -> Vector3:
	var local: Vector3 = Vector3(input.x, 0.0, input.y)
	var world: Vector3 = local.rotated(Vector3.UP, camera_yaw)
	return world.limit_length(1.0)


## Moves horizontal velocity toward the target at `rate` m/s², keeping vertical velocity.
static func approach_horizontal(velocity: Vector3, target: Vector3, rate: float, delta: float) -> Vector3:
	var horizontal: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var flat_target: Vector3 = Vector3(target.x, 0.0, target.z)
	horizontal = horizontal.move_toward(flat_target, rate * delta)
	return Vector3(horizontal.x, velocity.y, horizontal.z)


## Ground speed for an input magnitude: walk below the threshold, run above.
static func ground_speed(magnitude: float, data: PlayerMovementData, sprinting: bool) -> float:
	if magnitude <= 0.0:
		return 0.0
	if sprinting:
		return data.sprint_speed
	if magnitude < data.walk_threshold:
		return data.walk_speed
	return data.run_speed


## Initial upward velocity that reaches `height` under `gravity`.
static func jump_velocity(height: float, gravity: float) -> float:
	return sqrt(2.0 * gravity * height)


## Yaw (radians) that makes a node's -Z axis face `direction`.
static func yaw_for_direction(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


## Dodge speed over time: eases from start to end speed across the duration.
static func dodge_speed_at(elapsed: float, data: PlayerMovementData) -> float:
	var t: float = clampf(elapsed / data.dodge_duration_s, 0.0, 1.0)
	return lerpf(data.dodge_speed, data.dodge_end_speed, t * t)
