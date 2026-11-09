class_name AnimatedBody
extends Node3D
## Animated hero body (tools/import_hero_glb.gd output): plays the owner's animations
## from the pose CharacterModel picks, simulates hair and cloth chains with
## SpringBoneSimulator3D, and copies hand/body bones back into CharacterRig's joints so
## weapons, gear, trails and the spirit dragon keep working unchanged.

## Attack swings (AttackData.Swing order): [clip, start s, end s] of the move itself.
const SWINGS: Array[Array] = [
	[&"Slash", 0.15, 1.25], [&"Skill", 0.0, 1.45], [&"Dodge", 0.0, 1.1], [&"Slash", 0.55, 1.35],
]
const SKILL_CAST: Array = [&"Cast", 0.2, 2.2]
const ULTIMATE: Array = [&"Skill", 0.0, 1.6]
## Dagger heroes (rig has DaggerCombo, Meshy dagger clips): each swing is one strike of a
## combo clip, cut around the strike times measured from the arm speed.
const DAGGER_CLIP: StringName = &"DaggerCombo"
const DAGGER_SWINGS: Array[Array] = [
	[&"DaggerCombo", 0.25, 1.0], [&"DaggerCombo", 1.05, 1.75], [&"BladeSpin", 0.4, 1.3], [&"DaggerThrust", 0.35, 1.05],
]
const DAGGER_CAST: Array = [&"DaggerCombo2", 0.7, 3.9]
const DAGGER_ULTIMATE: Array = [&"BladeSpin", 0.4, 2.0]
const BOW_SHOT: Array = [&"Archery", 0.8, 2.6]
const STAFF_SHOT: Array = [&"Cast", 0.2, 1.3]
## Swing index CharacterModel passes for skill casts / ultimates.
const SWING_CAST: int = 10
const SWING_ULTIMATE: int = 11
const JUMP_RISE: Vector2 = Vector2(0.55, 0.8)
const JUMP_FALL: Vector2 = Vector2(0.84, 1.08)
const BLEND_S: float = 0.2
## Hair springs restart instead of whipping after teleports, respawns, hitches or snaps.
const SPRING_TELEPORT_M: float = 1.5
const SPRING_HITCH_S: float = 0.1
const SPRING_SNAP_RAD: float = 0.35
const SPRING_SETTLE_FRAMES: int = 3
const ATTACK_BLEND_S: float = 0.1
## Ground speed (m/s) at which each loop plays at 1x.
const WALK_ANIM_SPEED: float = 1.6
const RUN_ANIM_SPEED: float = 4.6
const SPRINT_ANIM_SPEED: float = 7.0
const DODGE_ANIM_SCALE: float = 1.8
const HURT_TILT_DEG: float = 14.0
const DEAD_TILT_DEG: float = 82.0

## Calm standing loop; every IDLE_FIDGET_S seconds one fidget plays once (stretch, look
## left / right), never the same twice in a row.
const ANIM_IDLE: StringName = &"IdleAlt"
const IDLE_FIDGETS: Array[StringName] = [&"Idle", &"TurnLeft", &"TurnRight"]
const IDLE_FIDGET_S: Vector2 = Vector2(9.0, 16.0)
const ANIM_WALK: StringName = &"Walking"
const ANIM_RUN: StringName = &"Running"
const ANIM_SPRINT: StringName = &"Running"
const ANIM_JUMP: StringName = &"Jump"
const ANIM_DODGE: StringName = &"Dodge"
const ANIM_HURT: StringName = &"KnockDown"
const ANIM_DEAD: StringName = &"Dead"
const SPRINT_RATE_BOOST: float = 1.3
const SQUASH: float = 0.05

