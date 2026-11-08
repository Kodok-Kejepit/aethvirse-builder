class_name DungeonRoomBuilder
extends RefCounted
## Builds one dungeon room from its plan entry: an irregular floor and ceiling, walls
## along the outline (some broken down to rubble with rock behind), door models in the
## doorways, a cracked-wall cache with a chest, lights, and style dressing (cave rocks,
## hall pillars, ruin rubble, statues, relics).

const WALL_T: float = 1.2
const BACKING_GAP_M: float = 3.0
const BROKEN_CHANCE: Dictionary[StringName, float] = {&"cave": 0.12, &"hall": 0.08, &"ruin": 0.45}
const CACHE_GAP_M: float = 3.0
const CACHE_DEPTH_M: float = 4.4
const DOUBLE_DOOR_ANGLE: float = PI
const DOUBLE_DOOR_MODEL: StringName = &"door_winged"
const BREAKABLE_SCENE: String = "res://scenes/world/props/breakable_wall.tscn"
const CAVE_ROCKS: Array[StringName] = [&"rock_spire", &"rock_pile", &"rock_large", &"rock_boulders"]
const RUIN_RUBBLE: Array[StringName] = [&"rubble_heap", &"ruin_stone_block", &"rock_pile"]

var theme: GateTheme
var door_models: Array[StringName] = []
var level: int = 1
var chest_prefix: String = ""
var _floor_mat: StandardMaterial3D
var _wall_mat: StandardMaterial3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Door spots of the room being built: props keep clear so the camera never ends up in a rock.
var _door_spots: Array[Vector2] = []
const DOOR_CLEAR_M: float = 7.5


func _init(gate_theme: GateTheme, doors: Array[StringName]) -> void:
	theme = gate_theme
	door_models = doors
	_floor_mat = theme.floor_material.duplicate() as StandardMaterial3D
	_floor_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_wall_mat = theme.wall_material.duplicate() as StandardMaterial3D
	_wall_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


## Fills `room` (already in the tree at its spot) and returns its doors, in plan order
## (plus the Double Gate door last, when the room has one).
func build(room: GateRoom, spec: DungeonPlan.Room, index: int) -> Array[DungeonDoor]:
	_rng.seed = spec.seed_value
	var angles: Array[float] = []
	for door: Dictionary in spec.doors:
		var angle: float = door["angle"]
		angles.append(angle)
	if spec.has_double_door:
		angles.append(DOUBLE_DOOR_ANGLE)
	var pts: Array[Dictionary] = DungeonRoomShape.outline(spec.radius, spec.style, angles, spec.seed_value)
	_door_spots.clear()
	for a: float in angles:
		_door_spots.append(Vector2(cos(a), sin(a)) * spec.radius * 0.92)
	_floor_and_ceiling(room, pts, spec.height)
	var cache_edge: int = _pick_cache_edge(pts) if spec.has_cache else -1
	var doors: Array[DungeonDoor] = []
	doors.resize(angles.size())
	var door_model: StringName = door_models[_rng.randi() % door_models.size()] if not door_models.is_empty() else &""
	for i: int in pts.size():
		var a: Vector2 = pts[i]["p"]
		var b: Vector2 = pts[(i + 1) % pts.size()]["p"]
		if DungeonRoomShape.is_door_edge(pts, i):
			var d: int = pts[i]["door"]
			var is_double: bool = spec.has_double_door and d == angles.size() - 1
			doors[d] = _doorway(room, a, b, spec.height, DOUBLE_DOOR_MODEL if is_double else door_model, is_double)
			doors[d].room_index = index
		elif i == cache_edge:
			_cache(room, a, b, spec.height, index)
		elif a.distance_to(b) > 3.0 and _rng.randf() < BROKEN_CHANCE.get(spec.style, 0.1):
			_broken_wall(room, a, b, spec.height)
		else:
			_wall(room, a, b, 0.0, spec.height)
	_lights(room, pts, spec)
	_dress(room, spec, angles)
	room.size = Vector2.ONE * spec.radius * 1.6
	room.spawn_points = _spawn_points(pts, spec.radius)
	return doors


