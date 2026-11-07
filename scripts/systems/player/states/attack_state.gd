extends PlayerState
## Runs one AttackData: lunge during startup, hitbox during active, recovery.
## Chains into the next attack from buffered input after combo_window_s; dodge cancels after dodge_cancel_s.

var _attack: AttackData
var _elapsed: float = 0.0
var _direction: Vector3 = Vector3.FORWARD
var _fired: bool = false

## Fraction of run speed you keep while attacking (light / heavy+skills).
const ATTACK_STEER: float = 0.45
const HEAVY_STEER: float = 0.2


func enter(_previous: StringName) -> void:
	_attack = player.combat.pending_attack
	_elapsed = 0.0
	_fired = false
	player.is_sprinting = false
	_direction = player.snap_facing(player.aim_direction())
	if player.stats.has_buff(&"stealth"):
		player.stats.remove_buff(&"stealth")
		player.combat.grant_counter()
	player.combat.begin_attack(_attack)
	EventBus.player_attack_started.emit()


func exit() -> void:
	player.combat.end_attack()


func physics_update(delta: float) -> void:
	# Attack speed (AGI) scales normal attacks; skills keep their authored timing.
	_elapsed += delta * (player.attack_speed if player.combat.current_skill == null else 1.0)
	var a: AttackData = _attack
	var lunge: float = 0.0
	if _elapsed < a.startup_s + a.active_s:
		lunge = a.lunge_speed * (1.0 - _elapsed / (a.startup_s + a.active_s))
	# Steering: you can keep walking while attacking (less while the blade is active / for heavies).
	var steer_factor: float = ATTACK_STEER if not a.is_heavy else HEAVY_STEER
	var steer: Vector3 = player.input_direction * player.movement.run_speed * steer_factor * player.speed_multiplier
	player.velocity.x = _direction.x * lunge + steer.x
	player.velocity.z = _direction.z * lunge + steer.z
	player.apply_gravity(delta)
	player.move_and_slide()
	if a.projectile != null:
		if not _fired and _elapsed >= a.startup_s:
			_fired = true
			player.combat.fire_projectile(a, _direction)
	else:
		player.combat.set_hitbox_active(_elapsed >= a.startup_s and _elapsed < a.startup_s + a.active_s)
	player.combat.update_swing(a, _elapsed / (a.startup_s + a.active_s))
	if _elapsed >= a.dodge_cancel_s and player.consume_dodge():
		transitioned.emit(DODGE)
		return
	if _elapsed >= a.combo_window_s and player.consume_jump():
		player.start_jump()
		transitioned.emit(AIR)
		return
	if _elapsed >= a.combo_window_s and player.combat.consume_attack():
		transitioned.emit(ATTACK)
		return
	if _elapsed >= a.get_total_s():
		transitioned.emit(MOVE if player.has_move_input() else IDLE)