## CharacterRig joint -> Mixamo bone.
const BONE_FOR_JOINT: Dictionary[StringName, String] = {
	&"hips": "mixamorig_Hips", &"spine": "mixamorig_Spine", &"chest": "mixamorig_Spine2",
	&"neck": "mixamorig_Neck", &"head": "mixamorig_Head",
	&"clav_r": "mixamorig_RightShoulder", &"arm_r": "mixamorig_RightArm",
	&"fore_r": "mixamorig_RightForeArm", &"hand_r": "mixamorig_RightHand",
	&"clav_l": "mixamorig_LeftShoulder", &"arm_l": "mixamorig_LeftArm",
	&"fore_l": "mixamorig_LeftForeArm", &"hand_l": "mixamorig_LeftHand",
	&"thigh_r": "mixamorig_RightUpLeg", &"shin_r": "mixamorig_RightLeg", &"foot_r": "mixamorig_RightFoot",
	&"thigh_l": "mixamorig_LeftUpLeg", &"shin_l": "mixamorig_LeftLeg", &"foot_l": "mixamorig_LeftFoot",
}
## Body colliders for hair and cloth (bone, radius in metres: collisions are world space).
const COLLIDERS: Array[Array] = [
	["mixamorig_Head", 0.1], ["mixamorig_Spine2", 0.12], ["mixamorig_Spine", 0.12],
	["mixamorig_Hips", 0.13], ["mixamorig_LeftUpLeg", 0.09], ["mixamorig_RightUpLeg", 0.09],
	["mixamorig_LeftLeg", 0.07], ["mixamorig_RightLeg", 0.07],
]
## Spring tuning (stiffness, drag, gravity): hair light and lively, cloth heavier and
## quicker to settle back so it never flips in front of the body.
const HAIR_SPRING: Vector3 = Vector3(1.6, 0.55, 0.5)
const CLOTH_SPRING: Vector3 = Vector3(2.4, 0.65, 0.8)

## Weapon of the class (CharacterRig.Weapon); picks bow / staff shots.
var weapon: int = 0
var _idle_for: float = 0.0
var _next_fidget: float = 12.0
var _fidget: StringName = &""
var _last_fidget: StringName = &""

var skeleton: Skeleton3D
var animation: AnimationPlayer
var springs: SpringBoneSimulator3D
var _pivot: Node3D
var _rig: CharacterRig
var _bone_of: Dictionary[StringName, int] = {}
var _current: StringName = &""
var _segment: int = -1
var _hold_time: float = -1.0
var _last_pos: Vector3 = Vector3.ZERO
var _last_tilt: float = 0.0
var _frames: int = 0


## Loads the rig scene (hair springs, toon material) under a pivot facing -Z.
func setup(rig: CharacterRig, scene: PackedScene, albedo: Texture2D, outline: bool) -> void:
	_rig = rig
	name = "AnimatedBody"
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	# Mixamo faces +Z; the game faces -Z.
	_pivot.rotation.y = PI
	add_child(_pivot)
	var model: Node3D = scene.instantiate() as Node3D
	_pivot.add_child(model)
	skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	animation = model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	for mesh: Node in skeleton.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = mesh
		var own: BaseMaterial3D = mi.mesh.surface_get_material(0) as BaseMaterial3D
		if own != null and own.albedo_texture != null:
			# GLB heroes bring their full material (colour + metal/roughness): keep it, add rim.
			# Toon look: colour only, no metal / gloss (the baked metal map made her glow white).
			var m: StandardMaterial3D = StandardMaterial3D.new()
			m.albedo_texture = own.albedo_texture
			m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			m.metallic = 0.0
			m.roughness = 0.9
			m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
			m.specular_mode = BaseMaterial3D.SPECULAR_TOON
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.rim_enabled = true
			m.rim = 0.2
			m.rim_tint = 0.5
			if outline:
				var o: ShaderMaterial = ShaderMaterial.new()
				o.shader = CharacterRig.OUTLINE_SHADER
				o.set_shader_parameter(&"width", 0.004)
				m.next_pass = o
			mi.material_override = m
		else:
			mi.material_override = ImportedBody._material(albedo, null, outline)
	for id: StringName in BONE_FOR_JOINT:
		_bone_of[id] = skeleton.find_bone(BONE_FOR_JOINT[id])
	# Centre the hips over the origin.
	var hips: Vector3 = _pivot.transform * (_skel_xform() * skeleton.get_bone_global_rest(_bone_of[&"hips"]).origin)
	_pivot.position = Vector3(-hips.x, 0.0, -hips.z)
	var chains: Array = model.get_meta(&"hair_chains", [])
	_build_springs(chains)
	# Advanced by drive() so joints read this frame's pose.
	animation.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	animation.play(ANIM_IDLE)


## Rest positions of the rig joints (model space, metres) from the Mixamo skeleton.
func joint_rest() -> Dictionary:
	var out: Dictionary = {}
	var to_model: Transform3D = _pivot.transform * _skel_xform()
	for id: StringName in _bone_of:
		out[String(id)] = to_model * skeleton.get_bone_global_rest(_bone_of[id]).origin
	return out


