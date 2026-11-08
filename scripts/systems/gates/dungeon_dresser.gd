class_name DungeonDresser
extends RefCounted
## Dresses each room of a built dungeon: lanterns along the walls and torches down the
## tunnels, style pieces (hall pillar rings, cave rocks, ruin rubble), statues, puddles,
## cracked-wall caches with a chest, and the treasure shrine of side rooms. Everything
## keeps clear of the room mouths so wards, doors and the camera are never blocked.

const MOUTH_CLEAR_M: float = 6.5
const TORCH_EVERY_M: float = 14.0
const CAVE_ROCKS: Array[StringName] = [&"rock_spire", &"rock_pile", &"rock_large", &"rock_boulders", &"rock_monolith_moss"]
const RUIN_RUBBLE: Array[StringName] = [&"rubble_heap", &"ruin_stone_block", &"rock_pile"]
const BREAKABLE_SCENE: String = "res://scenes/world/props/breakable_wall.tscn"
const WATER: Color = Color(0.05, 0.07, 0.09, 0.78)

var theme: GateTheme
var field: DungeonField
var plan: DungeonPlan
var level: int = 1
var chest_prefix: String = ""
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _mouths: Array[Vector2] = []
var _water: StandardMaterial3D


func _init(gate_theme: GateTheme, built: DungeonField, layout: DungeonPlan) -> void:
	theme = gate_theme
	field = built
	plan = layout
	for t: Dictionary in field.tunnels:
		_mouths.append(t["mouth_a"])
		_mouths.append(t["mouth_b"])
	for e: Dictionary in field.niches:
		_mouths.append(e["mouth"])
	_water = StandardMaterial3D.new()
	_water.albedo_color = WATER
	_water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water.metallic = 0.4
	_water.roughness = 0.04


func dress(index: int, group: Node3D, wall_material: Material) -> void:
	var spec: DungeonPlan.Room = plan.rooms[index]
	_rng.seed = spec.seed_value
	var c: Vector2 = plan.center(index)
	var near_wall: Array[Vector2] = _wall_spots(index)
	_lights(group, spec, c, near_wall)
	match spec.style:
		&"hall":
			_pillar_ring(group, spec, c, wall_material)
		&"cave":
			_scatter(group, near_wall, CAVE_ROCKS, _rng.randi_range(5, 8), Vector2(1.6, 5.0))
		_:
			_scatter(group, near_wall, RUIN_RUBBLE, _rng.randi_range(3, 5), Vector2(1.0, 2.0))
	_puddles(group, index, c, spec.radius)
	if spec.kind == DungeonPlan.Kind.SIDE:
		_treasure_shrine(group, index, c, near_wall)
	elif spec.kind == DungeonPlan.Kind.FIGHT and _rng.randf() < 0.45 and not near_wall.is_empty():
		var at: Vector2 = near_wall[_rng.randi() % near_wall.size()]
		_prop(group, &"dungeon_statue", _rng.randf_range(3.0, 4.2), at, (c - at).angle(), true)
	for e: Dictionary in field.niches:
		var room: int = e["room"]
		if room == index:
			_cache(group, e, index)


## Tunnel torches: one every TORCH_EVERY_M metres along the tunnel, on alternating walls.
func dress_tunnel(group: Node3D, t: Dictionary) -> void:
	var points: PackedVector2Array = t["points"]
	var width: float = t["width"]
	var a: int = t["a"]
	var b: int = t["b"]
	var walked: float = 0.0
	var side: float = 1.0
	for k: int in range(1, points.size()):
		walked += points[k].distance_to(points[k - 1])
		if walked < TORCH_EVERY_M:
			continue
		walked = 0.0
		if field.room_value(a, points[k]) > -0.15 or field.room_value(b, points[k]) > -0.15:
			continue
		var dir: Vector2 = (points[k] - points[k - 1]).normalized()
		var at: Vector2 = points[k] + dir.orthogonal() * side * (width - 1.0)
		side = -side
		_lantern(group, at, 9.0)


