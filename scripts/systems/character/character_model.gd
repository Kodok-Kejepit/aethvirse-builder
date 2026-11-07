class_name CharacterModel
extends Node3D
## Visual body of the player: builds a CharacterRig, picks a pose from the player state every
## frame (CharacterPoses), blends it in, drives the hair/sash springs and summons the
## SpiritDragon on skills (never on basic attacks). Pure presentation: no gameplay effect.

const BLEND_RATE: float = 14.0
const ATTACK_BLEND_RATE: float = 32.0
const WALK_STRIDE_M: float = 1.4
const RUN_STRIDE_M: float = 2.5
const FIDGET_AFTER_S: float = 7.0
const FIDGET_S: float = 2.6
const LAND_S: float = 0.24
const OVERLAY_SUMMON_S: float = 0.8
const OVERLAY_VICTORY_S: float = 1.6
## Run speed shown on preview stages (no player).
const PREVIEW_RUN_SPEED: float = 4.6

var player: Player
var rig: CharacterRig
## Pose shown instead of the live one (showcase / `pose` cheat); &"" = live.
var forced_pose: StringName = &""
## 0..1 through a forced one-shot pose (skill previews); < 0 = loop on its own.
var forced_progress: float = -1.0
## Name of the pose chosen this frame (debug / tests).
var pose_name: StringName = &"idle"
var dragon: SpiritDragon = null
var hero: HeroData = null
var trail: WeaponTrail = null
## Non-null when the hero has an imported (skinned) body.
var body: ImportedBody = null
## Non-null when the hero has an animated rig (owner's Mixamo animations).
var animated: AnimatedBody = null

var _pose: Dictionary[StringName, Vector3] = CharacterPoses.empty()
var _time: float = 0.0
var _phase: float = 0.0
var _state: StringName = &""
var _state_time: float = 0.0
var _idle_time: float = 0.0
var _land_timer: float = 0.0
var _land_strength: float = 0.0
var _last_vy: float = 0.0
var _overlay: StringName = &""
var _overlay_timer: float = 0.0
var _overlay_length: float = 1.0
var _last_yaw: float = 0.0
var _showcase: bool = false
var _showcase_index: int = -1
var _showcase_timer: float = 0.0
var _showcase_step: float = 2.4
var _label: Label3D = null


## `lite` = phone meshes/textures; `outline` = inverted-hull outline pass (doubles triangles).
func setup(owner_player: Player, weapon: CharacterRig.Weapon, lite: bool, hero_data: HeroData = null, outline: int = -1) -> void:
	var with_outline: bool = (not lite) if outline < 0 else outline == 1
	player = owner_player
	hero = hero_data
	name = "CharacterModel"
	rig = CharacterRig.new()
	rig.name = "Rig"
	add_child(rig)
	if hero != null and hero.has_rig():
		animated = AnimatedBody.new()
		add_child(animated)
		animated.setup(rig, load(hero.rig_scene) as PackedScene, load(hero.rig_albedo) as Texture2D, with_outline)
		animated.weapon = weapon
		rig.build_skeleton_only(weapon, animated.joint_rest(), with_outline)
	elif hero != null and hero.has_imported_model():
		var mesh: ArrayMesh = hero.body_mesh(lite)
		var rest: Dictionary = mesh.get_meta(&"joints", {})
		rig.build_skeleton_only(weapon, rest, with_outline)
		body = ImportedBody.new()
		rig.add_child(body)
		body.setup(rig, mesh, hero.body_texture(lite), hero.body_normal(lite), with_outline)
	else:
		rig.build(weapon, with_outline, hero)
	if player != null and rig.weapon_tip != null:
		trail = WeaponTrail.new()
		add_child(trail)
		var hand: Node3D = rig.get_joint(&"hand_l" if rig.weapon == CharacterRig.Weapon.BOW else &"hand_r")
		trail.setup(hand, rig.weapon_tip)
	if player != null:
		var gear: EquipmentVisuals = EquipmentVisuals.new()
		rig.add_child(gear)
		gear.setup(rig)
	EventBus.skill_used.connect(_on_skill_used)
	if animated != null:
		EventBus.player_respawned.connect(animated.reset_springs)
	EventBus.level_up.connect(func(_level: int) -> void: play_overlay(&"victory", OVERLAY_VICTORY_S))


