extends SceneTree
## Dev tool: turns a prepared hero .glb (faces -Z, feet on y = 0, see docs/DECISIONS p2) into
## skinned meshes for CharacterRig's joint layout.
##   godot --headless --path . -s tools/import_hero.gd -- <in.glb> <out_dir> <id> <hi_tris> <lo_tris> [joint_scale]
## Writes <out_dir>/<id>_hi.res and <id>_lo.res (ArrayMesh with bones/weights, joint rest
## positions in meta "joints"). Textures are copied by the caller (prep step).

## Bones that may only skin vertices close to them (metres): limbs.
const LIMB_RADIUS: Dictionary[StringName, float] = {
	&"arm_r": 0.075, &"fore_r": 0.07, &"hand_r": 0.07, &"arm_l": 0.075, &"fore_l": 0.07, &"hand_l": 0.07,
	&"thigh_r": 0.11, &"shin_r": 0.085, &"foot_r": 0.09, &"thigh_l": 0.11, &"shin_l": 0.085, &"foot_l": 0.09,
}
## Bone tip for leaf bones (local offset from the joint).
const LEAF_TIPS: Dictionary[StringName, Vector3] = {
	&"head": Vector3(0.0, 0.22, 0.0), &"hand_r": Vector3(0.0, -0.16, 0.0), &"hand_l": Vector3(0.0, -0.16, 0.0),
	&"foot_r": Vector3(0.0, -0.06, -0.16), &"foot_l": Vector3(0.0, -0.06, -0.16),
}
const SKIP_BONES: Array[StringName] = [&"clav_r", &"clav_l"]
## Laplacian passes over the welded mesh: softer arm/torso borders, fewer stretched streaks.
const SMOOTH_PASSES: int = 6


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var doc: GLTFDocument = GLTFDocument.new()
	var state: GLTFState = GLTFState.new()
	if doc.append_from_file(args[0], state) != OK:
		push_error("cannot read " + args[0])
		quit(1)
		return
	var gmesh: GLTFMesh = state.get_meshes()[0]
	var imesh: ImporterMesh = gmesh.mesh
	var joint_scale: float = args[5].to_float() if args.size() > 5 else 1.0
	var rest: Dictionary[StringName, Vector3] = fitted_joints(joint_scale)
	print("generating LODs...")
	imesh.generate_lods(25.0, 60.0, [])
	var arrays: Array = imesh.get_surface_arrays(0)
	for pair: Array in [["hi", args[3].to_int()], ["lo", args[4].to_int()]]:
		var indices: PackedInt32Array = _pick_lod(imesh, arrays, pair[1])
		var mesh: ArrayMesh = build_skinned(arrays, indices, rest)
		var path: String = "%s/%s_%s.res" % [args[1], args[2], pair[0]]
		ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS)
		print("%s: %d tris -> %s" % [pair[0], indices.size() / 3, path])
	quit()


## Global rest position of every joint, CharacterRig layout scaled to the model.
static func fitted_joints(k: float) -> Dictionary[StringName, Vector3]:
	var out: Dictionary[StringName, Vector3] = {}
	for row: Array in CharacterRig.JOINTS:
		var id: StringName = row[0]
		var parent: StringName = row[1]
		var local: Vector3 = row[2]
		out[id] = (out[parent] if parent != &"" else Vector3.ZERO) + local * k
	return out


static func _pick_lod(imesh: ImporterMesh, arrays: Array, target: int) -> PackedInt32Array:
	var best: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for i: int in imesh.get_surface_lod_count(0):
		var idx: PackedInt32Array = imesh.get_surface_lod_indices(0, i)
		if idx.size() / 3 >= target or idx.size() < best.size():
			if absi(idx.size() / 3 - target) < absi(best.size() / 3 - target):
				best = idx
	return best


## Compacts the vertices used by `indices` and adds 4 bone weights per vertex.
static func build_skinned(arrays: Array, indices: PackedInt32Array, rest: Dictionary[StringName, Vector3]) -> ArrayMesh:
	var src_pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_nrm: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var src_uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var remap: PackedInt32Array = PackedInt32Array()
	remap.resize(src_pos.size())
	remap.fill(-1)
	var pos: PackedVector3Array = PackedVector3Array()
	var nrm: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var out_idx: PackedInt32Array = PackedInt32Array()
	out_idx.resize(indices.size())
	for i: int in indices.size():
		var v: int = indices[i]
		if remap[v] < 0:
			remap[v] = pos.size()
			pos.append(src_pos[v])
			nrm.append(src_nrm[v])
			uv.append(src_uv[v])
		out_idx[i] = remap[v]
	var bone_names: Array[StringName] = []
	for row: Array in CharacterRig.JOINTS:
		bone_names.append(row[0])
	var segs: Array[Array] = _segments(rest, bone_names)
	var bones: PackedInt32Array = PackedInt32Array()
	var weights: PackedFloat32Array = PackedFloat32Array()
	bones.resize(pos.size() * 4)
	weights.resize(pos.size() * 4)
	for vi: int in pos.size():
		_weigh(pos[vi], segs, bones, weights, vi * 4)
	_smooth_weights(pos, out_idx, bones, weights, bone_names.size(), SMOOTH_PASSES)
	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = pos
	out[Mesh.ARRAY_NORMAL] = nrm
	out[Mesh.ARRAY_TEX_UV] = uv
	out[Mesh.ARRAY_INDEX] = out_idx
	out[Mesh.ARRAY_BONES] = bones
	out[Mesh.ARRAY_WEIGHTS] = weights
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	var joints_meta: Dictionary = {}
	for id: StringName in rest:
		joints_meta[String(id)] = rest[id]
	mesh.set_meta(&"joints", joints_meta)
	return mesh


