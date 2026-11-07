extends EnemyState
## Runs at the player; attacks when in range, cooldown is ready and a token is free.

## When no token is free, keep this distance and circle instead of crowding the player.
const WAIT_RING_FACTOR: float = 1.8


func physics_update(delta: float) -> void:
	var target: Node3D = enemy.get_target()
	if target == null or enemy.distance_from_home() > enemy.data.leash_radius:
		transitioned.emit(RETURN)
		return
	var dist: float = enemy.distance_to_target()
	if dist <= enemy.data.attack_range:
		enemy.stop(delta)
		enemy.face_point(target.global_position, delta)
		if enemy.attack_cooldown <= 0.0 and enemy.request_attack_token():
			enemy.apply_gravity_and_move(delta)
			transitioned.emit(ATTACK)
			return
	elif dist <= enemy.data.attack_range * WAIT_RING_FACTOR and enemy.attack_cooldown > 0.0:
		enemy.stop(delta)
		enemy.face_point(target.global_position, delta)
	else:
		enemy.move_toward_point(target.global_position, enemy.data.chase_speed * enemy.speed_multiplier, delta)
	enemy.apply_gravity_and_move(delta)
