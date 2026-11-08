class_name DungeonMesher
extends RefCounted
## Turns a DungeonField into meshes, one set per room (its tunnels' near halves included)
## so rooms can be shown / hidden: floor, ceiling (with vertical steps where a low tunnel
## meets a tall room) and walls traced with marching squares (smooth, never blocky).
## Every surface gets matching trimesh collision (the camera arm collides with the roof).

const WALL_BOTTOM: float = -0.3
const WALL_TOP: float = 18.0
const SURFACE_SHADER: Shader = preload("res://assets/shaders/dungeon_surface.gdshader")
const CRACKED_TILE: StringName = &"tile_dark_slate"
## Rough cave rock for tunnels and cave rooms (blended with the theme masonry).
const ROCK_WALL: StringName = &"wall_mossy_dark"
## Cave walls lean outward by this much at WALL_TOP (about a metre at tunnel roof height).
const CAVE_FLARE_M: float = 3.2
## Roofs reach a little past the walls so leaning cave walls never open a gap.
const ROOF_REACH: float = -0.45
const MOSS_TILE: StringName = &"tile_roots_grass"
const MUD_TILE: StringName = &"tile_mud"
const CORNERS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]

var floor_material: ShaderMaterial
var wall_material: ShaderMaterial
var ceiling_material: ShaderMaterial


func _init(theme: GateTheme, archetype: StringName = &"ruins") -> void:
	floor_material = _material(theme.floor_id, 0, 3.0, theme)
	wall_material = _material(theme.wall_id, 1, 4.0, theme)
	ceiling_material = _material(theme.wall_id, 2, 4.0, theme)
	var spec: Dictionary = DungeonArchetype.spec(archetype)
	for m: ShaderMaterial in [floor_material, wall_material, ceiling_material]:
		m.set_shader_parameter(&"moss", spec["moss"])
		m.set_shader_parameter(&"wetness", spec["wet"])


static func _material(base: StringName, surface: int, tile_m: float, theme: GateTheme) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = SURFACE_SHADER
	m.set_shader_parameter(&"tex_base", _tex(base))
	m.set_shader_parameter(&"tex_cracked", _tex(CRACKED_TILE))
	m.set_shader_parameter(&"tex_moss", _tex(MOSS_TILE))
	m.set_shader_parameter(&"tex_mud", _tex(MUD_TILE))
	m.set_shader_parameter(&"tex_rock", _tex(ROCK_WALL))
	m.set_shader_parameter(&"surface", surface)
	m.set_shader_parameter(&"tile_m", tile_m)
	m.set_shader_parameter(&"tint", Color.WHITE.lerp(theme.tint, 0.12))
	return m


static func _tex(id: StringName) -> Texture2D:
	var path: String = GateTheme.SURFACE_DIR % id
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## Adds Floor / Ceiling / Walls bodies to each room's group node.
func build(field: DungeonField, groups: Array[Node3D]) -> void:
	var floors: Array[SurfaceTool] = _tools(groups.size())
	var roofs: Array[SurfaceTool] = _tools(groups.size())
	var walls: Array[SurfaceTool] = _tools(groups.size())
	var cells: Vector2i = field.size - Vector2i.ONE
	for j: int in cells.y:
		for i: int in cells.x:
			var v: PackedFloat32Array = [field.density_at(i, j), field.density_at(i + 1, j), field.density_at(i + 1, j + 1), field.density_at(i, j + 1)]
			var top: float = maxf(maxf(v[0], v[1]), maxf(v[2], v[3]))
			if top <= ROOF_REACH:
				continue
			var best: int = 0
			for c: int in 4:
				if v[c] > v[best]:
					best = c
			var corner: Vector2i = Vector2i(i, j) + CORNERS[best]
			var room: int = field.room_of[corner.y * field.size.x + corner.x]
			if room < 0 or room >= groups.size():
				continue
			var p0: Vector2 = field.sample_pos(i, j)
			var p2: Vector2 = field.sample_pos(i + 1, j + 1)
			var tone: Color = Color(field.masonry((p0 + p2) * 0.5), 0.0, 0.0)
			_roof_quad(roofs[room], field, i, j, tone)
			if top <= 0.0:
				continue
			_quad_flat(floors[room], p0, p2, 0.0, Vector3.UP, tone)
			_walls(walls[room], field, i, j, v)
	for g: int in groups.size():
		_commit(groups[g], floors[g], floor_material, false)
		_commit(groups[g], roofs[g], ceiling_material, true)
		_commit(groups[g], walls[g], wall_material, false)


static func _tools(count: int) -> Array[SurfaceTool]:
	var out: Array[SurfaceTool] = []
	for _g: int in count:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		out.append(st)
	return out


static func _quad_flat(st: SurfaceTool, p0: Vector2, p2: Vector2, y: float, n: Vector3, tone: Color) -> void:
	var a: Vector3 = Vector3(p0.x, y, p0.y)
	var b: Vector3 = Vector3(p2.x, y, p0.y)
	var c: Vector3 = Vector3(p2.x, y, p2.y)
	var d: Vector3 = Vector3(p0.x, y, p2.y)
	_quad(st, a, b, c, d, n, [tone, tone, tone, tone])


## Two triangles; `tones` are the vertex colours of a, b, c, d (red = masonry share).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, tones: Array[Color]) -> void:
	var pts: Array[Vector3] = [a, b, c, a, c, d]
	var idx: PackedInt32Array = [0, 1, 2, 0, 2, 3]
	for k: int in 6:
		st.set_normal(n)
		st.set_color(tones[idx[k]])
		st.add_vertex(pts[k])


