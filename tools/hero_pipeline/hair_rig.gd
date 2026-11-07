class_name HeroHairRig
extends RefCounted
## Re-rigs loose hair (and anything hanging off the body) on an auto-rigged Mixamo hero.
## Auto-rigs weight long hair to whatever bone is nearest, usually the arms, so the hair
## swings with the hands. Here every vertex far from the body bones is "loose": it gets
## its own bone chains hanging from the head (one chain per angular sector), which the
## game simulates with SpringBoneSimulator3D. Looseness is smoothed over the mesh so the
## seam between body and hair blends instead of tearing.
@warning_ignore_start("integer_division")

const SECTORS: int = 12
const BONES_PER_CHAIN: int = 6
const MIN_CHAIN_VERTS: int = 80
const MIN_CHAIN_LEN_M: float = 0.2
const SMOOTH_ITERATIONS: int = 4
const HAND_EXTENSION_M: float = 0.14
## Clearance radius (m) around the segment parent -> bone, by bone name suffix.
const CLEARANCE: Dictionary = {
	"Spine": 0.17, "Spine1": 0.17, "Spine2": 0.16, "Neck": 0.1, "Head": 0.1, "HeadTop_End": 0.13,
	"Shoulder": 0.09, "Arm": 0.09, "ForeArm": 0.08, "Hand": 0.07,
	"UpLeg": 0.15, "Leg": 0.12, "Foot": 0.09, "ToeBase": 0.08,
}

var skel: Skeleton3D
var mi: MeshInstance3D
var chains: Array = []
var loose_count: int = 0

var _to_world: Transform3D
var _mesh_in_skel: Transform3D
var _bind_of: Dictionary = {}
var _g: Array[Vector3] = []
var _head: int
var _spine2: int
var _top_y: float
var _centre: Vector2


func _init(skeleton: Skeleton3D, mesh_instance: MeshInstance3D) -> void:
	skel = skeleton
	mi = mesh_instance


## Rewrites mesh weights + skin and adds hair bones. With `mask`, vertex colours show the
## classification (grey body, coloured by chain) for debug renders.
func build(mask: bool) -> void:
	var arrays: Array = (mi.mesh as ArrayMesh).surface_get_arrays(0)
	var pos: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	_setup_space()
	var wpos: PackedVector3Array = PackedVector3Array()
	wpos.resize(pos.size())
	for v: int in pos.size():
		wpos[v] = _to_world * pos[v]
	var loose: PackedFloat32Array = _classify(wpos)
	loose = _smooth(loose, pos, arrays[Mesh.ARRAY_INDEX])
	var sector_of: PackedInt32Array = _sectors(wpos, loose)
	var chain_info: Dictionary = _build_chains(wpos, loose, sector_of)
	var skin: Skin = mi.skin.duplicate() as Skin
	for i: int in skel.get_bone_count():
		if skel.get_bone_name(i).begins_with("hair_"):
			_bind_of[i] = skin.get_bind_count()
			skin.add_bind(i, skel.get_bone_global_rest(i).affine_inverse() * _mesh_in_skel)
	var colours: PackedColorArray = PackedColorArray()
	colours.resize(pos.size())
	for v: int in pos.size():
		colours[v] = Color(0.6, 0.6, 0.6)
		if loose[v] <= 0.0:
			continue
		var hair_w: Dictionary = _hair_weights(wpos[v], sector_of[v], chain_info)
		_blend(bones, weights, v, hair_w, loose[v])
		if loose[v] > 0.5:
			colours[v] = Color.from_hsv(float(sector_of[v]) / SECTORS, 0.8, 1.0)
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	if mask:
		arrays[Mesh.ARRAY_COLOR] = colours
	var new_mesh: ArrayMesh = ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = new_mesh
	mi.skin = skin