func _process(delta: float) -> void:
	_time += delta
	if _showcase:
		_tick_showcase(delta)
	var target: Dictionary[StringName, Vector3] = _target_pose(delta)
	if animated != null:
		_drive_animated(delta)
		return
	var attacking: bool = _state == PlayerState.ATTACK and forced_pose == &""
	var weight: float = 1.0 - exp(-(ATTACK_BLEND_RATE if attacking else BLEND_RATE) * delta)
	var target_root: Vector3 = target[CharacterPoses.ROOT]
	var current_root: Vector3 = _pose[CharacterPoses.ROOT]
	_pose = CharacterPoses.blend(_pose, target, weight)
	if absf(target_root.y) > 1.0:
		# Spins are authored as full turns: follow them exactly instead of easing.
		_pose[CharacterPoses.ROOT] = Vector3(current_root.x, target_root.y, current_root.z).lerp(target_root, weight)
	else:
		var root: Vector3 = _pose[CharacterPoses.ROOT]
		root.y = wrapf(root.y, -180.0, 180.0)
		_pose[CharacterPoses.ROOT] = root
	apply_pose(_pose)
	_update_trail()
	if body != null:
		body.sync_from_rig()
	_update_chains(delta)


## Imported (auto-skinned) bodies have sleeves/robes fused to the torso: wide arm spreads
## stretch them, so sideways arm angles are damped.
const IMPORTED_ARM_SPREAD: float = 0.5


func apply_pose(pose: Dictionary[StringName, Vector3]) -> void:
	for id: StringName in rig.joints:
		var rot: Vector3 = pose.get(id, Vector3.ZERO)
		if body != null and (id == &"arm_r" or id == &"arm_l"):
			rot.z *= IMPORTED_ARM_SPREAD
		rig.joints[id].rotation = rot * (PI / 180.0)
	var lift: Vector3 = pose.get(CharacterPoses.LIFT, Vector3.ZERO)
	rig.joints[&"hips"].position = rig.rest_positions[&"hips"] + lift
	var root: Vector3 = pose.get(CharacterPoses.ROOT, Vector3.ZERO)
	rig.rotation = root * (PI / 180.0)


func _update_trail() -> void:
	if trail == null or player == null:
		return
	var attack: AttackData = player.combat.current_attack
	var on: bool = attack != null and attack.projectile == null and player.combat.swing_progress > 0.25 \
		and player.combat.swing_progress < 1.15
	trail.active = on
	if on:
		var skill: SkillData = player.combat.current_skill
		trail.color = skill.icon_color if skill != null else Color(0.65, 0.85, 1.0)


func play_overlay(id: StringName, seconds: float) -> void:
	_overlay = id
	_overlay_timer = seconds
	_overlay_length = seconds


func has_dragon() -> bool:
	return hero == null or hero.has_dragon


## Spawns the spirit dragon (replacing one still on screen).
func summon_dragon(ultimate: bool) -> SpiritDragon:
	if dragon != null and is_instance_valid(dragon):
		dragon.queue_free()
	dragon = SpiritDragon.new()
	AudioManager.play_sfx(&"dragon")
	dragon.name = "SpiritDragon"
	add_child(dragon)
	dragon.setup(ultimate)
	return dragon


## Cycles through every named pose with a floating caption (`pose auto`).
func start_showcase(seconds_each: float = 2.4) -> void:
	_showcase = true
	_showcase_index = -1
	_showcase_timer = 0.0
	_showcase_step = seconds_each
	if _label == null:
		_label = Label3D.new()
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.font_size = 64
		_label.outline_size = 12
		_label.position = Vector3(0.0, 2.3, 0.0)
		_label.no_depth_test = true
		add_child(_label)
	_label.visible = true


func stop_showcase() -> void:
	_showcase = false
	forced_pose = &""
	if _label != null:
		_label.visible = false


func _tick_showcase(delta: float) -> void:
	_showcase_timer -= delta
	if _showcase_timer > 0.0:
		return
	_showcase_timer = _showcase_step
	_showcase_index += 1
	if _showcase_index >= CharacterPoses.NAMES.size():
		stop_showcase()
		return
	forced_pose = CharacterPoses.NAMES[_showcase_index]
	_time = 0.0
	_label.text = String(forced_pose).to_upper()
	if has_dragon() and (forced_pose == &"cast" or forced_pose == &"summon" or forced_pose == &"ultimate"):
		summon_dragon(forced_pose == &"ultimate")


func _on_skill_used(skill_id: StringName) -> void:
	if player == null or player.stats == null:
		return
	var skill: SkillData = player.stats.find_skill(skill_id)
	if skill == null:
		return
	if has_dragon():
		summon_dragon(skill.is_ultimate)
	if skill.is_instant() or skill.kind == SkillData.Kind.BUFF:
		play_overlay(&"summon", OVERLAY_SUMMON_S)


