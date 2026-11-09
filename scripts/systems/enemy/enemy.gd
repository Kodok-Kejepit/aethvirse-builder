class_name Enemy
extends CharacterBody3D
## Graybox enemy driven by EnemyData and a StateMachine
## (Idle/Patrol → Chase → Attack → Hurt → Return → Dead).

const HIT_FLASH_S: float = 0.12
const POISE_RESET_S: float = 2.0
const TURN_SPEED: float = 10.0
const TUNING: StatTuning = preload("res://data/balancing/stat_tuning.tres")
## Reference hero for enemy scaling (Balancing sheet uses the selected class; Warden — id vanguard — by default).
const REFERENCE_CLASS: ClassData = preload("res://data/classes/vanguard.tres")

@export var data: EnemyData

@onready var health: HealthComponent = %Health
@onready var hurtbox: HurtboxComponent = %Hurtbox
@onready var hitbox: HitboxComponent = %Hitbox
@onready var hitbox_shape: CollisionShape3D = %HitboxShape
@onready var state_machine: StateMachine = %StateMachine
@onready var visual: Node3D = %Visual
@onready var body_mesh: MeshInstance3D = %BodyMesh
@onready var telegraph: MeshInstance3D = %Telegraph
@onready var info_label: Label3D = %InfoLabel
@onready var health_bar: WorldHealthBar = %HealthBar

var home: Vector3 = Vector3.ZERO
var gravity: float = 9.8
var last_hit: DamageInfo = null
var attack_cooldown: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Per-instance stats (scaled copy of data.stats).
var stats: CombatStats
var xp_reward: int = 0
## Boss phases / affixes modify these at runtime.
var speed_multiplier: float = 1.0
var windup_multiplier: float = 1.0
var gold_reward: int = 0

var _poise_damage: float = 0.0
var _since_hit: float = 0.0
var _flash_material: StandardMaterial3D


func _ready() -> void:
	rng.randomize()
	home = global_position
	var project_gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", gravity)
	gravity = project_gravity
	_apply_scaling()
	hurtbox.stats = stats
	hurtbox.body = self
	hitbox.body = self
	hitbox.damage_builder = _build_damage
	var box: BoxShape3D = hitbox_shape.shape as BoxShape3D
	box.size = data.attack_hitbox_size
	hitbox.position = data.attack_hitbox_offset
	_setup_visuals()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	health.changed.connect(func(_c: int, _m: int) -> void: _update_label())
	for child: Node in state_machine.get_children():
		var state: EnemyState = child as EnemyState
		if state != null:
			state.enemy = self
	add_to_group(LockOnTargeter.GROUP)
	_update_label()
	state_machine.start()


func _apply_scaling() -> void:
	stats = data.stats.duplicate() as CombatStats
	var max_hp: int = data.max_health
	xp_reward = data.xp_reward
	gold_reward = data.gold_reward
	if data.scale_by_level:
		var scaled: EnemyScaling.Result = EnemyScaling.compute(data.level, data.tier, REFERENCE_CLASS, TUNING)
		max_hp = roundi(scaled.max_health * data.hp_scale)
		stats.attack = scaled.attack * data.attack_scale
		stats.defense = scaled.defense
		xp_reward = scaled.xp
		gold_reward = scaled.gold
	health.set_max_health(max_hp, true)


const FALL_LIMIT_Y: float = -40.0
## Beyond this distance from the player an idle / patrolling enemy sleeps: no AI, no
## animation, no physics (it wakes as soon as the player comes back).
const SLEEP_DISTANCE_M: float = 60.0
const SLEEP_CHECK_S: float = 0.5

var asleep: bool = false
var _sleep_check: float = 0.0


func _physics_process(delta: float) -> void:
	if global_position.y < FALL_LIMIT_Y:
		queue_free()
		return
	_sleep_check -= delta
	if _sleep_check <= 0.0:
		_sleep_check = SLEEP_CHECK_S
		_update_sleep()
	if asleep:
		return
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	if creature != null:
		creature.set_state(state_machine.get_state_name())
		creature.drive(Vector2(velocity.x, velocity.z).length(), state_machine.get_state_name() == &"Attack", delta)
	_watch_world_boss()
	_since_hit += delta
	if _since_hit > POISE_RESET_S:
		_poise_damage = 0.0


## Open-world bosses show the big boss bar while the player is close.
## Far enemies that are only idling or walking home stop processing.
func _update_sleep() -> void:
	var player: Node3D = GameState.player
	var far: bool = player != null and global_position.distance_to(player.global_position) > SLEEP_DISTANCE_M
	var calm: bool = state_machine.get_state_name() in [EnemyState.IDLE, EnemyState.RETURN]
	var sleep: bool = far and calm and not health.is_dead()
	if sleep == asleep:
		return
	asleep = sleep
	state_machine.process_mode = Node.PROCESS_MODE_DISABLED if sleep else Node.PROCESS_MODE_INHERIT
	if sleep:
		velocity = Vector3.ZERO


