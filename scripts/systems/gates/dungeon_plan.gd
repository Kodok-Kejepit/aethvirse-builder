class_name DungeonPlan
extends RefCounted
## Pure layout of a Gate run: rooms on a grid (one room per 64 m cell) joined by links.
## A main path runs from the start room to the boss; side branches end in dead-end
## treasure rooms. Links are a door (push it open), an open tunnel, or a wide breach.
## Seeded: same Gate + day gives the same dungeon.
## Map shapes (LAYOUTS): winding path, square spiral, a ring of rooms (two ways round, the
## boss off the far side), a fork (two routes that meet before the boss) and a hub (a great
## hall with spokes: the boss behind one, treasure at the end of the others).

enum Kind { START, FIGHT, SIDE, BOSS }
enum Link { DOOR, OPEN, BREACH }

const STYLES: Array[StringName] = [&"cave", &"hall", &"ruin"]
const CELL_M: float = 64.0
const RADIUS_RANGE: Vector2 = Vector2(13.0, 18.0)
const BOSS_RADIUS: float = 22.0
const SIDE_RADIUS_RANGE: Vector2 = Vector2(9.0, 11.0)
const HEIGHT_RANGE: Vector2 = Vector2(8.0, 12.0)
const CACHE_CHANCE: float = 0.3
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const WALK_ATTEMPTS: int = 60
const LAYOUTS: Array[StringName] = [&"winding", &"spiral", &"loop", &"fork", &"hub"]
## Rooms (start included) a shape needs; shorter runs fall back to the winding path.
const LAYOUT_MIN_ROOMS: Dictionary[StringName, int] = {&"spiral": 3, &"loop": 4, &"fork": 6, &"hub": 4}


class Room:
	var kind: Kind = Kind.FIGHT
	var style: StringName = &"cave"
	var cell: Vector2i = Vector2i.ZERO
	var radius: float = 14.0
	var height: float = 9.0
	var has_cache: bool = false
	var has_double_door: bool = false
	var enemy_count: int = 0
	var seed_value: int = 0
	## Room challenge (DungeonArchetype.CHALLENGES) or empty.
	var challenge: StringName = &""


var rooms: Array[Room] = []
## [{"a": room index, "b": room index, "kind": Link}]; b is the room further from the start.
var links: Array[Dictionary] = []
var boss_index: int = -1
var archetype: StringName = &"ruins"
var layout: StringName = &"winding"


## main_rooms: rooms before the boss (start included). double_at: main-path index that
## holds the Double Gate door, or -1.
static func make(main_rooms: int, per_room: int, seed_value: int, double_at: int = -1, kind_of_place: StringName = &"ruins",
		shape: StringName = &"") -> DungeonPlan:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = maxi(main_rooms, 1)
	var plan: DungeonPlan = DungeonPlan.new()
	plan.archetype = kind_of_place
	# The shape has its own dice so a winding run stays the same dungeon as before.
	plan.layout = shape if shape != &"" else DungeonArchetype.roll_layout(kind_of_place, seed_value)
	if count < LAYOUT_MIN_ROOMS.get(plan.layout, 1):
		plan.layout = &"winding"
	match plan.layout:
		&"spiral":
			plan._chain(_spiral(count + 1), count, per_room, double_at, rng)
		&"loop":
			plan._loop(count, per_room, double_at, rng)
		&"fork":
			plan._fork(count, per_room, double_at, rng)
		&"hub":
			plan._hub(count, per_room, double_at, rng)
		_:
			plan._chain(_main_path(count + 1, rng), count, per_room, double_at, rng)
	if plan.layout != &"hub":
		plan._add_branches(plan.boss_index, per_room, rng)
	return plan


## Main rooms along `cells` (start first), the boss on the last cell.
func _chain(cells: Array[Vector2i], count: int, per_room: int, double_at: int, rng: RandomNumberGenerator) -> void:
	for i: int in count:
		_fight_room(Kind.START if i == 0 else Kind.FIGHT, cells[i], i, per_room, double_at, rng)
		if i > 0:
			_link(i - 1, i, _roll_link(rng))
	_boss(cells[count], count - 1, rng)


func _fight_room(kind: Kind, cell: Vector2i, i: int, per_room: int, double_at: int, rng: RandomNumberGenerator) -> Room:
	var room: Room = _add(kind, cell, rng)
	room.enemy_count = 0 if i == 0 else per_room
	room.has_cache = i > 0 and rng.randf() < CACHE_CHANCE
	room.has_double_door = i == double_at and i > 0
	if i > 0 and rng.randf() < DungeonArchetype.CHALLENGE_CHANCE:
		room.challenge = DungeonArchetype.CHALLENGES[rng.randi() % DungeonArchetype.CHALLENGES.size()]
	return room


