class_name Player
extends CharacterBody3D
## Player body: reads input, owns buffers/timers and shared movement helpers.
## Behaviour per situation lives in the states under %StateMachine.

const ACTION_JUMP: StringName = &"jump"
const ACTION_DODGE: StringName = &"dodge"
const ACTION_SPRINT: StringName = &"sprint"

@export var movement: PlayerMovementData
@export var camera_rig: ThirdPersonCamera

@onready var stamina: StaminaComponent = %Stamina
@onready var state_machine: StateMachine = %StateMachine
@onready var visual: Node3D = %Visual
@onready var health: HealthComponent = %Health
@onready var combat: PlayerCombat = %Combat
@onready var lock_on: LockOnTargeter = %LockOn
@onready var stats: StatsComponent = %Stats
@onready var mana: ManaComponent = %Mana
@onready var skills: SkillCaster = %Skills
@onready var items: PlayerItems = %Items

## Hits with at least this much stagger interrupt the player (Hurt state).
@export var poise_threshold: float = 15.0
@export var respawn_delay_s: float = 2.0
## Below this height the player has fallen out of the world: back to the last safe ground.
@export var fall_limit_y: float = -30.0
@export_range(0.0, 1.0) var fall_damage_fraction: float = 0.1
## Replace the graybox capsule with the procedural heroine model.
@export var use_character_model: bool = true

## Desired move direction in world space (camera relative), length 0..1.
var input_direction: Vector3 = Vector3.ZERO
var input_magnitude: float = 0.0
var is_invulnerable: bool = false:
	set(value):
		is_invulnerable = value
		_sync_invulnerable()
## Debug cheat (console `god`).
var god_mode: bool = false:
	set(value):
		god_mode = value
		_sync_invulnerable()
## Knockback of the last hit, read by the Hurt state.
var last_hit: DamageInfo = null
## Anime character body (Big Phase 2 test model); null = graybox capsule.
var model: CharacterModel = null
## Familiars and shadow soldiers (created at runtime, see SummonManager).
var summons: SummonManager
var spawn_point: Vector3 = Vector3.ZERO
var last_safe_position: Vector3 = Vector3.ZERO
var _safe_timer: float = 0.0
## From StatsComponent (AGI). 1.0 = base.
var speed_multiplier: float = 1.0
var attack_speed: float = 1.0
var is_sprinting: bool = false
var gravity: float = 9.8
## Set by GravityZone (The Fracture): <1 floats, >1 pins you down. Jump strength stays normal.
var gravity_scale: float = 1.0

var _jump_buffer: float = 0.0
var _dodge_buffer: float = 0.0
var _coyote: float = 0.0
## One dash per jump (reset on landing).
var air_dash_used: bool = false
## True in the late part of a dash, when attacks / skills / jumps may cut it short.
var dodge_cancel_open: bool = false


func _ready() -> void:
	summons = SummonManager.new()
	summons.name = "Summons"
	summons.player = self
	add_child(summons)
	if use_character_model:
		_build_model()
	var project_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", gravity)
	gravity = project_gravity
	for child: Node in state_machine.get_children():
		var state: PlayerState = child as PlayerState
		if state != null:
			state.player = self
	stamina.changed.connect(_on_stamina_changed)
	health.damaged.connect(_on_damaged)
	health.dodged.connect(_on_dodged)
	health.died.connect(_on_died)
	health.changed.connect(func(current: int, maximum: int) -> void: EventBus.player_health_changed.emit(current, maximum))
	mana.changed.connect(func(current: float, maximum: float) -> void: EventBus.player_mana_changed.emit(current, maximum))
	spawn_point = global_position
	last_safe_position = global_position
	if GameState.pending_player_position is Vector3:
		var restored: Vector3 = GameState.pending_player_position
		global_position = restored
		last_safe_position = restored
		GameState.pending_player_position = null
	GameState.player = self
	state_machine.start()


const SAFE_SAMPLE_S: float = 0.5
const GRAYBOX_PARTS: Array[NodePath] = [^"Body", ^"Visor", ^"WeaponPivot/Blade"]


func _build_model() -> void:
	var lite: bool = OS.has_feature("mobile") or Settings.preset == QualityPresets.Preset.ANDROID_LOW
	model = CharacterModel.new()
	visual.add_child(model)
	# PC keeps the HD body; the outline pass (2× triangles) starts at PC Medium.
	var outline: bool = not lite and Settings.preset != QualityPresets.Preset.PC_LOW
	model.setup(self, CharacterRig.weapon_for_class(GameState.class_id), lite, HeroData.load_hero(GameState.hero_id), 1 if outline else 0)
	set_graybox_visible(false)