## [bone_index, a, b, radius (0 = unlimited)] per skinning bone.
static func _segments(rest: Dictionary[StringName, Vector3], names: Array[StringName]) -> Array[Array]:
	var child_of: Dictionary[StringName, StringName] = {&"hips": &"spine", &"spine": &"chest", &"chest": &"neck",
		&"neck": &"head", &"arm_r": &"fore_r", &"fore_r": &"hand_r", &"arm_l": &"fore_l", &"fore_l": &"hand_l",
		&"thigh_r": &"shin_r", &"shin_r": &"foot_r", &"thigh_l": &"shin_l", &"shin_l": &"foot_l"}
	var out: Array[Array] = []
	for i: int in names.size():
		var id: StringName = names[i]
		if SKIP_BONES.has(id):
			continue
		var a: Vector3 = rest[id]
		var b: Vector3 = rest[child_of[id]] if child_of.has(id) else a + LEAF_TIPS.get(id, Vector3(0.0, 0.1, 0.0))
		if id == &"hips":
			a.y -= 0.12
		out.append([i, a, b, LIMB_RADIUS.get(id, 0.0)])
	return out


static func _weigh(p: Vector3, segs: Array[Array], bones: PackedInt32Array, weights: PackedFloat32Array, at: int) -> void:
	var best_b: Array[int] = [0, 0, 0, 0]
	var best_w: Array[float] = [0.0, 0.0, 0.0, 0.0]
	for s: Array in segs:
		var a: Vector3 = s[1]
		var b: Vector3 = s[2]
		var radius: float = s[3]
		var ab: Vector3 = b - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-6), 0.0, 1.0)
		var d: float = p.distance_to(a + ab * t)
		if radius > 0.0 and d > radius:
			continue
		var w: float = 1.0 / pow(d * d + 0.0004, 2.0)
		for k: int in 4:
			if w > best_w[k]:
				best_w.insert(k, w)
				best_b.insert(k, s[0])
				best_w.resize(4)
				best_b.resize(4)
				break
	var total: float = best_w[0] + best_w[1] + best_w[2] + best_w[3]
	for k: int in 4:
		bones[at + k] = best_b[k]
		weights[at + k] = best_w[k] / total if total > 0.0 else (1.0 if k == 0 else 0.0)


## Averages each vertex's bone weights with its neighbours (positions welded so UV seams
## stay closed), then keeps the 4 strongest bones again.
static func _smooth_weights(pos: PackedVector3Array, idx: PackedInt32Array, bones: PackedInt32Array,
		weights: PackedFloat32Array, bone_count: int, passes: int) -> void:
	var weld: PackedInt32Array = PackedInt32Array()
	weld.resize(pos.size())
	var keys: Dictionary[Vector3i, int] = {}
	for i: int in pos.size():
		var k: Vector3i = Vector3i((pos[i] * 10000.0).round())
		if not keys.has(k):
			keys[k] = keys.size()
		weld[i] = keys[k]
	var n: int = keys.size()
	var dense: PackedFloat32Array = PackedFloat32Array()
	dense.resize(n * bone_count)
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(n)
	for i: int in pos.size():
		var w: int = weld[i]
		if counts[w] > 0:
			continue
		counts[w] = 1
		for k: int in 4:
			dense[w * bone_count + bones[i * 4 + k]] += weights[i * 4 + k]
	# Unique undirected edges between welded vertices.
	var edges: Dictionary[int, bool] = {}
	for t: int in range(0, idx.size(), 3):
		for e: int in 3:
			var a: int = weld[idx[t + e]]
			var b: int = weld[idx[t + (e + 1) % 3]]
			if a != b:
				edges[mini(a, b) * n + maxi(a, b)] = true
	var ea: PackedInt32Array = PackedInt32Array()
	var eb: PackedInt32Array = PackedInt32Array()
	for key: int in edges:
		ea.append(key / n)
		eb.append(key % n)
	for _p: int in passes:
		var acc: PackedFloat32Array = dense.duplicate()
		var deg: PackedInt32Array = PackedInt32Array()
		deg.resize(n)
		deg.fill(1)
		for e: int in ea.size():
			var a: int = ea[e]
			var b: int = eb[e]
			deg[a] += 1
			deg[b] += 1
			for bi: int in bone_count:
				acc[a * bone_count + bi] += dense[b * bone_count + bi]
				acc[b * bone_count + bi] += dense[a * bone_count + bi]
		for v: int in n:
			for bi: int in bone_count:
				dense[v * bone_count + bi] = acc[v * bone_count + bi] / float(deg[v])
	for i: int in pos.size():
		var w: int = weld[i]
		var top_b: Array[int] = [0, 0, 0, 0]
		var top_w: Array[float] = [0.0, 0.0, 0.0, 0.0]
		for bi: int in bone_count:
			var val: float = dense[w * bone_count + bi]
			for k: int in 4:
				if val > top_w[k]:
					top_w.insert(k, val)
					top_b.insert(k, bi)
					top_w.resize(4)
					top_b.resize(4)
					break
		var total: float = top_w[0] + top_w[1] + top_w[2] + top_w[3]
		for k: int in 4:
			bones[i * 4 + k] = top_b[k]
			weights[i * 4 + k] = top_w[k] / total if total > 0.0 else (1.0 if k == 0 else 0.0)