## Open samples close to this room's walls (not near a mouth), spread out.
func _wall_spots(index: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var c: Vector2 = plan.center(index)
	var reach: float = plan.rooms[index].radius * 1.3
	var step: float = 2.0
	var y: float = -reach
	while y <= reach:
		var x: float = -reach
		while x <= reach:
			var p: Vector2 = c + Vector2(x, y)
			var v: float = field.value_at(p)
			if v > 0.05 and v < 0.22 and field.room_at(p) == index and field.room_value(index, p) > -0.1 and _clear(p, MOUTH_CLEAR_M):
				out.append(p)
			x += step
		y += step
	# Shuffle deterministically so picks spread around the room.
	for i: int in range(out.size() - 1, 0, -1):
		var j: int = _rng.randi() % (i + 1)
		var tmp: Vector2 = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func _clear(p: Vector2, clearance: float) -> bool:
	for m: Vector2 in _mouths:
		if m.distance_to(p) < clearance:
			return false
	return true


## Picks up to `count` spots at least `gap` metres apart.
func _spread(spots: Array[Vector2], count: int, gap: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Vector2 in spots:
		if out.size() >= count:
			break
		var ok: bool = true
		for q: Vector2 in out:
			if q.distance_to(p) < gap:
				ok = false
		if ok:
			out.append(p)
	return out


## Pulls a wall spot a little into the room (along the density slope).
func _inward(p: Vector2, metres: float) -> Vector2:
	var gx: float = field.value_at(p + Vector2(0.5, 0.0)) - field.value_at(p - Vector2(0.5, 0.0))
	var gz: float = field.value_at(p + Vector2(0.0, 0.5)) - field.value_at(p - Vector2(0.0, 0.5))
	var g: Vector2 = Vector2(gx, gz)
	return p + (g.normalized() * metres if g.length() > 0.0001 else Vector2.ZERO)


func _lights(group: Node3D, spec: DungeonPlan.Room, c: Vector2, near_wall: Array[Vector2]) -> void:
	var fill: OmniLight3D = OmniLight3D.new()
	fill.light_color = theme.tint.lightened(0.55)
	fill.omni_range = spec.radius * 1.8
	fill.light_energy = 0.5
	fill.omni_attenuation = 0.6
	fill.position = Vector3(c.x, spec.height * 0.7, c.y)
	group.add_child(fill)
	var count: int = {DungeonPlan.Kind.SIDE: 3, DungeonPlan.Kind.BOSS: 8}.get(spec.kind, 5)
	for p: Vector2 in _spread(near_wall, count, spec.radius * 0.6):
		_lantern(group, _inward(p, 0.6), spec.radius * 0.8)


func _lantern(group: Node3D, at: Vector2, light_range: float) -> void:
	var lamp: DecorProp = DecorProp.new()
	lamp.kind = &"lantern"
	lamp.always_lit = true
	lamp.light_range_m = light_range
	lamp.tint = Color(1.0, 0.62, 0.3).lerp(theme.tint, 0.2)
	lamp.seed_value = _rng.randi()
	lamp.position = Vector3(at.x, 0.0, at.y)
	group.add_child(lamp)


func _pillar_ring(group: Node3D, spec: DungeonPlan.Room, c: Vector2, wall_material: Material) -> void:
	var ring: int = 8 if spec.radius >= 15.0 else 6
	var at_r: float = spec.radius * (0.62 if spec.kind == DungeonPlan.Kind.BOSS else 0.5)
	var phase: float = _rng.randf() * TAU
	for i: int in ring:
		var a: float = phase + TAU * float(i) / float(ring)
		var p: Vector2 = c + Vector2(cos(a), sin(a)) * at_r
		if field.value_at(p) < 0.35 or not _clear(p, MOUTH_CLEAR_M):
			continue
		var body: StaticBody3D = StaticBody3D.new()
		body.position = Vector3(p.x, spec.height * 0.5, p.y)
		var cs: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(1.6, spec.height, 1.6)
		cs.shape = box
		body.add_child(cs)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = box.size
		mi.mesh = bm
		mi.material_override = wall_material
		body.add_child(mi)
		group.add_child(body)
		theme.dress_pillar(body, spec.height)


func _scatter(group: Node3D, near_wall: Array[Vector2], ids: Array[StringName], count: int, heights: Vector2) -> void:
	for p: Vector2 in _spread(near_wall.slice(0, near_wall.size()), count, 4.0):
		var id: StringName = ids[_rng.randi() % ids.size()]
		_prop(group, id, _rng.randf_range(heights.x, heights.y), _inward(p, 1.2), _rng.randf() * TAU, true)


## Flat irregular pools on the floor (reflective, no collision).
func _puddles(group: Node3D, index: int, c: Vector2, radius: float) -> void:
	for _p: int in _rng.randi_range(1, 3):
		var at: Vector2 = c + Vector2.from_angle(_rng.randf() * TAU) * radius * _rng.randf_range(0.1, 0.6)
		var r: float = _rng.randf_range(1.2, 2.8)
		if field.value_at(at) < 0.3 or field.room_at(at) != index:
			continue
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rim: PackedVector2Array = []
		for k: int in 14:
			rim.append(Vector2.from_angle(TAU * float(k) / 14.0) * r * _rng.randf_range(0.65, 1.15))
		for k: int in 14:
			for q: Vector2 in [Vector2.ZERO, rim[k], rim[(k + 1) % 14]]:
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(q.x, 0.0, q.y))
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = _water
		mi.position = Vector3(at.x, 0.03, at.y)
		group.add_child(mi)


## Cracked wall (heavy attack) closing a lit niche with a chest.
func _cache(group: Node3D, e: Dictionary, index: int) -> void:
	var dir: Vector2 = e["dir"]
	var mouth: Vector2 = e["mouth"]
	var centre: Vector2 = e["center"]
	var crack: Breakable = (load(BREAKABLE_SCENE) as PackedScene).instantiate() as Breakable
	crack.position = Vector3(mouth.x, 0.0, mouth.y)
	crack.rotation.y = atan2(dir.x, dir.y)
	group.add_child(crack)
	var chest: LootChest = LootChest.new()
	chest.chest_id = StringName("%s_cache_%d" % [chest_prefix, index])
	chest.kind = &"treasure"
	chest.level = level
	chest.persistent = false
	chest.position = Vector3(centre.x, 0.0, centre.y)
	chest.rotation.y = atan2(-dir.x, -dir.y)
	group.add_child(chest)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.45)
	glow.omni_range = 4.0
	glow.light_energy = 0.9
	glow.position = Vector3(centre.x, 2.2, centre.y)
	group.add_child(glow)


