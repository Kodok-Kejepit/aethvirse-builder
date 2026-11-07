class_name Minion
extends CharacterBody3D
## A summoned ally (graybox capsule): follows the player, hunts the nearest enemy within its
## leash and hits it with a share of the player's attack. Enemies may target it; it has its
## own HP (share of the owner's) and vanishes when it drops (shadows return to the army).

const FOLLOW_DISTANCE: float = 2.5
const TURN_SPEED: float = 10.0
const GRAVITY: float = 9.8
const GROUP: StringName = &"minions"
## Physics layer of the player hurtbox (enemy hitboxes scan it).
const HURTBOX_LAYER: int = 8

var data: SummonData
var owner_player: Player
## Multiplies `data.power` (shadow soldier tier, skill level).
var power_scale: float = 1.0
## Shadow soldiers carry the enemy they came from.
var label_text: String = ""
var _attack_timer: float = 0.0
var _life: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _follow_offset: Vector3 = Vector3.ZERO
var health: HealthComponent
var hurtbox: HurtboxComponent
## Shadow soldiers: roster uid (gains XP/ranks) and rank (abilities). -1 = not a shadow.
var shadow_uid: int = -1
var rank: int = 0
## How much closer than the player this minion must be to draw aggro (negative = taunts).
var aggro_bias_m: float = 2.0


static func create(summon: SummonData, player: Player, scale_power: float, label: String) -> Minion:
	var m: Minion = Minion.new()
	m.data = summon
	m.owner_player = player
	m.power_scale = scale_power
	m.label_text = label
	return m


func _ready() -> void:
	_rng.randomize()
	collision_layer = 0
	collision_mask = 1
	_life = data.duration_s
	var angle: float = _rng.randf_range(0.0, TAU)
	_follow_offset = Vector3(cos(angle), 0.0, sin(angle)) * FOLLOW_DISTANCE
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.3 * data.height
	capsule.height = data.height
	shape.shape = capsule
	shape.position.y = data.height * 0.5
	add_child(shape)
	_build_hurtbox(capsule)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var capsule_mesh: CapsuleMesh = CapsuleMesh.new()
	capsule_mesh.radius = capsule.radius
	capsule_mesh.height = data.height
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = data.body_color
	mat.emission_enabled = true
	mat.emission = data.body_color
	mat.emission_energy_multiplier = 0.6
	if data.body_color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	capsule_mesh.material = mat
	mesh.mesh = capsule_mesh
	mesh.position.y = data.height * 0.5
	add_child(mesh)
	if label_text != "":
		var label: Label3D = Label3D.new()
		label.text = label_text
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 36
		label.modulate = data.body_color.lightened(0.4)
		label.position.y = data.height + 0.4
		add_child(label)


func _build_hurtbox(capsule: CapsuleShape3D) -> void:
	health = HealthComponent.new()
	health.name = "Health"
	var owner_max: int = owner_player.health.max_health if owner_player != null else 100
	health.max_health = maxi(1, roundi(float(owner_max) * data.hp_share))
	add_child(health)
	health.died.connect(queue_free)
	hurtbox = HurtboxComponent.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = HURTBOX_LAYER
	hurtbox.collision_mask = 0
	hurtbox.health = health
	hurtbox.body = self
	hurtbox.stats = owner_player.combat.stats if owner_player != null else CombatStats.new()
	var hshape: CollisionShape3D = CollisionShape3D.new()
	hshape.shape = capsule
	hshape.position.y = data.height * 0.5
	hurtbox.add_child(hshape)
	add_child(hurtbox)
	hurtbox.hit_received.connect(func(info: DamageInfo) -> void:
		EventBus.damage_number_requested.emit(global_position + Vector3.UP * data.height, info.amount, info.is_crit, info.element, true))


func is_alive() -> bool:
	return health != null and not health.is_dead()


