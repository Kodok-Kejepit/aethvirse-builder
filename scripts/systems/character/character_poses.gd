class_name CharacterPoses
extends RefCounted
## Pose library for CharacterRig. A pose maps joint id -> Euler degrees (rotation order YXZ),
## plus &"lift" (hips offset, metres) and &"root" (whole-model rotation, degrees).
## Limb convention: +x swings a hanging limb forward, -x bends the knee; for upright bones
## (spine/head) +x leans back. Arms/legs are written "mirrored": +z = outward, +y = inward,
## and _limbs() flips them for the left side.

const LIFT: StringName = &"lift"
const ROOT: StringName = &"root"
const KEYS: Array[StringName] = [
	&"hips", &"spine", &"chest", &"neck", &"head",
	&"clav_r", &"arm_r", &"fore_r", &"hand_r", &"clav_l", &"arm_l", &"fore_l", &"hand_l",
	&"thigh_r", &"shin_r", &"foot_r", &"thigh_l", &"shin_l", &"foot_l", LIFT, ROOT,
]
## Lower body + hips height: kept from locomotion when attacking on the move.
const LOWER: Array[StringName] = [&"thigh_r", &"shin_r", &"foot_r", &"thigh_l", &"shin_l", &"foot_l", LIFT]

## Named poses the showcase / `pose` cheat can display.
const NAMES: Array[StringName] = [
	&"idle", &"walk", &"run", &"sprint", &"jump", &"fall", &"land", &"dodge",
	&"slash", &"overhead", &"spin", &"thrust", &"shoot", &"cast", &"summon", &"ultimate",
	&"hurt", &"dead", &"victory", &"fidget",
]


static func empty() -> Dictionary[StringName, Vector3]:
	var d: Dictionary[StringName, Vector3] = {}
	for k: StringName in KEYS:
		d[k] = Vector3.ZERO
	return d


static func blend(a: Dictionary[StringName, Vector3], b: Dictionary[StringName, Vector3], w: float) -> Dictionary[StringName, Vector3]:
	var out: Dictionary[StringName, Vector3] = {}
	for k: StringName in KEYS:
		var va: Vector3 = a.get(k, Vector3.ZERO)
		var vb: Vector3 = b.get(k, Vector3.ZERO)
		out[k] = va.lerp(vb, w)
	return out


## Writes a symmetric pair: `r` for the right side, `l` mirrored (same meaning of +z outward).
static func _limbs(d: Dictionary[StringName, Vector3], part: String, r: Vector3, l: Vector3) -> void:
	d[StringName(part + "_r")] = r
	d[StringName(part + "_l")] = Vector3(l.x, -l.y, -l.z)


# --- base poses --------------------------------------------------------------------------

## Graceful stance from the reference art; `breath` in -1..1.
static func idle(breath: float = 0.0) -> Dictionary[StringName, Vector3]:
	var d: Dictionary[StringName, Vector3] = empty()
	d[LIFT] = Vector3(0.0, 0.004 * breath, 0.0)
	d[&"hips"] = Vector3(0.0, 4.0, 2.5)
	d[&"spine"] = Vector3(-1.0 + 1.2 * breath, -2.0, -1.5)
	d[&"chest"] = Vector3(0.8 * breath, -2.0, 0.0)
	d[&"neck"] = Vector3(2.0, 0.0, 0.0)
	d[&"head"] = Vector3(3.0, -4.0, 3.0)
	_limbs(d, "arm", Vector3(6.0, 0.0, 9.0), Vector3(4.0, 0.0, 10.0))
	_limbs(d, "fore", Vector3(16.0, 0.0, 0.0), Vector3(14.0, 0.0, 0.0))
	_limbs(d, "hand", Vector3(-60.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0))
	_limbs(d, "thigh", Vector3(1.0, 0.0, 3.5), Vector3(5.0, 6.0, -1.0))
	_limbs(d, "shin", Vector3(-2.0, 0.0, 0.0), Vector3(-10.0, 0.0, 0.0))
	_limbs(d, "foot", Vector3(0.0, 0.0, 0.0), Vector3(6.0, 0.0, 0.0))
	return d


