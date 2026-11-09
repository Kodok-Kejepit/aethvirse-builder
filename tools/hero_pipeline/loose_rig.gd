class_name HeroLooseRig
extends RefCounted
## Re-rigs everything that should hang and sway on an auto-rigged hero: hair (chains
## from the head) and skirts / coat tails / trains (chains from the hips). Auto-rigs weight
## those parts to the nearest limb, so hair follows the hands and a gown follows the legs.
## Vertices far from the body bones are "loose"; above the hips they join hair chains,
## below the hips cloth chains, with a blend band at the hips so the mesh never tears.
## Looseness is smoothed over the mesh; the game runs SpringBoneSimulator3D on the chains.
## Expects mixamo-style bone names (mixamorig_Hips, mixamorig_Head, ...).

const HAIR_SECTORS: int = 12
const CLOTH_SECTORS: int = 10
const HAIR_BONES: int = 5
const CLOTH_BONES: int = 4
const MIN_CHAIN_VERTS: int = 60
const MIN_CHAIN_LEN_M: float = 0.15
const SMOOTH_ITERATIONS: int = 4
const HAND_EXTENSION_M: float = 0.14
const HIP_BAND_M: float = 0.1
## Clearance radius (m) around parent -> bone, by bone suffix. Legs are tight so gowns
## around them count as cloth, not as leg.
const CLEARANCE: Dictionary = {
	"Spine": 0.16, "Spine1": 0.16, "Spine2": 0.15, "Neck": 0.09, "Head": 0.1, "HeadTop_End": 0.12,
	"Shoulder": 0.08, "Arm": 0.08, "ForeArm": 0.07, "Hand": 0.065,
	"UpLeg": 0.1, "Leg": 0.075, "Foot": 0.08, "ToeBase": 0.07,
}

## Long cloaks / coats brushing the boots: ASC_LEG_CLEARANCE (e.g. 0.6) narrows the leg
## capsules so the hem joins the cloth chains instead of following the feet.
const LEG_KEYS: Array[String] = ["UpLeg", "Leg", "Foot", "ToeBase"]

var skel: Skeleton3D
var mi: MeshInstance3D
## [{"names": PackedStringArray, "kind": "hair" | "cloth"}]
var chains: Array = []
var loose_count: int = 0

var _to_world: Transform3D
var _mesh_in_skel: Transform3D
var _bind_of: Dictionary = {}
var _g: Array[Vector3] = []
var _head: int
var _hips: int
var _head_y: float
var _hips_y: float


func _init(skeleton: Skeleton3D, mesh_instance: MeshInstance3D) -> void:
	skel = skeleton
	mi = mesh_instance


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
	var loose: PackedFloat32Array = _smooth(_classify(wpos), pos, arrays[Mesh.ARRAY_INDEX])
	var hair: Dictionary = _group(wpos, loose, true)
	var cloth: Dictionary = _group(wpos, loose, false)
	var skin: Skin = mi.skin.duplicate() as Skin
	for i: int in skel.get_bone_count():
		var bn: String = skel.get_bone_name(i)
		if bn.begins_with("hair_") or bn.begins_with("cloth_"):
			_bind_of[i] = skin.get_bind_count()
			skin.add_bind(i, skel.get_bone_global_rest(i).affine_inverse() * _mesh_in_skel)
	var colours: PackedColorArray = PackedColorArray()
	colours.resize(pos.size())
	for v: int in pos.size():
		colours[v] = Color(0.6, 0.6, 0.6)
		if loose[v] <= 0.0:
			continue
		var y: float = wpos[v].y
		var w_h: Dictionary = _weights(wpos[v], hair, _head)
		var w_c: Dictionary = _weights(wpos[v], cloth, _hips)
		# Hair above the band, cloth below, a linear blend inside it.
		var t: float = clampf((y - (_hips_y - HIP_BAND_M)) / (2.0 * HIP_BAND_M), 0.0, 1.0)
		var mixed: Dictionary = {}
		for b: int in w_c:
			mixed[b] = float(w_c[b]) * (1.0 - t)
		for b2: int in w_h:
			mixed[b2] = float(mixed.get(b2, 0.0)) + float(w_h[b2]) * t
		_blend(bones, weights, v, mixed, loose[v])
		if loose[v] > 0.5:
			colours[v] = Color(1.0, 0.4, 0.4).lerp(Color(0.4, 0.6, 1.0), 1.0 - t)
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	if mask:
		arrays[Mesh.ARRAY_COLOR] = colours
	var new_mesh: ArrayMesh = ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	if mi.mesh.surface_get_material(0) != null:
		new_mesh.surface_set_material(0, mi.mesh.surface_get_material(0))
	mi.mesh = new_mesh
	mi.skin = skin


