extends EnemyState
## Staggered: knocked back and unable to act for a moment.

const STAGGER_S: float = 0.6

var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	if enemy.last_hit != null:
		enemy.velocity.x = enemy.last_hit.knockback.x * 1.5
		enemy.velocity.z = enemy.last_hit.knockback.z * 1.5


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.velocity = MovementMath.approach_horizontal(enemy.velocity, Vector3.ZERO, 12.0, delta)
	enemy.visual.rotation.x = deg_to_rad(15.0) * (1.0 - _elapsed / STAGGER_S)
	enemy.apply_gravity_and_move(delta)
	if _elapsed >= STAGGER_S:
		enemy.visual.rotation.x = 0.0
		transitioned.emit(CHASE)
