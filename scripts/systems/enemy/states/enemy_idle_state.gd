extends EnemyState
## Patrol around home; notices the player inside aggro radius.

const WAIT_MIN_S: float = 1.5
const WAIT_MAX_S: float = 3.5

var _wait: float = 0.0
var _goal: Vector3 = Vector3.ZERO


func enter(_previous: StringName) -> void:
	_goal = enemy.global_position
	_wait = enemy.rng.randf_range(WAIT_MIN_S, WAIT_MAX_S)


func physics_update(delta: float) -> void:
	if enemy.distance_to_target() <= enemy.data.aggro_radius:
		transitioned.emit(CHASE)
		return
	if enemy.global_position.distance_to(_goal) > 0.4:
		enemy.move_toward_point(_goal, enemy.data.walk_speed, delta)
	else:
		enemy.stop(delta)
		_wait -= delta
		if _wait <= 0.0:
			_pick_goal()
	enemy.apply_gravity_and_move(delta)


func _pick_goal() -> void:
	var angle: float = enemy.rng.randf() * TAU
	var dist: float = enemy.rng.randf() * enemy.data.patrol_radius
	_goal = enemy.home + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	_wait = enemy.rng.randf_range(WAIT_MIN_S, WAIT_MAX_S)
