class_name CreatureBody
extends Node3D
## Procedural creature model (Big Phase 2 stand-in for modelled monsters): humanoid,
## quadruped, brute, wraith, wyvern or serpent, built from primitives with a toon material,
## glowing eyes and simple procedural animation (gait from speed, attack raise, bob, flaps).
## Faces -Z like every other model. Used by enemies and NPCs.
## When the owner's model exists (PropData "mob_<enemy id>" / "npc_<npc id>") it replaces
## the primitives; the whole model then breathes, bobs with the gait, leans into attacks,
## floats (wraiths) or hovers (wyverns).

enum Shape { HUMANOID, QUADRUPED, BRUTE, WRAITH, WYVERN, SERPENT }

const KEYWORDS: Dictionary[String, Shape] = {
	"hound": Shape.QUADRUPED, "stalker": Shape.QUADRUPED, "scuttler": Shape.QUADRUPED, "rat": Shape.QUADRUPED,
	"brute": Shape.BRUTE, "yeti": Shape.BRUTE, "colossus": Shape.BRUTE, "elder": Shape.BRUTE, "warden": Shape.BRUTE,
	"wraith": Shape.WRAITH, "ink": Shape.WRAITH, "wyvern": Shape.WYVERN,
	"burrower": Shape.SERPENT, "devourer": Shape.SERPENT, "worm": Shape.SERPENT,
	"viper": Shape.SERPENT, "matriarch": Shape.SERPENT,
}

var shape: Shape = Shape.HUMANOID
var parts: Array[MeshInstance3D] = []
var _limbs: Dictionary[StringName, Node3D] = {}
var _segments: Array[Node3D] = []
var _phase: float = 0.0
var _time: float = 0.0
var _attack: float = 0.0
var _mat: StandardMaterial3D
var _dark: StandardMaterial3D
var _eye: StandardMaterial3D
## Imported model root (null = primitive body).
var _model: Node3D = null
## Rigged monster (assets/creatures/<id>/<id>.glb from Meshy rig + animate): clips play
## by AI state instead of the procedural motion.
var _anim: AnimationPlayer = null
var _state: StringName = &"Idle"
var _clip: StringName = &""
## AI state -> clip name inside the rigged GLB (Meshy library names).
const RIG_CLIPS: Dictionary[StringName, Array] = {
	&"idle": [&"Idle_3", &"Idle", &"Idle_1"],
	&"walk": [&"Slow_Orc_Walk_inplace", &"Walking", &"Walk"],
	&"attack": [&"Heavy_Hammer_Swing", &"Attack"],
	&"hurt": [&"Hit_Reaction"],
	&"dead": [&"dying_backwards", &"Dead"],
}
const RIG_BLEND_S: float = 0.18
const RIG_WALK_SPEED: float = 1.6
const RIG_PATH: String = "res://assets/creatures/%s/%s.glb"


static func shape_for(id: StringName) -> Shape:
	var s: String = String(id)
	for key: String in KEYWORDS:
		if s.contains(key):
			return KEYWORDS[key]
	return Shape.HUMANOID


func build(body_shape: Shape, color: Color, eye_color: Color, size: float) -> void:
	shape = body_shape
	scale = Vector3.ONE * size
	_mat = _toon(color)
	_dark = _toon(color.darkened(0.35))
	_eye = StandardMaterial3D.new()
	_eye.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye.albedo_color = eye_color
	match shape:
		Shape.QUADRUPED:
			_quadruped()
		Shape.BRUTE:
			_humanoid(1.35, 0.75, 1.45, true)
		Shape.WRAITH:
			_wraith()
		Shape.WYVERN:
			_wyvern()
		Shape.SERPENT:
			_serpent()
		_:
			_humanoid(1.0, 1.0, 1.0, false)


## Rigged + animated model for this enemy id, if one was imported (kept at its own height).
func build_rigged(enemy_id: StringName, body_shape: Shape, size: float) -> bool:
	var path: String = RIG_PATH % [enemy_id, enemy_id]
	if not ResourceLoader.exists(path):
		return false
	shape = body_shape
	scale = Vector3.ONE * size
	var model: Node3D = (load(path) as PackedScene).instantiate() as Node3D
	# Meshy rigs face +Z; the game faces -Z.
	model.rotation.y = PI
	_model = Node3D.new()
	_model.name = "Rigged"
	add_child(_model)
	_model.add_child(model)
	var players: Array[Node] = model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		return true
	_anim = players[0] as AnimationPlayer
	for list_name: StringName in [&"idle", &"walk"]:
		var clip: StringName = _find_clip(list_name)
		if clip != &"":
			_anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for mi: Node in model.find_children("*", "MeshInstance3D", true, false):
		parts.append(mi as MeshInstance3D)
		(mi as MeshInstance3D).extra_cull_margin = 2.0
	_play(&"idle")
	return true