## Animated rig: the same pose choice, played from the owner's animations.
func _drive_animated(delta: float) -> void:
	var swing: int = 0
	var progress: float = fmod(_time, 1.0)
	var speed: float = 0.0
	if player != null:
		speed = player.get_horizontal_speed()
		match pose_name:
			&"attack", &"shoot", &"cast":
				var attack: AttackData = player.combat.current_attack
				swing = attack.swing if attack != null else 0
				var skill: SkillData = player.combat.current_skill
				if skill != null:
					swing = AnimatedBody.SWING_ULTIMATE if skill.is_ultimate else AnimatedBody.SWING_CAST
				progress = player.combat.swing_progress
			&"jump", &"fall":
				progress = 1.0 - clampf(absf(player.velocity.y) / 6.0, 0.0, 1.0) if pose_name == &"jump" else clampf(-player.velocity.y / 8.0, 0.0, 1.0)
			&"hurt":
				progress = _state_time / 0.35
			&"dead":
				progress = _state_time
			&"dodge":
				progress = _state_time / maxf(player.movement.dodge_duration_s, 0.01)
	elif pose_name == &"run":
		speed = PREVIEW_RUN_SPEED
	if player == null and (pose_name == &"cast" or pose_name == &"summon" or pose_name == &"victory"):
		swing = AnimatedBody.SWING_CAST
	elif pose_name == &"slash":
		swing = 0
	if forced_pose != &"" and forced_progress >= 0.0:
		progress = forced_progress
	if _overlay_timer > 0.0 and (pose_name == &"summon" or pose_name == &"victory"):
		progress = 1.0 - _overlay_timer / _overlay_length
	animated.drive(pose_name, swing, progress, speed, delta)
	animated.sync_to_rig()
	_update_trail()


# --- pose selection ----------------------------------------------------------------------

func _target_pose(delta: float) -> Dictionary[StringName, Vector3]:
	var weapon: int = rig.weapon
	if forced_pose != &"":
		pose_name = forced_pose
		return CharacterPoses.named(forced_pose, _time, weapon)
	if player == null:
		pose_name = &"idle"
		return CharacterPoses.idle(sin(_time * 2.2))
	var state: StringName = player.state_machine.get_state_name()
	if state != _state:
		if _state == PlayerState.AIR and (state == PlayerState.IDLE or state == PlayerState.MOVE):
			_land_timer = LAND_S
			_land_strength = clampf(-_last_vy / 10.0, 0.25, 1.0)
		_state = state
		_state_time = 0.0
	_state_time += delta
	_last_vy = player.velocity.y
	_overlay_timer = maxf(_overlay_timer - delta, 0.0)
	_land_timer = maxf(_land_timer - delta, 0.0)
	match state:
		PlayerState.DEAD:
			pose_name = &"dead"
			return CharacterPoses.dead(_state_time)
		PlayerState.HURT:
			pose_name = &"hurt"
			return CharacterPoses.hurt(_state_time / 0.35)
		PlayerState.DODGE:
			pose_name = &"dodge"
			return CharacterPoses.dodge(_state_time / maxf(player.movement.dodge_duration_s, 0.01))
		PlayerState.AIR:
			pose_name = &"jump" if player.velocity.y > 0.0 else &"fall"
			return CharacterPoses.air(clampf(player.velocity.y / 6.0 + 0.5, 0.0, 1.0))
		PlayerState.ATTACK:
			return _attack_pose(delta, weapon)
	return _ground_pose(delta)


func _ground_pose(delta: float) -> Dictionary[StringName, Vector3]:
	var speed: float = player.get_horizontal_speed()
	var base: Dictionary[StringName, Vector3]
	if speed > 0.3:
		_idle_time = 0.0
		base = _locomotion(delta, speed)
	else:
		_idle_time += delta
		var breath: float = sin(_time * 2.2)
		var cycle: float = fmod(_idle_time, FIDGET_AFTER_S + FIDGET_S)
		if _idle_time > FIDGET_AFTER_S and cycle < FIDGET_S:
			pose_name = &"fidget"
			var w: float = sin(cycle / FIDGET_S * PI)
			base = CharacterPoses.blend(CharacterPoses.idle(breath), CharacterPoses.fidget(breath), clampf(w * 1.6, 0.0, 1.0))
		else:
			pose_name = &"idle"
			base = CharacterPoses.idle(breath)
	if _land_timer > 0.0:
		var k: float = _land_timer / LAND_S
		base = CharacterPoses.blend(base, CharacterPoses.land(_land_strength), k)
		pose_name = &"land"
	if _overlay_timer > 0.0:
		var fade: float = clampf(minf(_overlay_timer, _overlay_length - _overlay_timer) / 0.15, 0.0, 1.0)
		var over: Dictionary[StringName, Vector3] = CharacterPoses.victory() if _overlay == &"victory" else CharacterPoses.summon()
		if speed > 0.3:
			over = _with_lower(over, base)
		base = CharacterPoses.blend(base, over, fade)
		pose_name = _overlay
	return base