## Walk/run/sprint cycle. `phase` in radians, `gait` 0 = walk, 1 = run, 2 = sprint.
static func locomotion(phase: float, gait: float) -> Dictionary[StringName, Vector3]:
	var walk: Dictionary[StringName, Vector3] = _cycle(phase, 0)
	if gait <= 0.0:
		return walk
	var run: Dictionary[StringName, Vector3] = _cycle(phase, 1)
	if gait <= 1.0:
		return blend(walk, run, gait)
	return blend(run, _cycle(phase, 2), clampf(gait - 1.0, 0.0, 1.0))


static func _cycle(p: float, kind: int) -> Dictionary[StringName, Vector3]:
	var d: Dictionary[StringName, Vector3] = empty()
	var s: float = sin(p)
	var swing_r: float = maxf(0.0, cos(p))
	var swing_l: float = maxf(0.0, -cos(p))
	match kind:
		0:
			d[LIFT] = Vector3(0.0, -0.025 + 0.025 * absf(cos(p)), 0.0)
			d[&"hips"] = Vector3(0.0, 7.0 * s, 3.0 * s)
			d[&"spine"] = Vector3(-3.0, 0.0, 0.0)
			d[&"chest"] = Vector3(0.0, -9.0 * s, -1.5 * s)
			d[&"head"] = Vector3(2.0, 2.0 * s, 0.0)
			d[&"thigh_r"] = Vector3(26.0 * s, 0.0, 2.0)
			d[&"thigh_l"] = Vector3(-26.0 * s, 0.0, -2.0)
			d[&"shin_r"] = Vector3(-6.0 - 42.0 * swing_r, 0.0, 0.0)
			d[&"shin_l"] = Vector3(-6.0 - 42.0 * swing_l, 0.0, 0.0)
			d[&"foot_r"] = Vector3(-10.0 * s, 0.0, 0.0)
			d[&"foot_l"] = Vector3(10.0 * s, 0.0, 0.0)
			_limbs(d, "arm", Vector3(-18.0 * s, 0.0, 9.0), Vector3(18.0 * s, 0.0, 9.0))
			_limbs(d, "fore", Vector3(18.0 + 10.0 * maxf(0.0, -s), 0.0, 0.0), Vector3(18.0 + 10.0 * maxf(0.0, s), 0.0, 0.0))
			_limbs(d, "hand", Vector3(-60.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0))
		1:
			d[LIFT] = Vector3(0.0, -0.05 + 0.06 * absf(cos(p)), 0.0)
			d[&"hips"] = Vector3(0.0, 10.0 * s, 4.0 * s)
			d[&"spine"] = Vector3(-12.0, 0.0, 0.0)
			d[&"chest"] = Vector3(-2.0, -14.0 * s, -2.0 * s)
			d[&"head"] = Vector3(8.0, 4.0 * s, 0.0)
			d[&"thigh_r"] = Vector3(12.0 + 48.0 * s, 0.0, 2.0)
			d[&"thigh_l"] = Vector3(12.0 - 48.0 * s, 0.0, -2.0)
			d[&"shin_r"] = Vector3(-14.0 - 85.0 * swing_r, 0.0, 0.0)
			d[&"shin_l"] = Vector3(-14.0 - 85.0 * swing_l, 0.0, 0.0)
			d[&"foot_r"] = Vector3(-15.0 * s, 0.0, 0.0)
			d[&"foot_l"] = Vector3(15.0 * s, 0.0, 0.0)
			_limbs(d, "arm", Vector3(-42.0 * s, 0.0, 12.0), Vector3(42.0 * s, 0.0, 12.0))
			_limbs(d, "fore", Vector3(75.0, 0.0, 0.0), Vector3(75.0, 0.0, 0.0))
			_limbs(d, "hand", Vector3(-70.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0))
		_:
			# Sprint: low lean, arms swept back like a gliding mage.
			d[LIFT] = Vector3(0.0, -0.09 + 0.07 * absf(cos(p)), 0.0)
			d[&"hips"] = Vector3(0.0, 8.0 * s, 3.0 * s)
			d[&"spine"] = Vector3(-26.0, 0.0, 0.0)
			d[&"chest"] = Vector3(-6.0, -8.0 * s, 0.0)
			d[&"head"] = Vector3(22.0, 0.0, 0.0)
			d[&"thigh_r"] = Vector3(20.0 + 55.0 * s, 0.0, 2.0)
			d[&"thigh_l"] = Vector3(20.0 - 55.0 * s, 0.0, -2.0)
			d[&"shin_r"] = Vector3(-18.0 - 95.0 * swing_r, 0.0, 0.0)
			d[&"shin_l"] = Vector3(-18.0 - 95.0 * swing_l, 0.0, 0.0)
			_limbs(d, "arm", Vector3(-58.0, 0.0, 22.0), Vector3(-58.0, 0.0, 22.0))
			_limbs(d, "fore", Vector3(10.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0))
			_limbs(d, "hand", Vector3(-20.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0))
	return d


