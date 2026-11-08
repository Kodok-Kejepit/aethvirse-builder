class_name CharacterRig
extends Node3D
## Procedural stand-in body (used only when a hero has no imported model; neutral colours): a joint hierarchy of Node3Ds
## with primitive meshes, toon materials, long spring-driven hair and sashes, and a
## class weapon. Faces -Z, feet on y = 0. Poses come from CharacterPoses via CharacterAnimator.

enum Weapon { SWORD, DAGGERS, STAFF, BOW }

const TOON_SHADER: Shader = preload("res://assets/shaders/toon_character.gdshader")
const OUTLINE_SHADER: Shader = preload("res://assets/shaders/toon_outline.gdshader")

const SKIN: Color = Color(0.98, 0.8, 0.72)
const SUIT: Color = Color(0.13, 0.14, 0.16)
const GOLD: Color = Color(0.62, 0.64, 0.68)
const HAIR: Color = Color(0.14, 0.11, 0.1)
const HAIR_TIP: Color = Color(0.22, 0.18, 0.16)
const SLEEVE: Color = Color(0.24, 0.27, 0.32)
const SLEEVE_END: Color = Color(0.12, 0.13, 0.16)
const GLOVE: Color = Color(0.08, 0.08, 0.09)
const SASH: Color = Color(0.3, 0.33, 0.38)
const SASH_TIP: Color = Color(0.45, 0.5, 0.56)
const EYE: Color = Color(0.95, 0.72, 0.35)
const GEM: Color = Color(0.45, 0.75, 1.0)

## Joint rest positions (parent-relative). Order matters: parents first.
const JOINTS: Array[Array] = [
	[&"hips", &"", Vector3(0.0, 0.98, 0.0)],
	[&"spine", &"hips", Vector3(0.0, 0.07, 0.0)],
	[&"chest", &"spine", Vector3(0.0, 0.2, 0.0)],
	[&"neck", &"chest", Vector3(0.0, 0.25, 0.0)],
	[&"head", &"neck", Vector3(0.0, 0.09, 0.0)],
	[&"clav_r", &"chest", Vector3(0.11, 0.19, 0.0)],
	[&"arm_r", &"clav_r", Vector3(0.06, 0.0, 0.0)],
	[&"fore_r", &"arm_r", Vector3(0.0, -0.27, 0.0)],
	[&"hand_r", &"fore_r", Vector3(0.0, -0.25, 0.0)],
	[&"clav_l", &"chest", Vector3(-0.11, 0.19, 0.0)],
	[&"arm_l", &"clav_l", Vector3(-0.06, 0.0, 0.0)],
	[&"fore_l", &"arm_l", Vector3(0.0, -0.27, 0.0)],
	[&"hand_l", &"fore_l", Vector3(0.0, -0.25, 0.0)],
	[&"thigh_r", &"hips", Vector3(0.09, -0.05, 0.0)],
	[&"shin_r", &"thigh_r", Vector3(0.0, -0.44, 0.0)],
	[&"foot_r", &"shin_r", Vector3(0.0, -0.42, 0.0)],
	[&"thigh_l", &"hips", Vector3(-0.09, -0.05, 0.0)],
	[&"shin_l", &"thigh_l", Vector3(0.0, -0.44, 0.0)],
	[&"foot_l", &"shin_l", Vector3(0.0, -0.42, 0.0)],
]


## Spring chain (hair strand / sash): joints[i] is the pivot of segment i.
class Chain:
	extends RefCounted
	var joints: Array[Node3D] = []
	## Rest angles (deg, model space) per segment: x = back(-)/front(+), y = side.
	var rest: Array[Vector2] = []
	var angle: Array[Vector2] = []
	var velocity: Array[Vector2] = []
	var stiffness: float = 60.0
	var damping: float = 7.0
	## How strongly motion drags this chain (hair > sash).
	var drag: float = 1.0
	## Front sashes are pushed by the leading thigh.
	var front: bool = false
	var phase_seed: float = 0.0


