class_name TreeProp
extends StaticBody3D
## Procedural low-poly tree (Big Phase 2 stand-in for modelled foliage): oak, pine (with
## snow), palm, dead, crystal. Trunk collides; leaves sway with the foliage shader.

@export var kind: StringName = &"oak"

## Tree kinds drawn from the owner's model sets: kind -> [prop id prefix, variant count].
const VARIANTS: Dictionary[StringName, Array] = {
	&"ruin": ["ruin_tree", 12], &"ruin_twisted": ["ruin_twisted", 4], &"ruin_stump": ["ruin_stump", 4],
	&"ruin_bush": ["ruin_bush", 2],
}
@export var height: float = 9.0
@export var seed_value: int = 0
@export var snowy: bool = false

const BARK: Color = Color(0.33, 0.24, 0.17)
const LEAF: Color = Color(0.22, 0.48, 0.24)
const PINE: Color = Color(0.13, 0.32, 0.22)
const PALM: Color = Color(0.3, 0.55, 0.25)
const CRYSTAL: Color = Color(0.7, 0.55, 1.0)


func _ready() -> void:
	_snap_to_ground.call_deferred()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value if seed_value != 0 else hash(global_position)
	var trunk_r: float = height * (0.045 if kind != &"palm" else 0.035)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cyl: CylinderShape3D = CylinderShape3D.new()
	cyl.radius = trunk_r * 1.2
	cyl.height = height * 0.7
	shape.shape = cyl
	shape.position.y = height * 0.35
	add_child(shape)
	# Owner's model sets: one variant per tree, picked by seed and turned randomly.
	if VARIANTS.has(kind):
		var variants: Array = VARIANTS[kind]
		var count: int = variants[1]
		var model_id: StringName = StringName("%s_%d" % [variants[0], 1 + rng.randi() % count])
		rotation.y = rng.randf_range(0.0, TAU)
		if PropInstance.attach_model(self, model_id, height):
			return
	if PropInstance.attach_model(self, StringName("tree_" + String(kind)), height):
		return
	match kind:
		&"pine":
			_trunk(trunk_r, height * 0.5, 0.0)
			for i: int in 4:
				var r: float = height * (0.32 - 0.06 * float(i))
				var cone: CylinderMesh = CylinderMesh.new()
				cone.top_radius = 0.0
				cone.bottom_radius = r
				cone.height = height * 0.32
				cone.radial_segments = 8
				_leaf(cone, Vector3(0, height * (0.3 + 0.17 * float(i)), 0), PINE, height * 0.3)
				if snowy:
					var cap: CylinderMesh = CylinderMesh.new()
					cap.top_radius = 0.0
					cap.bottom_radius = r * 0.55
					cap.height = height * 0.13
					cap.radial_segments = 8
					_mesh(cap, WorldStreamer.shared_material(Color(0.93, 0.96, 1.0)), Vector3(0, height * (0.4 + 0.17 * float(i)), 0))
		&"palm":
			var lean: float = rng.randf_range(-12.0, 12.0)
			_trunk(trunk_r, height, lean)
			var top: Vector3 = Vector3(sin(deg_to_rad(lean)) * height, height, 0)
			for i: int in 7:
				var frond: BoxMesh = BoxMesh.new()
				frond.size = Vector3(height * 0.08, 0.04, height * 0.36)
				var a: float = TAU * float(i) / 7.0
				var m: MeshInstance3D = _leaf(frond, top, PALM, height * 0.2)
				m.rotation = Vector3(deg_to_rad(28.0), a, 0)
				m.position += Vector3(sin(a), -0.15, cos(a)) * height * 0.16
		&"dead":
			_trunk(trunk_r, height * 0.85, rng.randf_range(-6.0, 6.0))
			for i: int in 4:
				var branch: CylinderMesh = CylinderMesh.new()
				branch.top_radius = trunk_r * 0.15
				branch.bottom_radius = trunk_r * 0.4
				branch.height = height * 0.3
				branch.radial_segments = 5
				var bm: MeshInstance3D = _mesh(branch, WorldStreamer.shared_material(BARK.darkened(0.2)),
					Vector3(0, height * (0.45 + 0.1 * float(i)), 0))
				bm.rotation = Vector3(deg_to_rad(rng.randf_range(35, 60)), rng.randf_range(0, TAU), 0)
		&"crystal":
			for i: int in 5:
				var shard: PrismMesh = PrismMesh.new()
				shard.size = Vector3(height * 0.12, height * rng.randf_range(0.4, 0.9), height * 0.12)
				var m2: MeshInstance3D = _mesh(shard, _crystal_mat(), Vector3(rng.randf_range(-0.6, 0.6), shard.size.y * 0.5, rng.randf_range(-0.6, 0.6)))
				m2.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf_range(0, TAU), rng.randf_range(-0.3, 0.3))
		_:
			_trunk(trunk_r, height * 0.6, rng.randf_range(-4.0, 4.0))
			for i: int in 4:
				var blob: SphereMesh = SphereMesh.new()
				var r2: float = height * rng.randf_range(0.2, 0.3)
				blob.radius = r2
				blob.height = r2 * 1.6
				blob.radial_segments = 10
				blob.rings = 6
				var off: Vector3 = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.55, 0.8), rng.randf_range(-0.2, 0.2)) * height
				# Four shades only, so a forest shares a few materials (chunk batching).
				_leaf(blob, off, LEAF.lerp(Color(0.35, 0.55, 0.2), floorf(rng.randf() * 4.0) / 3.0), height * 0.8)


func _trunk(r: float, h: float, lean_deg: float) -> void:
	var trunk: CylinderMesh = CylinderMesh.new()
	trunk.top_radius = r * 0.6
	trunk.bottom_radius = r
	trunk.height = h
	trunk.radial_segments = 7
	var m: MeshInstance3D = _mesh(trunk, WorldStreamer.shared_material(BARK), Vector3(0, h * 0.5, 0))
	m.rotation_degrees.z = lean_deg
	m.position.x = sin(deg_to_rad(-lean_deg)) * h * 0.5


func _leaf(mesh: PrimitiveMesh, pos: Vector3, color: Color, _sway_ref: float) -> MeshInstance3D:
	var mat: ShaderMaterial = WorldStreamer.shared_material(color, false) as ShaderMaterial
	return _mesh(mesh, mat, pos)


func _mesh(mesh: PrimitiveMesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	mesh.material = mat
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	if Settings.profile != null:
		mi.visibility_range_end = Settings.profile.view_distance_m * 0.5
	add_child(mi)
	return mi


func _crystal_mat() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = CRYSTAL
	m.emission_enabled = true
	m.emission = CRYSTAL
	m.emission_energy_multiplier = 1.2
	m.roughness = 0.2
	return m


## Sit on rolling terrain (the TerrainPatch builds in the same frame).
func _snap_to_ground() -> void:
	if is_inside_tree():
		position.y += TerrainPatch.height_at(get_tree(), global_position)
