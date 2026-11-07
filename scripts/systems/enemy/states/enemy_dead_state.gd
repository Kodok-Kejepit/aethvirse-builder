extends EnemyState
## Collapses, stops colliding, then removes itself (EnemySpawner may respawn it).

const REMOVE_AFTER_S: float = 1.6

var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	enemy.hitbox.deactivate()
	enemy.show_telegraph(0.0)
	enemy.hurtbox.set_deferred(&"monitorable", false)
	enemy.collision_layer = 0
	enemy.info_label.visible = false
	enemy.health_bar.visible = false


func physics_update(delta: float) -> void:
	_elapsed += delta
	enemy.stop(delta)
	enemy.visual.rotation.x = lerpf(enemy.visual.rotation.x, deg_to_rad(-85.0), 1.0 - exp(-8.0 * delta))
	enemy.apply_gravity_and_move(delta)
	if _elapsed >= REMOVE_AFTER_S:
		enemy.queue_free()
