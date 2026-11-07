class_name TerrainPatch
extends StaticBody3D
## Rolling ground for one 128 m chunk: noise hills in global space (seamless between
## chunks), flattened around gameplay content (`flatten` = x, z, radius in chunk space),
## height-map collision and a toon terrain material per region style.
## Trees, grass and spawners ask `TerrainPatch.height_at()` to sit on the surface.

const GROUP: StringName = &"terrain_patch"
const SIZE_M: float = 128.0
const STYLES: Dictionary[StringName, Array] = {
	# base, patch, rock, top colour, top height
	&"ashfall": [Color(0.36, 0.34, 0.31), Color(0.33, 0.4, 0.26), Color(0.46, 0.44, 0.43), Color(0.42, 0.4, 0.37), 99.0],
	&"verdant": [Color(0.27, 0.45, 0.23), Color(0.34, 0.52, 0.26), Color(0.4, 0.4, 0.36), Color(0.3, 0.5, 0.25), 99.0],
	&"dunes": [Color(0.74, 0.45, 0.31), Color(0.66, 0.38, 0.26), Color(0.55, 0.3, 0.22), Color(0.8, 0.52, 0.36), 99.0],
	&"frost": [Color(0.78, 0.83, 0.92), Color(0.7, 0.77, 0.88), Color(0.4, 0.43, 0.5), Color(0.93, 0.95, 1.0), 2.5],
	&"archive": [Color(0.35, 0.42, 0.46), Color(0.3, 0.4, 0.32), Color(0.42, 0.44, 0.47), Color(0.35, 0.42, 0.46), 99.0],
	&"fracture": [Color(0.35, 0.26, 0.5), Color(0.45, 0.38, 0.62), Color(0.9, 0.9, 0.95), Color(0.95, 0.95, 1.0), 4.0],
	&"hollow": [Color(0.12, 0.1, 0.16), Color(0.18, 0.15, 0.22), Color(0.8, 0.8, 0.85), Color(0.12, 0.1, 0.16), 99.0],
}
const SHADER: Shader = preload("res://assets/shaders/terrain.gdshader")

@export var style: StringName = &"ashfall"
@export var amplitude: float = 4.0
@export var seed_value: int = 1
@export var resolution: int = 48
## Flatten discs: x, z (chunk space), radius.
@export var flatten: PackedVector3Array = PackedVector3Array()

var _noise: FastNoiseLite
var _detail: FastNoiseLite
var _heights: PackedFloat32Array = PackedFloat32Array()

func _ready() -> void:
	add_to_group(GROUP)
	_noise = FastNoiseLite.new()
	_noise.seed = seed_value
	_noise.frequency = 0.009
	_noise.fractal_octaves = 3
	_detail = FastNoiseLite.new()
	_detail.seed = seed_value + 7
	_detail.frequency = 0.06
	_build()


## Ground height under a global point (0 where no patch covers it).
static func height_at(tree: SceneTree, global_pos: Vector3) -> float:
	for node: Node in tree.get_nodes_in_group(GROUP):
		var p: TerrainPatch = node as TerrainPatch
		var local: Vector3 = global_pos - p.global_position
		if p._noise != null and absf(local.x) <= SIZE_M * 0.5 and absf(local.z) <= SIZE_M * 0.5:
			return p.local_height(local.x, local.z)
	return 0.0


## Exact surface height at chunk-local x/z (bilinear on the grid the mesh uses).
func local_height(x: float, z: float) -> float:
	if _heights.is_empty():
		return _raw_height(x, z)
	var n: int = resolution + 1
	var step: float = SIZE_M / float(resolution)
	var fx: float = clampf((x + SIZE_M * 0.5) / step, 0.0, float(resolution) - 0.001)
	var fz: float = clampf((z + SIZE_M * 0.5) / step, 0.0, float(resolution) - 0.001)
	var ix: int = int(fx)
	var iz: int = int(fz)
	var tx: float = fx - float(ix)
	var tz: float = fz - float(iz)
	var h00: float = _heights[iz * n + ix]
	var h10: float = _heights[iz * n + ix + 1]
	var h01: float = _heights[(iz + 1) * n + ix]
	var h11: float = _heights[(iz + 1) * n + ix + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _raw_height(x: float, z: float) -> float:
	var gx: float = global_position.x + x
	var gz: float = global_position.z + z
	var hill: float = maxf(0.0, _noise.get_noise_2d(gx, gz) * 1.5 + 0.15)
	var h: float = pow(hill, 1.4) * amplitude + (_detail.get_noise_2d(gx, gz) * 0.5 + 0.5) * 0.35
	var mask: float = 1.0
	for f: Vector3 in flatten:
		var d: float = Vector2(x - f.x, z - f.y).length()
		mask = minf(mask, smoothstep(f.z + 1.5, f.z + 12.0, d))
		if mask <= 0.0:
			break
	return h * mask + 0.03


func _build() -> void:
	var n: int = resolution + 1
	var step: float = SIZE_M / float(resolution)
	_heights.resize(n * n)
	for iz: int in n:
		for ix: int in n:
			_heights[iz * n + ix] = _raw_height(-SIZE_M * 0.5 + float(ix) * step, -SIZE_M * 0.5 + float(iz) * step)
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz: int in n:
		for ix: int in n:
			st.add_vertex(Vector3(-SIZE_M * 0.5 + float(ix) * step, _heights[iz * n + ix], -SIZE_M * 0.5 + float(iz) * step))
	for iz: int in resolution:
		for ix: int in resolution:
			var a: int = iz * n + ix
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + n)
			st.add_index(a + 1)
			st.add_index(a + n + 1)
			st.add_index(a + n)
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _material(style)
	add_child(mi)
	# Height-map collision (uniform scale = grid step; heights pre-divided).
	var shape: HeightMapShape3D = HeightMapShape3D.new()
	shape.map_width = n
	shape.map_depth = n
	var data: PackedFloat32Array = PackedFloat32Array()
	data.resize(n * n)
	for i: int in n * n:
		data[i] = _heights[i] / step
	shape.map_data = data
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3.ONE * step
	add_child(cs)


static func _material(id: StringName) -> ShaderMaterial:
	var row: Array = STYLES.get(id, STYLES[&"ashfall"])
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SHADER
	m.set_shader_parameter(&"base_color", row[0])
	m.set_shader_parameter(&"patch_color", row[1])
	m.set_shader_parameter(&"rock_color", row[2])
	m.set_shader_parameter(&"top_color", row[3])
	m.set_shader_parameter(&"top_from", row[4])
	return m