var joints: Dictionary[StringName, Node3D] = {}
var rest_positions: Dictionary[StringName, Vector3] = {}
var chains: Array[Chain] = []
var weapon: Weapon = Weapon.SWORD
var hair_style: HeroData.Hair = HeroData.Hair.LONG
var hair_color: Color = HAIR
var hair_tip: Color = HAIR_TIP
var outlines: bool = true
## Node the spirit dragon coils around (model root).
var weapon_tip: Node3D = null

var _materials: Dictionary[String, ShaderMaterial] = {}
var _outline: ShaderMaterial = null


static func weapon_for_class(class_id: StringName) -> Weapon:
	match class_id:
		&"phantom":
			return Weapon.DAGGERS
		&"arcanist":
			return Weapon.STAFF
		&"ranger":
			return Weapon.BOW
	return Weapon.SWORD


## Joints + weapon only, rest positions taken from an imported body (global, metres).
## The imported skinned mesh supplies the body; see ImportedBody.
func build_skeleton_only(weapon_kind: Weapon, global_rest: Dictionary, with_outlines: bool) -> void:
	weapon = weapon_kind
	outlines = with_outlines
	if outlines:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
	for row: Array in JOINTS:
		var id: StringName = row[0]
		var parent_id: StringName = row[1]
		var fallback: Vector3 = row[2]
		var g: Vector3 = global_rest.get(String(id), fallback)
		var pg: Vector3 = global_rest.get(String(parent_id), Vector3.ZERO) if parent_id != &"" else Vector3.ZERO
		var joint_node: Node3D = Node3D.new()
		joint_node.name = String(id)
		joint_node.position = g - pg
		var parent: Node3D = self if parent_id == &"" else joints[parent_id]
		parent.add_child(joint_node)
		joints[id] = joint_node
		rest_positions[id] = joint_node.position
	_build_weapon()
	_merge_static_parts()


func build(weapon_kind: Weapon, with_outlines: bool = true, hero: HeroData = null) -> void:
	weapon = weapon_kind
	if hero != null:
		hair_style = hero.hair
		hair_color = hero.hair_color
		hair_tip = hero.hair_tip_color
	outlines = with_outlines
	if outlines:
		_outline = ShaderMaterial.new()
		_outline.shader = OUTLINE_SHADER
	for row: Array in JOINTS:
		var id: StringName = row[0]
		var parent_id: StringName = row[1]
		var pos: Vector3 = row[2]
		var joint: Node3D = Node3D.new()
		joint.name = String(id)
		joint.position = pos
		var parent: Node3D = self if parent_id == &"" else joints[parent_id]
		parent.add_child(joint)
		joints[id] = joint
		rest_positions[id] = pos
	_build_torso()
	_build_head()
	_build_arm(1.0)
	_build_arm(-1.0)
	_build_leg(1.0)
	_build_leg(-1.0)
	_build_hair()
	_build_sashes()
	_build_weapon()
	_merge_static_parts()


func get_joint(id: StringName) -> Node3D:
	return joints.get(id, null)


# --- materials / parts -------------------------------------------------------------------

func _mat(key: String, color: Color, params: Dictionary = {}) -> ShaderMaterial:
	if key == "skin" and params.is_empty():
		params = {"rim_strength": 0.12, "rim_color": Color(1.0, 0.7, 0.7)}
	if _materials.has(key):
		return _materials[key]
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = TOON_SHADER
	m.set_shader_parameter(&"albedo", color)
	m.set_shader_parameter(&"albedo_end", color)
	for p: String in params:
		m.set_shader_parameter(StringName(p), params[p])
	if _outline != null and not params.has("no_outline"):
		m.next_pass = _outline
	_materials[key] = m
	return m


func _glow(key: String, color: Color, energy: float) -> ShaderMaterial:
	return _mat(key, color, {"emission": color, "emission_energy": energy, "no_outline": true, "rim_strength": 0.0})


