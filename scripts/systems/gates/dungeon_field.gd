class_name DungeonField
extends RefCounted
## Open space of a whole dungeon as a density grid (> 0 = open). Rooms are unions of
## random ellipses (never a plain circle), links are winding capsules (cave tunnels),
## caches and Double Gate dead ends are small extra capsules. Each sample remembers the
## room that owns it and its ceiling height. World noise then roughens every wall, except
## in "quiet" spots where a door, ward or cracked wall must fit exactly.

const CELL_M: float = 1.5
const PAD_M: float = 48.0
const CORRIDOR_H: float = 5.5
const NICHE_H: float = 3.0
const EMPTY: float = -2.0
const LINK_WIDTH: Dictionary[DungeonPlan.Link, float] = {
	DungeonPlan.Link.DOOR: 2.6, DungeonPlan.Link.OPEN: 2.9, DungeonPlan.Link.BREACH: 6.5,
}
const STYLE_NOISE: Dictionary[StringName, float] = {&"cave": 0.24, &"hall": 0.07, &"ruin": 0.15}
const TUNNEL_NOISE: float = 0.2
const NICHE_WIDTH: float = 1.3
const DEAD_END_LEN: float = 9.0

var origin: Vector2 = Vector2.ZERO
var size: Vector2i = Vector2i.ZERO
var density: PackedFloat32Array = []
var room_of: PackedInt32Array = []
var ceiling: PackedFloat32Array = []
## Per room: ellipses as PackedFloat32Array [cx, cz, rx, rz, rot].
var blobs: Array[Array] = []
## Per plan link: {"a", "b", "kind", "width", "points": PackedVector2Array,
## "mouth_a", "dir_a", "mouth_b", "dir_b"} (dir points from the room into the tunnel).
var tunnels: Array[Dictionary] = []
## Cracked-wall caches: {"room", "mouth", "dir", "center"}.
var niches: Array[Dictionary] = []
## Double Gate dead ends: {"room", "end", "dir"}.
var dead_ends: Array[Dictionary] = []
## Ceiling height per sample, blurred so roofs slope instead of stepping.
var _roof: PackedFloat32Array = []
var _is_room: PackedByteArray = []
var _quiet: Array[Vector3] = []
var _styles: Array[StringName] = []
var _centers: Array[Vector2] = []
var _radii: Array[float] = []


static func build(plan: DungeonPlan, seed_value: int) -> DungeonField:
	var f: DungeonField = DungeonField.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	for i: int in plan.rooms.size():
		f._styles.append(plan.rooms[i].style)
		f._centers.append(plan.center(i))
		f._radii.append(plan.rooms[i].radius)
		f.blobs.append(f._make_blobs(plan, i, rng))
	for link: Dictionary in plan.links:
		f.tunnels.append(f._make_tunnel(plan, link, rng))
	for i: int in plan.rooms.size():
		if plan.rooms[i].has_cache:
			f._make_niche(plan, i, rng)
		if plan.rooms[i].has_double_door:
			f._make_dead_end(plan, i, rng)
	f._allocate(plan)
	f._rasterize(plan)
	f._roughen(seed_value)
	f._smooth_roof()
	return f


# --- shapes -----------------------------------------------------------------------

func _make_blobs(plan: DungeonPlan, index: int, rng: RandomNumberGenerator) -> Array:
	var room: DungeonPlan.Room = plan.rooms[index]
	var c: Vector2 = plan.center(index)
	var r: float = room.radius
	var out: Array = [PackedFloat32Array([c.x, c.y, r * 0.62, r * 0.62 * rng.randf_range(0.7, 1.0), rng.randf() * TAU])]
	var lobes: int = {&"cave": 5, &"hall": 2, &"ruin": 3}.get(room.style, 3)
	if room.kind == DungeonPlan.Kind.BOSS:
		lobes = 3
	for _l: int in lobes:
		var a: float = rng.randf() * TAU
		var at: Vector2 = c + Vector2(cos(a), sin(a)) * r * rng.randf_range(0.35, 0.6)
		out.append(PackedFloat32Array([at.x, at.y, r * rng.randf_range(0.3, 0.5), r * rng.randf_range(0.2, 0.42), a + rng.randf_range(-0.5, 0.5)]))
	return out