func set_state(state: StringName) -> void:
	_state = state


func _find_clip(kind: StringName) -> StringName:
	for c: StringName in RIG_CLIPS[kind]:
		if _anim.has_animation(c):
			return c
	return &""


func _play(kind: StringName, rate: float = 1.0) -> void:
	var clip: StringName = _find_clip(kind)
	if clip == &"":
		return
	_anim.speed_scale = rate
	if clip != _clip:
		_clip = clip
		_anim.play(clip, RIG_BLEND_S)


func _drive_rigged(speed: float, attacking: bool) -> void:
	match _state:
		&"Dead":
			_play(&"dead")
		&"Hurt":
			_play(&"hurt")
		_:
			if attacking:
				_play(&"attack")
			elif speed > 0.3:
				_play(&"walk", clampf(speed / RIG_WALK_SPEED, 0.7, 2.2))
			else:
				_play(&"idle")


func is_rigged() -> bool:
	return _anim != null


## Uses the imported model `model_id` instead of primitives. Returns false if missing.
func build_model(model_id: StringName, body_shape: Shape, size: float) -> bool:
	var d: PropData = PropData.find(model_id)
	if d == null or not ResourceLoader.exists(d.mesh_path):
		return false
	shape = body_shape
	scale = Vector3.ONE * size
	_model = Node3D.new()
	_model.name = "Model"
	add_child(_model)
	if not PropInstance.attach_model(_model, model_id, d.size.y):
		_model.queue_free()
		_model = null
		return false
	for mi: Node in _model.find_children("*", "MeshInstance3D", true, false):
		parts.append(mi as MeshInstance3D)
	_seed_time(model_id)
	return true


func _seed_time(id: StringName) -> void:
	_time = float(hash(id) % 1000) * 0.01


func has_model() -> bool:
	return _model != null


## Called every frame by the owner: horizontal speed (m/s) and whether it is attacking.
func drive(speed: float, attacking: bool, delta: float) -> void:
	_time += delta
	_phase += delta * (2.0 + speed * 2.2)
	_attack = lerpf(_attack, 1.0 if attacking else 0.0, 1.0 - exp(-12.0 * delta))
	var s: float = sin(_phase)
	var moving: float = clampf(speed / 3.0, 0.0, 1.0)
	if _anim != null:
		_drive_rigged(speed, attacking)
		return
	if _model != null:
		_drive_model(s, moving)
		return
	match shape:
		Shape.QUADRUPED:
			_swing(&"leg_fl", s * 35.0 * moving)
			_swing(&"leg_br", s * 35.0 * moving)
			_swing(&"leg_fr", -s * 35.0 * moving)
			_swing(&"leg_bl", -s * 35.0 * moving)
			_rot(&"head", Vector3(-20.0 * _attack + sin(_time * 3.0) * 3.0, 0, 0))
			_rot(&"tail", Vector3(20.0, sin(_time * 4.0) * 25.0, 0))
		Shape.WRAITH:
			position.y = 0.25 + sin(_time * 2.0) * 0.12
			_rot(&"arm_l", Vector3(40.0 + 90.0 * _attack, 0, -25.0))
			_rot(&"arm_r", Vector3(40.0 + 90.0 * _attack, 0, 25.0))
		Shape.WYVERN:
			position.y = 1.0 + sin(_time * 3.0) * 0.15
			var flap: float = sin(_time * (6.0 + moving * 4.0)) * 40.0
			_rot(&"wing_l", Vector3(0, 0, flap))
			_rot(&"wing_r", Vector3(0, 0, -flap))
			_rot(&"head", Vector3(-25.0 * _attack, 0, 0))
		Shape.SERPENT:
			for i: int in _segments.size():
				var seg: Node3D = _segments[i]
				seg.position.x = sin(_time * 3.0 - float(i) * 0.7) * 0.25 * float(i) * 0.25
				seg.position.y = 0.45 + sin(_time * 2.0 - float(i) * 0.5) * 0.08 + (0.8 * _attack if i == 0 else 0.0)
		_:
			_swing(&"leg_l", s * 30.0 * moving)
			_swing(&"leg_r", -s * 30.0 * moving)
			_rot(&"arm_l", Vector3(-s * 25.0 * moving + 130.0 * _attack, 0, -8.0))
			_rot(&"arm_r", Vector3(s * 25.0 * moving + 150.0 * _attack, 0, 8.0))
			_rot(&"torso", Vector3(-10.0 * _attack + absf(s) * 3.0 * moving, 0, 0))