## Airborne: `rise` 1 = going up (knee tuck), 0 = falling (legs long, arms out).
static func air(rise: float) -> Dictionary[StringName, Vector3]:
	var up: Dictionary[StringName, Vector3] = empty()
	up[&"spine"] = Vector3(-8.0, 0.0, 0.0)
	up[&"head"] = Vector3(-4.0, 0.0, 0.0)
	up[&"thigh_r"] = Vector3(75.0, 0.0, 4.0)
	up[&"shin_r"] = Vector3(-105.0, 0.0, 0.0)
	up[&"thigh_l"] = Vector3(15.0, 0.0, -4.0)
	up[&"shin_l"] = Vector3(-40.0, 0.0, 0.0)
	up[&"foot_l"] = Vector3(-25.0, 0.0, 0.0)
	_limbs(up, "arm", Vector3(-25.0, 0.0, 38.0), Vector3(-15.0, 0.0, 42.0))
	_limbs(up, "fore", Vector3(35.0, 0.0, 0.0), Vector3(30.0, 0.0, 0.0))
	_limbs(up, "hand", Vector3(-60.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0))
	var down: Dictionary[StringName, Vector3] = empty()
	down[&"spine"] = Vector3(5.0, 0.0, 0.0)
	down[&"head"] = Vector3(-10.0, 0.0, 0.0)
	down[&"thigh_r"] = Vector3(28.0, 0.0, 5.0)
	down[&"shin_r"] = Vector3(-45.0, 0.0, 0.0)
	down[&"thigh_l"] = Vector3(-8.0, 0.0, -6.0)
	down[&"shin_l"] = Vector3(-22.0, 0.0, 0.0)
	down[&"foot_r"] = Vector3(-20.0, 0.0, 0.0)
	down[&"foot_l"] = Vector3(-30.0, 0.0, 0.0)
	_limbs(down, "arm", Vector3(5.0, 0.0, 68.0), Vector3(5.0, 0.0, 70.0))
	_limbs(down, "fore", Vector3(22.0, 0.0, 0.0), Vector3(18.0, 0.0, 0.0))
	_limbs(down, "hand", Vector3(-40.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0))
	return blend(down, up, clampf(rise, 0.0, 1.0))


## Landing crouch, `strength` 0..1 (from fall speed).
static func land(strength: float) -> Dictionary[StringName, Vector3]:
	var d: Dictionary[StringName, Vector3] = idle()
	var k: float = clampf(strength, 0.0, 1.0)
	d[LIFT] = Vector3(0.0, -0.2 * k, 0.0)
	d[&"spine"] = Vector3(-22.0 * k, 0.0, 0.0)
	d[&"head"] = Vector3(14.0 * k, 0.0, 0.0)
	_limbs(d, "thigh", Vector3(55.0 * k, 0.0, 6.0), Vector3(48.0 * k, 0.0, 8.0))
	_limbs(d, "shin", Vector3(-95.0 * k, 0.0, 0.0), Vector3(-90.0 * k, 0.0, 0.0))
	_limbs(d, "foot", Vector3(40.0 * k, 0.0, 0.0), Vector3(40.0 * k, 0.0, 0.0))
	_limbs(d, "arm", Vector3(20.0 * k, 0.0, 30.0 * k), Vector3(15.0 * k, 0.0, 35.0 * k))
	return d


