extends PlayerState
## Player is down; respawns at the spawn point after a delay.

var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	player.is_sprinting = false
	player.lock_on.set_target(null)
	if player.model == null or not player.model.visible:
		player.visual.rotation.x = deg_to_rad(-80.0)


func exit() -> void:
	player.visual.rotation.x = 0.0


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.velocity = MovementMath.approach_horizontal(player.velocity, Vector3.ZERO, player.movement.deceleration, delta)
	player.apply_gravity(delta)
	player.move_and_slide()
	if _elapsed >= player.respawn_delay_s:
		player.respawn()
