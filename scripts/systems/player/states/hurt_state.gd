extends PlayerState
## Short stagger with knockback after a strong hit. Blows with `launch` (brutes, alphas,
## bosses) throw the hero through the air: no braking while flying, a short get-up after
## landing, and a dash only breaks out once back on the ground.

@export var stagger_s: float = 0.35
## After this much of the stagger a dash breaks out of it.
@export var dodge_escape_s: float = 0.15
## Lying on the ground after a throw before control returns.
@export var get_up_s: float = 0.45
## Airborne braking while thrown (fraction of normal deceleration).
const AIR_DRAG: float = 0.08
const THROW_SHAKE: float = 0.35

var _elapsed: float = 0.0
var _thrown: bool = false
var _landed_at: float = -1.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	_landed_at = -1.0
	_thrown = false
	player.is_sprinting = false
	if player.last_hit != null:
		player.velocity.x = player.last_hit.knockback.x
		player.velocity.z = player.last_hit.knockback.z
		if player.last_hit.launch > 0.0:
			_thrown = true
			player.velocity.y = player.last_hit.launch
			if player.camera_rig != null:
				player.camera_rig.shake(THROW_SHAKE)


func physics_update(delta: float) -> void:
	_elapsed += delta
	var airborne: bool = _thrown and (_elapsed < 0.1 or not player.is_on_floor())
	var drag: float = AIR_DRAG if airborne else 0.5
	player.velocity = MovementMath.approach_horizontal(player.velocity, Vector3.ZERO, player.movement.deceleration * drag, delta)
	player.apply_gravity(delta)
	player.move_and_slide()
	if _thrown:
		if airborne:
			return
		if _landed_at < 0.0:
			_landed_at = _elapsed
		if _elapsed - _landed_at >= get_up_s * 0.5 and player.consume_dodge():
			transitioned.emit(DODGE)
			return
		if _elapsed - _landed_at >= get_up_s:
			transitioned.emit(IDLE)
		return
	if _elapsed >= dodge_escape_s and player.consume_dodge():
		transitioned.emit(DODGE)
		return
	if _elapsed >= stagger_s:
		transitioned.emit(IDLE)