## Low forward dash; `t` 0..1 over the dodge.
static func dodge(t: float) -> Dictionary[StringName, Vector3]:
	var k: float = sin(clampf(t, 0.0, 1.0) * PI)
	var d: Dictionary[StringName, Vector3] = empty()
	d[LIFT] = Vector3(0.0, -0.16 * k, 0.0)
	d[&"spine"] = Vector3(-38.0 * k, 0.0, 0.0)
	d[&"chest"] = Vector3(-8.0 * k, 0.0, 0.0)
	d[&"head"] = Vector3(30.0 * k, 0.0, 0.0)
	d[&"thigh_r"] = Vector3(65.0 * k, 0.0, 3.0)
	d[&"shin_r"] = Vector3(-95.0 * k, 0.0, 0.0)
	d[&"thigh_l"] = Vector3(-45.0 * k, 0.0, -3.0)
	d[&"shin_l"] = Vector3(-35.0 * k, 0.0, 0.0)
	_limbs(d, "arm", Vector3(-65.0 * k, 0.0, 25.0), Vector3(-65.0 * k, 0.0, 25.0))
	_limbs(d, "fore", Vector3(10.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0))
	_limbs(d, "hand", Vector3(-30.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0))
	return d


static func hurt(t: float) -> Dictionary[StringName, Vector3]:
	var k: float = 1.0 - clampf(t, 0.0, 1.0) * 0.6
	var d: Dictionary[StringName, Vector3] = idle()
	d[LIFT] = Vector3(0.0, -0.06 * k, 0.04 * k)
	d[&"spine"] = Vector3(22.0 * k, 0.0, 4.0 * k)
	d[&"chest"] = Vector3(8.0 * k, 0.0, 0.0)
	d[&"head"] = Vector3(-24.0 * k, 10.0 * k, 0.0)
	_limbs(d, "arm", Vector3(-25.0 * k, 0.0, 40.0 * k), Vector3(40.0 * k, 20.0 * k, 25.0 * k))
	_limbs(d, "fore", Vector3(45.0 * k, 0.0, 0.0), Vector3(90.0 * k, 0.0, 0.0))
	_limbs(d, "thigh", Vector3(-12.0 * k, 0.0, 4.0), Vector3(18.0 * k, 0.0, 4.0))
	_limbs(d, "shin", Vector3(-15.0 * k, 0.0, 0.0), Vector3(-35.0 * k, 0.0, 0.0))
	return d


## Collapse: to the knees first, then onto her side. `t` = seconds in the Dead state.
static func dead(t: float) -> Dictionary[StringName, Vector3]:
	var kneel: Dictionary[StringName, Vector3] = empty()
	kneel[LIFT] = Vector3(0.0, -0.46, 0.0)
	kneel[&"spine"] = Vector3(-25.0, 0.0, 0.0)
	kneel[&"head"] = Vector3(-30.0, 0.0, 0.0)
	_limbs(kneel, "thigh", Vector3(85.0, 0.0, 8.0), Vector3(80.0, 0.0, 10.0))
	_limbs(kneel, "shin", Vector3(-150.0, 0.0, 0.0), Vector3(-150.0, 0.0, 0.0))
	_limbs(kneel, "arm", Vector3(10.0, 0.0, 10.0), Vector3(10.0, 0.0, 10.0))
	_limbs(kneel, "hand", Vector3(-80.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0))
	var down: Dictionary[StringName, Vector3] = empty()
	down[LIFT] = Vector3(0.0, -0.78, 0.0)
	down[ROOT] = Vector3(0.0, 0.0, 82.0)
	down[&"spine"] = Vector3(-10.0, 0.0, 6.0)
	down[&"head"] = Vector3(-10.0, 0.0, 15.0)
	_limbs(down, "thigh", Vector3(40.0, 0.0, 2.0), Vector3(25.0, 0.0, 6.0))
	_limbs(down, "shin", Vector3(-60.0, 0.0, 0.0), Vector3(-30.0, 0.0, 0.0))
	_limbs(down, "arm", Vector3(30.0, 0.0, 60.0), Vector3(50.0, 0.0, 15.0))
	_limbs(down, "fore", Vector3(30.0, 0.0, 0.0), Vector3(40.0, 0.0, 0.0))
	if t < 0.5:
		return blend(empty(), kneel, smoothstep(0.0, 0.5, t))
	return blend(kneel, down, smoothstep(0.5, 1.1, t))