var _boss_phases: BossPhases = null
const WORLD_BOSS_BAR_RANGE_M: float = 30.0


func _watch_world_boss() -> void:
	if data.tier != EnemyScaling.Tier.BOSS or GameState.gate_session != null or health.is_dead():
		return
	if Engine.get_physics_frames() % 15 != 0:
		return
	var player: Node3D = GameState.player
	var near: bool = player != null and global_position.distance_to(player.global_position) < WORLD_BOSS_BAR_RANGE_M
	if near and _boss_phases == null:
		_boss_phases = BossPhases.new()
		add_child(_boss_phases)
		_boss_phases.attach(self)
		EventBus.boss_health_changed.emit(health.current, health.max_health)
	elif not near and _boss_phases != null and global_position.distance_to(player.global_position if player != null else global_position) > data.leash_radius:
		EventBus.boss_ended.emit(self, false)
		_boss_phases.queue_free()
		_boss_phases = null


# --- Lock-on interface ---------------------------------------------------------------

func is_lockable() -> bool:
	return not health.is_dead()


func get_lock_point() -> Vector3:
	return global_position + Vector3.UP * 1.0


# --- Helpers used by states ------------------------------------------------------------

## Player, or a minion when one is clearly closer (Summoner / Necromancer armies).
func get_target() -> Node3D:
	var best: Node3D = null
	var best_d: float = INF
	var player: Player = GameState.player as Player
	if player != null and is_instance_valid(player) and not player.health.is_dead() and not player.stats.has_buff(&"stealth"):
		best = player
		best_d = global_position.distance_to(player.global_position)
	for node: Node in get_tree().get_nodes_in_group(Minion.GROUP):
		var m: Minion = node as Minion
		if m == null or not m.is_alive():
			continue
		var d: float = global_position.distance_to(m.global_position) + m.aggro_bias_m
		if d < best_d and d < data.aggro_radius:
			best = m
			best_d = d
	return best


func distance_to_target() -> float:
	var target: Node3D = get_target()
	return INF if target == null else global_position.distance_to(target.global_position)


func distance_from_home() -> float:
	return global_position.distance_to(home)


func move_toward_point(point: Vector3, speed: float, delta: float) -> void:
	var to: Vector3 = point - global_position
	to.y = 0.0
	var desired: Vector3 = to.normalized() * speed if to.length() > 0.2 else Vector3.ZERO
	velocity = MovementMath.approach_horizontal(velocity, desired, 30.0, delta)
	face_point(point, delta)


func stop(delta: float) -> void:
	velocity = MovementMath.approach_horizontal(velocity, Vector3.ZERO, 30.0, delta)


func face_point(point: Vector3, delta: float) -> void:
	var to: Vector3 = point - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return
	visual.rotation.y = lerp_angle(visual.rotation.y, MovementMath.yaw_for_direction(to), 1.0 - exp(-TURN_SPEED * delta))


func get_facing() -> Vector3:
	return -visual.global_basis.z


func apply_gravity_and_move(delta: float) -> void:
	velocity.y -= gravity * delta
	move_and_slide()


func request_attack_token() -> bool:
	var pool: AttackTokenPool = AttackTokenPool.find(self)
	return pool == null or pool.request(self)


func release_attack_token() -> void:
	var pool: AttackTokenPool = AttackTokenPool.find(self)
	if pool != null:
		pool.release(self)


func show_telegraph(progress: float) -> void:
	telegraph.visible = progress > 0.0
	var r: float = data.telegraph_radius * clampf(progress, 0.15, 1.0)
	telegraph.scale = Vector3(r, 1.0, r)
	var forward: Vector3 = get_facing() * (data.attack_hitbox_offset.length() * 0.8)
	telegraph.global_position = global_position + Vector3(forward.x, 0.05, forward.z)


# --- Hits ----------------------------------------------------------------------------

## Damage of this enemy's blows and shots (projectiles call it too).
func build_damage_for(target: HurtboxComponent) -> DamageInfo:
	return _build_damage(target)


var _aim_line: MeshInstance3D = null


## Ranged sight line (EnemyRanged); hidden with `progress` < 0.
func show_aim_line(to: Vector3, progress: float, locked: bool) -> void:
	if _aim_line == null:
		_aim_line = EnemyRanged.make_line()
		add_child(_aim_line)
	if progress < 0.0:
		_aim_line.visible = false
		return
	EnemyRanged.update_line(_aim_line, EnemyRanged.muzzle(self), to, progress, locked)