## Marching squares on one cell: wall quads along the zero line, normal facing the room.
func _walls(st: SurfaceTool, field: DungeonField, i: int, j: int, v: PackedFloat32Array) -> void:
	var case_id: int = (1 if v[0] > 0.0 else 0) | (2 if v[1] > 0.0 else 0) | (4 if v[2] > 0.0 else 0) | (8 if v[3] > 0.0 else 0)
	if case_id == 0 or case_id == 15:
		return
	var corners: Array[Vector2] = [field.sample_pos(i, j), field.sample_pos(i + 1, j), field.sample_pos(i + 1, j + 1), field.sample_pos(i, j + 1)]
	var edge: Array[Vector2] = []
	for e: int in 4:
		var a: int = e
		var b: int = (e + 1) % 4
		var t: float = v[a] / (v[a] - v[b]) if (v[a] > 0.0) != (v[b] > 0.0) else 0.5
		edge.append(corners[a].lerp(corners[b], clampf(t, 0.0, 1.0)))
	var centre: float = (v[0] + v[1] + v[2] + v[3]) * 0.25
	for pair: Vector2i in _segments(case_id, centre > 0.0):
		_wall_quad(st, field, edge[pair.x], edge[pair.y])


## Edge pairs per case (edges: 0 bottom, 1 right, 2 top, 3 left; saddles use the centre).
static func _segments(case_id: int, centre_in: bool) -> Array[Vector2i]:
	match case_id:
		1, 14:
			return [Vector2i(3, 0)]
		2, 13:
			return [Vector2i(0, 1)]
		3, 12:
			return [Vector2i(3, 1)]
		4, 11:
			return [Vector2i(1, 2)]
		6, 9:
			return [Vector2i(0, 2)]
		7, 8:
			return [Vector2i(2, 3)]
		5:
			return [Vector2i(0, 1), Vector2i(2, 3)] if centre_in else [Vector2i(3, 0), Vector2i(1, 2)]
		10:
			return [Vector2i(3, 0), Vector2i(1, 2)] if centre_in else [Vector2i(0, 1), Vector2i(2, 3)]
	return []


static func _wall_quad(st: SurfaceTool, field: DungeonField, p: Vector2, q: Vector2) -> void:
	if p.distance_squared_to(q) < 0.0001:
		return
	var mid: Vector2 = (p + q) * 0.5
	var n2: Vector2 = (q - p).orthogonal().normalized()
	if field.value_at(mid + n2 * 0.4) < field.value_at(mid - n2 * 0.4):
		n2 = -n2
	var mp: float = field.masonry(p)
	var mq: float = field.masonry(q)
	# Lean and normal depend only on the point itself, so neighbouring quads meet exactly
	# and shade smoothly (no toon-banded facets).
	var op: Vector2 = _outward(field, p)
	var oq: Vector2 = _outward(field, q)
	if op == Vector2.ZERO:
		op = -n2
	if oq == Vector2.ZERO:
		oq = -n2
	var tp: Vector2 = p + op * CAVE_FLARE_M * (1.0 - mp)
	var tq: Vector2 = q + oq * CAVE_FLARE_M * (1.0 - mq)
	var cp: Color = Color(mp, 0.0, 0.0)
	var cq: Color = Color(mq, 0.0, 0.0)
	var np: Vector3 = Vector3(-op.x, 0.0, -op.y)
	var nq: Vector3 = Vector3(-oq.x, 0.0, -oq.y)
	var pts: Array[Vector3] = [Vector3(p.x, WALL_BOTTOM, p.y), Vector3(q.x, WALL_BOTTOM, q.y), Vector3(tq.x, WALL_TOP, tq.y), Vector3(tp.x, WALL_TOP, tp.y)]
	var normals: Array[Vector3] = [np, nq, nq, np]
	var tones: Array[Color] = [cp, cq, cq, cp]
	for k: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(normals[k])
		st.set_color(tones[k])
		st.add_vertex(pts[k])


## Direction away from open space at a wall point (down the density slope).
static func _outward(field: DungeonField, p: Vector2) -> Vector2:
	var gx: float = field.value_at(p + Vector2(0.5, 0.0)) - field.value_at(p - Vector2(0.5, 0.0))
	var gz: float = field.value_at(p + Vector2(0.0, 0.5)) - field.value_at(p - Vector2(0.0, 0.5))
	var g: Vector2 = Vector2(gx, gz)
	return -g.normalized() if g.length() > 0.0001 else Vector2.ZERO


## Roof over one cell, each corner at its own (smoothed) height: one continuous surface
## that slopes down from tall rooms into low tunnels, like a rough arch.
static func _roof_quad(st: SurfaceTool, field: DungeonField, i: int, j: int, tone: Color) -> void:
	var pts: Array[Vector3] = []
	for c: Vector2i in CORNERS:
		var p: Vector2 = field.sample_pos(i + c.x, j + c.y)
		pts.append(Vector3(p.x, field.roof_at(i + c.x, j + c.y), p.y))
	_quad(st, pts[0], pts[1], pts[2], pts[3], Vector3.DOWN, [tone, tone, tone, tone])


static func _commit(group: Node3D, st: SurfaceTool, material: Material, is_roof: bool) -> void:
	var mesh: ArrayMesh = st.commit()
	if mesh.get_surface_count() == 0:
		return
	var body: StaticBody3D = StaticBody3D.new()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	body.add_child(mi)
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	if is_roof:
		body.set_meta(&"ceiling", true)
	group.add_child(body)