## Winding tunnel from room a to room b (Catmull-Rom through two jittered points).
func _make_tunnel(plan: DungeonPlan, link: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var a: int = link["a"]
	var b: int = link["b"]
	var kind: DungeonPlan.Link = link["kind"]
	var ca: Vector2 = plan.center(a)
	var cb: Vector2 = plan.center(b)
	var side: Vector2 = (cb - ca).orthogonal().normalized()
	var wind: float = DungeonArchetype.spec(plan.archetype)["wiggle"]
	var wiggle: float = (4.0 if kind == DungeonPlan.Link.BREACH else 10.0) * wind
	var key: PackedVector2Array = [ca, ca.lerp(cb, 0.35) + side * rng.randf_range(-wiggle, wiggle), ca.lerp(cb, 0.65) + side * rng.randf_range(-wiggle, wiggle), cb]
	var points: PackedVector2Array = _spline(key, 2.0)
	var t: Dictionary = {"a": a, "b": b, "kind": kind, "width": LINK_WIDTH[kind], "points": points}
	var ma: Array = _mouth(a, points, false)
	var mb: Array = _mouth(b, points, true)
	var mouth_a: Vector2 = ma[0]
	var mouth_b: Vector2 = mb[0]
	t["mouth_a"] = mouth_a
	t["dir_a"] = ma[1]
	t["mouth_b"] = mouth_b
	t["dir_b"] = mb[1]
	var quiet_r: float = LINK_WIDTH[kind] + 2.5
	_quiet.append(Vector3(mouth_a.x, mouth_a.y, quiet_r))
	_quiet.append(Vector3(mouth_b.x, mouth_b.y, quiet_r))
	return t


## Where a tunnel leaves a room: [point, direction into the tunnel].
func _mouth(room: int, points: PackedVector2Array, from_end: bool) -> Array:
	var n: int = points.size()
	for k: int in n:
		var idx: int = n - 1 - k if from_end else k
		if room_value(room, points[idx]) < 0.0:
			var prev: int = mini(idx + 1, n - 1) if from_end else maxi(idx - 1, 0)
			var dir: Vector2 = (points[idx] - points[prev]).normalized()
			return [points[idx], dir]
	return [points[0], Vector2.RIGHT]


func _make_niche(plan: DungeonPlan, room: int, rng: RandomNumberGenerator) -> void:
	var dir: Vector2 = _free_direction(room, rng)
	var edge: float = _edge_distance(plan, room, dir)
	var c: Vector2 = plan.center(room)
	var mouth: Vector2 = c + dir * (edge + 1.2)
	var centre: Vector2 = c + dir * (edge + 5.6)
	niches.append({"room": room, "dir": dir, "mouth": mouth, "center": centre, "from": c + dir * (edge - 1.5)})
	_quiet.append(Vector3(mouth.x, mouth.y, 3.5))
	_quiet.append(Vector3(centre.x, centre.y, 4.0))


func _make_dead_end(plan: DungeonPlan, room: int, rng: RandomNumberGenerator) -> void:
	var dir: Vector2 = _free_direction(room, rng)
	var edge: float = _edge_distance(plan, room, dir)
	var c: Vector2 = plan.center(room)
	var end_at: Vector2 = c + dir * (edge + DEAD_END_LEN - 1.5)
	dead_ends.append({"room": room, "dir": dir, "from": c + dir * (edge - 1.0), "end": end_at})
	_quiet.append(Vector3(end_at.x, end_at.y, 4.5))


## A direction out of the room that keeps clear of its tunnels and other extras.
func _free_direction(room: int, rng: RandomNumberGenerator) -> Vector2:
	var taken: Array[Vector2] = []
	for t: Dictionary in tunnels:
		var ta: int = t["a"]
		var tb: int = t["b"]
		if ta == room:
			taken.append(t["dir_a"])
		elif tb == room:
			taken.append(t["dir_b"])
	for e: Dictionary in niches + dead_ends:
		var er: int = e["room"]
		if er == room:
			taken.append(e["dir"])
	var best: Vector2 = Vector2.RIGHT
	var best_gap: float = -1.0
	for _try: int in 16:
		var a: float = rng.randf() * TAU
		var d: Vector2 = Vector2(cos(a), sin(a))
		var gap: float = PI
		for t2: Vector2 in taken:
			gap = minf(gap, absf(d.angle_to(t2)))
		if gap > best_gap:
			best_gap = gap
			best = d
	return best


func _edge_distance(plan: DungeonPlan, room: int, dir: Vector2) -> float:
	var c: Vector2 = plan.center(room)
	var dist: float = 0.0
	while dist < plan.rooms[room].radius * 2.0 and room_value(room, c + dir * dist) > 0.0:
		dist += 0.5
	return dist


## Analytic room shape (no noise): > 0 inside one of the room's ellipses.
func room_value(room: int, p: Vector2) -> float:
	var best: float = EMPTY
	for b: PackedFloat32Array in blobs[room]:
		best = maxf(best, 1.0 - _ellipse_norm(b, p))
	return best


static func _ellipse_norm(b: PackedFloat32Array, p: Vector2) -> float:
	var d: Vector2 = p - Vector2(b[0], b[1])
	var cr: float = cos(b[4])
	var sr: float = sin(b[4])
	var x: float = (d.x * cr + d.y * sr) / b[2]
	var z: float = (-d.x * sr + d.y * cr) / b[3]
	return sqrt(x * x + z * z)


static func _spline(key: PackedVector2Array, step_m: float) -> PackedVector2Array:
	var out: PackedVector2Array = []
	for i: int in key.size() - 1:
		var p0: Vector2 = key[maxi(i - 1, 0)]
		var p1: Vector2 = key[i]
		var p2: Vector2 = key[i + 1]
		var p3: Vector2 = key[mini(i + 2, key.size() - 1)]
		var steps: int = maxi(ceili(p1.distance_to(p2) / step_m), 1)
		for s: int in steps:
			var t: float = float(s) / float(steps)
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t * t + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t * t * t))
	out.append(key[key.size() - 1])
	return out