## Level up / victory: weapon raised high.
static func victory() -> Dictionary[StringName, Vector3]:
	var d: Dictionary[StringName, Vector3] = idle()
	d[&"spine"] = Vector3(6.0, 0.0, 0.0)
	d[&"head"] = Vector3(-14.0, -6.0, 0.0)
	_limbs(d, "arm", Vector3(172.0, 0.0, 12.0), Vector3(-12.0, 0.0, 38.0))
	_limbs(d, "fore", Vector3(12.0, 0.0, 0.0), Vector3(110.0, 0.0, 0.0))
	_limbs(d, "hand", Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0))
	_limbs(d, "thigh", Vector3(2.0, 0.0, 6.0), Vector3(-6.0, 0.0, 4.0))
	return d


## Long-idle fidget: brushing the hair back with the free hand.
static func fidget(breath: float = 0.0) -> Dictionary[StringName, Vector3]:
	var d: Dictionary[StringName, Vector3] = idle(breath)
	d[&"head"] = Vector3(-6.0, 12.0, 8.0)
	d[&"arm_l"] = Vector3(135.0, 20.0, -35.0)
	d[&"fore_l"] = Vector3(120.0, 0.0, 0.0)
	return d


## Instant cast (summon / buff / call): arms open wide, face lifted.
static func summon() -> Dictionary[StringName, Vector3]:
	var d: Dictionary[StringName, Vector3] = idle()
	d[LIFT] = Vector3(0.0, 0.02, 0.0)
	d[&"spine"] = Vector3(8.0, 0.0, 0.0)
	d[&"head"] = Vector3(-18.0, 0.0, 0.0)
	_limbs(d, "arm", Vector3(120.0, 0.0, 55.0), Vector3(120.0, 0.0, 55.0))
	_limbs(d, "fore", Vector3(10.0, 0.0, 0.0), Vector3(10.0, 0.0, 0.0))
	_limbs(d, "hand", Vector3(-20.0, 0.0, 0.0), Vector3(0.0, 0.0, 0.0))
	return d


# --- attacks -----------------------------------------------------------------------------

## Attack pose. `swing` = AttackData.Swing, `k` 0..1 over startup+active (>1 = recovery).
## `ranged` = projectile attack, `skill` adds the magic flourish of the free hand.
static func attack(swing: int, k: float, ranged: bool, skill: bool, weapon: int) -> Dictionary[StringName, Vector3]:
	if ranged:
		return _shoot(k, weapon)
	var wind: Dictionary[StringName, Vector3]
	var hit: Dictionary[StringName, Vector3]
	match swing:
		1:
			wind = _overhead_wind()
			hit = _overhead_hit()
		2:
			return _spin(k)
		3:
			wind = _thrust_wind()
			hit = _thrust_hit()
		_:
			wind = _slash_wind()
			hit = _slash_hit()
	var d: Dictionary[StringName, Vector3] = blend(wind, hit, smoothstep(0.3, 1.0, k))
	if skill:
		d[&"arm_l"] = Vector3(85.0, 15.0, 0.0)
		d[&"fore_l"] = Vector3(5.0, 0.0, 0.0)
		d[&"hand_l"] = Vector3(-70.0, 0.0, 0.0)
	return d


static func _stance(d: Dictionary[StringName, Vector3], depth: float) -> void:
	d[LIFT] = Vector3(0.0, -0.08 * depth, 0.0)
	_limbs(d, "thigh", Vector3(28.0 * depth, 0.0, 8.0), Vector3(-22.0 * depth, 0.0, 10.0))
	_limbs(d, "shin", Vector3(-38.0 * depth, 0.0, 0.0), Vector3(-12.0 * depth, 0.0, 0.0))