func _setup_space() -> void:
	var skin: Skin = mi.skin
	var b0: int = skin.get_bind_bone(0)
	if b0 < 0:
		b0 = skel.find_bone(skin.get_bind_name(0))
	_mesh_in_skel = skel.get_bone_global_rest(b0) * skin.get_bind_pose(0)
	_to_world = _gxf(skel) * _mesh_in_skel
	for b: int in skin.get_bind_count():
		var bone: int = skin.get_bind_bone(b)
		if bone < 0:
			bone = skel.find_bone(skin.get_bind_name(b))
		_bind_of[bone] = b
	for i: int in skel.get_bone_count():
		_g.append((_gxf(skel) * skel.get_bone_global_rest(i)).origin)
	_head = skel.find_bone("mixamorig_Head")
	_hips = skel.find_bone("mixamorig_Hips")
	_head_y = _g[_head].y
	_hips_y = _g[_hips].y


static func _leg_scale() -> float:
	var v: String = OS.get_environment("ASC_LEG_CLEARANCE")
	return v.to_float() if v.is_valid_float() else 1.0


func _classify(wpos: PackedVector3Array) -> PackedFloat32Array:
	var segs: Array[Array] = []
	for i: int in skel.get_bone_count():
		var parent: int = skel.get_bone_parent(i)
		var key: String = skel.get_bone_name(i).trim_prefix("mixamorig_").trim_prefix("Left").trim_prefix("Right")
		if parent < 0 or not CLEARANCE.has(key):
			continue
		var clearance: float = float(CLEARANCE[key])
		if LEG_KEYS.has(key):
			clearance *= _leg_scale()
		segs.append([_g[parent], _g[i], clearance])
		if key == "Hand":
			var dir: Vector3 = (_g[i] - _g[parent]).normalized()
			segs.append([_g[i], _g[i] + dir * HAND_EXTENSION_M, float(CLEARANCE[key])])
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(wpos.size())
	loose_count = 0
	for v: int in wpos.size():
		var free: float = 1.0
		for s: Array in segs:
			if _seg_dist(wpos[v], s[0], s[1]) < float(s[2]):
				free = 0.0
				break
		out[v] = free
		loose_count += int(free)
	return out


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


## One chain per populated angular sector of a group. Hair: head height down to the hip
## band; cloth: hip height down to the lowest cloth vertex. Returns sector -> [names, band, top, centre].
func _group(wpos: PackedVector3Array, loose: PackedFloat32Array, is_hair: bool) -> Dictionary:
	var root: int = _head if is_hair else _hips
	var sectors: int = HAIR_SECTORS if is_hair else CLOTH_SECTORS
	var n_bones: int = HAIR_BONES if is_hair else CLOTH_BONES
	var top: float = _head_y if is_hair else _hips_y
	var centre: Vector2 = Vector2(_g[root].x, _g[root].z)
	var info: Dictionary = {"sectors": sectors, "centre": centre, "top": top}
	for s: int in sectors:
		var bottom: float = INF
		var count: int = 0
		for v: int in wpos.size():
			var y: float = wpos[v].y
			if loose[v] <= 0.5 or y > top or (is_hair and y < _hips_y - HIP_BAND_M) or (not is_hair and y > _hips_y + HIP_BAND_M):
				continue
			if _sector(wpos[v], centre, sectors) != s:
				continue
			bottom = minf(bottom, y)
			count += 1
		if count < MIN_CHAIN_VERTS or top - bottom < MIN_CHAIN_LEN_M:
			continue
		var band: float = (top - bottom) / n_bones
		var sums: Array[Vector3] = []
		var counts: PackedInt32Array = PackedInt32Array()
		counts.resize(n_bones)
		for b: int in n_bones:
			sums.append(Vector3.ZERO)
		for v2: int in wpos.size():
			if loose[v2] > 0.5 and wpos[v2].y <= top and wpos[v2].y >= bottom and _sector(wpos[v2], centre, sectors) == s:
				var bi: int = clampi(int((top - wpos[v2].y) / band), 0, n_bones - 1)
				sums[bi] += wpos[v2]
				counts[bi] += 1
		var names: PackedStringArray = PackedStringArray()
		var parent: int = root
		var prev: Vector3 = _g[root]
		for b2: int in n_bones:
			var c: Vector3 = sums[b2] / float(counts[b2]) if counts[b2] > 0 else prev
			c.y = top - band * float(b2)
			var bname: String = "%s_%d_%d" % ["hair" if is_hair else "cloth", s, b2]
			var idx: int = skel.get_bone_count()
			skel.add_bone(bname)
			skel.set_bone_parent(idx, parent)
			var local: Vector3 = skel.get_bone_global_rest(parent).affine_inverse() * (_gxf(skel).affine_inverse() * c)
			skel.set_bone_rest(idx, Transform3D(Basis.IDENTITY, local))
			skel.reset_bone_pose(idx)
			names.append(bname)
			parent = idx
			prev = c
		chains.append({"names": names, "kind": "hair" if is_hair else "cloth"})
		info[s] = [names, band]
	return info