func _floor_and_ceiling(room: Node3D, pts: Array[Dictionary], height: float) -> void:
	for y: float in [0.0, height]:
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var up: Vector3 = Vector3.UP if y == 0.0 else Vector3.DOWN
		for i: int in pts.size():
			var p1: Vector2 = pts[i]["p"]
			var p2: Vector2 = pts[(i + 1) % pts.size()]["p"]
			for p: Vector2 in ([Vector2.ZERO, p2, p1] if y == 0.0 else [Vector2.ZERO, p1, p2]):
				st.set_normal(up)
				st.add_vertex(Vector3(p.x, y, p.y))
		var mesh: ArrayMesh = st.commit()
		var body: StaticBody3D = StaticBody3D.new()
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = _floor_mat if y == 0.0 else _wall_mat
		body.add_child(mi)
		var cs: CollisionShape3D = CollisionShape3D.new()
		var trimesh: ConcavePolygonShape3D = mesh.create_trimesh_shape()
		trimesh.backface_collision = true
		cs.shape = trimesh
		body.add_child(cs)
		if y > 0.0:
			body.set_meta(&"ceiling", true)
		room.add_child(body)


## Wall box along a→b (outline corners), from y0 to y1, pushed outward by `out` metres.
func _wall(room: Node3D, a: Vector2, b: Vector2, y0: float, y1: float, out: float = 0.0) -> void:
	var dir: Vector2 = (b - a).normalized()
	var n: Vector2 = Vector2(dir.y, -dir.x)
	var mid: Vector2 = (a + b) * 0.5 + n * (WALL_T * 0.5 + out)
	var size: Vector3 = Vector3(a.distance_to(b) + WALL_T * 0.9, y1 - y0, WALL_T)
	_box(room, size, Vector3(mid.x, (y0 + y1) * 0.5, mid.y), atan2(-dir.y, dir.x), _wall_mat)


func _box(room: Node3D, size: Vector3, pos: Vector3, yaw: float, mat: Material) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	body.rotation.y = yaw
	var cs: CollisionShape3D = CollisionShape3D.new()
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)
	room.add_child(body)
	return body


## Door model in the gap, wall filling the sides and the space up to the ceiling.
func _doorway(room: Node3D, a: Vector2, b: Vector2, height: float, model: StringName, is_double: bool) -> DungeonDoor:
	var dir: Vector2 = (b - a).normalized()
	var mid: Vector2 = (a + b) * 0.5
	var door: DungeonDoor = DungeonDoor.new()
	door.position = Vector3(mid.x, 0.0, mid.y)
	door.rotation.y = atan2(-dir.y, dir.x)
	room.add_child(door)
	door.setup(model, is_double)
	var span: float = a.distance_to(b)
	var side: float = (span - door.door_width) * 0.5
	if side > 0.15:
		_wall(room, a, a + dir * side, 0.0, height)
		_wall(room, b - dir * side, b, 0.0, height)
	_wall(room, a, b, minf(door.door_height, height - 0.5), height)
	return door


## Jagged, half-fallen wall: uneven stubs with rock wall behind and rubble inside.
func _broken_wall(room: Node3D, a: Vector2, b: Vector2, height: float) -> void:
	var pieces: int = 3
	var dir: Vector2 = (b - a).normalized()
	var n: Vector2 = Vector2(dir.y, -dir.x)
	var span_len: float = a.distance_to(b)
	for k: int in pieces:
		var p0: Vector2 = a + dir * span_len * float(k) / pieces
		var p1: Vector2 = a + dir * span_len * float(k + 1) / pieces
		_wall(room, p0, p1, 0.0, height * _rng.randf_range(0.35, 0.8))
	_wall(room, a - dir * 1.5, b + dir * 1.5, 0.0, height, BACKING_GAP_M)
	# Roof and floor over the gap behind the stubs (no sky through the crack).
	var back_mid: Vector2 = (a + b) * 0.5 + n * (BACKING_GAP_M + WALL_T) * 0.5
	var slab: Vector3 = Vector3(span_len + 3.0, 0.6, BACKING_GAP_M + WALL_T * 2.0)
	_box(room, slab, Vector3(back_mid.x, height + 0.3, back_mid.y), atan2(-dir.y, dir.x), _wall_mat)
	_box(room, slab, Vector3(back_mid.x, -0.3, back_mid.y), atan2(-dir.y, dir.x), _floor_mat)
	var mid: Vector2 = (a + b) * 0.5 - n * 1.4
	_prop(room, RUIN_RUBBLE[_rng.randi() % RUIN_RUBBLE.size()], _rng.randf_range(1.0, 1.8), Vector3(mid.x, 0.0, mid.y), _rng.randf() * TAU, true)


func _pick_cache_edge(pts: Array[Dictionary]) -> int:
	var options: Array[int] = []
	for i: int in pts.size():
		var a: Vector2 = pts[i]["p"]
		var b: Vector2 = pts[(i + 1) % pts.size()]["p"]
		if not DungeonRoomShape.is_door_edge(pts, i) and a.distance_to(b) >= CACHE_GAP_M + 2.0:
			options.append(i)
	return options[_rng.randi() % options.size()] if not options.is_empty() else -1