## Whole-model motion for imported (unrigged) bodies.
func _drive_model(s: float, moving: float) -> void:
	var breath: float = sin(_time * 2.2)
	var lift: float = 0.0
	match shape:
		Shape.WRAITH:
			lift = 0.25 + sin(_time * 2.0) * 0.12
		Shape.WYVERN:
			lift = 1.0 + sin(_time * 3.0) * 0.15
		_:
			lift = absf(s) * 0.07 * moving
	_model.position = Vector3(0.0, lift, -0.3 * _attack)
	_model.rotation = Vector3(deg_to_rad(-14.0 * _attack + absf(s) * 2.0 * moving), 0.0, deg_to_rad(s * 3.5 * moving))
	_model.scale = Vector3(1.0 + 0.04 * _attack, 1.0 + 0.015 * breath - 0.05 * _attack, 1.0 + 0.04 * _attack)


func set_overlay(mat: Material) -> void:
	for p: MeshInstance3D in parts:
		p.material_overlay = mat


# --- builders ----------------------------------------------------------------------------

static func _toon(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.75
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.rim_enabled = true
	m.rim = 0.3
	return m


func _pivot(id: StringName, parent: Node3D, pos: Vector3) -> Node3D:
	var n: Node3D = Node3D.new()
	n.position = pos
	parent.add_child(n)
	_limbs[id] = n
	return n


func _part(parent: Node3D, mesh: PrimitiveMesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, s: Vector3 = Vector3.ONE) -> MeshInstance3D:
	mesh.material = mat
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = s
	parent.add_child(mi)
	parts.append(mi)
	return mi


func _swing(id: StringName, deg: float) -> void:
	if _limbs.has(id):
		_limbs[id].rotation_degrees.x = deg


func _rot(id: StringName, deg: Vector3) -> void:
	if _limbs.has(id):
		_limbs[id].rotation_degrees = deg


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var m: CapsuleMesh = CapsuleMesh.new()
	m.radius = r
	m.height = maxf(h, r * 2.0)
	m.radial_segments = 10
	m.rings = 3
	return m


static func _sphere(r: float) -> SphereMesh:
	var m: SphereMesh = SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 10
	m.rings = 6
	return m


static func _box(s: Vector3) -> BoxMesh:
	var m: BoxMesh = BoxMesh.new()
	m.size = s
	return m


func _eyes(parent: Node3D, at: Vector3, gap: float, r: float) -> void:
	for side: float in [1.0, -1.0]:
		_part(parent, _sphere(r), _eye, at + Vector3(gap * side, 0, 0))


func _humanoid(width: float, leg_len: float, arm_len: float, big: bool) -> void:
	var hip_y: float = 0.85 * leg_len
	var torso: Node3D = _pivot(&"torso", self, Vector3(0, hip_y, 0))
	_part(torso, _capsule(0.24 * width, 0.75 * width), _mat, Vector3(0, 0.35 * width, 0), Vector3.ZERO, Vector3(1.15, 1, 0.8))
	var head_y: float = 0.85 * width
	_part(torso, _sphere(0.17 * (0.8 if big else 1.0)), _dark, Vector3(0, head_y, -0.03 if not big else -0.12))
	_eyes(torso, Vector3(0, head_y + 0.02, -0.17 if not big else -0.26), 0.06, 0.03)
	if big:
		for side: float in [1.0, -1.0]:
			_part(torso, _sphere(0.16), _dark, Vector3(0.3 * side * width, 0.65 * width, 0))
	for side: float in [1.0, -1.0]:
		var key: StringName = &"arm_r" if side > 0.0 else &"arm_l"
		var arm: Node3D = _pivot(key, torso, Vector3(0.32 * width * side, 0.62 * width, 0))
		_part(arm, _capsule(0.07 * width, 0.62 * arm_len), _mat, Vector3(0, -0.3 * arm_len, 0))
		_part(arm, _sphere(0.09 * width * (1.4 if big else 1.0)), _dark, Vector3(0, -0.62 * arm_len, 0))
		var lkey: StringName = &"leg_r" if side > 0.0 else &"leg_l"
		var leg: Node3D = _pivot(lkey, self, Vector3(0.13 * width * side, hip_y, 0))
		_part(leg, _capsule(0.08 * width, hip_y), _dark, Vector3(0, -hip_y * 0.5, 0))


func _quadruped() -> void:
	var body: Node3D = _pivot(&"body", self, Vector3(0, 0.55, 0))
	_part(body, _capsule(0.22, 0.9), _mat, Vector3.ZERO, Vector3(90, 0, 0))
	var head: Node3D = _pivot(&"head", body, Vector3(0, 0.12, -0.5))
	_part(head, _box(Vector3(0.24, 0.2, 0.3)), _dark, Vector3(0, 0, -0.08))
	_part(head, _box(Vector3(0.16, 0.12, 0.18)), _dark, Vector3(0, -0.04, -0.28))
	_eyes(head, Vector3(0, 0.05, -0.23), 0.08, 0.025)
	for side: float in [1.0, -1.0]:
		var ear: PrismMesh = PrismMesh.new()
		ear.size = Vector3(0.07, 0.12, 0.05)
		_part(head, ear, _dark, Vector3(0.08 * side, 0.15, 0.0))
	for key: StringName in [&"leg_fl", &"leg_fr", &"leg_bl", &"leg_br"]:
		var x: float = -0.14 if String(key).ends_with("l") else 0.14
		var z: float = -0.3 if String(key).contains("f") else 0.3
		var leg: Node3D = _pivot(key, body, Vector3(x, -0.05, z))
		_part(leg, _capsule(0.055, 0.5), _dark, Vector3(0, -0.25, 0))
	var tail: Node3D = _pivot(&"tail", body, Vector3(0, 0.08, 0.48))
	_part(tail, _capsule(0.04, 0.4), _mat, Vector3(0, 0, 0.18), Vector3(90, 0, 0))


func _wraith() -> void:
	var robe: CylinderMesh = CylinderMesh.new()
	robe.top_radius = 0.16
	robe.bottom_radius = 0.42
	robe.height = 1.3
	_part(self, robe, _mat, Vector3(0, 0.75, 0))
	_part(self, _sphere(0.2), _dark, Vector3(0, 1.5, 0))
	_eyes(self, Vector3(0, 1.52, -0.17), 0.06, 0.03)
	for side: float in [1.0, -1.0]:
		var key: StringName = &"arm_r" if side > 0.0 else &"arm_l"
		var arm: Node3D = _pivot(key, self, Vector3(0.2 * side, 1.3, 0))
		var sleeve: CylinderMesh = CylinderMesh.new()
		sleeve.top_radius = 0.05
		sleeve.bottom_radius = 0.12
		sleeve.height = 0.6
		_part(arm, sleeve, _mat, Vector3(0, -0.3, 0))


func _wyvern() -> void:
	var body: Node3D = _pivot(&"body", self, Vector3(0, 0.5, 0))
	_part(body, _capsule(0.24, 1.0), _mat, Vector3.ZERO, Vector3(90, 0, 0))
	var head: Node3D = _pivot(&"head", body, Vector3(0, 0.25, -0.6))
	_part(head, _box(Vector3(0.2, 0.18, 0.38)), _dark, Vector3(0, 0, -0.1))
	_eyes(head, Vector3(0, 0.05, -0.2), 0.08, 0.025)
	for side: float in [1.0, -1.0]:
		var key: StringName = &"wing_r" if side > 0.0 else &"wing_l"
		var wing: Node3D = _pivot(key, body, Vector3(0.2 * side, 0.12, -0.05))
		var membrane: PrismMesh = PrismMesh.new()
		membrane.size = Vector3(1.2, 0.03, 0.8)
		_part(wing, membrane, _dark, Vector3(0.6 * side, 0, 0.1), Vector3(0, 0, 0))
	_part(body, _capsule(0.06, 0.8), _mat, Vector3(0, 0, 0.75), Vector3(90, 0, 0))


func _serpent() -> void:
	var count: int = 9
	for i: int in count:
		var seg: Node3D = Node3D.new()
		seg.position = Vector3(0, 0.45, float(i) * 0.38)
		add_child(seg)
		_segments.append(seg)
		var r: float = lerpf(0.42, 0.16, float(i) / float(count - 1))
		_part(seg, _sphere(r), _mat if i % 2 == 0 else _dark, Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.85, 1.3))
	var head: Node3D = _segments[0]
	_eyes(head, Vector3(0, 0.15, -0.36), 0.15, 0.05)
	for side: float in [1.0, -1.0]:
		var fang: PrismMesh = PrismMesh.new()
		fang.size = Vector3(0.06, 0.18, 0.06)
		_part(head, fang, _eye, Vector3(0.12 * side, -0.14, -0.38), Vector3(180, 0, 0))