static func _sector(p: Vector3, centre: Vector2, sectors: int) -> int:
	var d: Vector2 = Vector2(p.x, p.z) - centre
	return int(floor((d.angle() + PI) / TAU * sectors)) % sectors


## Skeleton bone -> weight inside one group's chain (its band bone, blended with neighbours).
func _weights(p: Vector3, info: Dictionary, root: int) -> Dictionary:
	var s: int = _sector(p, info["centre"], info["sectors"])
	var top: float = info["top"]
	if p.y >= top or not info.has(s):
		return {root: 1.0}
	var names: PackedStringArray = info[s][0]
	var band: float = info[s][1]
	var n: int = names.size()
	var f: float = clampf((top - p.y) / band, 0.0, n - 0.001)
	var i0: int = int(f)
	var t: float = f - float(i0)
	var me: int = skel.find_bone(names[i0])
	var prev: int = root if i0 == 0 else skel.find_bone(names[i0 - 1])
	var w_prev: float = 0.5 * (1.0 - smoothstep(0.0, 0.4, t))
	var w_next: float = 0.0
	var out: Dictionary = {}
	if i0 < n - 1:
		w_next = 0.5 * smoothstep(0.6, 1.0, t)
		out[skel.find_bone(names[i0 + 1])] = w_next
	out[prev] = float(out.get(prev, 0.0)) + w_prev
	out[me] = float(out.get(me, 0.0)) + 1.0 - w_prev - w_next
	return out


func _blend(bones: PackedInt32Array, weights: PackedFloat32Array, v: int, extra: Dictionary, k: float) -> void:
	var mix: Dictionary = {}
	for j: int in 4:
		var bind: int = bones[v * 4 + j]
		mix[bind] = float(mix.get(bind, 0.0)) + weights[v * 4 + j] * (1.0 - k)
	for bone: int in extra:
		var bind2: int = _bind_of[bone]
		mix[bind2] = float(mix.get(bind2, 0.0)) + float(extra[bone]) * k
	var keys: Array = mix.keys()
	keys.sort_custom(func(a: int, b: int) -> bool: return float(mix[a]) > float(mix[b]))
	var total: float = 0.0
	for j2: int in mini(4, keys.size()):
		total += float(mix[keys[j2]])
	for j3: int in 4:
		bones[v * 4 + j3] = int(keys[j3]) if j3 < keys.size() else 0
		weights[v * 4 + j3] = float(mix[keys[j3]]) / maxf(total, 1e-6) if j3 < keys.size() else 0.0


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 1e-8), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func _gxf(n: Node3D) -> Transform3D:
	var t: Transform3D = n.transform
	var p: Node = n.get_parent()
	while p is Node3D:
		t = (p as Node3D).transform * t
		p = p.get_parent()
	return t