func _setup_space() -> void:
	var skin: Skin = mi.skin
	# FBX mesh is in metres, bones in cm: the bind of any bone gives mesh -> skeleton space.
	_mesh_in_skel = skel.get_bone_global_rest(skin.get_bind_bone(0)) * skin.get_bind_pose(0)
	_to_world = _gxf(skel) * _mesh_in_skel
	for b: int in skin.get_bind_count():
		_bind_of[skin.get_bind_bone(b)] = b
	for i: int in skel.get_bone_count():
		_g.append((_gxf(skel) * skel.get_bone_global_rest(i)).origin)
	_head = skel.find_bone("mixamorig_Head")
	_spine2 = skel.find_bone("mixamorig_Spine2")
	_top_y = _g[_head].y
	_centre = Vector2(_g[_head].x, _g[_head].z)


## 1 = far from every body segment (hair, ribbons...), 0 = body.
func _classify(wpos: PackedVector3Array) -> PackedFloat32Array:
	var segs: Array[Array] = []
	for i: int in skel.get_bone_count():
		var parent: int = skel.get_bone_parent(i)
		var key: String = skel.get_bone_name(i).trim_prefix("mixamorig_").trim_prefix("Left").trim_prefix("Right")
		if parent < 0 or not CLEARANCE.has(key):
			continue
		segs.append([_g[parent], _g[i], float(CLEARANCE[key])])
		if key == "Hand":
			var dir: Vector3 = (_g[i] - _g[parent]).normalized()
			segs.append([_g[i], _g[i] + dir * HAND_EXTENSION_M, float(CLEARANCE[key])])
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(wpos.size())
	for v: int in wpos.size():
		var is_loose: float = 1.0
		for s: Array in segs:
			if _seg_dist(wpos[v], s[0], s[1]) < float(s[2]):
				is_loose = 0.0
				break
		out[v] = is_loose
	loose_count = 0
	for v2: int in out.size():
		loose_count += int(out[v2])
	return out


## Averages looseness with mesh neighbours (welded by position) so seams blend.
func _smooth(loose: PackedFloat32Array, pos: PackedVector3Array, idx: PackedInt32Array) -> PackedFloat32Array:
	var weld: PackedInt32Array = PackedInt32Array()
	weld.resize(pos.size())
	var first: Dictionary = {}
	for v: int in pos.size():
		var k: Vector3i = Vector3i((pos[v] * 10000.0).round())
		weld[v] = first.get(k, v)
		first[k] = weld[v]
	var cur: PackedFloat32Array = loose
	for _it: int in SMOOTH_ITERATIONS:
		var acc: PackedFloat32Array = PackedFloat32Array()
		acc.resize(pos.size())
		var cnt: PackedFloat32Array = PackedFloat32Array()
		cnt.resize(pos.size())
		for t: int in range(0, idx.size(), 3):
			for e: int in 3:
				var a: int = weld[idx[t + e]]
				var b: int = weld[idx[t + (e + 1) % 3]]
				acc[a] += cur[b]
				cnt[a] += 1.0
				acc[b] += cur[a]
				cnt[b] += 1.0
		var nxt: PackedFloat32Array = PackedFloat32Array()
		nxt.resize(pos.size())
		for v2: int in pos.size():
			var w: int = weld[v2]
			nxt[v2] = (cur[w] + acc[w]) / (1.0 + cnt[w]) if cnt[w] > 0.0 else cur[w]
		cur = nxt
	return cur


func _sectors(wpos: PackedVector3Array, loose: PackedFloat32Array) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(wpos.size())
	for v: int in wpos.size():
		out[v] = -1
		if loose[v] > 0.0:
			var d: Vector2 = Vector2(wpos[v].x, wpos[v].z) - _centre
			out[v] = int(floor((d.angle() + PI) / TAU * SECTORS)) % SECTORS
	return out


