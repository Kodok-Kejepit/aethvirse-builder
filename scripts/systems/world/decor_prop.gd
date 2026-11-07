class_name DecorProp
extends StaticBody3D
## Town / camp dressing built from primitives: lamp post, campfire, crate, barrel, fence,
## banner, lantern. Lamps and fires light up at night (lights fade out with distance;
## phones get fewer, shadowless lights).

@export var kind: StringName = &"crate"
@export var tint: Color = Color(1.0, 0.75, 0.4)
@export var seed_value: int = 1

const WOOD: Color = Color(0.42, 0.3, 0.2)
const IRON: Color = Color(0.22, 0.22, 0.25)
const LIGHT_FADE_M: float = 55.0

var _light: OmniLight3D = null
var _flame: CPUParticles3D = null
var _bulb: StandardMaterial3D = null


func _ready() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	if _use_model():
		return
	match kind:
		&"lamp":
			_box(Vector3(0.14, 3.6, 0.14), Vector3(0, 1.8, 0), IRON, true)
			_box(Vector3(0.8, 0.08, 0.1), Vector3(0.35, 3.55, 0), IRON, false)
			_bulb = _glow_mat(tint)
			_sphere(0.16, Vector3(0.7, 3.38, 0), _bulb)
			_add_light(Vector3(0.7, 3.2, 0), 9.0)
		&"lantern":
			_box(Vector3(0.1, 2.2, 0.1), Vector3(0, 1.1, 0), WOOD, true)
			_bulb = _glow_mat(tint)
			_box_mat(Vector3(0.22, 0.3, 0.22), Vector3(0, 2.3, 0), _bulb)
			_add_light(Vector3(0, 2.3, 0), 7.0)
		&"campfire":
			for i: int in 5:
				var a: float = TAU * float(i) / 5.0
				var log_mesh: CylinderMesh = CylinderMesh.new()
				log_mesh.top_radius = 0.08
				log_mesh.bottom_radius = 0.1
				log_mesh.height = 0.9
				var m: MeshInstance3D = _mesh(log_mesh, _mat(WOOD.darkened(0.2)), Vector3(cos(a) * 0.25, 0.15, sin(a) * 0.25))
				m.rotation = Vector3(deg_to_rad(70), -a, 0)
			for i: int in 8:
				var a2: float = TAU * float(i) / 8.0
				_sphere(0.14, Vector3(cos(a2) * 0.6, 0.08, sin(a2) * 0.6), _mat(Color(0.4, 0.4, 0.42)))
			_flame = _fire()
			add_child(_flame)
			_add_light(Vector3(0, 0.8, 0), 10.0)
			_collide(Vector3(1.2, 0.5, 1.2), 0.25)
		&"barrel":
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.36
			cyl.bottom_radius = 0.36
			cyl.height = 1.0
			_mesh(cyl, _mat(WOOD.lerp(tint, 0.15)), Vector3(0, 0.5, 0))
			for y: float in [0.2, 0.8]:
				var band: TorusMesh = TorusMesh.new()
				band.inner_radius = 0.35
				band.outer_radius = 0.39
				_mesh(band, _mat(IRON), Vector3(0, y, 0))
			_collide(Vector3(0.75, 1.0, 0.75), 0.5)
		&"fence":
			for x: float in [-1.4, 0.0, 1.4]:
				_box(Vector3(0.12, 1.1, 0.12), Vector3(x, 0.55, 0), WOOD, false)
			for y: float in [0.4, 0.85]:
				_box(Vector3(3.0, 0.1, 0.06), Vector3(0, y, 0), WOOD.lightened(0.1), false)
			_collide(Vector3(3.0, 1.1, 0.2), 0.55)
		&"banner":
			_box(Vector3(0.1, 4.0, 0.1), Vector3(0, 2.0, 0), WOOD, true)
			var cloth: MeshInstance3D = _box(Vector3(0.9, 1.6, 0.03), Vector3(0.5, 3.1, 0), tint, false)
			cloth.material_override = WorldStreamer.shared_material(tint, false)
		_:
			var s: float = rng.randf_range(0.7, 1.1)
			_box(Vector3(s, s, s), Vector3(0, s * 0.5, 0), WOOD.lerp(tint, 0.1), false)
			_box(Vector3(s + 0.02, 0.08, s + 0.02), Vector3(0, s * 0.5, 0), WOOD.darkened(0.3), false)
			_collide(Vector3(s, s, s), s * 0.5)
			rotation.y = rng.randf_range(0, TAU)


