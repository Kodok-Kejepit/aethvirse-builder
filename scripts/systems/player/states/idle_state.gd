extends PlayerState
## Standing still on the ground.


func enter(_previous: StringName) -> void:
	player.is_sprinting = false


func physics_update(delta: float) -> void:
	player.apply_horizontal(0.0, delta)
	player.apply_gravity(delta)
	player.move_and_slide()
	if try_ground_transitions():
		return
	if player.has_move_input():
		transitioned.emit(MOVE)