func _build_damage(target: HurtboxComponent) -> DamageInfo:
	var defender: CombatStats = target.stats if target.stats != null else CombatStats.new()
	var info: DamageInfo = DamageCalculator.resolve(stats, defender, data.attack_multiplier,
		stats.element, rng)
	info.stagger = data.attack_stagger
	var push: Vector3 = target.global_position - global_position
	push.y = 0.0
	info.knockback = push.normalized() * data.attack_knockback
	info.launch = data.attack_launch
	info.poison_chance = data.attack_poison
	info.poison_share = data.poison_share
	info.poison_s = data.poison_s
	return info


func _on_damaged(info: DamageInfo) -> void:
	if asleep:
		asleep = false
		state_machine.process_mode = Node.PROCESS_MODE_INHERIT
	last_hit = info
	_since_hit = 0.0
	_poise_damage += info.stagger
	_flash()
	velocity += Vector3(info.knockback.x, 0.0, info.knockback.z)
	if health.is_dead():
		return
	if _poise_damage >= data.poise:
		_poise_damage = 0.0
		state_machine.transition_to(EnemyState.HURT)
	elif state_machine.get_state_name() in [EnemyState.IDLE, EnemyState.RETURN]:
		state_machine.transition_to(EnemyState.CHASE)


func _on_died() -> void:
	release_attack_token()
	if data.death_flag != &"":
		GameState.set_flag(data.death_flag)
	EventBus.enemy_killed.emit(data.id, global_position)
	EventBus.xp_gained.emit(xp_reward)
	EventBus.gold_gained.emit(gold_reward)
	_drop_loot()
	state_machine.transition_to(EnemyState.DEAD)


func _drop_loot() -> void:
	if not data.drops_loot or GameState.items == null:
		return
	var drops: Array[ItemStack] = LootDropper.roll(data.level, data.tier, GameState.items, rng)
	for i: int in drops.size():
		var offset: Vector3 = Vector3(cos(i * 2.1), 0.0, sin(i * 2.1)) * 0.9
		WorldPickup.spawn.call_deferred(get_parent(), global_position + offset, drops[i])


## Tier sizes: normal, elite, boss.
const TIER_SIZE: Array[float] = [1.0, 1.25, 1.7]

var creature: CreatureBody = null


func _setup_visuals() -> void:
	var body_material: StandardMaterial3D = StandardMaterial3D.new()
	body_material.albedo_color = data.body_color
	body_mesh.material_override = body_material
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.albedo_color = Color(1, 1, 1, 0)
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	body_mesh.material_overlay = _flash_material
	telegraph.visible = false
	# Procedural creature replaces the capsule (collision stays the capsule).
	creature = CreatureBody.new()
	creature.name = "Creature"
	visual.add_child(creature)
	var element: int = data.stats.element if data.stats != null else 0
	var eye: Color = Element.COLORS.get(element as Element.Type, Color(1, 0.3, 0.2)) if element != 0 else Color(1, 0.3, 0.2)
	var size: float = TIER_SIZE[clampi(data.tier, 0, 2)]
	if not creature.build_rigged(data.id, CreatureBody.shape_for(data.id), size) \
			and not creature.build_model(StringName("mob_" + String(data.id)), CreatureBody.shape_for(data.id), size):
		creature.build(CreatureBody.shape_for(data.id), data.body_color, eye, size)
	creature.set_overlay(_flash_material)
	body_mesh.visible = false
	var eye_node: Node3D = visual.get_node_or_null(^"Eye") as Node3D
	if eye_node != null:
		eye_node.visible = false
	limit_draw_distance(self, data.tier)


## Far monsters are not drawn (and cast no shadow): small ones from 35 % of the preset's
## view distance (at least 70 m), bosses from twice that. They sleep beyond 60 m anyway.
static func limit_draw_distance(root: Node, tier: int) -> void:
	var view: float = Settings.profile.view_distance_m if Settings.profile != null else 400.0
	var reach: float = maxf(70.0, view * 0.35) * (2.0 if tier == EnemyScaling.Tier.BOSS else 1.0)
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var g: GeometryInstance3D = node as GeometryInstance3D
		if g.visibility_range_end <= 0.0 or g.visibility_range_end > reach:
			g.visibility_range_end = reach
			g.visibility_range_end_margin = 8.0


func _flash() -> void:
	_flash_material.albedo_color.a = 0.85
	var tween: Tween = create_tween()
	tween.tween_property(_flash_material, ^"albedo_color:a", 0.0, HIT_FLASH_S)


func _update_label() -> void:
	info_label.text = "%s  Lv %d" % [data.display_name, data.level]
	health_bar.set_ratio(health.get_ratio())
