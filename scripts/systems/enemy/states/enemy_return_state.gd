extends EnemyState
## Leashed: walks home, ignores the player and heals to full on arrival.


func physics_update(delta: float) -> void:
	enemy.move_toward_point(enemy.home, enemy.data.chase_speed, delta)
	enemy.apply_gravity_and_move(delta)
	if enemy.distance_from_home() < 0.6:
		enemy.health.revive_full()
		transitioned.emit(IDLE)