static func _slash_wind() -> Dictionary[StringName, Vector3]:
	var d: Dictionary[StringName, Vector3] = empty()
	_stance(d, 0.8)
	d[&"hips"] = Vector3(0.0, 15.0, 0.0)
	d[&"chest"] = Vector3(0.0, 35.0, 0.0)
	d[&"head"] = Vector3(0.0, -30.0, 0.0)
	d[&"arm_r"] = Vector3(80.0, 65.0, 0.0)
	d[&"fore_r"] = Vector3(45.0, 0.0, 0.0)
	d[&"hand_r"] = Vector3(-80.0, 0.0, 0.0)
	_limbs_l(d, Vector3(15.0, 0.0, 35.0), Vector3(40.0, 0.0, 0.0))
	return d


static func _slash_hit() -> Dictionary[StringName, Vector3]:
	var d: Dictionary[StringName, Vector3] = empty()
	_stance(d, 1.0)
	d[&"hips"] = Vector3(0.0, -15.0, 0.0)
	d[&"spine"] = Vector3(-10.0, 0.0, 0.0)
	d[&"chest"] = Vector3(0.0, -35.0, 0.0)
	d[&"head"] = Vector3(0.0, 40.0, 0.0)
	d[&"arm_r"] = Vector3(85.0, -75.0, 0.0)
	d[&"fore_r"] = Vector3(5.0, 0.0, 0.0)
	d[&"hand_r"] = Vector3(-85.0, 0.0, 0.0)
	_limbs_l(d, Vector3(-30.0, 0.0, 45.0), Vector3(30.0, 0.0, 0.0))
	return d


static func _overhead_wind() -> Dictionary[StringName, Vector3]:
	var d: Dictionary[StringName, Vector3] = empty()
	_stance(d, 0.5)
	d[&"spine"] = Vector3(10.0, 0.0, 0.0)
	d[&"head"] = Vector3(-8.0, 0.0, 0.0)
	d[&"arm_r"] = Vector3(165.0, 0.0, 10.0)
	d[&"fore_r"] = Vector3(35.0, 0.0, 0.0)
	d[&"hand_r"] = Vector3(-70.0, 0.0, 0.0)
	d[&"arm_l"] = Vector3(160.0, 0.0, -15.0)
	d[&"fore_l"] = Vector3(40.0, 0.0, 0.0)
	return d


static func _overhead_hit() -> Dictionary[StringName, Vector3]:
	var d: Dictionary[StringName, Vector3] = empty()
	_stance(d, 1.6)
	d[&"spine"] = Vector3(-28.0, 0.0, 0.0)
	d[&"head"] = Vector3(20.0, 0.0, 0.0)
	d[&"arm_r"] = Vector3(55.0, 10.0, 0.0)
	d[&"fore_r"] = Vector3(5.0, 0.0, 0.0)
	d[&"hand_r"] = Vector3(-85.0, 0.0, 0.0)
	d[&"arm_l"] = Vector3(50.0, -15.0, 0.0)
	d[&"fore_l"] = Vector3(15.0, 0.0, 0.0)
	return d


static func _thrust_wind() -> Dictionary[StringName, Vector3]:
	var d: Dictionary[StringName, Vector3] = empty()
	_stance(d, 0.9)
	d[&"chest"] = Vector3(0.0, -30.0, 0.0)
	d[&"head"] = Vector3(0.0, 28.0, 0.0)
	d[&"arm_r"] = Vector3(30.0, 0.0, 30.0)
	d[&"fore_r"] = Vector3(110.0, 0.0, 0.0)
	d[&"hand_r"] = Vector3(-10.0, 0.0, 0.0)
	_limbs_l(d, Vector3(75.0, 10.0, 10.0), Vector3(10.0, 0.0, 0.0))
	return d


static func _thrust_hit() -> Dictionary[StringName, Vector3]:
	var d: Dictionary[StringName, Vector3] = empty()
	_stance(d, 1.5)
	d[&"spine"] = Vector3(-20.0, 0.0, 0.0)
	d[&"chest"] = Vector3(0.0, 15.0, 0.0)
	d[&"head"] = Vector3(10.0, -12.0, 0.0)
	d[&"arm_r"] = Vector3(92.0, 8.0, 0.0)
	d[&"fore_r"] = Vector3(0.0, 0.0, 0.0)
	d[&"hand_r"] = Vector3(-90.0, 0.0, 0.0)
	_limbs_l(d, Vector3(-35.0, 0.0, 40.0), Vector3(20.0, 0.0, 0.0))
	return d