# --- grid -------------------------------------------------------------------------

func _allocate(plan: DungeonPlan) -> void:
	var lo: Vector2 = plan.center(0)
	var hi: Vector2 = lo
	for i: int in plan.rooms.size():
		lo = lo.min(plan.center(i))
		hi = hi.max(plan.center(i))
	origin = lo - Vector2.ONE * PAD_M
	size = Vector2i(ceili((hi.x - lo.x + PAD_M * 2.0) / CELL_M) + 1, ceili((hi.y - lo.y + PAD_M * 2.0) / CELL_M) + 1)
	var n: int = size.x * size.y
	density.resize(n)
	density.fill(EMPTY)
	room_of.resize(n)
	room_of.fill(-1)
	ceiling.resize(n)
	ceiling.fill(CORRIDOR_H)
	_is_room.resize(n)
	_is_room.fill(0)


func _rasterize(plan: DungeonPlan) -> void:
	for i: int in plan.rooms.size():
		for b: PackedFloat32Array in blobs[i]:
			_stamp_ellipse(b, i, plan.rooms[i].height)
	for t: Dictionary in tunnels:
		var a: int = t["a"]
		var b2: int = t["b"]
		var kind: DungeonPlan.Link = t["kind"]
		var h: float = minf(plan.rooms[a].height, plan.rooms[b2].height) if kind == DungeonPlan.Link.BREACH else CORRIDOR_H
		var points: PackedVector2Array = t["points"]
		var mouths: PackedVector2Array = [t["mouth_a"], t["mouth_b"]]
		_stamp_path(points, LINK_WIDTH[kind], a, b2, h, mouths, kind != DungeonPlan.Link.BREACH)
	for e: Dictionary in niches:
		var room: int = e["room"]
		var from: Vector2 = e["from"]
		var centre: Vector2 = e["center"]
		_stamp_path(PackedVector2Array([from, centre]), NICHE_WIDTH, room, room, NICHE_H)
		_stamp_ellipse(PackedFloat32Array([centre.x, centre.y, 2.4, 2.4, 0.0]), room, NICHE_H, false)
	for e2: Dictionary in dead_ends:
		var room2: int = e2["room"]
		var from2: Vector2 = e2["from"]
		var end_at: Vector2 = e2["end"]
		_stamp_path(PackedVector2Array([from2, end_at]), LINK_WIDTH[DungeonPlan.Link.DOOR], room2, room2, CORRIDOR_H)


