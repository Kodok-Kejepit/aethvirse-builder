class_name GrassField
extends MultiMeshInstance3D
@warning_ignore_start("integer_division")
## Swaying grass (and a few flowers) scattered over a chunk area with one MultiMesh.
## Each instance is a tuft of curved, tapering blades of different heights and lean
## (BLADES_PER_TUFT); `blades` stays the blade budget. Count scales with foliage density.

@export var area: Vector2 = Vector2(124, 124)
@export var blades: int = 5000
@export var color: Color = Color(0.25, 0.5, 0.25)
@export var seed_value: int = 1

const BLADES_PER_TUFT: int = 5
const SEGMENTS: int = 3
## One tuft stands in for this many blades of the `blades` budget (triangle budget).
const BUDGET_PER_TUFT: int = 8
const BLADE_W: float = 0.045
## Fields bigger than this are cut into cells of this size, so the camera only draws the
## cells near it and in view (one big MultiMesh is drawn whole if any corner is visible).
const CELL_M: float = 24.0
## Grass is only drawn near the player (owner: "active things only around the character"):
## DRAW_BASE_M + DRAW_PER_DENSITY_M × foliage density (Ultra / High 70 m, phones 40 m).
const DRAW_BASE_M: float = 30.0
const DRAW_PER_DENSITY_M: float = 40.0


func _ready() -> void:
	_build.call_deferred()


func _build() -> void:
	var ground: TerrainPatch = null
	for sib: Node in get_parent().get_children():
		if sib is TerrainPatch:
			ground = sib
	var density: float = Settings.profile.foliage_density if Settings.profile != null else 1.0
	var count: int = int(float(blades) * density / float(BUDGET_PER_TUFT))
	if count <= 0:
		return
	var draw_m: float = draw_distance(density)
	var mesh: ArrayMesh = _blade_mesh(draw_m)
	var cells: Vector2i = Vector2i(maxi(1, ceili(area.x / CELL_M)), maxi(1, ceili(area.y / CELL_M)))
	var cell_size: Vector2 = Vector2(area.x / cells.x, area.y / cells.y)
	var transforms: Array[Array] = []
	transforms.resize(cells.x * cells.y)
	for c: int in transforms.size():
		transforms[c] = []
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var centres: Array[Vector2] = []
	for k: int in 90:
		centres.append(Vector2(rng.randf_range(-area.x, area.x) * 0.5, rng.randf_range(-area.y, area.y) * 0.5))
	for _i: int in count:
		# Clumps: most blades gather around patch centres.
		var patch: Vector2 = centres[rng.randi() % centres.size()]
		var pos: Vector3 = Vector3(patch.x + rng.randfn(0.0, 4.0), 0.0, patch.y + rng.randfn(0.0, 4.0))
		pos.x = clampf(pos.x, -area.x * 0.5, area.x * 0.5)
		pos.z = clampf(pos.z, -area.y * 0.5, area.y * 0.5)
		if ground != null:
			pos.y = ground.local_height(pos.x + position.x, pos.z + position.z) - 0.02
		var s: float = rng.randf_range(0.7, 1.35)
		var b: Basis = Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(s, s, s))
		var flower: bool = rng.randf() < 0.025
		var tint: Color = Color(1, 0.85, 0.4) if flower else color.lerp(Color(0.5, 0.65, 0.3), rng.randf() * 0.5)
		var cx: int = clampi(floori((pos.x + area.x * 0.5) / cell_size.x), 0, cells.x - 1)
		var cz: int = clampi(floori((pos.z + area.y * 0.5) / cell_size.y), 0, cells.y - 1)
		transforms[cz * cells.x + cx].append([Transform3D(b, pos), tint])
	# A small field is its own MultiMesh; a big one gets one child per cell.
	var single: bool = transforms.size() == 1
	for c: int in transforms.size():
		if transforms[c].is_empty():
			continue
		var target: MultiMeshInstance3D = self if single else MultiMeshInstance3D.new()
		var centre: Vector3 = Vector3.ZERO if single else Vector3(
			-area.x * 0.5 + (float(c % cells.x) + 0.5) * cell_size.x, 0.0,
			-area.y * 0.5 + (float(c / cells.x) + 0.5) * cell_size.y)
		_fill(target, transforms[c], mesh, centre)
		target.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Range is measured to the cell's centre: add its half diagonal.
		target.visibility_range_end = draw_m + cell_size.length() * 0.5
		if not single:
			target.position = centre
			add_child(target)


## Instances of one cell, positions relative to `origin` (the cell node's position).
static func _fill(target: MultiMeshInstance3D, items: Array, mesh: ArrayMesh, origin: Vector3) -> void:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i: int in items.size():
		var item: Array = items[i]
		var xf: Transform3D = item[0]
		var tint: Color = item[1]
		xf.origin -= origin
		mm.set_instance_transform(i, xf)
		mm.set_instance_color(i, tint)
	target.multimesh = mm


static func draw_distance(density: float) -> float:
	return DRAW_BASE_M + DRAW_PER_DENSITY_M * clampf(density, 0.0, 1.0)


## One tuft: blades fanned around the centre, each bending out along a curve and
## narrowing to a point. UV.y runs 0 at the root to 1 at the tip (the shader uses it).
func _blade_mesh(draw_m: float) -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77
	for b: int in BLADES_PER_TUFT:
		var yaw: float = TAU * float(b) / float(BLADES_PER_TUFT) + rng.randf_range(-0.4, 0.4)
		var out: Vector3 = Vector3(cos(yaw), 0.0, sin(yaw))
		var side: Vector3 = out.cross(Vector3.UP).normalized()
		var height: float = rng.randf_range(0.28, 0.62)
		var lean: float = rng.randf_range(0.08, 0.3)
		var root: Vector3 = out * rng.randf_range(0.0, 0.06)
		var rows: Array[Vector3] = []
		var widths: Array[float] = []
		for s: int in SEGMENTS + 1:
			var t: float = float(s) / float(SEGMENTS)
			rows.append(root + Vector3.UP * height * t + out * lean * t * t)
			widths.append(BLADE_W * (1.0 - t) + 0.004)
		for s: int in SEGMENTS:
			var t0: float = float(s) / float(SEGMENTS)
			var t1: float = float(s + 1) / float(SEGMENTS)
			var a0: Vector3 = rows[s] - side * widths[s]
			var a1: Vector3 = rows[s] + side * widths[s]
			var b0: Vector3 = rows[s + 1] - side * widths[s + 1]
			var b1: Vector3 = rows[s + 1] + side * widths[s + 1]
			# Normals lean up so blades light softly from both sides.
			var n: Vector3 = (out * -0.4 + Vector3.UP).normalized()
			for v: Array in [[a0, t0], [a1, t0], [b1, t1], [a0, t0], [b1, t1], [b0, t1]]:
				var p: Vector3 = v[0]
				var tt: float = v[1]
				st.set_normal(n)
				st.set_uv(Vector2(0.0, tt))
				st.add_vertex(p)
	var mesh: ArrayMesh = st.commit()
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = GRASS_SHADER
	mat.set_shader_parameter(&"draw_distance", draw_m)
	mesh.surface_set_material(0, mat)
	return mesh


const GRASS_SHADER: Shader = preload("res://assets/shaders/grass.gdshader")
