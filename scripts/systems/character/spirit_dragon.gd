class_name SpiritDragon
extends Node3D
## Serpentine spirit dragon that coils up around the heroine when she casts a skill, rears
## above her shoulder, strikes forward and dissolves. Purely visual (the skill deals the
## damage). Body segments trail the analytic head path, so no history buffer is needed.
## Lives in model space (child of the character model): it turns with her facing.

const SHADER: Shader = preload("res://assets/shaders/spirit_dragon.gdshader")
const SEGMENTS: int = 36
## Seconds between neighbouring body segments along the head path.
const LAG_S: float = 0.022
const FADE_IN_S: float = 0.3
const FADE_OUT_S: float = 0.45
const COIL_S: float = 0.85
const REAR_S: float = 0.3
const STRIKE_S: float = 0.35

var duration_s: float = 1.9
var scale_factor: float = 1.0
var elapsed: float = 0.0

var _material: ShaderMaterial
var _segments: Array[Node3D] = []
var _head: Node3D
var _sparks: CPUParticles3D


## `ultimate` = longer, larger, two full coils.
func setup(ultimate: bool) -> void:
	scale_factor = 1.35 if ultimate else 1.0
	duration_s = 2.6 if ultimate else 1.9
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.set_shader_parameter(&"dissolve", 1.0)
	_build_body()
	_build_head()
	_build_sparks()
	_update_transforms()


func is_finished() -> bool:
	return elapsed >= duration_s


func _process(delta: float) -> void:
	elapsed += delta
	if is_finished():
		queue_free()
		return
	var fade: float = 1.0 - smoothstep(0.0, FADE_IN_S, elapsed)
	fade = maxf(fade, smoothstep(duration_s - FADE_OUT_S, duration_s, elapsed))
	_material.set_shader_parameter(&"dissolve", fade)
	_update_transforms()


## Head position (model space) at time `t` since the summon. t < 0 = still underground.
func head_position(t: float) -> Vector3:
	var s: float = scale_factor
	var coil_end: float = COIL_S * s
	if t < coil_end:
		var k: float = t / coil_end
		var turns: float = 1.25 * s
		var a: float = PI * 0.5 + TAU * turns * k
		var r: float = (1.2 + 0.15 * sin(k * PI)) * s
		return Vector3(cos(a) * r, -0.4 + 2.9 * s * k, sin(a) * r)
	var coil_top: Vector3 = head_position(coil_end - 0.0001)
	var rear: Vector3 = Vector3(0.7, 2.9, 0.9) * s
	if t < coil_end + REAR_S:
		return coil_top.lerp(rear, smoothstep(0.0, 1.0, (t - coil_end) / REAR_S))
	var strike_t: float = (t - coil_end - REAR_S) / STRIKE_S
	var target: Vector3 = Vector3(0.0, 0.9, -6.5) * s
	if strike_t < 1.0:
		var k2: float = strike_t * strike_t
		var mid: Vector3 = rear.lerp(target, k2)
		mid.y += sin(strike_t * PI) * 0.6
		return mid
	# Swoop up and away while dissolving.
	var after: float = strike_t - 1.0
	return target + Vector3(0.0, after * 2.5, -after * 3.0) * s


func _update_transforms() -> void:
	for i: int in _segments.size():
		var t: float = elapsed - float(i + 1) * LAG_S * scale_factor
		var pos: Vector3 = head_position(t)
		var ahead: Vector3 = head_position(t + LAG_S)
		var seg: Node3D = _segments[i]
		seg.position = pos
		if pos.distance_squared_to(ahead) > 0.000001:
			seg.basis = Basis.looking_at(ahead - pos, Vector3.UP).scaled(seg.scale)
	var hp: Vector3 = head_position(elapsed)
	var dir: Vector3 = head_position(elapsed + 0.02) - hp
	_head.position = hp
	if dir.length_squared() > 0.000001:
		_head.basis = Basis.looking_at(dir, Vector3.UP)