func _skel_xform() -> Transform3D:
	var t: Transform3D = skeleton.transform
	var p: Node = skeleton.get_parent()
	while p != null and p != _pivot:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t


func _build_springs(chains: Array) -> void:
	if chains.is_empty():
		return
	springs = SpringBoneSimulator3D.new()
	springs.name = "HairSprings"
	skeleton.add_child(springs)
	for row: Array in COLLIDERS:
		var col: SpringBoneCollisionSphere3D = SpringBoneCollisionSphere3D.new()
		col.bone_name = row[0]
		col.radius = row[1]
		springs.add_child(col)
	# Skeleton units per metre (FBX rigs are in cm, GLB rigs in m).
	var upm: float = 1.0 / maxf(_skel_xform().basis.get_scale().y, 0.0001)
	springs.set_setting_count(chains.size())
	for i: int in chains.size():
		var names: PackedStringArray = PackedStringArray()
		var cloth: bool = false
		if chains[i] is Dictionary:
			var d: Dictionary = chains[i]
			names = d["names"]
			cloth = d.get("kind", "hair") == "cloth"
		else:
			names = chains[i]
		var tune: Vector3 = CLOTH_SPRING if cloth else HAIR_SPRING
		springs.set_root_bone_name(i, names[0])
		springs.set_end_bone_name(i, names[names.size() - 1])
		springs.set_extend_end_bone(i, true)
		springs.set_end_bone_length(i, 0.1 * upm)
		springs.set_radius(i, 0.02 * upm)
		springs.set_stiffness(i, tune.x)
		springs.set_drag(i, tune.y)
		springs.set_gravity(i, tune.z)
		springs.set_enable_all_child_collisions(i, true)


## Plays the animation for CharacterModel's pose. `progress` = 0..1 through the swing,
## jump arc, hurt or death; `speed` = horizontal m/s.
func drive(pose: StringName, swing: int, progress: float, speed: float, delta: float) -> void:
	_hold_time = -1.0
	_select(pose, swing, progress, speed)
	if _hold_time >= 0.0:
		# Land exactly on the held moment after advancing (advance also runs the blends);
		# never past the end, so one-shot clips don't stop.
		animation.seek(maxf(_hold_time - delta, 0.0), true)
	animation.advance(delta)
	_guard_springs(delta)


## Restarts the hair simulation when the body jumps (teleport, respawn, death tilt
## snapping back, long frame): otherwise the chains get a huge velocity and scatter.
func _guard_springs(delta: float) -> void:
	_frames += 1
	var pos: Vector3 = global_position
	var tilt: float = _pivot.rotation.x
	var jumped: bool = pos.distance_to(_last_pos) > SPRING_TELEPORT_M or absf(tilt - _last_tilt) > SPRING_SNAP_RAD
	_last_pos = pos
	_last_tilt = tilt
	if springs != null and (jumped or delta > SPRING_HITCH_S or _frames <= SPRING_SETTLE_FRAMES):
		springs.reset()


## Landing squash, 0..1 (CharacterModel feeds its land timer): wider and shorter, a few %.
func squash(amount: float) -> void:
	var k: float = clampf(amount, 0.0, 1.0) * SQUASH
	_pivot.scale = Vector3(1.0 + k, 1.0 - k * 1.2, 1.0 + k)


## Restart hair (call after moving the character by script).
func reset_springs() -> void:
	if springs != null:
		springs.reset()


func _select(pose: StringName, swing: int, progress: float, speed: float) -> void:
	_pivot.rotation.x = 0.0
	var p: float = clampf(progress, 0.0, 1.0)
	match pose:
		&"walk":
			_loop(ANIM_WALK, speed / WALK_ANIM_SPEED)
		&"run":
			_loop(ANIM_RUN, speed / RUN_ANIM_SPEED)
		&"sprint":
			_loop(ANIM_SPRINT, speed / SPRINT_ANIM_SPEED * SPRINT_RATE_BOOST)
		&"dodge":
			_hold(ANIM_DODGE, lerpf(0.0, 1.1, p), ATTACK_BLEND_S)
		&"jump", &"fall":
			var span: Vector2 = JUMP_RISE if pose == &"jump" else JUMP_FALL
			_hold(ANIM_JUMP, lerpf(span.x, span.y, p), BLEND_S)
		&"attack", &"shoot", &"cast", &"slash", &"summon", &"victory", &"ultimate":
			var move: Array = _move_for(pose, swing)
			var clip: StringName = move[0]
			var t0: float = move[1]
			var t1: float = move[2]
			_hold(clip, lerpf(t0, t1, p), ATTACK_BLEND_S, swing)
		&"hurt":
			_hold(ANIM_HURT, lerpf(0.0, 0.5, p), BLEND_S)
		&"dead":
			_hold(ANIM_DEAD, lerpf(0.0, 2.9, clampf(progress / 1.5, 0.0, 1.0)), BLEND_S)
		_:
			_idle()