## One chain per populated sector: joints at band centroids from head height down.
func _build_chains(wpos: PackedVector3Array, loose: PackedFloat32Array, sector_of: PackedInt32Array) -> Dictionary:
	var info: Dictionary = {}
	for s: int in SECTORS:
		var bottom: float = INF
		var n: int = 0
		for v: int in wpos.size():
			if sector_of[v] == s and loose[v] > 0.5:
				bottom = minf(bottom, wpos[v].y)
				n += 1
		if n < MIN_CHAIN_VERTS or _top_y - bottom < MIN_CHAIN_LEN_M:
			continue
		var band: float = (_top_y - bottom) / BONES_PER_CHAIN
		var sums: Array[Vector3] = []
		var counts: PackedInt32Array = PackedInt32Array()
		counts.resize(BONES_PER_CHAIN)
		for b: int in BONES_PER_CHAIN:
			sums.append(Vector3.ZERO)
		for v2: int in wpos.size():
			if sector_of[v2] == s and loose[v2] > 0.5 and wpos[v2].y <= _top_y:
				var bi: int = clampi(int((_top_y - wpos[v2].y) / band), 0, BONES_PER_CHAIN - 1)
				sums[bi] += wpos[v2]
				counts[bi] += 1
		var names: PackedStringArray = PackedStringArray()
		var parent: int = _head
		var prev: Vector3 = _g[_head]
		for b2: int in BONES_PER_CHAIN:
			var c: Vector3 = sums[b2] / float(counts[b2]) if counts[b2] > 0 else prev
			c.y = _top_y - band * float(b2)
			var bname: String = "hair_%d_%d" % [s, b2]
			var idx: int = skel.get_bone_count()
			skel.add_bone(bname)
			skel.set_bone_parent(idx, parent)
			var local: Vector3 = skel.get_bone_global_rest(parent).affine_inverse() * (_gxf(skel).affine_inverse() * c)
			skel.set_bone_rest(idx, Transform3D(Basis.IDENTITY, local))
			skel.reset_bone_pose(idx)
			names.append(bname)
			parent = idx
			prev = c
		chains.append(names)
		info[s] = [names, band]
	return info


## Skeleton bone -> weight for a hair vertex: its band bone, blended with neighbours.
func _hair_weights(p: Vector3, sector: int, info: Dictionary) -> Dictionary:
	if p.y >= _top_y or not info.has(sector):
		return {_head if p.y > _g[_spine2].y else _spine2: 1.0}
	var names: PackedStringArray = info[sector][0]
	var band: float = info[sector][1]
	var f: float = clampf((_top_y - p.y) / band, 0.0, BONES_PER_CHAIN - 0.001)
	var i0: int = int(f)
	var t: float = f - float(i0)
	var me: int = skel.find_bone(names[i0])
	var prev: int = _head if i0 == 0 else skel.find_bone(names[i0 - 1])
	var w_prev: float = 0.5 * (1.0 - smoothstep(0.0, 0.4, t))
	var w_next: float = 0.0
	var out: Dictionary = {}
	if i0 < BONES_PER_CHAIN - 1:
		w_next = 0.5 * smoothstep(0.6, 1.0, t)
		out[skel.find_bone(names[i0 + 1])] = w_next
	out[prev] = w_prev
	out[me] = 1.0 - w_prev - w_next
	return out


## Mixes the vertex's original weights with hair weights by looseness; keeps the top 4.
func _blend(bones: PackedInt32Array, weights: PackedFloat32Array, v: int, hair: Dictionary, k: float) -> void:
	var mix: Dictionary = {}
	for j: int in 4:
		var bind: int = bones[v * 4 + j]
		mix[bind] = float(mix.get(bind, 0.0)) + weights[v * 4 + j] * (1.0 - k)
	for bone: int in hair:
		var bind2: int = _bind_of[bone]
		mix[bind2] = float(mix.get(bind2, 0.0)) + float(hair[bone]) * k
	var keys: Array = mix.keys()
	keys.sort_custom(func(a: int, b: int) -> bool: return float(mix[a]) > float(mix[b]))
	var total: float = 0.0
	for j2: int in 4:
		total += float(mix[keys[j2]]) if j2 < keys.size() else 0.0
	for j3: int in 4:
		bones[v * 4 + j3] = int(keys[j3]) if j3 < keys.size() else 0
		weights[v * 4 + j3] = float(mix[keys[j3]]) / total if j3 < keys.size() else 0.0


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Global transform without being inside the scene tree (tool runs before the tree starts).
static func _gxf(n: Node3D) -> Transform3D:
	var t: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