## A cracked section (heavy attack breaks it) hiding a small niche with a chest.
func _cache(room: Node3D, a: Vector2, b: Vector2, height: float, index: int) -> void:
	var dir: Vector2 = (b - a).normalized()
	var mid: Vector2 = (a + b) * 0.5
	var half: float = CACHE_GAP_M * 0.5
	_wall(room, a, mid - dir * half, 0.0, height)
	_wall(room, mid + dir * half, b, 0.0, height)
	_wall(room, mid - dir * half, mid + dir * half, 3.0, height)
	var holder: Node3D = Node3D.new()
	holder.position = Vector3(mid.x, 0.0, mid.y)
	holder.rotation.y = atan2(-dir.y, dir.x)
	room.add_child(holder)
	var crack: Breakable = (load(BREAKABLE_SCENE) as PackedScene).instantiate() as Breakable
	crack.position = Vector3(0.0, 0.0, -WALL_T * 0.5)
	holder.add_child(crack)
	# Local frame: +X along the wall, +Z into the room, so the niche is towards -Z.
	var back: float = WALL_T + CACHE_DEPTH_M
	var c: float = -(WALL_T + CACHE_DEPTH_M * 0.5)
	_box(holder, Vector3(CACHE_GAP_M + 1.4, 1.0, CACHE_DEPTH_M + 0.4), Vector3(0, -0.5, c), 0.0, _floor_mat)
	_box(holder, Vector3(CACHE_GAP_M + 1.4, 3.6, 0.8), Vector3(0, 1.8, -back), 0.0, _wall_mat)
	_box(holder, Vector3(CACHE_GAP_M + 1.4, 0.6, CACHE_DEPTH_M + 0.4), Vector3(0, 3.3, c), 0.0, _wall_mat)
	for sx: float in [-1.0, 1.0]:
		_box(holder, Vector3(0.6, 3.6, CACHE_DEPTH_M + 0.4), Vector3(sx * (half + 0.4), 1.8, c), 0.0, _wall_mat)
	var chest: LootChest = LootChest.new()
	chest.chest_id = StringName("%s_cache_%d" % [chest_prefix, index])
	chest.kind = &"treasure"
	chest.level = level
	chest.persistent = false
	chest.position = Vector3(0.0, 0.0, c - 0.6)
	holder.add_child(chest)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.8, 0.45)
	glow.omni_range = 4.0
	glow.light_energy = 0.9
	glow.position = Vector3(0.0, 2.2, c)
	holder.add_child(glow)


func _lights(room: Node3D, pts: Array[Dictionary], spec: DungeonPlan.Room) -> void:
	var fill: OmniLight3D = OmniLight3D.new()
	fill.light_color = theme.tint.lightened(0.55)
	fill.omni_range = spec.radius * 1.7
	fill.light_energy = 0.55
	fill.omni_attenuation = 0.6
	fill.position = Vector3(0.0, spec.height * 0.7, 0.0)
	room.add_child(fill)
	var count: int = 3 if spec.kind == DungeonPlan.Kind.SIDE else 5
	var step: int = maxi(floori(float(pts.size()) / float(count)), 1)
	var placed: int = 0
	for i: int in range(_rng.randi() % step, pts.size(), step):
		if placed >= count or DungeonRoomShape.is_door_edge(pts, i):
			continue
		var a: Vector2 = pts[i]["p"]
		var b: Vector2 = pts[(i + 1) % pts.size()]["p"]
		var dir: Vector2 = (b - a).normalized()
		var at: Vector2 = (a + b) * 0.5 - Vector2(dir.y, -dir.x) * 1.3
		var lamp: DecorProp = DecorProp.new()
		lamp.kind = &"lantern"
		lamp.always_lit = true
		lamp.light_range_m = spec.radius * 0.8
		lamp.tint = Color(1.0, 0.62, 0.3).lerp(theme.tint, 0.25)
		lamp.seed_value = i
		lamp.position = Vector3(at.x, 0.0, at.y)
		room.add_child(lamp)
		placed += 1