func _physics_process(delta: float) -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		queue_free()
		return
	if data.duration_s > 0.0:
		_life -= delta
		if _life <= 0.0:
			queue_free()
			return
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	var target: Enemy = find_target()
	var goal: Vector3 = owner_player.global_position + _follow_offset
	if target != null:
		goal = target.global_position
		if _flat_distance(target.global_position) <= data.attack_range:
			_face(target.global_position, delta)
			_try_hit(target)
			goal = global_position
	_move_to(goal, delta)
	if global_position.distance_to(owner_player.global_position) > data.leash_m * 2.0:
		global_position = owner_player.global_position + _follow_offset


func find_target() -> Enemy:
	var best: Enemy = null
	var best_d: float = data.leash_m
	for node: Node in get_tree().get_nodes_in_group(LockOnTargeter.GROUP):
		var enemy: Enemy = node as Enemy
		if enemy == null or enemy.health.is_dead():
			continue
		var d: float = enemy.global_position.distance_to(owner_player.global_position)
		if d < best_d:
			best_d = d
			best = enemy
	return best


const CLEAVE_RADIUS_M: float = 2.5
const TAUNT_BIAS_M: float = -3.0


## Applies a shadow's rank: power, HP, taunt, attack speed.
func apply_rank(new_rank: int) -> void:
	rank = new_rank
	if rank >= ShadowArmy.RANK_TAUNT:
		aggro_bias_m = TAUNT_BIAS_M


func _try_hit(target: Enemy) -> void:
	if _attack_timer > 0.0 or owner_player.combat.stats == null:
		return
	_attack_timer = data.attack_interval_s * (0.75 if rank >= ShadowArmy.RANK_MARSHAL else 1.0)
	_strike(target, 1.0)
	if rank >= ShadowArmy.RANK_CLEAVE:
		for node: Node in get_tree().get_nodes_in_group(LockOnTargeter.GROUP):
			var other: Enemy = node as Enemy
			if other != null and other != target and not other.health.is_dead() \
					and other.global_position.distance_to(target.global_position) <= CLEAVE_RADIUS_M:
				_strike(other, 0.5 if rank < ShadowArmy.RANK_MARSHAL else 0.75)


func _strike(target: Enemy, share: float) -> void:
	var info: DamageInfo = DamageCalculator.resolve(owner_player.combat.stats, target.stats,
		data.power * power_scale * share, data.element, _rng)
	info.source = self
	info.hit_position = target.global_position + Vector3.UP
	var was_alive: bool = not target.health.is_dead()
	target.hurtbox.receive(info)
	EventBus.damage_number_requested.emit(info.hit_position, info.amount, info.is_crit, data.element, false)
	if was_alive and target.health.is_dead():
		EventBus.summon_killed_enemy.emit(data.id)
		_gain_xp(target)


func _gain_xp(prey: Enemy) -> void:
	if shadow_uid < 0:
		return
	var new_rank: int = GameState.shadows.add_xp(shadow_uid, ShadowArmy.kill_xp(prey.data.tier))
	if new_rank < 0:
		return
	power_scale *= ShadowArmy.rank_power(new_rank) / ShadowArmy.rank_power(rank)
	apply_rank(new_rank)
	Codex.notify(tr(&"SHADOW_RANK_UP") % [label_text, tr(StringName("SHADOW_RANK_%d" % new_rank))], &"anomaly")


func _move_to(goal: Vector3, delta: float) -> void:
	var to: Vector3 = goal - global_position
	to.y = 0.0
	var speed: float = data.move_speed * (1.4 if to.length() > 6.0 else 1.0)
	var vel: Vector3 = to.normalized() * speed if to.length() > 0.4 else Vector3.ZERO
	velocity.x = vel.x
	velocity.z = vel.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	if vel != Vector3.ZERO:
		_face(global_position + vel, delta)
	move_and_slide()


func _face(point: Vector3, delta: float) -> void:
	var dir: Vector3 = point - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(TURN_SPEED * delta, 1.0))


func _flat_distance(point: Vector3) -> float:
	return Vector2(point.x - global_position.x, point.z - global_position.z).length()
