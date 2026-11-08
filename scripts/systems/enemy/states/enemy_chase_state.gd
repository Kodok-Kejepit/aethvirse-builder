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
	if enemy.data.ranged:
		_ranged(target, dist, delta)
		return
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


## Ranged: back off when the hero is close, shoot from range with a clear line, else close in.
func _ranged(target: Node3D, dist: float, delta: float) -> void:
	var d: EnemyData = enemy.data
	if dist < d.keep_distance_m:
		var away: Vector3 = enemy.global_position * 2.0 - target.global_position
		enemy.move_toward_point(away, d.chase_speed * enemy.speed_multiplier, delta)
	elif dist <= d.attack_range and EnemyRanged.clear_shot(enemy, target.global_position + Vector3.UP * EnemyRanged.CHEST_HEIGHT):
		enemy.stop(delta)
		enemy.face_point(target.global_position, delta)
		if enemy.attack_cooldown <= 0.0 and enemy.request_attack_token():
			enemy.apply_gravity_and_move(delta)
			transitioned.emit(ATTACK)
			return
	else:
		enemy.move_toward_point(target.global_position, d.chase_speed * enemy.speed_multiplier, delta)
	enemy.apply_gravity_and_move(delta)
