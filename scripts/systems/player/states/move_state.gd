extends PlayerState
## Walk / run / sprint on the ground. Sprint = hold `sprint` while moving: unlimited
## (big world — stamina is only spent on dashes).


func exit() -> void:
	player.is_sprinting = false


func physics_update(delta: float) -> void:
	player.is_sprinting = player.wants_sprint() and player.has_move_input()
	var speed: float = MovementMath.ground_speed(player.input_magnitude, player.movement, player.is_sprinting) * player.speed_multiplier
	player.apply_horizontal(speed, delta)
	player.apply_gravity(delta)
	player.face_direction(player.input_direction, delta)
	player.move_and_slide()
	if try_ground_transitions():
		return
	if not player.has_move_input() and player.get_horizontal_speed() < 0.1:
		transitioned.emit(IDLE)