## Which clip (and part of it) shows an attack / cast.
func _move_for(pose: StringName, swing: int) -> Array:
	var dagger: bool = animation.has_animation(DAGGER_CLIP)
	if pose == &"ultimate" or swing == SWING_ULTIMATE:
		return DAGGER_ULTIMATE if dagger else ULTIMATE
	if pose == &"cast" or pose == &"summon" or pose == &"victory" or swing == SWING_CAST:
		return DAGGER_CAST if dagger else SKILL_CAST
	if pose == &"shoot":
		return BOW_SHOT if weapon == CharacterRig.Weapon.BOW else STAFF_SHOT
	var table: Array[Array] = DAGGER_SWINGS if dagger else SWINGS
	return table[clampi(swing, 0, table.size() - 1)]


func _idle() -> void:
	if _current != ANIM_IDLE and not IDLE_FIDGETS.has(_current):
		_idle_for = 0.0
		_fidget = &""
	if _fidget != &"":
		if animation.current_animation == _fidget and animation.current_animation_position < animation.current_animation_length - 0.25:
			return
		_fidget = &""
		_idle_for = 0.0
		_next_fidget = randf_range(IDLE_FIDGET_S.x, IDLE_FIDGET_S.y)
	_loop(ANIM_IDLE, 1.0)
	_idle_for += get_process_delta_time()
	if _idle_for >= _next_fidget and animation.has_animation(IDLE_FIDGETS[0]):
		var pick: StringName = IDLE_FIDGETS[randi() % IDLE_FIDGETS.size()]
		if pick == _last_fidget:
			pick = IDLE_FIDGETS[(IDLE_FIDGETS.find(pick) + 1) % IDLE_FIDGETS.size()]
		_fidget = pick
		_last_fidget = pick
		_current = pick
		animation.speed_scale = 1.0
		animation.play(pick, 0.35)


func _loop(anim: StringName, rate: float) -> void:
	if _current != anim or animation.current_animation != anim:
		_current = anim
		_segment = -1
		animation.play(anim, BLEND_S)
	animation.speed_scale = clampf(rate, 0.5, 1.8)


## Shows one moment of an animation (stance, a swing, the jump arc).
func _hold(anim: StringName, time: float, blend: float, segment: int = -1) -> void:
	animation.speed_scale = 1.0
	if _current != anim or segment != _segment or animation.current_animation != anim:
		_current = anim
		_segment = segment
		animation.play(anim, blend)
	# Stay just inside the clip so a finished one-shot never stops the player.
	_hold_time = minf(time, animation.current_animation_length - 0.02)


## Copies bone poses into the rig joints (world space), so anything parented to a joint
## follows the animated body. Joint rest = identity basis, so only the change from the
## bone's rest rotation is applied (hands: weapon grip axis instead).
func sync_to_rig() -> void:
	var skel_world: Transform3D = skeleton.global_transform
	for id: StringName in _bone_of:
		var bone: int = _bone_of[id]
		var pose: Transform3D = skel_world * skeleton.get_bone_global_pose(bone)
		var rest: Transform3D = skel_world * skeleton.get_bone_global_rest(bone)
		var delta: Basis = (pose.basis.orthonormalized() * rest.basis.orthonormalized().inverse())
		var b: Basis = delta * _rig.global_basis.orthonormalized()
		if id == &"hand_r" or id == &"hand_l":
			# Held weapons point out of the fist (Mixamo hand +Z), flat side along the fingers.
			var hb: Basis = pose.basis.orthonormalized()
			b = Basis.looking_at(hb.z, -hb.y)
		_rig.joints[id].global_transform = Transform3D(b, pose.origin)
