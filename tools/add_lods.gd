extends SceneTree
@warning_ignore_start("integer_division")
## Adds distance LODs to imported prop meshes that have none (or too few).
##   godot --headless --path . -s tools/add_lods.gd -- [only_id] [--dry]
## Meshy models baked to a fresh UV atlas are "triangle soup" (every UV island has its
## own copies of the shared corners), so Godot's simplifier finds no edge to collapse and
## makes no LOD. Here the corners are welded by position first, the welded surface is
## simplified, and each simplified triangle gets back original corners from one UV island
## (the copies whose UVs lie closest together), so textures stay put at a distance.
## LOD 0 (the full mesh) is never changed.

const PROPS_DIR: String = "res://assets/props"
const MIN_TRIS: int = 1500
## Meshes that already have at least this many LODs are left alone.
const ENOUGH_LODS: int = 3
const WELD_EPS: float = 0.0005
## Seamless ground surfaces: neighbouring pieces at different LODs would open cracks.
const SKIP_PREFIXES: PackedStringArray = ["ground_"]


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var dry: bool = "--dry" in args
	var only: String = ""
	for a: String in args:
		if not a.begins_with("--"):
			only = a
	var done: int = 0
	for id: String in DirAccess.get_directories_at(PROPS_DIR):
		if only != "" and id != only:
			continue
		if SKIP_PREFIXES.has(id.substr(0, id.find("_") + 1)):
			continue
		var path: String = "%s/%s/%s.res" % [PROPS_DIR, id, id]
		if not ResourceLoader.exists(path):
			continue
		if _process_mesh(path, id, dry):
			done += 1
	print("LODs added to %d meshes" % done)
	quit()


func _process_mesh(path: String, id: String, dry: bool) -> bool:
	var mesh: ArrayMesh = load(path) as ArrayMesh
	if mesh == null or mesh.get_surface_count() != 1:
		return false
	var lods_before: int = RenderingServer.mesh_get_surface(mesh.get_rid(), 0).get("lods", []).size()
	var arrays: Array = mesh.surface_get_arrays(0)
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if index.size() / 3 < MIN_TRIS or lods_before >= ENOUGH_LODS:
		return false
	var lods: Dictionary = build_lods(arrays)
	var sizes: PackedStringArray = []
	for key: float in lods:
		sizes.append(str((lods[key] as PackedInt32Array).size() / 3))
	print("%s: %d tris, LODs %d → %d (%s)" % [id, index.size() / 3, lods_before, lods.size(), ", ".join(sizes)])
	if dry or lods.size() <= lods_before:
		return false
	var out: ArrayMesh = ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], lods)
	var mat: Material = mesh.surface_get_material(0)
	if mat != null:
		out.surface_set_material(0, mat)
	out.surface_set_name(0, mesh.surface_get_name(0))
	return ResourceSaver.save(out, path, ResourceSaver.FLAG_COMPRESS) == OK


## LOD key (Godot's screen-error distance) -> index array over the ORIGINAL vertices.
static func build_lods(arrays: Array) -> Dictionary:
	var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	# Weld: one canonical vertex per position; remember every original copy.
	var canon_of: PackedInt32Array = PackedInt32Array()
	canon_of.resize(pos.size())
	var by_key: Dictionary[Vector3i, int] = {}
	var welded: PackedVector3Array = PackedVector3Array()
	var copies: Array[PackedInt32Array] = []
	for v: int in pos.size():
		var key: Vector3i = Vector3i((pos[v] / WELD_EPS).round())
		var c: int = by_key.get(key, -1)
		if c < 0:
			c = welded.size()
			by_key[key] = c
			welded.append(pos[v])
			copies.append(PackedInt32Array())
		canon_of[v] = c
		copies[c].append(v)
	var widx: PackedInt32Array = PackedInt32Array()
	widx.resize(index.size())
	for i: int in index.size():
		widx[i] = canon_of[index[i]]
	var w_arrays: Array = []
	w_arrays.resize(Mesh.ARRAY_MAX)
	w_arrays[Mesh.ARRAY_VERTEX] = welded
	w_arrays[Mesh.ARRAY_INDEX] = widx
	var st: SurfaceTool = SurfaceTool.new()
	st.create_from_arrays(w_arrays)
	st.generate_normals()
	var im: ImporterMesh = ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays())
	im.generate_lods(25.0, 60.0, [])
	var out: Dictionary = {}
	for l: int in im.get_surface_lod_count(0):
		var lod: PackedInt32Array = im.get_surface_lod_indices(0, l)
		out[im.get_surface_lod_size(0, l)] = _unweld(lod, copies, uv)
	return out


## Each welded triangle takes the original corner copies whose UVs are closest together
## (same UV island where possible).
static func _unweld(lod: PackedInt32Array, copies: Array[PackedInt32Array], uv: PackedVector2Array) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(lod.size())
	for t: int in lod.size() / 3:
		var ca: PackedInt32Array = copies[lod[t * 3]]
		var cb: PackedInt32Array = copies[lod[t * 3 + 1]]
		var cc: PackedInt32Array = copies[lod[t * 3 + 2]]
		var best: Vector3i = Vector3i(ca[0], cb[0], cc[0])
		if not uv.is_empty() and ca.size() * cb.size() * cc.size() > 1:
			var best_d: float = INF
			for a: int in ca:
				for b: int in cb:
					for c: int in cc:
						var d: float = uv[a].distance_to(uv[b]) + uv[b].distance_to(uv[c]) + uv[c].distance_to(uv[a])
						if d < best_d:
							best_d = d
							best = Vector3i(a, b, c)
		out[t * 3] = best.x
		out[t * 3 + 1] = best.y
		out[t * 3 + 2] = best.z
	return out