func _build_body() -> void:
	var fin_mat: ShaderMaterial = _material
	for i: int in SEGMENTS:
		var k: float = float(i) / float(SEGMENTS - 1)
		var radius: float = lerpf(0.17, 0.035, k * k) * scale_factor
		var seg: Node3D = Node3D.new()
		add_child(seg)
		var mesh: SphereMesh = SphereMesh.new()
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 10
		mesh.rings = 5
		mesh.material = _material
		var body: MeshInstance3D = MeshInstance3D.new()
		body.mesh = mesh
		body.scale = Vector3(1.0, 0.92, 2.7)
		body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		seg.add_child(body)
		if i % 3 == 0 and i < SEGMENTS - 4:
			var fin: MeshInstance3D = MeshInstance3D.new()
			var prism: PrismMesh = PrismMesh.new()
			prism.size = Vector3(0.02, radius * 1.3, radius * 1.4)
			prism.material = fin_mat
			fin.mesh = prism
			fin.position = Vector3(0.0, radius * 1.15, 0.05)
			fin.rotation_degrees = Vector3(-30.0, 0.0, 0.0)
			fin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			seg.add_child(fin)
		_segments.append(seg)


func _build_head() -> void:
	_head = Node3D.new()
	add_child(_head)
	var s: float = scale_factor
	_mesh(_head, _box(Vector3(0.24, 0.16, 0.3) * s), Vector3(0.0, 0.0, -0.05 * s))
	_mesh(_head, _box(Vector3(0.16, 0.09, 0.24) * s), Vector3(0.0, -0.02 * s, -0.27 * s))
	_mesh(_head, _box(Vector3(0.15, 0.05, 0.26) * s), Vector3(0.0, -0.1 * s, -0.22 * s), Vector3(-14.0, 0.0, 0.0))
	var eye_mat: StandardMaterial3D = StandardMaterial3D.new()
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	eye_mat.albedo_color = Color(1.0, 0.35, 0.8)
	for side: float in [1.0, -1.0]:
		var eye: MeshInstance3D = _mesh(_head, _box(Vector3(0.05, 0.025, 0.05) * s), Vector3(0.1 * side, 0.05, -0.12) * s)
		eye.material_override = eye_mat
		# Swept-back horns, mane fins and long whiskers.
		_mesh(_head, _prism(Vector3(0.04, 0.34, 0.06) * s), Vector3(0.08 * side, 0.15, 0.12) * s, Vector3(-60.0, 0.0, -12.0 * side))
		_mesh(_head, _prism(Vector3(0.03, 0.2, 0.05) * s), Vector3(0.1 * side, 0.02, 0.15) * s, Vector3(-80.0, 0.0, -50.0 * side))
		var whisker: CylinderMesh = CylinderMesh.new()
		whisker.top_radius = 0.008 * s
		whisker.bottom_radius = 0.002 * s
		whisker.height = 0.6 * s
		whisker.radial_segments = 4
		_mesh(_head, whisker, Vector3(0.12 * side, -0.04, -0.15) * s + Vector3(0.18 * side, 0.0, 0.18) * s, Vector3(70.0, 0.0, 35.0 * side))
	var light: OmniLight3D = OmniLight3D.new()
	light.light_color = Color(1.0, 0.45, 0.85)
	light.light_energy = 1.6
	light.omni_range = 4.0 * s
	light.shadow_enabled = false
	_head.add_child(light)


func _build_sparks() -> void:
	_sparks = CPUParticles3D.new()
	_sparks.amount = 40
	_sparks.lifetime = 0.7
	_sparks.local_coords = false
	_sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_sparks.emission_sphere_radius = 0.18 * scale_factor
	_sparks.gravity = Vector3(0.0, 0.4, 0.0)
	_sparks.initial_velocity_min = 0.1
	_sparks.initial_velocity_max = 0.6
	_sparks.scale_amount_min = 0.5
	_sparks.scale_amount_max = 1.0
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.6, 0.95, 0.9)
	mat.vertex_color_use_as_albedo = true
	quad.material = mat
	_sparks.mesh = quad
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color(1.0, 0.8, 1.0, 1.0))
	ramp.set_color(1, Color(0.7, 0.3, 1.0, 0.0))
	_sparks.color_ramp = ramp
	_head.add_child(_sparks)


func _mesh(parent: Node3D, mesh: PrimitiveMesh, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	mesh.material = _material
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = pos
	inst.rotation_degrees = rot
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst


static func _box(size: Vector3) -> BoxMesh:
	var m: BoxMesh = BoxMesh.new()
	m.size = size
	return m


static func _prism(size: Vector3) -> PrismMesh:
	var m: PrismMesh = PrismMesh.new()
	m.size = size
	return m
