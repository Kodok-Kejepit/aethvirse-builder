extends PlayerState
## Dash in the input direction (or facing) with i-frames. Its late part can be cut short by
## a jump, another dash, an attack (dash attack) or a skill.

var _elapsed: float = 0.0
var _direction: Vector3 = Vector3.FORWARD
var _airborne: bool = false

## Air dash: no falling for its first part, then light gravity.
const AIR_GRAVITY_SCALE: float = 0.25


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_airborne = not player.is_on_floor()
	if _airborne:
		player.velocity.y = maxf(player.velocity.y, 0.0) * 0.3
	player.stamina.try_spend(player.movement.dodge_stamina_cost)
	_direction = player.input_direction.normalized() if player.has_move_input() else player.get_facing()
	_direction.y = 0.0
	_direction = _direction.normalized()
	player.visual.rotation.y = MovementMath.yaw_for_direction(_direction)
	player.is_invulnerable = true
	player.is_sprinting = false
	player.combat.notify_dodge_started()
	EventBus.player_dodge_started.emit()


func exit() -> void:
	player.is_invulnerable = false
	player.dodge_cancel_open = false


func physics_update(delta: float) -> void:
	_elapsed += delta
	var data: PlayerMovementData = player.movement
	if _elapsed >= data.dodge_iframe_s:
		player.is_invulnerable = false
	var speed: float = MovementMath.dodge_speed_at(_elapsed, data)
	player.velocity.x = _direction.x * speed
	player.velocity.z = _direction.z * speed
	if _airborne:
		player.velocity.y -= player.gravity * AIR_GRAVITY_SCALE * delta
	else:
		player.apply_gravity(delta)
	player.move_and_slide()
	player.dodge_cancel_open = _elapsed >= data.dodge_duration_s * data.dodge_cancel_ratio
	if player.dodge_cancel_open and _try_cancel():
		return
	if _elapsed >= data.dodge_duration_s:
		if not player.is_on_floor():
			transitioned.emit(AIR)
		else:
			transitioned.emit(MOVE if player.has_move_input() else IDLE)


func _try_cancel() -> bool:
	if player.is_on_floor() and player.consume_jump():
		player.start_jump()
		transitioned.emit(AIR)
		return true
	if player.consume_dodge():
		transitioned.emit(DODGE)
		return true
	# Dash attack: the swing comes straight out of the dash.
	if player.combat.consume_attack():
		transitioned.emit(ATTACK)
		return true
	return false
