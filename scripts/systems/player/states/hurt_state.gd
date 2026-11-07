extends PlayerState
## Short stagger with knockback after a strong hit.

@export var stagger_s: float = 0.35
## After this much of the stagger a dash breaks out of it.
@export var dodge_escape_s: float = 0.15

var _elapsed: float = 0.0


func enter(_previous: StringName) -> void:
	_elapsed = 0.0
	player.is_sprinting = false
	if player.last_hit != null:
		player.velocity.x = player.last_hit.knockback.x
		player.velocity.z = player.last_hit.knockback.z


func physics_update(delta: float) -> void:
	_elapsed += delta
	player.velocity = MovementMath.approach_horizontal(player.velocity, Vector3.ZERO, player.movement.deceleration * 0.5, delta)
	player.apply_gravity(delta)
	player.move_and_slide()
	if _elapsed >= dodge_escape_s and player.consume_dodge():
		transitioned.emit(DODGE)
		return
	if _elapsed >= stagger_s:
		transitioned.emit(IDLE)