func _stamp_ellipse(b: PackedFloat32Array, room: int, h: float, is_room: bool = true) -> void:
	var reach: float = maxf(b[2], b[3]) * 1.6
	var lo: Vector2i = _cell_of(Vector2(b[0], b[1]) - Vector2.ONE * reach)
	var hi: Vector2i = _cell_of(Vector2(b[0], b[1]) + Vector2.ONE * reach)
	for j: int in range(lo.y, hi.y + 1):
		for i: int in range(lo.x, hi.x + 1):
			_put(i, j, 1.0 - _ellipse_norm(b, sample_pos(i, j)), room, h, is_room)


## Capsule chain; the first half belongs to room a, the second to room b. Away from the
## mouths a cave tunnel swells and narrows and its roof rises and dips; at the mouths it
## keeps the base width / height so wards and doors fit.
func _stamp_path(points: PackedVector2Array, width: float, a: int, b: int, h: float, mouths: PackedVector2Array = [], cave: bool = false) -> void:
	var half: int = floori(float(points.size()) / 2.0)
	var phase: float = fposmod(points[0].x * 0.37 + points[points.size() - 1].y * 0.61, TAU)
	for s: int in points.size() - 1:
		var p: Vector2 = points[s]
		var q: Vector2 = points[s + 1]
		var wild: float = 0.0
		if cave:
			wild = 1.0
			for m: Vector2 in mouths:
				wild = minf(wild, clampf((p.distance_to(m) - 4.0) / 6.0, 0.0, 1.0))
		var t: float = float(s) * 0.45 + phase
		var w: float = width * (1.0 + wild * (0.32 * sin(t) + 0.14 * sin(t * 2.3 + 1.7)))
		var roof: float = h + wild * (1.2 * sin(t * 0.8 + 0.6) + 0.6)
		var lo: Vector2i = _cell_of(p.min(q) - Vector2.ONE * w * 1.6)
		var hi: Vector2i = _cell_of(p.max(q) + Vector2.ONE * w * 1.6)
		var room: int = a if s < half else b
		for j: int in range(lo.y, hi.y + 1):
			for i: int in range(lo.x, hi.x + 1):
				var at: Vector2 = sample_pos(i, j)
				_put(i, j, 1.0 - Geometry2D.get_closest_point_to_segment(at, p, q).distance_to(at) / w, room, roof, false)


## Keeps the strongest value. Tunnels never lower a room's ceiling or steal its cells.
func _put(i: int, j: int, v: float, room: int, h: float, is_room: bool) -> void:
	if i < 0 or j < 0 or i >= size.x or j >= size.y:
		return
	var k: int = j * size.x + i
	if v <= density[k]:
		return
	density[k] = v
	if is_room or _is_room[k] == 0 or v <= 0.0:
		room_of[k] = room
		ceiling[k] = h
		_is_room[k] = 1 if is_room and v > 0.0 else _is_room[k]


func _roughen(seed_value: int) -> void:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.07
	noise.fractal_octaves = 3
	for j: int in size.y:
		for i: int in size.x:
			var k: int = j * size.x + i
			if density[k] < -0.8:
				continue
			var at: Vector2 = sample_pos(i, j)
			var amp: float = STYLE_NOISE.get(_styles[room_of[k]], 0.15) if _is_room[k] == 1 else TUNNEL_NOISE
			density[k] += noise.get_noise_2d(at.x, at.y) * amp * _calm(at)


