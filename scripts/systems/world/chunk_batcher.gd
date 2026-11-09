class_name ChunkBatcher
extends RefCounted
## Merges a chunk's static graybox blocks into a few meshes: one per material for the big
## always-drawn slabs, and one per material and 64 m cell for the small blocks (so they
## still fade out by distance). Each block keeps its node and collision; only its own mesh
## goes away. Ashfall drew ~1100 boxes one draw call each (twice with shadows).
## Leaves (they sway by local height) and hidden blocks are left alone.
## Town dressing (DecorProp built from primitives: posts, planks, crates, rubble) and the
## procedural trees (trunks, crowns, fronds) join the same batches; glowing bulbs, fire,
## crystals and imported models keep their own nodes. Run it after the trees have settled
## on the terrain (WorldStreamer calls it deferred).

const CELL_M: float = 64.0
## Trees are drawn a little further out than blocks and dressing (their own old range).
const TREE_VIEW_SHARE: float = 0.5
const FOLIAGE_SHADER: Shader = preload("res://assets/shaders/foliage.gdshader")
const WATER_SHADER: Shader = preload("res://assets/shaders/water.gdshader")


class Group:
	var material: Material
	var always: bool = false
	var share: float = GrayboxBlock.PROP_VIEW_SHARE
	var tool: SurfaceTool = SurfaceTool.new()
	var count: int = 0


static var _unit_box: BoxMesh = null


## Returns how many blocks and decor parts were merged.
static func batch(chunk: Node3D) -> int:
	if _unit_box == null:
		_unit_box = BoxMesh.new()
	var groups: Dictionary[String, Group] = {}
	var merged: Array[GrayboxBlock] = []
	var parts: Array[MeshInstance3D] = []
	for child: Node in chunk.get_children():
		var b: GrayboxBlock = child as GrayboxBlock
		if b != null:
			if b.can_batch():
				var always: bool = b.is_always_visible()
				var g: Group = _group(groups, b.mesh_material(), b.position, always)
				g.tool.append_from(_unit_box, 0, b.transform * Transform3D(Basis.from_scale(b.size), Vector3.ZERO))
				merged.append(b)
			continue
		var d: Node3D = child as Node3D
		var tree: bool = child is TreeProp
		if d == null or not d.visible or not (child is DecorProp or tree):
			continue
		for part: Node in d.get_children():
			var mi: MeshInstance3D = part as MeshInstance3D
			var mat: Material = _shared_material_of(mi, tree)
			if mat == null:
				continue
			_group(groups, mat, d.position, false, TREE_VIEW_SHARE if tree else GrayboxBlock.PROP_VIEW_SHARE) \
				.tool.append_from(mi.mesh, 0, d.transform * mi.transform)
			parts.append(mi)
	if merged.is_empty() and parts.is_empty():
		return 0
	var view: float = Settings.profile.view_distance_m if Settings.profile != null else 400.0
	var i: int = 0
	for key: String in groups:
		var g: Group = groups[key]
		var mesh: ArrayMesh = g.tool.commit()
		mesh.surface_set_material(0, g.material)
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Batch%d" % i
		i += 1
		mi.mesh = mesh
		if not g.always:
			mi.visibility_range_end = view * g.share
			mi.visibility_range_end_margin = 10.0
		chunk.add_child(mi)
	for b: GrayboxBlock in merged:
		b.drop_mesh()
	for mi: MeshInstance3D in parts:
		mi.queue_free()
	return merged.size() + parts.size()


static func _group(groups: Dictionary[String, Group], mat: Material, at: Vector3, always: bool,
		share: float = GrayboxBlock.PROP_VIEW_SHARE) -> Group:
	var key: String = "%d" % mat.get_instance_id()
	if not always:
		key += ":%d:%d:%.2f" % [floori(at.x / CELL_M), floori(at.z / CELL_M), share]
	var g: Group = groups.get(key)
	if g == null:
		g = Group.new()
		g.material = mat
		g.always = always
		g.share = share
		g.tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		groups[key] = g
	return g


## A part that may be merged: a primitive mesh with one of the world's shared surface
## materials (not a per-lamp glow, not water). Swaying cloth / leaves only on trees: a merged
## crown sways as one (its own sway was a few centimetres anyway).
static func _shared_material_of(mi: MeshInstance3D, allow_leaves: bool = false) -> Material:
	if mi == null or not mi.visible or not mi.mesh is PrimitiveMesh:
		return null
	var mat: Material = mi.material_override if mi.material_override != null else (mi.mesh as PrimitiveMesh).material
	var sm: ShaderMaterial = mat as ShaderMaterial
	if sm == null or sm.shader == null or sm.shader == WATER_SHADER or (sm.shader == FOLIAGE_SHADER and not allow_leaves):
		return null
	return sm