func _part(parent: Node3D, mesh: PrimitiveMesh, mat: Material, pos: Vector3,
		rot_deg: Vector3 = Vector3.ZERO, scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var inst: MeshInstance3D = MeshInstance3D.new()
	mesh.material = mat
	inst.mesh = mesh
	inst.position = pos
	inst.rotation_degrees = rot_deg
	inst.scale = scale_v
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(inst)
	return inst


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m: CapsuleMesh = CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = 12
	m.rings = 4
	return m


static func _sphere(radius: float, height: float) -> SphereMesh:
	var m: SphereMesh = SphereMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 16
	m.rings = 8
	return m


static func _cylinder(top: float, bottom: float, height: float) -> CylinderMesh:
	var m: CylinderMesh = CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 12
	m.rings = 1
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	return m


static func _prism(size: Vector3) -> PrismMesh:
	var m: PrismMesh = PrismMesh.new()
	m.size = size
	return m


# --- body --------------------------------------------------------------------------------

func _suit() -> ShaderMaterial:
	return _mat("suit", SUIT, {"star_amount": 0.0, "rim_color": Color(0.6, 0.7, 0.85), "rim_strength": 0.3})


func _build_torso() -> void:
	var hips: Node3D = joints[&"hips"]
	var spine: Node3D = joints[&"spine"]
	var chest: Node3D = joints[&"chest"]
	var gold: ShaderMaterial = _mat("gold", GOLD, {"roughness": 0.35, "rim_strength": 0.2})
	_part(hips, _sphere(0.15, 0.27), _suit(), Vector3(0.0, -0.02, 0.0), Vector3.ZERO, Vector3(1.12, 1.0, 0.85))
	_part(spine, _capsule(0.1, 0.3), _suit(), Vector3(0.0, 0.1, 0.0), Vector3.ZERO, Vector3(1.0, 1.0, 0.78))
	_part(chest, _sphere(0.145, 0.3), _suit(), Vector3(0.0, 0.08, 0.0), Vector3.ZERO, Vector3(1.08, 1.0, 0.8))
	for side: float in [1.0, -1.0]:
		_part(chest, _sphere(0.068, 0.12), _suit(), Vector3(0.062 * side, 0.085, -0.075))
		# Bare shoulders (cut-out suit).
		_part(chest, _sphere(0.06, 0.1), _mat("skin", SKIN), Vector3(0.12 * side, 0.18, 0.0))
		# Gold filigree down the front and over the hips.
		_part(chest, _box(Vector3(0.018, 0.2, 0.012)), gold, Vector3(0.05 * side, -0.02, -0.112), Vector3(0.0, 0.0, -18.0 * side))
		_part(hips, _box(Vector3(0.02, 0.16, 0.012)), gold, Vector3(0.08 * side, -0.02, -0.11), Vector3(0.0, 0.0, 25.0 * side))
	_part(chest, _box(Vector3(0.022, 0.32, 0.012)), gold, Vector3(0.0, -0.06, -0.118))
	# High collar, gold neck ring and the pink crystal brooches.
	_part(chest, _cylinder(0.052, 0.07, 0.07), _suit(), Vector3(0.0, 0.23, 0.0))
	var ring: TorusMesh = TorusMesh.new()
	ring.inner_radius = 0.055
	ring.outer_radius = 0.075
	_part(chest, ring, gold, Vector3(0.0, 0.22, -0.01), Vector3(-12.0, 0.0, 0.0))
	_part(chest, _prism(Vector3(0.045, 0.07, 0.03)), _glow("gem", GEM, 1.1), Vector3(0.0, 0.17, -0.1), Vector3(180.0, 0.0, 0.0))
	_part(chest, _sphere(0.04, 0.06), _glow("gem", GEM, 1.1), Vector3(0.085, 0.12, -0.11))
	for i: int in 5:
		var a: float = TAU * float(i) / 5.0
		_part(chest, _prism(Vector3(0.025, 0.07, 0.01)), _glow("gem", GEM, 1.1),
			Vector3(0.085 + cos(a) * 0.035, 0.12 + sin(a) * 0.035, -0.115), Vector3(0.0, 0.0, rad_to_deg(a) - 90.0))


func _build_head() -> void:
	var neck: Node3D = joints[&"neck"]
	var head: Node3D = joints[&"head"]
	var skin: ShaderMaterial = _mat("skin", SKIN)
	var hair: ShaderMaterial = _mat("hair", hair_color, {"rim_color": Color(1.0, 0.95, 0.7), "rim_strength": 0.4})
	_part(neck, _capsule(0.038, 0.13), skin, Vector3(0.0, 0.03, 0.0))
	_part(head, _sphere(0.1, 0.23), skin, Vector3(0.0, 0.1, -0.005), Vector3.ZERO, Vector3(0.95, 1.0, 1.0))
	# Big anime eyes: violet glow + white highlight; small brows.
	for side: float in [1.0, -1.0]:
		_part(head, _sphere(0.024, 0.036), _glow("eye", EYE, 0.9), Vector3(0.038 * side, 0.095, -0.088), Vector3(0.0, -14.0 * side, 0.0), Vector3(1.0, 1.0, 0.45))
		_part(head, _sphere(0.007, 0.01), _glow("eye_hi", Color.WHITE, 1.0), Vector3(0.033 * side, 0.103, -0.097))
		_part(head, _box(Vector3(0.03, 0.005, 0.006)), _mat("brow", Color(0.55, 0.4, 0.25), {"no_outline": true}),
			Vector3(0.04 * side, 0.128, -0.092), Vector3(0.0, 0.0, -8.0 * side))
		_part(head, _sphere(0.012, 0.03), _mat("gold", GOLD), Vector3(0.1 * side, 0.06, 0.0))
	_part(head, _box(Vector3(0.016, 0.004, 0.004)), _mat("mouth", Color(0.75, 0.38, 0.42), {"no_outline": true}), Vector3(0.0, 0.045, -0.095))
	# Hair cap, bangs, side volume, ahoge.
	_part(head, _sphere(0.118, 0.26), hair, Vector3(0.0, 0.12, 0.018))
	for i: int in 7:
		var x: float = -0.072 + 0.024 * float(i)
		var drop: float = 0.012 * absf(sin(float(i) * 1.9))
		_part(head, _capsule(0.017, 0.11), hair, Vector3(x, 0.155 - drop, -0.098), Vector3(-8.0, 0.0, -x * 260.0), Vector3(1.4, 1.0, 0.55))
	for side: float in [1.0, -1.0]:
		_part(head, _capsule(0.028, 0.26), hair, Vector3(0.092 * side, 0.05, -0.035), Vector3(-4.0, 0.0, 6.0 * side), Vector3(1.0, 1.0, 0.7))
	_part(head, _capsule(0.012, 0.12), hair, Vector3(0.01, 0.25, 0.0), Vector3(30.0, 0.0, -20.0))


func _build_arm(side: float) -> void:
	var s: String = "r" if side > 0.0 else "l"
	var arm: Node3D = joints[StringName("arm_" + s)]
	var fore: Node3D = joints[StringName("fore_" + s)]
	var hand: Node3D = joints[StringName("hand_" + s)]
	var skin: ShaderMaterial = _mat("skin", SKIN)
	var sleeve: ShaderMaterial = _mat("sleeve", SLEEVE, {"albedo_end": SLEEVE_END, "grad_top": -0.06, "grad_bottom": -0.25})
	var glove: ShaderMaterial = _mat("glove", GLOVE, {"rim_color": Color(1.0, 0.4, 0.7), "rim_strength": 0.5})
	_part(arm, _capsule(0.04, 0.27), skin, Vector3(0.0, -0.12, 0.0))
	# Detached sleeve / cuff from mid upper arm (silver band on the left arm like the reference).
	_part(arm, _cylinder(0.048, 0.052, 0.07), _mat("silver", Color(0.85, 0.85, 0.95), {"roughness": 0.3}) if side < 0.0 else _mat("sleeve_top", SLEEVE),
		Vector3(0.0, -0.17, 0.0))
	_part(fore, _cylinder(0.062, 0.042, 0.1), sleeve, Vector3(0.0, -0.02, 0.0))
	_part(fore, _capsule(0.037, 0.26), sleeve, Vector3(0.0, -0.12, 0.0))
	_part(hand, _sphere(0.036, 0.1), glove, Vector3(0.0, -0.045, -0.005), Vector3.ZERO, Vector3(0.85, 1.0, 1.0))
	_part(hand, _box(Vector3(0.012, 0.06, 0.02)), glove, Vector3(0.03 * side, -0.035, -0.02), Vector3(0.0, 0.0, 25.0 * side))


func _build_leg(side: float) -> void:
	var s: String = "r" if side > 0.0 else "l"
	var thigh: Node3D = joints[StringName("thigh_" + s)]
	var shin: Node3D = joints[StringName("shin_" + s)]
	var foot: Node3D = joints[StringName("foot_" + s)]
	var gold: ShaderMaterial = _mat("gold", GOLD, {"roughness": 0.35, "rim_strength": 0.2})
	_part(thigh, _capsule(0.072, 0.47), _suit(), Vector3(0.0, -0.21, 0.0))
	_part(thigh, _box(Vector3(0.016, 0.22, 0.012)), gold, Vector3(0.03 * side, -0.24, -0.066), Vector3(0.0, 0.0, 14.0 * side))
	_part(shin, _cylinder(0.055, 0.04, 0.44), _suit(), Vector3(0.0, -0.21, 0.0))
	_part(shin, _prism(Vector3(0.05, 0.1, 0.012)), gold, Vector3(0.0, -0.02, -0.05), Vector3(180.0, 0.0, 0.0))
	# Heeled boots: black with pink crystal and gold tip.
	var boot: ShaderMaterial = _mat("boot", Color(0.08, 0.05, 0.09), {"rim_color": Color(1.0, 0.4, 0.75), "rim_strength": 0.5})
	_part(foot, _box(Vector3(0.075, 0.07, 0.17)), boot, Vector3(0.0, -0.04, -0.045), Vector3(-8.0, 0.0, 0.0))
	_part(foot, _box(Vector3(0.025, 0.07, 0.025)), boot, Vector3(0.0, -0.07, 0.04))
	_part(foot, _prism(Vector3(0.04, 0.06, 0.02)), _glow("gem", GEM, 1.1), Vector3(0.0, 0.0, -0.06))
	_part(foot, _box(Vector3(0.078, 0.012, 0.03)), gold, Vector3(0.0, -0.075, -0.125))


# --- hair and sashes ---------------------------------------------------------------------

func _gradient_mat(prefix: String, a: Color, b: Color, i: int, count: int) -> ShaderMaterial:
	var t: float = float(i) / float(maxi(count - 1, 1))
	return _mat("%s_%d" % [prefix, i], a.lerp(b, t * t), {"rim_color": Color(1.0, 0.95, 0.75), "rim_strength": 0.35})


func _chain(parent: Node3D, at: Vector3, count: int, seg_len: float, width: Vector2, thick: float,
		rest: Array[Vector2], prefix: String, colors: PackedColorArray, flat: bool) -> Chain:
	var c: Chain = Chain.new()
	var holder: Node3D = parent
	for i: int in count:
		var j: Node3D = Node3D.new()
		j.position = at if i == 0 else Vector3(0.0, -seg_len, 0.0)
		holder.add_child(j)
		var w: float = lerpf(width.x, width.y, float(i) / float(maxi(count - 1, 1)))
		var mat: ShaderMaterial = _gradient_mat(prefix, colors[0], colors[1], i, count)
		if flat:
			_part(j, _box(Vector3(w, seg_len * 1.08, thick)), mat, Vector3(0.0, -seg_len * 0.5, 0.0))
		else:
			_part(j, _capsule(0.5, 1.0), mat, Vector3(0.0, -seg_len * 0.5, 0.0), Vector3.ZERO, Vector3(w, seg_len * 1.7, thick))
		c.joints.append(j)
		c.rest.append(rest[mini(i, rest.size() - 1)])
		c.angle.append(rest[mini(i, rest.size() - 1)])
		c.velocity.append(Vector2.ZERO)
		holder = j
	chains.append(c)
	return c


func _build_hair() -> void:
	var head: Node3D = joints[&"head"]
	var colors: PackedColorArray = PackedColorArray([hair_color, hair_tip])
	var short: bool = hair_style == HeroData.Hair.SHORT
	# Back curtain: to the calves (long) or a bob above the shoulders (short).
	var strands: int = 5 if not short else 6
	for i: int in strands:
		var x: float = -0.08 + 0.16 * float(i) / float(strands - 1)
		var spread: float = x * (70.0 if not short else 120.0)
		var rest: Array[Vector2] = [Vector2(-32.0, spread), Vector2(-14.0, spread * 0.6), Vector2(-9.0, spread * 0.5),
			Vector2(-7.0, spread * 0.45), Vector2(-5.0, spread * 0.4), Vector2(-4.0, spread * 0.4), Vector2(-3.0, spread * 0.4)]
		var c: Chain
		if short:
			rest = [Vector2(-38.0, spread), Vector2(-12.0, spread * 0.8)]
			c = _chain(head, Vector3(x, 0.13, 0.06), 2, 0.1, Vector2(0.075, 0.05), 0.05, rest, "hair", colors, false)
			c.stiffness = 110.0
			c.drag = 0.5
		else:
			c = _chain(head, Vector3(x, 0.12, 0.07), 7, 0.19, Vector2(0.14, 0.075), 0.05, rest, "hair", colors, false)
			c.drag = 1.0
		c.phase_seed = float(i) * 1.7
	# Front locks framing the face (chin length when short).
	for side: float in [1.0, -1.0]:
		var rest: Array[Vector2] = [Vector2(4.0, 10.0 * side), Vector2(2.0, 4.0 * side), Vector2(0.0, 2.0 * side)]
		var c: Chain = _chain(head, Vector3(0.085 * side, 0.05, -0.03), 5 if not short else 2, 0.13 if not short else 0.08,
			Vector2(0.06, 0.03), 0.035, rest, "hair", colors, false)
		c.phase_seed = 9.0 + side
		c.drag = 0.7
		c.stiffness = 80.0


func _build_sashes() -> void:
	var hips: Node3D = joints[&"hips"]
	var colors: PackedColorArray = PackedColorArray([SASH, SASH_TIP])
	for side: float in [1.0, -1.0]:
		var front_rest: Array[Vector2] = [Vector2(8.0, 3.0 * side), Vector2(3.0, 1.0 * side)]
		var f: Chain = _chain(hips, Vector3(0.035 * side, -0.07, -0.13), 5, 0.14, Vector2(0.05, 0.04), 0.01, front_rest, "sash", colors, true)
		f.front = true
		f.drag = 0.6
		f.phase_seed = 20.0 + side
		var back_rest: Array[Vector2] = [Vector2(-14.0, 8.0 * side), Vector2(-6.0, 4.0 * side), Vector2(-3.0, 2.0 * side)]
		var b: Chain = _chain(hips, Vector3(0.07 * side, -0.02, 0.13), 7, 0.14, Vector2(0.08, 0.05), 0.012, back_rest, "sash", colors, true)
		b.drag = 0.8
		b.phase_seed = 30.0 + side


# --- weapon ------------------------------------------------------------------------------

func _build_weapon() -> void:
	var hand_r: Node3D = joints[&"hand_r"]
	var hand_l: Node3D = joints[&"hand_l"]
	var gold: ShaderMaterial = _mat("gold", GOLD, {"roughness": 0.35, "rim_strength": 0.2})
	var blade: ShaderMaterial = _mat("blade", Color(0.7, 0.68, 0.85), {"emission": Color(0.85, 0.5, 1.0), "emission_energy": 0.0, "roughness": 0.25, "rim_strength": 0.15})
	var grip: Vector3 = Vector3(0.0, -0.06, 0.0)
	match weapon:
		Weapon.SWORD:
			var root: Node3D = _holder(hand_r, grip)
			_part(root, _cylinder(0.016, 0.016, 0.2), _mat("glove", GLOVE), Vector3(0.0, 0.0, 0.03), Vector3(90.0, 0.0, 0.0))
			_part(root, _box(Vector3(0.2, 0.03, 0.035)), gold, Vector3(0.0, 0.0, -0.07))
			_part(root, _box(Vector3(0.055, 0.012, 1.0)), blade, Vector3(0.0, 0.0, -0.58))
			_part(root, _prism(Vector3(0.055, 0.12, 0.012)), blade, Vector3(0.0, 0.0, -1.14), Vector3(-90.0, 0.0, 0.0))
			_part(root, _sphere(0.025, 0.05), _glow("gem", GEM, 1.1), Vector3(0.0, 0.0, -0.07))
			weapon_tip = _holder(root, Vector3(0.0, 0.0, -1.15))
		Weapon.DAGGERS:
			for hand: Node3D in [hand_r, hand_l]:
				var root: Node3D = _holder(hand, grip)
				_part(root, _box(Vector3(0.1, 0.02, 0.025)), gold, Vector3(0.0, 0.0, -0.04))
				_part(root, _prism(Vector3(0.05, 0.38, 0.012)), blade, Vector3(0.0, 0.0, -0.24), Vector3(-90.0, 0.0, 0.0))
				if weapon_tip == null:
					weapon_tip = _holder(root, Vector3(0.0, 0.0, -0.42))
		Weapon.STAFF:
			var root: Node3D = _holder(hand_r, grip)
			_part(root, _cylinder(0.018, 0.022, 1.6), _mat("staff", Color(0.22, 0.12, 0.3)), Vector3(0.0, 0.42, 0.0))
			var halo: TorusMesh = TorusMesh.new()
			halo.inner_radius = 0.07
			halo.outer_radius = 0.09
			_part(root, halo, gold, Vector3(0.0, 1.22, 0.0), Vector3(90.0, 0.0, 0.0))
			_part(root, _prism(Vector3(0.08, 0.2, 0.08)), _glow("gem", GEM, 1.1), Vector3(0.0, 1.24, 0.0))
			weapon_tip = _holder(root, Vector3(0.0, 1.25, 0.0))
		Weapon.BOW:
			var root: Node3D = _holder(hand_l, grip)
			for dir: float in [1.0, -1.0]:
				_part(root, _capsule(0.016, 0.62), gold, Vector3(0.0, 0.29 * dir, -0.06), Vector3(-14.0 * dir, 0.0, 0.0))
				_part(root, _prism(Vector3(0.04, 0.1, 0.012)), _glow("gem", GEM, 1.1), Vector3(0.0, 0.6 * dir, -0.13))
			_part(root, _cylinder(0.003, 0.003, 1.15), _glow("string", Color(1.0, 0.8, 1.0), 1.0), Vector3(0.0, 0.0, 0.02))
			weapon_tip = _holder(root, Vector3(0.0, 0.0, -0.1))


## Bakes the rigid parts of each joint (and weapon holder) into one mesh, one surface per
## material: ~3x fewer draw calls. Chain segments stay separate (they move).
func _merge_static_parts() -> void:
	var targets: Array[Node3D] = []
	for id: StringName in joints:
		targets.append(joints[id])
		for child: Node in joints[id].get_children():
			var holder: Node3D = child as Node3D
			if holder != null and not holder is MeshInstance3D and not joints.values().has(holder) and not _is_chain_joint(holder):
				targets.append(holder)
	for node: Node3D in targets:
		merge_children(node)


func _is_chain_joint(node: Node3D) -> bool:
	for c: Chain in chains:
		if c.joints.has(node):
			return true
	return false


static func merge_children(node: Node3D) -> MeshInstance3D:
	var parts: Array[MeshInstance3D] = []
	for child: Node in node.get_children():
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi != null and mi.mesh is PrimitiveMesh:
			parts.append(mi)
	if parts.size() < 2:
		return null
	var tools: Dictionary[Material, SurfaceTool] = {}
	for mi: MeshInstance3D in parts:
		var prim: PrimitiveMesh = mi.mesh as PrimitiveMesh
		var st: SurfaceTool = tools.get(prim.material, null)
		if st == null:
			st = SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[prim.material] = st
		st.append_from(prim, 0, mi.transform)
	var merged: ArrayMesh = ArrayMesh.new()
	for mat: Material in tools:
		tools[mat].commit(merged)
		merged.surface_set_material(merged.get_surface_count() - 1, mat)
	for mi: MeshInstance3D in parts:
		node.remove_child(mi)
		mi.free()
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.name = "Merged"
	inst.mesh = merged
	node.add_child(inst)
	return inst


func _holder(parent: Node3D, pos: Vector3) -> Node3D:
	var n: Node3D = Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n
