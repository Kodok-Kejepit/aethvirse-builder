extends EnemyState
## Windup (red ground telegraph) → active hitbox with lunge → recovery.

var _elapsed: float = 0.0
var _direction: Vector3 = Vector3.FORWARD


func enter(_previous: StringName) -> void:
	_elapsed = 0.0


func exit() -> void:
	enemy.hitbox.deactivate()
	enemy.show_telegraph(0.0)
	enemy.release_attack_token()
	enemy.attack_cooldown = enemy.data.attack_cooldown_s


func physics_update(delta: float) -> void:
	var d: EnemyData = enemy.data
	_elapsed += delta / enemy.windup_multiplier if _elapsed < d.attack_windup_s else delta
	var target: Node3D = enemy.get_target()
	if _elapsed < d.attack_windup_s:
		if target != null:
			# Tracks the player during the first half of the windup only, so dodging works.
			if _elapsed < d.attack_windup_s * 0.5:
				enemy.face_point(target.global_position, delta)
		_direction = enemy.get_facing()
		enemy.show_telegraph(_elapsed / d.attack_windup_s)
		enemy.stop(delta)
	elif _elapsed < d.attack_windup_s + d.attack_active_s:
		enemy.show_telegraph(0.0)
		if not enemy.hitbox.is_active():
			enemy.hitbox.activate()
		enemy.velocity.x = _direction.x * d.attack_lunge_speed
		enemy.velocity.z = _direction.z * d.attack_lunge_speed
	else:
		enemy.hitbox.deactivate()
		enemy.stop(delta)
	enemy.apply_gravity_and_move(delta)
	if _elapsed >= d.attack_windup_s + d.attack_active_s + d.attack_recovery_s:
		transitioned.emit(CHASE)