## Shows/hides the capsule placeholder (the `model` cheat toggles between the two).
func set_graybox_visible(on: bool) -> void:
	for path: NodePath in GRAYBOX_PARTS:
		var part: Node3D = visual.get_node_or_null(path) as Node3D
		if part != null:
			part.visible = on
	if model != null:
		model.visible = not on


func _track_safe_ground(delta: float) -> void:
	if global_position.y < fall_limit_y:
		recover_from_fall()
		return
	_safe_timer += delta
	if is_on_floor() and _safe_timer >= SAFE_SAMPLE_S:
		_safe_timer = 0.0
		last_safe_position = global_position


## Fell out of the world (gap, off a bridge): back to the last safe ground, small HP cost.
func recover_from_fall() -> void:
	global_position = last_safe_position + Vector3.UP * 0.5
	velocity = Vector3.ZERO
	if not health.is_dead() and not god_mode:
		var info: DamageInfo = DamageInfo.new()
		info.amount = maxi(1, roundi(health.max_health * fall_damage_fraction))
		if health.current - info.amount < 1:
			info.amount = health.current - 1
		if info.amount > 0:
			health.take_damage(info)
	Codex.notify(tr(&"CODEX_MSG_FELL"), &"warning")
	if state_machine.get_state_name() == PlayerState.DEAD:
		return
	state_machine.transition_to(PlayerState.IDLE)


func _sync_invulnerable() -> void:
	if health != null:
		health.invulnerable = is_invulnerable or god_mode


func _exit_tree() -> void:
	if GameState.player == self:
		GameState.player = null


func _physics_process(delta: float) -> void:
	_track_safe_ground(delta)
	_read_input()
	_tick_timers(delta)
	if camera_rig != null:
		camera_rig.fov_boost = is_sprinting


func _read_input() -> void:
	var raw: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var yaw: float = camera_rig.get_yaw() if camera_rig != null else 0.0
	input_direction = MovementMath.camera_relative(raw, yaw)
	input_magnitude = input_direction.length()
	if Input.is_action_pressed(SkillCaster.MODIFIER_ACTION):
		return
	if Input.is_action_just_pressed(ACTION_JUMP):
		_jump_buffer = movement.input_buffer_s
	if Input.is_action_just_pressed(ACTION_DODGE):
		_dodge_buffer = movement.input_buffer_s


func _tick_timers(delta: float) -> void:
	_jump_buffer = maxf(_jump_buffer - delta, 0.0)
	_dodge_buffer = maxf(_dodge_buffer - delta, 0.0)
	_coyote = movement.coyote_time_s if is_on_floor() else maxf(_coyote - delta, 0.0)
	if is_on_floor():
		air_dash_used = false


func has_move_input() -> bool:
	return input_magnitude > 0.0


func wants_sprint() -> bool:
	return Input.is_action_pressed(ACTION_SPRINT)


func is_jump_held() -> bool:
	return Input.is_action_pressed(ACTION_JUMP)


## True (and clears the buffer) if a jump was pressed recently and the player may jump.
func consume_jump() -> bool:
	if _jump_buffer <= 0.0 or _coyote <= 0.0:
		return false
	_jump_buffer = 0.0
	_coyote = 0.0
	return true


func consume_dodge() -> bool:
	if _dodge_buffer <= 0.0 or not stamina.can_spend():
		return false
	_dodge_buffer = 0.0
	return true


func start_jump() -> void:
	velocity.y = MovementMath.jump_velocity(movement.jump_height, gravity)


func apply_gravity(delta: float) -> void:
	var multiplier: float = movement.fall_gravity_multiplier if velocity.y < 0.0 else 1.0
	velocity.y = maxf(velocity.y - gravity * gravity_scale * multiplier * delta, -movement.max_fall_speed)


func apply_horizontal(target_speed: float, delta: float, control: float = 1.0) -> void:
	var target: Vector3 = input_direction.normalized() * target_speed if has_move_input() else Vector3.ZERO
	var rate: float = movement.acceleration if has_move_input() else movement.deceleration
	velocity = MovementMath.approach_horizontal(velocity, target, rate * control, delta)


