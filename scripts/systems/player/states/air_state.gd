extends PlayerState
## Jumping or falling. Reduced air control, variable jump height, coyote jump via Player buffers.

var _jump_cut_done: bool = false
var _carried_speed: float = 0.0


func enter(_previous: StringName) -> void:
	_jump_cut_done = false
	# Keep sprint/run momentum through the jump instead of snapping to run speed.
	_carried_speed = maxf(player.get_horizontal_speed(), player.movement.run_speed)
	player.is_sprinting = false


func physics_update(delta: float) -> void:
	if not _jump_cut_done and player.velocity.y > 0.0 and not player.is_jump_held():
		player.velocity.y *= player.movement.jump_cut_multiplier
		_jump_cut_done = true
	if player.consume_jump():
		player.start_jump()
	if player.combat.consume_attack():
		transitioned.emit(ATTACK)
		return
	# Air dash: one per jump, dodges attacks mid-air.
	if not player.air_dash_used and player.consume_dodge():
		player.air_dash_used = true
		transitioned.emit(DODGE)
		return
	player.apply_horizontal(_carried_speed, delta, player.movement.air_control)
	player.apply_gravity(delta)
	player.face_direction(player.input_direction, delta)
	player.move_and_slide()
	if player.is_on_floor():
		transitioned.emit(MOVE if player.has_move_input() else IDLE)