static func _spin(k: float) -> Dictionary[StringName, Vector3]:
	var d: Dictionary[StringName, Vector3] = empty()
	_stance(d, 0.9)
	d[ROOT] = Vector3(0.0, -360.0 * smoothstep(0.15, 1.0, k), 0.0)
	d[&"spine"] = Vector3(-12.0, 0.0, -6.0)
	d[&"arm_r"] = Vector3(10.0, 0.0, 85.0)
	d[&"fore_r"] = Vector3(10.0, 0.0, 0.0)
	d[&"hand_r"] = Vector3(-90.0, 0.0, 0.0)
	_limbs_l(d, Vector3(10.0, 0.0, 75.0), Vector3(10.0, 0.0, 0.0))
	return d


## Bow draw / staff bolt / thrown blade: aim forward with the leading hand.
static func _shoot(k: float, weapon: int) -> Dictionary[StringName, Vector3]:
	var d: Dictionary[StringName, Vector3] = empty()
	_stance(d, 0.6)
	var release: float = smoothstep(0.75, 1.0, k)
	if weapon == CharacterRig.Weapon.BOW:
		d[&"chest"] = Vector3(0.0, 55.0, 0.0)
		d[&"head"] = Vector3(0.0, -52.0, 0.0)
		d[&"arm_l"] = Vector3(88.0, -55.0, 0.0)
		d[&"fore_l"] = Vector3(0.0, 0.0, 0.0)
		d[&"hand_l"] = Vector3(-90.0, 0.0, 0.0)
		d[&"arm_r"] = Vector3(85.0, 75.0 - 15.0 * release, 0.0)
		d[&"fore_r"] = Vector3(lerpf(140.0, 40.0, release), 0.0, 0.0)
		return d
	d[&"spine"] = Vector3(-6.0, 0.0, 0.0)
	d[&"chest"] = Vector3(0.0, 10.0 - 25.0 * release, 0.0)
	d[&"arm_r"] = Vector3(lerpf(140.0, 90.0, release), 0.0, 15.0)
	d[&"fore_r"] = Vector3(lerpf(30.0, 0.0, release), 0.0, 0.0)
	d[&"hand_r"] = Vector3(-30.0, 0.0, 0.0)
	_limbs_l(d, Vector3(lerpf(60.0, 90.0, release), 10.0, 5.0), Vector3(5.0, 0.0, 0.0))
	d[&"hand_l"] = Vector3(-80.0, 0.0, 0.0)
	return d


static func _limbs_l(d: Dictionary[StringName, Vector3], arm: Vector3, fore: Vector3) -> void:
	d[&"arm_l"] = Vector3(arm.x, -arm.y, -arm.z)
	d[&"fore_l"] = Vector3(fore.x, -fore.y, -fore.z)


## Static preview of any NAMES entry (showcase / `pose` cheat). `t` animates cycles.
static func named(id: StringName, t: float, weapon: int) -> Dictionary[StringName, Vector3]:
	var breath: float = sin(t * 2.2)
	match id:
		&"walk":
			return locomotion(t * 6.0, 0.0)
		&"run":
			return locomotion(t * 9.0, 1.0)
		&"sprint":
			return locomotion(t * 11.0, 2.0)
		&"jump":
			return air(1.0)
		&"fall":
			return air(0.0)
		&"land":
			return land(1.0)
		&"dodge":
			return dodge(0.5)
		&"slash":
			return attack(0, fmod(t, 1.2), false, false, weapon)
		&"overhead":
			return attack(1, fmod(t, 1.2), false, false, weapon)
		&"spin":
			return attack(2, fmod(t, 1.2), false, false, weapon)
		&"thrust":
			return attack(3, fmod(t, 1.2), false, false, weapon)
		&"shoot":
			return attack(0, fmod(t, 1.2), true, false, weapon)
		&"cast":
			return attack(3, fmod(t, 1.2), false, true, weapon)
		&"summon", &"ultimate":
			return summon()
		&"hurt":
			return hurt(0.0)
		&"dead":
			return dead(2.0)
		&"victory":
			return victory()
		&"fidget":
			return fidget(breath)
	return idle(breath)
