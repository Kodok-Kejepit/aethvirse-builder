class_name DungeonChallenges
extends Node
## Room challenges of a Gate dungeon (owner: more than just monsters): an elite guardian,
## a timed clear with a chest for the quick, fire vents in the floor, lights out.

const TRAP_COUNT: Vector2i = Vector2i(3, 5)

var _dungeon: GateDungeon


func _init(dungeon: GateDungeon) -> void:
	_dungeon = dungeon
	name = "Challenges"


## Elites are swapped in now; traps / darkness / the timed reward hang on the room's
## start and clear.
func setup(room: GateRoom, index: int) -> void:
	match room.challenge:
		&"elite":
			if not room.enemies.is_empty():
				var guard: EnemyData = room.enemies[0].duplicate() as EnemyData
				guard.tier = EnemyScaling.Tier.ELITE
				guard.level += 2
				room.enemies[0] = guard
				room.started.connect(func() -> void: Codex.notify(tr(&"CHALLENGE_ELITE"), &"warning"))
		&"timed":
			room.time_limit_s = 20.0 + 7.0 * float(room.enemies.size())
			room.challenge_done.connect(func(success: bool) -> void: _timed_result(index, success))
		&"traps":
			room.started.connect(func() -> void: _arm_traps(index, true))
			room.cleared.connect(func() -> void: _arm_traps(index, false))
		&"dark":
			room.started.connect(func() -> void: _darken(index, true))
			room.cleared.connect(func() -> void: _darken(index, false))


func _arm_traps(index: int, on: bool) -> void:
	if on:
		Codex.notify(tr(&"CHALLENGE_TRAPS"), &"warning")
		var c: Vector2 = _dungeon.plan.center(index)
		var r: float = _dungeon.plan.rooms[index].radius
		var count: int = _dungeon.rng.randi_range(TRAP_COUNT.x, TRAP_COUNT.y)
		for _try: int in 30:
			if count <= 0:
				break
			var p: Vector2 = c + Vector2.from_angle(_dungeon.rng.randf() * TAU) * r * _dungeon.rng.randf_range(0.15, 0.7)
			if _dungeon.field.value_at(p) < 0.35:
				continue
			var trap: DungeonTrap = DungeonTrap.new()
			trap.position = Vector3(p.x, 0.0, p.y)
			trap.armed = true
			trap.add_to_group(StringName("traps_%d" % index))
			_dungeon.add_child(trap)
			count -= 1
		return
	for trap: Node in get_tree().get_nodes_in_group(StringName("traps_%d" % index)):
		trap.queue_free()


## Lights out in this room while it fights; only the hero's own light is left.
func _darken(index: int, dark: bool) -> void:
	if dark:
		Codex.notify(tr(&"CHALLENGE_DARK"), &"warning")
	for node: Node in _dungeon._groups[index].find_children("*", "", true, false):
		if node is DecorProp:
			(node as DecorProp).snuffed = dark
		elif node is OmniLight3D and not (node.get_parent() is DecorProp):
			(node as OmniLight3D).visible = not dark


func _timed_result(index: int, success: bool) -> void:
	if not success:
		Codex.notify(tr(&"CHALLENGE_TIMED_LOST"), &"info")
		return
	Codex.notify(tr(&"CHALLENGE_TIMED_WON"), &"reward")
	var c: Vector2 = _dungeon.plan.center(index)
	var chest: LootChest = LootChest.new()
	chest.chest_id = StringName("%s_trial_%d" % [_dungeon.session.gate.id, index])
	chest.kind = &"treasure"
	chest.level = GameState.progression.level if GameState.progression != null else 1
	chest.persistent = false
	chest.position = Vector3(c.x, 0.0, c.y)
	_dungeon.add_child(chest)
