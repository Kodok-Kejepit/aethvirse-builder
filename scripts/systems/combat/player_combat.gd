class_name PlayerCombat
extends Node
## Player-side combat: attack input buffers, combo chaining, damage building, hit feedback,
## perfect dodge → counter, combo rank. Movement/state flow stays in Player + states.

const ACTION_LIGHT: StringName = &"attack_light"
const ACTION_HEAVY: StringName = &"attack_heavy"

@export var player: Player
@export var combo: ComboData
@export var stats: CombatStats
@export var hitbox: HitboxComponent
@export var hitbox_shape: CollisionShape3D
@export var weapon_pivot: Node3D
@export_group("Tuning")
@export var input_buffer_s: float = 0.25
@export var perfect_dodge_window_s: float = 0.15
@export var perfect_dodge_time_scale: float = 0.25
@export var perfect_dodge_slowmo_s: float = 0.5
@export var counter_window_s: float = 1.5
@export var counter_bonus: float = 1.5
@export var combo_timeout_s: float = 3.0
@export var heavy_shake: float = 0.25

## Attack chosen by consume_attack() / queue_skill(), read by the Attack state on enter.
var pending_attack: AttackData = null
var current_attack: AttackData = null
## Set when the pending/current attack is a skill.
var pending_skill: SkillData = null
var current_skill: SkillData = null
var _pending_skill_level: int = 1
var _current_skill_level: int = 1
var _pending_combo: SkillComboData = null
var _current_combo: SkillComboData = null
var tracker: ComboTracker
## 0..1 over startup+active of the current attack (>1 = recovery); read by CharacterModel.
var swing_progress: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _light_buffer: float = 0.0
var _heavy_buffer: float = 0.0
var _last_attack: AttackData = null
var _chain_timer: float = 0.0
var _counter_timer: float = 0.0
var _dodge_started_at: float = -INF
const WEAPON_POISON_SHARE: float = 0.025
const WEAPON_POISON_S: float = 5.0


func _ready() -> void:
	EventBus.projectile_hit.connect(func(target: Node, info: RefCounted, applied: bool) -> void:
		var damage: DamageInfo = info as DamageInfo
		var hurtbox: HurtboxComponent = target as HurtboxComponent
		if damage != null and hurtbox != null and damage.source == player:
			_on_hit_landed(hurtbox, damage, applied))
	tracker = ComboTracker.new(combo_timeout_s)
	rng.randomize()
	hitbox.body = player
	hitbox.damage_builder = _build_damage
	hitbox.hit_landed.connect(_on_hit_landed)


func _physics_process(delta: float) -> void:
	var modifier: bool = Input.is_action_pressed(SkillCaster.MODIFIER_ACTION)
	if Input.is_action_just_pressed(ACTION_LIGHT) and not modifier:
		_light_buffer = input_buffer_s
	if Input.is_action_just_pressed(ACTION_HEAVY) and not modifier:
		_heavy_buffer = input_buffer_s
	_light_buffer = maxf(_light_buffer - delta, 0.0)
	_heavy_buffer = maxf(_heavy_buffer - delta, 0.0)
	_chain_timer = maxf(_chain_timer - delta, 0.0)
	_counter_timer = maxf(_counter_timer - delta, 0.0)
	if tracker.count > 0 and not tracker.is_active(_now()):
		tracker.break_combo()
		EventBus.combo_changed.emit(0, ComboTracker.Rank.NONE)


func has_attack_input() -> bool:
	return _light_buffer > 0.0 or _heavy_buffer > 0.0


## Picks the next attack from the buffered input (heavy wins) and stores it in pending_attack.
func consume_attack() -> bool:
	if not has_attack_input():
		return false
	var heavy: bool = _heavy_buffer > 0.0
	_light_buffer = 0.0
	_heavy_buffer = 0.0
	var previous: AttackData = current_attack if current_attack != null else (_last_attack if _chain_timer > 0.0 else null)
	pending_attack = combo.resolve_next(previous, heavy)
	pending_skill = null
	return pending_attack != null


func queue_skill(skill: SkillData, level: int, skill_combo: SkillComboData) -> void:
	pending_attack = skill.attack
	pending_skill = skill
	_pending_skill_level = level
	_pending_combo = skill_combo
	_light_buffer = 0.0
	_heavy_buffer = 0.0


## Skills may cancel normal attacks once the combo window opens (not other skills).
func can_cancel_into_skill() -> bool:
	return current_attack != null and current_skill == null


func begin_attack(attack: AttackData) -> void:
	current_attack = attack
	swing_progress = 0.0
	current_skill = pending_skill
	_current_skill_level = _pending_skill_level
	_current_combo = _pending_combo
	pending_attack = null
	pending_skill = null
	_pending_combo = null
	var box: BoxShape3D = hitbox_shape.shape as BoxShape3D
	box.size = attack.hitbox_size
	hitbox.position = attack.hitbox_offset
	var mesh: BoxMesh = hitbox.debug_mesh.mesh as BoxMesh if hitbox.debug_mesh != null else null
	if mesh != null:
		mesh.size = attack.hitbox_size


func set_hitbox_active(active: bool) -> void:
	if active and not hitbox.is_active():
		hitbox.activate()
	elif not active and hitbox.is_active():
		hitbox.deactivate()


