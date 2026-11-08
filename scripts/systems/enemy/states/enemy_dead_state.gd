extends EnemyState
## Collapses, stops colliding, then removes itself (EnemySpawner may respawn it).

const REMOVE_AFTER_S: float = 1.6
const RIGGED_REMOVE_AFTER_S: float = 2.6

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
	# Rigged monsters play their death clip; primitive bodies tip over.
	var rigged: bool = enemy.creature != null and enemy.creature.is_rigged()
	if not rigged:
		enemy.visual.rotation.x = lerpf(enemy.visual.rotation.x, deg_to_rad(-85.0), 1.0 - exp(-8.0 * delta))
	if enemy.creature != null:
		enemy.creature.set_state(&"Dead")
		enemy.creature.drive(0.0, false, delta)
	enemy.apply_gravity_and_move(delta)
	if _elapsed >= (RIGGED_REMOVE_AFTER_S if rigged else REMOVE_AFTER_S):
		enemy.queue_free()