func _dress(room: Node3D, spec: DungeonPlan.Room, door_angles: Array[float]) -> void:
	var r: float = spec.radius
	match spec.style:
		&"hall":
			var ring: int = 8 if r >= 15.0 else 6
			var at_r: float = r * (0.74 if spec.kind == DungeonPlan.Kind.BOSS else 0.62)
			for i: int in ring:
				var a: float = TAU * (float(i) + 0.5) / float(ring)
				var p: Vector3 = Vector3(cos(a) * at_r, spec.height * 0.5, sin(a) * at_r)
				if not _clear_of_doors(p, DOOR_CLEAR_M * 0.7):
					continue
				theme.dress_pillar(_box(room, Vector3(1.6, spec.height, 1.6), p, 0.0, _wall_mat), spec.height)
		&"cave":
			for _i: int in _rng.randi_range(5, 8):
				var a2: float = _free_angle(door_angles, 0.45)
				var dist: float = r * _rng.randf_range(0.72, 0.86)
				var id: StringName = CAVE_ROCKS[_rng.randi() % CAVE_ROCKS.size()]
				_prop(room, id, _rng.randf_range(1.6, 5.5), Vector3(cos(a2) * dist, 0.0, sin(a2) * dist), _rng.randf() * TAU, true)
		_:
			for _i: int in _rng.randi_range(3, 5):
				var a3: float = _free_angle(door_angles, 0.45)
				var dist2: float = r * _rng.randf_range(0.65, 0.82)
				var at: Vector3 = Vector3(cos(a3) * dist2, 0.0, sin(a3) * dist2)
				if not _clear_of_doors(at, DOOR_CLEAR_M):
					continue
				if _rng.randf() < 0.4:
					theme.dress_pillar(_box(room, Vector3(1.4, 2.6, 1.4), at + Vector3.UP * 1.3, 0.0, _wall_mat), 2.6)
				else:
					_prop(room, RUIN_RUBBLE[_rng.randi() % RUIN_RUBBLE.size()], _rng.randf_range(1.0, 2.0), at, _rng.randf() * TAU, true)
	if spec.kind == DungeonPlan.Kind.SIDE:
		_treasure_shrine(room, spec, door_angles)
	elif spec.kind == DungeonPlan.Kind.FIGHT and _rng.randf() < 0.45:
		var a4: float = _free_angle(door_angles, 0.6)
		var sp: Vector3 = Vector3(cos(a4), 0.0, sin(a4)) * r * 0.78
		_prop(room, &"dungeon_statue", _rng.randf_range(3.0, 4.2), sp, atan2(sp.x, sp.z) + PI, true)


## Dead-end room: an ornate chest, a glowing relic and a guardian statue.
func _treasure_shrine(room: Node3D, spec: DungeonPlan.Room, door_angles: Array[float]) -> void:
	var back: Vector3 = Vector3(0.0, 0.0, -spec.radius * 0.45)
	var chest: LootChest = LootChest.new()
	chest.chest_id = StringName("%s_side_%d" % [chest_prefix, spec.seed_value])
	chest.kind = &"treasure"
	chest.level = level + 1
	chest.persistent = false
	chest.position = back
	room.add_child(chest)
	var a: float = _free_angle(door_angles, 0.6)
	var at: Vector3 = Vector3(cos(a), 0.0, sin(a)) * spec.radius * 0.6
	_prop(room, &"rock_pile", 1.2, at, 0.0, true)
	_prop(room, &"dungeon_relic_gem", 0.9, at + Vector3.UP * 1.1, _rng.randf() * TAU, false)
	var glow: OmniLight3D = OmniLight3D.new()
	glow.light_color = Color(0.4, 1.0, 0.6)
	glow.omni_range = 5.0
	glow.light_energy = 1.2
	glow.position = at + Vector3.UP * 1.8
	room.add_child(glow)
	_prop(room, &"dungeon_statue", 3.4, back + Vector3(2.8, 0.0, -1.0), 0.0, true)


## A random angle around the room that keeps clear of the doors.
func _free_angle(door_angles: Array[float], clearance: float) -> float:
	var a: float = 0.0
	for _attempt: int in 12:
		a = _rng.randf() * TAU - PI
		var ok: bool = true
		for d: float in door_angles:
			if absf(angle_difference(a, d)) < clearance:
				ok = false
		if ok:
			return a
	return a


func _clear_of_doors(pos: Vector3, clearance: float) -> bool:
	for spot: Vector2 in _door_spots:
		if spot.distance_to(Vector2(pos.x, pos.z)) < clearance:
			return false
	return true


func _prop(room: Node3D, id: StringName, height: float, pos: Vector3, yaw: float, collide: bool) -> void:
	if collide and not _clear_of_doors(pos, DOOR_CLEAR_M):
		return
	var holder: Node3D = StaticBody3D.new() if collide else Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	room.add_child(holder)
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


func _spawn_points(pts: Array[Dictionary], radius: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for _attempt: int in 40:
		if out.size() >= 6:
			break
		var a: float = _rng.randf() * TAU
		var p: Vector2 = Vector2(cos(a), sin(a)) * radius * _rng.randf_range(0.2, 0.55)
		if DungeonRoomShape.contains(pts, p):
			out.append(Vector3(p.x, 0.3, p.y))
	if out.is_empty():
		out.append(Vector3(0.0, 0.3, 0.0))
	return out