## Soft aim assist: an enemy inside this cone / range of the aim pulls the attack to it.
const AIM_ASSIST_DEG: float = 28.0
const AIM_ASSIST_RANGE_M: float = 9.0


## Where attacks and skills go (lock-on still wins in snap_facing):
## camera forward, or the mouse cursor on the ground when the cursor is free (PC);
## the legacy mode uses the movement direction.
func aim_direction() -> Vector3:
	var dir: Vector3 = get_facing()
	if Settings.aim_mode == 1:
		dir = input_direction if has_move_input() else get_facing()
	elif camera_rig != null:
		dir = _cursor_aim() if _cursor_free() else -camera_rig.get_camera().global_basis.z
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = get_facing()
	return _assist(dir.normalized())


func _cursor_free() -> bool:
	return not Settings.wants_touch_controls() and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE


func _cursor_aim() -> Vector3:
	var cam: Camera3D = camera_rig.get_camera()
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var origin: Vector3 = cam.project_ray_origin(mouse)
	var normal: Vector3 = cam.project_ray_normal(mouse)
	if absf(normal.y) < 0.001:
		return -cam.global_basis.z
	var t: float = (global_position.y + 1.0 - origin.y) / normal.y
	if t <= 0.0:
		return -cam.global_basis.z
	return origin + normal * t - global_position


func _assist(dir: Vector3) -> Vector3:
	var best: Node3D = null
	var best_score: float = INF
	var cos_limit: float = cos(deg_to_rad(AIM_ASSIST_DEG))
	for node: Node in get_tree().get_nodes_in_group(LockOnTargeter.GROUP):
		var e: Node3D = node as Node3D
		if e == null or (e.has_method(&"is_lockable") and not e.call(&"is_lockable")):
			continue
		var to: Vector3 = e.global_position - global_position
		to.y = 0.0
		var d: float = to.length()
		if d < 0.1 or d > AIM_ASSIST_RANGE_M:
			continue
		var c: float = to.normalized().dot(dir)
		if c < cos_limit:
			continue
		var score: float = d * (2.0 - c)
		if score < best_score:
			best_score = score
			best = e
	if best == null:
		return dir
	var aim: Vector3 = best.global_position - global_position
	aim.y = 0.0
	return aim.normalized()


## Faces the lock-on target if any, else the given direction (instant).
func snap_facing(fallback: Vector3) -> Vector3:
	var direction: Vector3 = fallback
	if lock_on.target != null and is_instance_valid(lock_on.target):
		direction = lock_on.target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = get_facing()
	direction = direction.normalized()
	visual.rotation.y = MovementMath.yaw_for_direction(direction)
	return direction


func respawn() -> void:
	global_position = spawn_point
	velocity = Vector3.ZERO
	health.revive_full()
	mana.refill()
	stamina.reset()
	EventBus.player_respawned.emit()
	state_machine.transition_to(PlayerState.IDLE)


func face_direction(direction: Vector3, delta: float) -> void:
	if direction.length_squared() < 0.0001:
		return
	var target_yaw: float = MovementMath.yaw_for_direction(direction)
	var weight: float = 1.0 - exp(-movement.turn_speed * delta)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, weight)


func get_facing() -> Vector3:
	return -visual.global_basis.z


func get_horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## Shown by the F3 debug overlay.
func get_debug_state() -> String:
	var flags: String = " i-frame" if is_invulnerable else ""
	return "%s%s | %.1f m/s | stamina %d" % [state_machine.get_state_name(), flags, get_horizontal_speed(), roundi(stamina.current)]


func _on_stamina_changed(current: float, maximum: float) -> void:
	EventBus.player_stamina_changed.emit(current, maximum)


func _on_damaged(info: DamageInfo) -> void:
	last_hit = info
	combat.break_combo()
	EventBus.damage_number_requested.emit(global_position + Vector3.UP * 2.0, info.amount, info.is_crit, info.element, true)
	if health.is_dead():
		return
	var armored: bool = combat.current_attack != null and combat.current_attack.is_heavy
	if info.stagger >= poise_threshold and not armored:
		state_machine.transition_to(PlayerState.HURT)


func _on_dodged(_info: DamageInfo) -> void:
	combat.on_dodged_hit()


func _on_died() -> void:
	EventBus.player_died.emit()
	state_machine.transition_to(PlayerState.DEAD)
