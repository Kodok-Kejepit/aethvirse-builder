class_name DecorProp
extends StaticBody3D
## Town / camp dressing built from primitives: lamp post, campfire, crate, barrel, fence,
## banner, lantern. Lamps and fires light up at night (lights fade out with distance;
## phones get fewer, shadowless lights).

@export var kind: StringName = &"crate"
@export var tint: Color = Color(1.0, 0.75, 0.4)
@export var seed_value: int = 1
## Dungeons: always burning (no day / night), optionally with a wider light.
@export var always_lit: bool = false
@export var light_range_m: float = 0.0
## Put out (dark challenge rooms): no light, no glow, whatever the time of day.
var snuffed: bool = false

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
		&"streetlight", &"palisade", &"junk", &"water_tank", &"debris":
			_ruined(rng)
		_:
			var s: float = rng.randf_range(0.7, 1.1)
			_box(Vector3(s, s, s), Vector3(0, s * 0.5, 0), WOOD.lerp(tint, 0.1), false)
			_box(Vector3(s + 0.02, 0.08, s + 0.02), Vector3(0, s * 0.5, 0), WOOD.darkened(0.3), false)
			_collide(Vector3(s, s, s), s * 0.5)
			rotation.y = rng.randf_range(0, TAU)


const RUST_IRON: Color = Color(0.36, 0.27, 0.22)
const SODIUM: Color = Color(1.0, 0.62, 0.3)
const SHEET: Color = Color(0.42, 0.4, 0.38)
const CONCRETE_CHUNK: Color = Color(0.55, 0.53, 0.5)
const JUNK_COLORS: Array[Color] = [Color(0.42, 0.3, 0.2), Color(0.42, 0.4, 0.38), Color(0.36, 0.27, 0.22)]