func end_attack() -> void:
	set_hitbox_active(false)
	_last_attack = current_attack if current_skill == null else null
	_chain_timer = combo.chain_grace_s
	current_attack = null
	current_skill = null
	_current_combo = null
	reset_weapon_pose()


## Graybox weapon motion; `t` goes 0..1 over startup + active.
func update_swing(attack: AttackData, t: float) -> void:
	swing_progress = t
	var k: float = clampf(t, 0.0, 1.0)
	weapon_pivot.position = Vector3.ZERO
	match attack.swing:
		AttackData.Swing.HORIZONTAL:
			weapon_pivot.rotation = Vector3(0.0, lerpf(deg_to_rad(100.0), deg_to_rad(-100.0), k), 0.0)
		AttackData.Swing.VERTICAL:
			weapon_pivot.rotation = Vector3(lerpf(deg_to_rad(80.0), deg_to_rad(-70.0), k), 0.0, 0.0)
		AttackData.Swing.SPIN:
			weapon_pivot.rotation = Vector3(0.0, lerpf(0.0, -TAU, k), 0.0)
		AttackData.Swing.THRUST:
			weapon_pivot.rotation = Vector3.ZERO
			weapon_pivot.position = Vector3(0.0, 0.0, lerpf(0.6, -0.8, k))


func reset_weapon_pose() -> void:
	weapon_pivot.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(40.0), 0.0)
	weapon_pivot.position = Vector3.ZERO


func notify_dodge_started() -> void:
	_dodge_started_at = _now()


## Called when a hit lands while invulnerable.
func on_dodged_hit() -> void:
	if _now() - _dodge_started_at > perfect_dodge_window_s:
		return
	_counter_timer = counter_window_s
	TimeFx.slow_motion(perfect_dodge_time_scale, perfect_dodge_slowmo_s)
	EventBus.perfect_dodge.emit()


## Next hit is a guaranteed bonus crit (perfect dodge, breaking stealth).
func grant_counter() -> void:
	_counter_timer = counter_window_s


func is_counter_ready() -> bool:
	return _counter_timer > 0.0


func break_combo() -> void:
	tracker.break_combo()
	EventBus.combo_changed.emit(0, ComboTracker.Rank.NONE)


func _build_damage(target: HurtboxComponent) -> DamageInfo:
	return build_damage_for(target, current_attack, current_skill, _current_skill_level, _current_combo)


## Damage builder frozen to the current attack (projectiles land after the attack ended).
func make_builder() -> Callable:
	return build_damage_for.bind(current_attack, current_skill, _current_skill_level, _current_combo)


func build_damage_for(target: HurtboxComponent, attack: AttackData, skill: SkillData, skill_level: int,
		skill_combo: SkillComboData) -> DamageInfo:
	var counter: bool = is_counter_ready()
	var defender: CombatStats = target.stats if target.stats != null else CombatStats.new()
	var multiplier: float = attack.damage_multiplier
	var bonus: float = counter_bonus if counter else 1.0
	var force_crit: bool = counter
	var extra_stagger: float = 0.0
	if skill != null:
		multiplier = skill.multiplier_at(skill_level)
	if skill_combo != null:
		bonus *= skill_combo.bonus_multiplier
		force_crit = force_crit or skill_combo.force_crit
		extra_stagger = skill_combo.extra_stagger
	var info: DamageInfo = DamageCalculator.resolve(stats, defender, multiplier,
		attack.element, rng, force_crit, bonus)
	info.is_heavy = attack.is_heavy
	info.stagger = attack.stagger + extra_stagger
	info.hit_stop_s = attack.hit_stop_s
	var push: Vector3 = target.global_position - player.global_position
	push.y = 0.0
	info.knockback = push.normalized() * attack.knockback
	_apply_weapon_venom(info)
	return info


## Venom weapons (ItemData.on_hit_poison) poison what they cut.
func _apply_weapon_venom(info: DamageInfo) -> void:
	var weapon: ItemData = GameState.inventory.get_equipped_item(ItemData.Slot.WEAPON) if GameState.inventory != null else null
	if weapon != null and weapon.on_hit_poison > 0.0:
		info.poison_chance = weapon.on_hit_poison
		info.poison_share = WEAPON_POISON_SHARE
		info.poison_s = WEAPON_POISON_S


func fire_projectile(attack: AttackData, direction: Vector3) -> void:
	var from: Vector3 = player.global_position + Vector3.UP * 1.2 + direction * 0.8
	var target: Node3D = player.lock_on.target if player.lock_on.target != null and is_instance_valid(player.lock_on.target) else null
	Projectile.fire(player.get_parent(), from, direction, attack.projectile, make_builder(), player, target)


func _on_hit_landed(target: HurtboxComponent, info: DamageInfo, applied: bool) -> void:
	if not applied:
		return
	if is_counter_ready():
		_counter_timer = 0.0
	tracker.register_hit(_now())
	EventBus.combo_changed.emit(tracker.count, tracker.get_rank(_now()))
	EventBus.damage_number_requested.emit(target.global_position + Vector3.UP * 1.8, info.amount,
		info.is_crit, info.element, false)
	TimeFx.hit_stop(info.hit_stop_s)
	if info.is_heavy and player.camera_rig != null:
		player.camera_rig.shake(heavy_shake)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
