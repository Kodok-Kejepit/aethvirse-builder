extends SceneTree
@warning_ignore_start("integer_division")
## Imports world models (owner's Meshy GLBs) into PropData assets.
##   godot --headless --path . -s tools/import_props.gd -- <input_dir> [only_id]
## Per file `<id>.glb`: decimate to a category budget, face -Z, feet on y = 0, scale to a
## height, albedo → 1024 JPG, ArrayMesh → assets/props/<id>/<id>.res, data/props/<id>.tres.
## Category by prefix (height m, triangles); override per id in assets/props_manifest.csv:
##   id,height_m,collision(none|box|convex),max_tris

const CATEGORIES: Array[Array] = [
	["prop_", 1.0, 5000], ["bld_", 10.0, 25000], ["landmark_", 12.0, 40000], ["gate_", 6.0, 20000],
	["tree_", 9.0, 8000], ["rock_", 3.0, 4000], ["statue_", 3.0, 30000],
]
const DEFAULT_CATEGORY: Array = ["", 2.0, 12000]
const MANIFEST: String = "res://assets/props_manifest.csv"
const TEX_PX: int = 1024


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else OS.get_environment("HOME") + "/Unduhan/assets"
	var only: String = args[1] if args.size() > 1 else ""
	var manifest: Dictionary = _manifest()
	var count: int = 0
	for file: String in DirAccess.get_files_at(dir):
		if not (file.ends_with(".glb") or file.ends_with(".gltf")):
			continue
		var id: String = file.get_basename().to_lower().replace(" ", "_").replace("-", "_")
		if only != "" and id != only:
			continue
		var over: Dictionary = manifest.get(id, {})
		if _import(dir.path_join(file), id, over):
			count += 1
	print("imported %d props" % count)
	quit()


func _manifest() -> Dictionary:
	var out: Dictionary = {}
	if not FileAccess.file_exists(MANIFEST):
		return out
	var f: FileAccess = FileAccess.open(MANIFEST, FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() >= 2 and row[0] != "":
			out[row[0]] = {"height": row[1].to_float(), "collision": row[2] if row.size() > 2 else "box",
				"tris": row[3].to_int() if row.size() > 3 else 0}
	return out


static func category(id: String) -> Array:
	for c: Array in CATEGORIES:
		var prefix: String = c[0]
		if id.begins_with(prefix):
			return c
	if id.length() > 2 and id[0] == "r" and id[1].is_valid_int():
		return ["bld_", 10.0, 25000]
	return DEFAULT_CATEGORY


func _import(path: String, id: String, over: Dictionary) -> bool:
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if doc.append_from_file(path, state) != OK or state.get_meshes().is_empty():
		push_error("cannot read " + path)
		return false
	var cat: Array = category(id)
	var height: float = over.get("height", 0.0) if over.get("height", 0.0) > 0.0 else cat[1]
	var max_tris: int = over.get("tris", 0) if over.get("tris", 0) > 0 else cat[2]
	var collision: String = over.get("collision", "box")
	var imesh: ImporterMesh = (state.get_meshes()[0] as GLTFMesh).mesh
	imesh.generate_lods(25.0, 60.0, [])
	var arrays: Array = imesh.get_surface_arrays(0)
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i: int in imesh.get_surface_lod_count(0):
		var idx: PackedInt32Array = imesh.get_surface_lod_indices(0, i)
		if idx.size() / 3 <= max_tris and idx.size() / 3 >= 200:
			indices = idx
			break
	var mesh: ArrayMesh = _normalise(arrays, indices, height)
	var out_dir: String = "res://assets/props/%s" % id
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var mesh_path: String = "%s/%s.res" % [out_dir, id]
	ResourceSaver.save(mesh, mesh_path, ResourceSaver.FLAG_COMPRESS)
	var albedo_path: String = _save_albedo(imesh.get_surface_material(0), out_dir, id)
	var data: PropData = PropData.new()
	data.id = StringName(id)
	data.mesh_path = mesh_path
	data.albedo_path = albedo_path
	data.size = mesh.get_aabb().size
	data.collision = {"none": PropData.Collision.NONE, "convex": PropData.Collision.CONVEX}.get(collision, PropData.Collision.BOX)
	ResourceSaver.save(data, PropData.path_for(StringName(id)))
	print("%s: %d tris, %.1f m tall" % [id, indices.size() / 3, data.size.y])
	return true


## Compacts used vertices, turns the model to face -Z, puts its base on y = 0 and scales
## it to `height`.
static func _normalise(arrays: Array, indices: PackedInt32Array, height: float) -> ArrayMesh:
	var src_pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var vmap: Dictionary[int, int] = {}
	var pos: PackedVector3Array = PackedVector3Array()
	var nrm: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var out_idx: PackedInt32Array = PackedInt32Array()
	for v: int in indices:
		if not vmap.has(v):
			vmap[v] = pos.size()
			pos.append(Vector3(-src_pos[v].x, src_pos[v].y, -src_pos[v].z))
			nrm.append(Vector3(-src_nrm[v].x, src_nrm[v].y, -src_nrm[v].z) if v < src_nrm.size() else Vector3.UP)
			uv.append(src_uv[v] if v < src_uv.size() else Vector2.ZERO)
		out_idx.append(vmap[v])
	var lo: Vector3 = pos[0]
	var hi: Vector3 = pos[0]
	for p: Vector3 in pos:
		lo = lo.min(p)
		hi = hi.max(p)
	var k: float = height / maxf(hi.y - lo.y, 0.0001)
	var offset: Vector3 = Vector3((lo.x + hi.x) * 0.5, lo.y, (lo.z + hi.z) * 0.5)
	for i: int in pos.size():
		pos[i] = (pos[i] - offset) * k
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = pos
	out[Mesh.ARRAY_NORMAL] = nrm
	out[Mesh.ARRAY_TEX_UV] = uv
	out[Mesh.ARRAY_INDEX] = out_idx
	# Through ImporterMesh so the saved mesh carries automatic LODs (distance detail).
	var im: ImporterMesh = ImporterMesh.new()
	im.add_surface(Mesh.PRIMITIVE_TRIANGLES, out)
	im.generate_lods(25.0, 60.0, [])
	return im.get_mesh()


static func _save_albedo(mat: Material, out_dir: String, id: String) -> String:
	var base: BaseMaterial3D = mat as BaseMaterial3D
	if base == null or base.albedo_texture == null:
		return ""
	var img: Image = base.albedo_texture.get_image()
	if img == null:
		return ""
	if img.is_compressed():
		img.decompress()
	if img.get_width() > TEX_PX:
		img.resize(TEX_PX, TEX_PX * img.get_height() / img.get_width(), Image.INTERPOLATE_LANCZOS)
	var path: String = "%s/%s_albedo.jpg" % [out_dir, id]
	img.save_jpg(ProjectSettings.globalize_path(path), 0.9)
	var imp: FileAccess = FileAccess.open(ProjectSettings.globalize_path(path + ".import"), FileAccess.WRITE)
	imp.store_string('[remap]\n\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\n\nsource_file="%s"\n\n[params]\n\ncompress/mode=2\nmipmaps/generate=true\ndetect_3d/compress_to=0\n' % path)
	return path