func _boss(cell: Vector2i, from: int, rng: RandomNumberGenerator) -> void:
	var boss: Room = _add(Kind.BOSS, cell, rng)
	boss.enemy_count = 1
	boss_index = rooms.size() - 1
	_link(from, boss_index, Link.DOOR)


## Square spiral out from the start: right 1, down 1, left 2, up 2, right 3, ...
static func _spiral(length: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var at: Vector2i = Vector2i.ZERO
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
	var leg: int = 1
	var d: int = 0
	while cells.size() < length:
		for _twice: int in 2:
			for _step: int in leg:
				if cells.size() >= length:
					return cells
				at += dirs[d]
				cells.append(at)
			d = (d + 1) % 4
		leg += 1
	return cells


## A ring of rooms around a rectangle (the last one joins the start again, so there are two
## ways round); the boss waits outside the ring behind the room furthest from the start.
func _loop(count: int, per_room: int, double_at: int, rng: RandomNumberGenerator) -> void:
	var w: int = 2
	var h: int = 2
	while 2 * (w + h) - 4 < count:
		if w <= h:
			w += 1
		else:
			h += 1
	var ring: Array[Vector2i] = []
	for x: int in w:
		ring.append(Vector2i(x, 0))
	for y: int in range(1, h):
		ring.append(Vector2i(w - 1, y))
	for x: int in range(w - 2, -1, -1):
		ring.append(Vector2i(x, h - 1))
	for y: int in range(h - 2, 0, -1):
		ring.append(Vector2i(0, y))
	for i: int in ring.size():
		_fight_room(Kind.START if i == 0 else Kind.FIGHT, ring[i], i, per_room, double_at, rng)
		if i > 0:
			_link(i - 1, i, _roll_link(rng))
	_link(ring.size() - 1, 0, Link.OPEN)
	var far: int = floori(ring.size() / 2.0)
	# Every ring room is on the rectangle's edge: step out of the rectangle from it.
	var out: Vector2i = ring[far] + Vector2i(0, 1)
	for d: Vector2i in DIRS:
		var c: Vector2i = ring[far] + d
		if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
			out = c
			break
	_boss(out, far, rng)


## Two routes from the start (north and south rows) that meet in one hall before the boss.
func _fork(count: int, per_room: int, double_at: int, rng: RandomNumberGenerator) -> void:
	var k: int = maxi(floori((count - 2) / 2.0), 2)
	var i: int = 0
	_fight_room(Kind.START, Vector2i.ZERO, i, per_room, double_at, rng)
	var ends: Array[int] = []
	for row: int in [-1, 1]:
		var prev: int = 0
		for step: int in k:
			i += 1
			_fight_room(Kind.FIGHT, Vector2i(step, row), i, per_room, double_at, rng)
			_link(prev, rooms.size() - 1, _roll_link(rng))
			prev = rooms.size() - 1
		ends.append(prev)
	i += 1
	_fight_room(Kind.FIGHT, Vector2i(k - 1, 0), i, per_room, double_at, rng)
	var meet: int = rooms.size() - 1
	for e: int in ends:
		_link(e, meet, Link.OPEN)
	_boss(Vector2i(k, 0), meet, rng)


## A great hall next to the start with spokes north, south and east: the boss sits at the end
## of the east spoke, the other spokes end in treasure rooms.
func _hub(count: int, per_room: int, double_at: int, rng: RandomNumberGenerator) -> void:
	_fight_room(Kind.START, Vector2i.ZERO, 0, per_room, double_at, rng)
	var hub: Room = _fight_room(Kind.FIGHT, Vector2i(1, 0), 1, per_room + 1, double_at, rng)
	hub.radius = BOSS_RADIUS * 0.9
	hub.style = &"hall"
	_link(0, 1, Link.DOOR)
	var left: int = maxi(count - 2, 0)
	var east: int = ceili(float(left) / 2.0)
	var north: int = floori((left - east) / 2.0)
	var south: int = left - east - north
	var i: int = 2
	for spoke: Array in [[Vector2i(0, -1), north], [Vector2i(0, 1), south]]:
		var dir: Vector2i = spoke[0]
		var length: int = spoke[1]
		var prev: int = 1
		for step: int in length:
			_fight_room(Kind.FIGHT, Vector2i(1, 0) + dir * (step + 1), i, per_room, double_at, rng)
			i += 1
			_link(prev, rooms.size() - 1, _roll_link(rng))
			prev = rooms.size() - 1
		var side: Room = _add(Kind.SIDE, Vector2i(1, 0) + dir * (length + 1), rng)
		side.enemy_count = 0
		_link(prev, rooms.size() - 1, Link.DOOR)
	var prev_e: int = 1
	for step: int in east:
		_fight_room(Kind.FIGHT, Vector2i(2 + step, 0), i, per_room, double_at, rng)
		i += 1
		_link(prev_e, rooms.size() - 1, _roll_link(rng))
		prev_e = rooms.size() - 1
	_boss(Vector2i(2 + east, 0), prev_e, rng)


## Self-avoiding walk on the grid (restarts until it fits).
static func _main_path(length: int, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	for _attempt: int in WALK_ATTEMPTS:
		cells = [Vector2i.ZERO]
		while cells.size() < length:
			var options: Array[Vector2i] = []
			for d: Vector2i in DIRS:
				var next: Vector2i = cells[cells.size() - 1] + d
				if not next in cells:
					options.append(next)
			if options.is_empty():
				break
			cells.append(options[rng.randi() % options.size()])
		if cells.size() == length:
			return cells
	# Fallback: a straight line always fits.
	cells.clear()
	for i: int in length:
		cells.append(Vector2i(i, 0))
	return cells


func _add_branches(boss: int, per_room: int, rng: RandomNumberGenerator) -> void:
	var fights: Array[int] = []
	for i: int in rooms.size():
		if rooms[i].kind == Kind.FIGHT:
			fights.append(i)
	if fights.is_empty() or boss < 0:
		return
	var count: int = fights.size() + 1
	var branches: int = clampi(floori(float(count) / 3.0), 1 if count > 2 else 0, 3)
	for _b: int in branches:
		for _try: int in 10:
			var from: int = fights[rng.randi() % fights.size()]
			var free: Array[Vector2i] = _free_neighbours(rooms[from].cell)
			if free.is_empty():
				continue
			var side: Room = _add(Kind.SIDE, free[rng.randi() % free.size()], rng)
			side.enemy_count = maxi(floori(float(per_room) / 2.0), 1) if rng.randf() < 0.5 else 0
			_link(from, rooms.size() - 1, Link.DOOR if rng.randf() < 0.5 else Link.OPEN)
			break


func _free_neighbours(cell: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d: Vector2i in DIRS:
		var next: Vector2i = cell + d
		var used: bool = false
		for room: Room in rooms:
			if room.cell == next:
				used = true
		if not used:
			out.append(next)
	return out


func _roll_link(rng: RandomNumberGenerator) -> Link:
	var r: float = rng.randf()
	if r < 0.45:
		return Link.DOOR
	return Link.OPEN if r < 0.8 else Link.BREACH


func _add(kind: Kind, cell: Vector2i, rng: RandomNumberGenerator) -> Room:
	var room: Room = Room.new()
	room.kind = kind
	room.cell = cell
	room.seed_value = rng.randi()
	room.style = DungeonArchetype.roll_style(archetype, rng)
	var spec: Dictionary = DungeonArchetype.spec(archetype)
	var size_k: float = spec["radius"]
	var roof_k: float = spec["roof"]
	match kind:
		Kind.BOSS:
			room.radius = BOSS_RADIUS
			room.style = &"hall"
			room.height = HEIGHT_RANGE.y + 2.0
		Kind.SIDE:
			room.radius = rng.randf_range(SIDE_RADIUS_RANGE.x, SIDE_RADIUS_RANGE.y)
			room.height = HEIGHT_RANGE.x
		_:
			room.radius = rng.randf_range(RADIUS_RANGE.x, RADIUS_RANGE.y) * size_k
			room.height = rng.randf_range(HEIGHT_RANGE.x, HEIGHT_RANGE.y) * roof_k
	rooms.append(room)
	return room


func _link(a: int, b: int, kind: Link) -> void:
	links.append({"a": a, "b": b, "kind": kind})


## World-space (x, z) centre of a room.
func center(index: int) -> Vector2:
	return Vector2(rooms[index].cell) * CELL_M


func neighbours(index: int) -> Array[int]:
	var out: Array[int] = []
	for link: Dictionary in links:
		var a: int = link["a"]
		var b: int = link["b"]
		if a == index:
			out.append(b)
		elif b == index:
			out.append(a)
	return out


## Every room can be reached from the start (sanity check for tests).
func all_reachable() -> bool:
	var seen: Dictionary = {0: true}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var at: int = queue.pop_back()
		for to: int in neighbours(at):
			if not seen.has(to):
				seen[to] = true
				queue.append(to)
	return seen.size() == rooms.size()
