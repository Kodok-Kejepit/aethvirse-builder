class_name DungeonPlan
extends RefCounted
## Pure layout of a Gate run as a graph of rooms joined by doors. A main path runs from
## the start room to the boss; side branches end in dead-end treasure rooms; some fight
## rooms hide a cracked-wall cache; one room may hold the sealed Double Gate door.
## Each room gets its own shape style, size and ceiling height. Seeded: same Gate + day
## gives the same dungeon.

enum Kind { START, FIGHT, SIDE, BOSS }

const STYLES: Array[StringName] = [&"cave", &"hall", &"ruin"]
const RADIUS_RANGE: Vector2 = Vector2(13.0, 18.0)
const BOSS_RADIUS: float = 22.0
const SIDE_RADIUS_RANGE: Vector2 = Vector2(10.0, 12.0)
const HEIGHT_RANGE: Vector2 = Vector2(8.0, 12.0)
const CACHE_CHANCE: float = 0.3
## Door directions are angles around the room (0 = +X, PI/2 = +Z). Entrances face +Z.
const ENTRY_ANGLE: float = PI * 0.5
## Exits spread over the far half of the room.
const EXIT_ARC: Vector2 = Vector2(-PI * 0.85, -PI * 0.15)


class Room:
	var kind: Kind = Kind.FIGHT
	var style: StringName = &"cave"
	var radius: float = 14.0
	var height: float = 9.0
	## [{"to": room index, "angle": float}]; the first door of every room but the start
	## leads back to where the player came from.
	var doors: Array[Dictionary] = []
	var has_cache: bool = false
	var has_double_door: bool = false
	var enemy_count: int = 0
	var seed_value: int = 0


var rooms: Array[Room] = []
var boss_index: int = -1


## main_rooms: rooms before the boss (start included). double_at: main-path index that
## holds the Double Gate door, or -1.
static func make(main_rooms: int, per_room: int, seed_value: int, double_at: int = -1) -> DungeonPlan:
	var plan: DungeonPlan = DungeonPlan.new()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var count: int = maxi(main_rooms, 1)
	for i: int in count:
		var kind: Kind = Kind.START if i == 0 else Kind.FIGHT
		var room: Room = plan._add(kind, rng)
		room.enemy_count = 0 if i == 0 else per_room
		room.has_cache = i > 0 and rng.randf() < CACHE_CHANCE
		room.has_double_door = i == double_at and i > 0
		if i > 0:
			plan._link(i - 1, i)
	var boss: Room = plan._add(Kind.BOSS, rng)
	boss.enemy_count = 1
	plan.boss_index = plan.rooms.size() - 1
	plan._link(count - 1, plan.boss_index)
	# Side branches: dead ends off the main path (never the start or the boss).
	var branches: int = clampi(floori(float(count) / 3.0), 1 if count > 2 else 0, 3)
	for b: int in branches:
		var from: int = 1 + rng.randi() % maxi(count - 1, 1)
		var side: Room = plan._add(Kind.SIDE, rng)
		side.enemy_count = maxi(floori(float(per_room) / 2.0), 1) if rng.randf() < 0.5 else 0
		plan._link(from, plan.rooms.size() - 1)
	plan._spread_exits(rng)
	return plan


func _add(kind: Kind, rng: RandomNumberGenerator) -> Room:
	var room: Room = Room.new()
	room.kind = kind
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


## Joins a parent room to a child: the child's first door leads back.
func _link(parent: int, child: int) -> void:
	rooms[parent].doors.append({"to": child, "angle": 0.0})
	rooms[child].doors.push_front({"to": parent, "angle": ENTRY_ANGLE})


## Exits (doors after the way back) get evenly spread angles with a little jitter.
func _spread_exits(rng: RandomNumberGenerator) -> void:
	for room: Room in rooms:
		var first_exit: int = 0 if room.kind == Kind.START else 1
		var exits: int = room.doors.size() - first_exit
		for e: int in exits:
			var t: float = (float(e) + 0.5) / float(exits)
			var a: float = lerpf(EXIT_ARC.x, EXIT_ARC.y, t) + rng.randf_range(-0.12, 0.12)
			if exits == 1:
				a = -PI * 0.5 + rng.randf_range(-0.35, 0.35)
			room.doors[first_exit + e]["angle"] = a


## Index of the door in room `to` that leads back to room `from`.
func door_back(from: int, to: int) -> int:
	var doors: Array[Dictionary] = rooms[to].doors
	for i: int in doors.size():
		var leads_to: int = doors[i]["to"]
		if leads_to == from:
			return i
	return -1


## Every room can be reached from the start (sanity check for tests).
func all_reachable() -> bool:
	var seen: Dictionary = {0: true}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var at: int = queue.pop_back()
		for door: Dictionary in rooms[at].doors:
			var to: int = door["to"]
			if not seen.has(to):
				seen[to] = true
				queue.append(to)
	return seen.size() == rooms.size()
