class_name DungeonPlan
extends RefCounted
## Pure layout of a Gate run: rooms on a grid (one room per 64 m cell) joined by links.
## A main path runs from the start room to the boss; side branches end in dead-end
## treasure rooms. Links are a door (push it open), an open tunnel, or a wide breach.
## Seeded: same Gate + day gives the same dungeon.

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


var rooms: Array[Room] = []
## [{"a": room index, "b": room index, "kind": Link}]; b is the room further from the start.
var links: Array[Dictionary] = []
var boss_index: int = -1


## main_rooms: rooms before the boss (start included). double_at: main-path index that
## holds the Double Gate door, or -1.
static func make(main_rooms: int, per_room: int, seed_value: int, double_at: int = -1) -> DungeonPlan:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = maxi(main_rooms, 1)
	var cells: Array[Vector2i] = _main_path(count + 1, rng)
	var plan: DungeonPlan = DungeonPlan.new()
	for i: int in count:
		var room: Room = plan._add(Kind.START if i == 0 else Kind.FIGHT, cells[i], rng)
		room.enemy_count = 0 if i == 0 else per_room
		room.has_cache = i > 0 and rng.randf() < CACHE_CHANCE
		room.has_double_door = i == double_at and i > 0
		if i > 0:
			plan._link(i - 1, i, plan._roll_link(rng))
	var boss: Room = plan._add(Kind.BOSS, cells[count], rng)
	boss.enemy_count = 1
	plan.boss_index = plan.rooms.size() - 1
	plan._link(count - 1, plan.boss_index, Link.DOOR)
	plan._add_branches(count, per_room, rng)
	return plan


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


func _add_branches(count: int, per_room: int, rng: RandomNumberGenerator) -> void:
	var branches: int = clampi(floori(float(count) / 3.0), 1 if count > 2 else 0, 3)
	for _b: int in branches:
		for _try: int in 10:
			var from: int = 1 + rng.randi() % maxi(count - 1, 1)
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
	room.style = STYLES[rng.randi() % STYLES.size()]
	match kind:
		Kind.BOSS:
			room.radius = BOSS_RADIUS
			room.style = &"hall"
			room.height = HEIGHT_RANGE.y + 2.0
		Kind.SIDE:
			room.radius = rng.randf_range(SIDE_RADIUS_RANGE.x, SIDE_RADIUS_RANGE.y)
			room.height = HEIGHT_RANGE.x
		_:
			room.radius = rng.randf_range(RADIUS_RANGE.x, RADIUS_RANGE.y)
			room.height = rng.randf_range(HEIGHT_RANGE.x, HEIGHT_RANGE.y)
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