func _smooth_roof() -> void:
	_roof = ceiling.duplicate()
	for _pass: int in 2:
		var src: PackedFloat32Array = _roof.duplicate()
		for j: int in range(1, size.y - 1):
			for i: int in range(1, size.x - 1):
				var sum: float = 0.0
				for dj: int in range(-1, 2):
					for di: int in range(-1, 2):
						sum += src[(j + dj) * size.x + i + di]
				_roof[j * size.x + i] = sum / 9.0


## Highest (smoothed) roof within `radius` metres of a point: doors and wards reach it.
func roof_near(p: Vector2, radius: float) -> float:
	var c: Vector2i = _cell_of(p)
	var reach: int = ceili(radius / CELL_M)
	var top: float = CORRIDOR_H
	for dj: int in range(-reach, reach + 1):
		for di: int in range(-reach, reach + 1):
			top = maxf(top, roof_at(c.x + di, c.y + dj))
	return top


func roof_at(i: int, j: int) -> float:
	if i < 0 or j < 0 or i >= size.x or j >= size.y:
		return CORRIDOR_H
	return _roof[j * size.x + i]


## 0 inside quiet spots, rising to 1 two metres outside them.
func _calm(at: Vector2) -> float:
	var f: float = 1.0
	for q: Vector3 in _quiet:
		f = minf(f, clampf((at.distance_to(Vector2(q.x, q.y)) - q.z) / 2.0, 0.0, 1.0))
	return f


# --- queries ----------------------------------------------------------------------

func sample_pos(i: int, j: int) -> Vector2:
	return origin + Vector2(i, j) * CELL_M


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori((p.x - origin.x) / CELL_M), floori((p.y - origin.y) / CELL_M))


func density_at(i: int, j: int) -> float:
	if i < 0 or j < 0 or i >= size.x or j >= size.y:
		return EMPTY
	return density[j * size.x + i]


## Bilinear density at a world (x, z) point.
func value_at(p: Vector2) -> float:
	var g: Vector2 = (p - origin) / CELL_M
	var i: int = floori(g.x)
	var j: int = floori(g.y)
	var fx: float = g.x - float(i)
	var fz: float = g.y - float(j)
	return lerpf(lerpf(density_at(i, j), density_at(i + 1, j), fx), lerpf(density_at(i, j + 1), density_at(i + 1, j + 1), fx), fz)


## Room owning the nearest sample (-1 outside the grid).
func room_at(p: Vector2) -> int:
	var c: Vector2i = _cell_of(p + Vector2.ONE * CELL_M * 0.5)
	if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
		return -1
	return room_of[c.y * size.x + c.x]


## Open samples reachable from `from` (4-neighbour flood fill), as a set of indices.
func reachable_from(from: Vector2) -> Dictionary:
	var start: Vector2i = _cell_of(from + Vector2.ONE * CELL_M * 0.5)
	var seen: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		if c.x < 0 or c.y < 0 or c.x >= size.x or c.y >= size.y:
			continue
		var k: int = c.y * size.x + c.x
		if seen.has(k) or density[k] <= 0.0:
			continue
		seen[k] = true
		queue.append_array([c + Vector2i(1, 0), c - Vector2i(1, 0), c + Vector2i(0, 1), c - Vector2i(0, 1)])
	return seen


## 1 inside / around hall and ruin rooms (dressed masonry, straight walls), fading to 0
## in caves and tunnels (rough rock that leans outward like a cave).
func masonry(p: Vector2) -> float:
	var m: float = 0.0
	for i: int in _centers.size():
		if _styles[i] == &"cave":
			continue
		var d: float = p.distance_to(_centers[i]) - _radii[i] * 1.15
		m = maxf(m, 1.0 - clampf(d / 6.0, 0.0, 1.0))
	return m


func index_of(p: Vector2) -> int:
	var c: Vector2i = _cell_of(p + Vector2.ONE * CELL_M * 0.5)
	return c.y * size.x + c.x