func _locomotion(delta: float, speed: float) -> Dictionary[StringName, Vector3]:
	var m: PlayerMovementData = player.movement
	var gait: float = clampf((speed - m.walk_speed) / maxf(m.run_speed - m.walk_speed, 0.01), 0.0, 1.0)
	if player.is_sprinting:
		gait = 1.0 + clampf((speed - m.run_speed) / maxf(m.sprint_speed - m.run_speed, 0.01), 0.0, 1.0)
	var stride: float = lerpf(WALK_STRIDE_M, RUN_STRIDE_M, minf(gait, 1.0))
	_phase = fmod(_phase + delta * speed / stride * TAU, TAU)
	pose_name = &"walk" if gait < 0.5 else (&"sprint" if gait > 1.5 else &"run")
	return CharacterPoses.locomotion(_phase, gait)


func _attack_pose(delta: float, weapon: int) -> Dictionary[StringName, Vector3]:
	var attack: AttackData = player.combat.current_attack
	if attack == null:
		pose_name = &"idle"
		return CharacterPoses.idle()
	var skill: SkillData = player.combat.current_skill
	var ranged: bool = attack.projectile != null
	pose_name = &"cast" if skill != null else (&"shoot" if ranged else &"attack")
	var pose: Dictionary[StringName, Vector3] = CharacterPoses.attack(attack.swing, player.combat.swing_progress, ranged, skill != null, weapon)
	var speed: float = player.get_horizontal_speed()
	if speed > 1.0 and attack.swing != AttackData.Swing.SPIN and player.has_move_input():
		pose = _with_lower(pose, _locomotion(delta, speed))
	return pose


static func _with_lower(upper: Dictionary[StringName, Vector3], lower: Dictionary[StringName, Vector3]) -> Dictionary[StringName, Vector3]:
	var out: Dictionary[StringName, Vector3] = upper.duplicate()
	for k: StringName in CharacterPoses.LOWER:
		out[k] = lower.get(k, Vector3.ZERO)
	return out


# --- hair & sashes -----------------------------------------------------------------------

func _update_chains(delta: float) -> void:
	if delta <= 0.0:
		return
	var frame: Basis = rig.global_basis.orthonormalized()
	var velocity: Vector3 = player.velocity if player != null else Vector3.ZERO
	var local_v: Vector3 = frame.inverse() * velocity
	var yaw: float = global_rotation.y
	var yaw_rate: float = wrapf(yaw - _last_yaw, -PI, PI) / delta
	_last_yaw = yaw
	var forward: float = -local_v.z
	var fall: float = clampf(-velocity.y, 0.0, 12.0)
	var thigh_push: float = maxf(maxf(_pose[&"thigh_r"].x, _pose[&"thigh_l"].x), 0.0)
	var step: float = minf(delta, 1.0 / 30.0)
	for c: CharacterRig.Chain in rig.chains:
		var drag_x: float = clampf(-forward * 7.0 - fall * 4.0, -70.0, 25.0) * c.drag
		var drag_side: float = clampf(-local_v.x * 6.0 - yaw_rate * 6.0, -40.0, 40.0) * c.drag
		var push: float = thigh_push * 0.85 if c.front else 0.0
		for i: int in c.joints.size():
			var grow: float = 1.0 + float(i) * 0.25
			var wind: float = sin(_time * 1.7 + c.phase_seed + float(i) * 0.55) * 2.5
			var target: Vector2 = c.rest[i] + Vector2(drag_x * grow + push + wind, drag_side * grow)
			var k: float = c.stiffness / (1.0 + float(i) * 0.3)
			var accel: Vector2 = (target - c.angle[i]) * k - c.velocity[i] * c.damping
			c.velocity[i] += accel * step
			c.angle[i] += c.velocity[i] * step
			var a: Vector2 = c.angle[i]
			c.joints[i].global_basis = frame * Basis.from_euler(Vector3(deg_to_rad(a.x), 0.0, deg_to_rad(a.y)))