## Owner model `prop_<kind>` replaces the primitives; lights / fire stay.
const MODEL_HEIGHT: Dictionary[StringName, float] = {
	&"lamp": 3.8, &"lantern": 2.5, &"campfire": 0.8, &"barrel": 1.0, &"fence": 1.1, &"banner": 4.0, &"crate": 0.9,
}


func _use_model() -> bool:
	var h: float = MODEL_HEIGHT.get(kind, 1.0)
	if not PropInstance.attach_model(self, StringName("prop_" + String(kind)), h):
		return false
	_collide(Vector3(0.8, h, 0.8) if kind != &"fence" else Vector3(3.0, h, 0.2), h * 0.5)
	match kind:
		&"lamp":
			_add_light(Vector3(0.7, 3.2, 0), 9.0)
		&"lantern":
			_add_light(Vector3(0, 2.3, 0), 7.0)
		&"campfire":
			_flame = _fire()
			add_child(_flame)
			_add_light(Vector3(0, 0.8, 0), 10.0)
	return true


func _process(_delta: float) -> void:
	if _light == null:
		return
	var night: float = 1.0 - clampf(sin((GameState.clock.day_fraction() - 0.25) * TAU) * 1.5 + 0.2, 0.0, 1.0)
	var lit: bool = kind == &"campfire" or night > 0.15
	_light.visible = lit
	if lit:
		var flicker: float = 1.0 + (sin(Time.get_ticks_msec() * 0.013) * 0.08 if kind == &"campfire" else 0.0)
		_light.light_energy = (1.6 if kind == &"campfire" else 1.3) * maxf(night, 0.35 if kind == &"campfire" else 0.0) * flicker
	if _bulb != null:
		_bulb.emission_energy_multiplier = 0.3 + 2.5 * night


func _add_light(at: Vector3, range_m: float) -> void:
	_light = OmniLight3D.new()
	_light.position = at
	_light.light_color = tint
	_light.omni_range = range_m
	_light.shadow_enabled = false
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = LIGHT_FADE_M * (0.5 if OS.has_feature("mobile") else 1.0)
	_light.distance_fade_length = 10.0
	add_child(_light)


func _fire() -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	p.amount = 28
	p.lifetime = 0.8
	p.position = Vector3(0, 0.25, 0)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.2
	p.direction = Vector3.UP
	p.spread = 12.0
	p.gravity = Vector3(0, 1.5, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.2
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.6
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	quad.material = m
	p.mesh = quad
	var g: Gradient = Gradient.new()
	g.set_color(0, Color(1.0, 0.8, 0.3, 1.0))
	g.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	p.color_ramp = g
	return p


func _mat(c: Color) -> Material:
	return WorldStreamer.shared_material(c)


static func _glow_mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.0
	return m


func _mesh(mesh: PrimitiveMesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	mesh.material = mat
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	if Settings.profile != null:
		mi.visibility_range_end = Settings.profile.view_distance_m * 0.35
	add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, c: Color, collide: bool) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	var mi: MeshInstance3D = _mesh(bm, _mat(c), pos)
	if collide:
		_collide(size, pos.y)
	return mi


func _box_mat(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	return _mesh(bm, mat, pos)


func _sphere(r: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	return _mesh(sm, mat, pos)


func _collide(size: Vector3, y: float) -> void:
	var cs: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position.y = y
	add_child(cs)
