class_name GrassField
extends MultiMeshInstance3D
## Swaying grass (and a few flowers) scattered over a chunk area with one MultiMesh.
## Blade count scales with the platform's foliage density.

@export var area: Vector2 = Vector2(124, 124)
@export var blades: int = 5000
@export var color: Color = Color(0.25, 0.5, 0.25)
@export var seed_value: int = 1

const BLADE_H: float = 0.38


func _ready() -> void:
	_build.call_deferred()


func _build() -> void:
	var ground: TerrainPatch = null
	for sib: Node in get_parent().get_children():
		if sib is TerrainPatch:
			ground = sib
	var density: float = Settings.profile.foliage_density if Settings.profile != null else 1.0
	var count: int = int(float(blades) * density)
	if count <= 0:
		return
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _blade_mesh()
	mm.instance_count = count
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var centres: Array[Vector2] = []
	for k: int in 90:
		centres.append(Vector2(rng.randf_range(-area.x, area.x) * 0.5, rng.randf_range(-area.y, area.y) * 0.5))
	for i: int in count:
		# Clumps: most blades gather around patch centres.
		var patch: Vector2 = centres[rng.randi() % centres.size()]
		var pos: Vector3 = Vector3(patch.x + rng.randfn(0.0, 4.0), 0.0, patch.y + rng.randfn(0.0, 4.0))
		pos.x = clampf(pos.x, -area.x * 0.5, area.x * 0.5)
		pos.z = clampf(pos.z, -area.y * 0.5, area.y * 0.5)
		if ground != null:
			pos.y = ground.local_height(pos.x + position.x, pos.z + position.z) - 0.02
		var s: float = rng.randf_range(0.6, 1.4)
		var b: Basis = Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(b, pos))
		var flower: bool = rng.randf() < 0.025
		mm.set_instance_color(i, Color(1, 0.85, 0.4) if flower else color.lerp(Color(0.5, 0.65, 0.3), rng.randf() * 0.5))
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_range_end = 90.0


func _blade_mesh() -> ArrayMesh:
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k: int in 2:
		var a: float = float(k) * PI * 0.5
		var side: Vector3 = Vector3(cos(a), 0, sin(a)) * 0.035
		st.set_normal(Vector3.UP)
		st.add_vertex(-side)
		st.add_vertex(side)
		st.add_vertex(Vector3(0, BLADE_H, 0))
	var mesh: ArrayMesh = st.commit()
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = GRASS_SHADER
	mesh.surface_set_material(0, mat)
	return mesh


const GRASS_SHADER: Shader = preload("res://assets/shaders/grass.gdshader")