## Dead-end room: an ornate chest, a glowing relic on a rock and a guardian statue.
func _treasure_shrine(group: Node3D, index: int, c: Vector2, near_wall: Array[Vector2]) -> void:
	var away: Vector2 = Vector2.ZERO
	for t: Dictionary in field.tunnels:
		var b: int = t["b"]
		var mouth: Vector2 = t["mouth_b"]
		if b == index:
			away = (c - mouth).normalized()
	var at: Vector2 = c + away * plan.rooms[index].radius * 0.35
	var chest: LootChest = LootChest.new()
	chest.chest_id = StringName("%s_side_%d" % [chest_prefix, index])
	chest.kind = &"treasure"
	chest.level = level + 1
	chest.persistent = false
	chest.position = Vector3(at.x, 0.0, at.y)
	chest.rotation.y = atan2(-away.x, -away.y)
	group.add_child(chest)
	_prop(group, &"dungeon_statue", 3.4, at + away.orthogonal() * 2.8, atan2(-away.x, -away.y), true)
	if near_wall.is_empty():
		return
	var relic: Vector2 = _inward(near_wall[0], 1.2)
	_prop(group, &"rock_pile", 1.2, relic, 0.0, true)
	_prop(group, &"dungeon_relic_gem", 0.9, relic, _rng.randf() * TAU, false, 1.1)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(0.4, 1.0, 0.6)
	glow.omni_range = 5.0
	glow.light_energy = 1.2
	glow.position = Vector3(relic.x, 1.8, relic.y)
	group.add_child(glow)


func _prop(group: Node3D, id: StringName, height: float, at: Vector2, yaw: float, collide: bool, lift: float = 0.0) -> void:
	var holder: Node3D = StaticBody3D.new() if collide else Node3D.new()
	holder.position = Vector3(at.x, lift, at.y)
	holder.rotation.y = yaw
	group.add_child(holder)
	if not PropInstance.attach_model(holder, id, height):
		holder.queue_free()
		return
	var d: PropData = PropData.find(id)
	if collide and d != null and d.size.y > 0.001:
		var s: Vector3 = d.size * (height / d.size.y) * 0.8
		var cs: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = s
		cs.shape = box
		cs.position.y = s.y * 0.5
		holder.add_child(cs)