## Dressing for the ruined city and the refugee camp (Ashfall).
func _ruined(rng: RandomNumberGenerator) -> void:
	match kind:
		&"streetlight":
			# Rusted city lamp: some lean, about a third are dead.
			rotation.z = deg_to_rad(rng.randf_range(-9.0, 9.0)) if rng.randf() < 0.4 else 0.0
			_box(Vector3(0.16, 6.0, 0.16), Vector3(0, 3.0, 0), RUST_IRON, true)
			_box(Vector3(1.7, 0.1, 0.1), Vector3(0.8, 5.95, 0), RUST_IRON, false)
			_box(Vector3(0.6, 0.14, 0.32), Vector3(1.55, 5.85, 0), IRON, false)
			if rng.randf() > 0.33:
				_bulb = _glow_mat(SODIUM)
				_box_mat(Vector3(0.5, 0.05, 0.26), Vector3(1.55, 5.77, 0), _bulb)
				tint = SODIUM
				_add_light(Vector3(1.55, 5.5, 0), 11.0)
		&"palisade":
			# Makeshift wall: uneven planks and a corrugated sheet nailed to two rails.
			for i: int in 9:
				var x: float = -1.4 + float(i) * 0.35
				var h: float = rng.randf_range(1.5, 2.3)
				var plank: MeshInstance3D = _box(Vector3(0.28, h, 0.06), Vector3(x, h * 0.5, 0), WOOD.lerp(Color(0.3, 0.25, 0.2), rng.randf()), false)
				plank.rotation.z = deg_to_rad(rng.randf_range(-4.0, 4.0))
			for y: float in [0.5, 1.3]:
				_box(Vector3(3.1, 0.09, 0.08), Vector3(0, y, 0.05), WOOD.darkened(0.25), false)
			if rng.randf() < 0.5:
				var sheet: MeshInstance3D = _box(Vector3(1.2, 1.5, 0.03), Vector3(rng.randf_range(-0.8, 0.8), 0.9, -0.05), SHEET, false)
				sheet.material_override = WorldStreamer.shared_material(Color(0.5, 0.35, 0.25))
			_collide(Vector3(3.1, 2.0, 0.3), 1.0)
		&"junk":
			# Scrap heap: boxes, a barrel on its side, planks, a tyre.
			for i: int in 6:
				var sz: Vector3 = Vector3(rng.randf_range(0.4, 1.0), rng.randf_range(0.3, 0.7), rng.randf_range(0.4, 0.9))
				var b: MeshInstance3D = _box(sz, Vector3(rng.randf_range(-0.8, 0.8), sz.y * 0.5, rng.randf_range(-0.6, 0.6)),
					JUNK_COLORS[i % JUNK_COLORS.size()], false)
				b.rotation = Vector3(0, rng.randf_range(0, TAU), deg_to_rad(rng.randf_range(-12, 12)))
			var tyre: TorusMesh = TorusMesh.new()
			tyre.inner_radius = 0.2
			tyre.outer_radius = 0.38
			_mesh(tyre, _mat(Color(0.12, 0.12, 0.13)), Vector3(0.6, 0.12, 0.5))
			_collide(Vector3(2.0, 0.9, 1.6), 0.45)
		&"water_tank":
			# Rusty drum on a timber stand with a tap: the camp's water.
			for x: float in [-0.6, 0.6]:
				for z: float in [-0.6, 0.6]:
					_box(Vector3(0.14, 1.4, 0.14), Vector3(x, 0.7, z), WOOD, false)
			_box(Vector3(1.5, 0.1, 1.5), Vector3(0, 1.4, 0), WOOD.darkened(0.2), false)
			var drum: CylinderMesh = CylinderMesh.new()
			drum.top_radius = 0.7
			drum.bottom_radius = 0.7
			drum.height = 1.5
			_mesh(drum, _mat(Color(0.5, 0.35, 0.25)), Vector3(0, 2.2, 0))
			_box(Vector3(0.06, 0.06, 0.4), Vector3(0, 1.6, 0.75), IRON, false)
			_collide(Vector3(1.5, 3.0, 1.5), 1.5)
		&"debris":
			# Broken concrete slabs with bent rebar.
			for i: int in 5:
				var sz2: Vector3 = Vector3(rng.randf_range(0.8, 2.2), rng.randf_range(0.2, 0.5), rng.randf_range(0.6, 1.6))
				var chunk: MeshInstance3D = _box(sz2, Vector3(rng.randf_range(-1.2, 1.2), sz2.y * 0.4, rng.randf_range(-1.0, 1.0)), CONCRETE_CHUNK, false)
				chunk.rotation = Vector3(deg_to_rad(rng.randf_range(-25, 25)), rng.randf_range(0, TAU), deg_to_rad(rng.randf_range(-25, 25)))
			for i2: int in 3:
				var bar: MeshInstance3D = _box(Vector3(0.03, rng.randf_range(0.6, 1.3), 0.03), Vector3(rng.randf_range(-1, 1), 0.4, rng.randf_range(-0.8, 0.8)), RUST_IRON, false)
				bar.rotation = Vector3(deg_to_rad(rng.randf_range(-50, 50)), 0, deg_to_rad(rng.randf_range(-50, 50)))
			_collide(Vector3(2.4, 0.6, 2.0), 0.3)


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
	var night: float = 1.0 if always_lit or GameState.clock == null else 1.0 - clampf(sin((GameState.clock.day_fraction() - 0.25) * TAU) * 1.5 + 0.2, 0.0, 1.0)
	var lit: bool = not snuffed and (kind == &"campfire" or night > 0.15 or kind == &"streetlight" and night > 0.05)
	_light.visible = lit
	if lit:
		var flicker: float = 1.0 + (sin(Time.get_ticks_msec() * 0.013) * 0.08 if kind == &"campfire" else 0.0)
		_light.light_energy = (1.6 if kind == &"campfire" else 1.3) * maxf(night, 0.35 if kind == &"campfire" else 0.0) * flicker
	if _bulb != null:
		_bulb.emission_energy_multiplier = 0.0 if snuffed else 0.3 + 2.5 * night


func _add_light(at: Vector3, range_m: float) -> void:
	_light = OmniLight3D.new()
	_light.position = at
	_light.light_color = tint
	_light.omni_range = light_range_m if light_range_m > 0.0 else range_m
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
