class_name GateDungeon
extends Node3D
## Builds a Gate instance from GameState.gate_session as one connected cave map: abstract
## rooms joined by winding tunnels (DungeonPlan -> DungeonField -> DungeonMesher), some
## through doors you push open, some open, some a wide breach. A room seals its mouths
## with red wards while it fights. Side rooms hold treasure, cracked walls hide caches,
## and some runs have the winged Double Gate door (needs a Gate Key). Size and enemy
## levels scale with the player (GateLayout). Handles rules, rewards and the exit.

const SCENE: String = "res://scenes/world/gates/gate_dungeon.tscn"
const EXIT_PORTAL_SCENE: String = "res://scenes/world/gates/exit_portal.tscn"
const DOUBLE_DOOR_MODEL: StringName = &"door_winged"
const VISIBILITY_TICK_S: float = 0.25
## Red Gates: harder monsters, triple gold (no way out but forward).
const RED_LEVEL_BONUS: int = 5
const RED_REWARD_MULT: int = 3

@export var fallback_gate: GateData

@onready var player: Player = %Player

var session: GateSession
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var plan: DungeonPlan
var field: DungeonField
var _theme: GateTheme
var _rooms: Array[GateRoom] = []
## Per room: everything drawn for it (meshes, lights, props), shown near the player.
var _groups: Array[Node3D] = []
var _current: int = -1
var _tick: float = 0.0
## Today's kind of place (DungeonArchetype).
var archetype: StringName = &"ruins"
var _challenges: DungeonChallenges


func _ready() -> void:
	session = GameState.gate_session
	if session == null:
		session = GateSession.new()
		session.gate = fallback_gate
		GameState.gate_session = session
	rng.seed = session.gate.seed_value if session.gate.seed_value != 0 else hash(session.gate.id)
	AudioManager.set_area_music(&"gate")
	add_child(Vfx.new())
	AudioManager.play_sfx(&"gate_enter")
	_theme = GateTheme.new(session.gate.rank, session.gate.has_rule(&"red"))
	_dim_sun()
	var world_env: WorldEnvironment = get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if world_env != null:
		Settings.apply_effects(world_env.environment)
	_build()
	Codex.notify(tr(&"CODEX_MSG_GATE_ENTERED") % [GateData.Rank.keys()[session.gate.rank], tr(session.gate.display_name)], &"warning")
	for rule: StringName in session.gate.rules:
		Codex.notify(tr(StringName("GATE_RULE_" + String(rule).to_upper())), &"anomaly")


func _build() -> void:
	var gate: GateData = session.gate
	var level: int = GameState.progression.level if GameState.progression != null else 1
	var day: int = GameState.clock.day() if GameState.clock != null else 1
	var main_rooms: int = GateLayout.room_count(gate, level)
	var per_room: int = GateLayout.enemies_per_room(gate, level)
	if gate.has_rule(&"red"):
		session.enemy_level_bonus = maxi(session.enemy_level_bonus, RED_LEVEL_BONUS)
	var double_at: int = -1
	if session.force_double or GateLayout.has_double_gate(gate, day):
		double_at = GateLayout.double_gate_room(main_rooms, day)
	archetype = DungeonArchetype.pick(gate.rank, gate.seed_value + day * 31)
	plan = DungeonPlan.make(main_rooms, per_room, rng.randi(), double_at, archetype)
	field = DungeonField.build(plan, rng.randi())
	_apply_archetype_look()
	_challenges = DungeonChallenges.new(self)
	add_child(_challenges)
	for i: int in plan.rooms.size():
		var group: Node3D = Node3D.new()
		group.name = "Room%d" % i
		add_child(group)
		_groups.append(group)
	var mesher: DungeonMesher = DungeonMesher.new(_theme, archetype)
	mesher.build(field, _groups)
	var dresser: DungeonDresser = DungeonDresser.new(_theme, field, plan)
	dresser.level = level
	dresser.chest_prefix = "%s_%d" % [gate.id, day]
	for i: int in plan.rooms.size():
		dresser.dress(i, _groups[i], mesher.wall_material)
		_rooms.append(_make_room(i, gate, level))
	for t: Dictionary in field.tunnels:
		var a: int = t["a"]
		dresser.dress_tunnel(_groups[a], t)
		_link_pieces(t, mesher.wall_material)
	for e: Dictionary in field.dead_ends:
		_double_door(e, mesher.wall_material)
	var start: Vector2 = plan.center(0)
	player.global_position = Vector3(start.x, 0.3, start.y)
	# Falling in battle without an altar sends you back to the start room.
	player.spawn_point = player.global_position
	player.last_safe_position = player.global_position
	EventBus.player_respawned.connect(_on_player_respawned)
	_update_visibility(true)
	# No way back out of a Double Gate: the exit only opens when its boss falls.


func _make_room(index: int, gate: GateData, level: int) -> GateRoom:
	var spec: DungeonPlan.Room = plan.rooms[index]
	var is_boss: bool = spec.kind == DungeonPlan.Kind.BOSS
	var room: GateRoom = BossRoom.new() if is_boss else GateRoom.new()
	var c: Vector2 = plan.center(index)
	room.position = Vector3(c.x, 0.0, c.y)
	room.size = Vector2.ONE * spec.radius * 2.4
	add_child(room)
	room.spawn_points = _spawn_points(index)
	if is_boss:
		var boss: EnemyData = _scaled(gate.boss, level)
		room.enemies.append(boss)
		room.cleared.connect(_on_boss_cleared)
		_hook_boss(room as BossRoom, boss, gate, level)
	else:
		for _e: int in spec.enemy_count:
			room.enemies.append(_scaled(gate.enemy_pool[rng.randi() % gate.enemy_pool.size()], level))
	room.challenge = spec.challenge if not is_boss else &""
	_challenges.setup(room, index)
	# The fight starts once the player is well inside (past the mouths and their wards).
	room.setup_trigger(Vector2.ONE * (spec.radius + 4.0))
	return room


## Fog colour of today's kind of place, and its name on the Codex.
func _apply_archetype_look() -> void:
	var spec: Dictionary = DungeonArchetype.spec(archetype)
	var env: WorldEnvironment = get_node_or_null(^"WorldEnvironment") as WorldEnvironment
	if env != null and env.environment != null:
		env.environment.fog_light_color = spec["fog"]
	var kind_name: StringName = spec["name"]
	Codex.notify(tr(&"CODEX_MSG_DUNGEON_KIND") % tr(kind_name), &"info")


func _spawn_points(index: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var c: Vector2 = plan.center(index)
	var r: float = plan.rooms[index].radius
	for _try: int in 60:
		if out.size() >= 6:
			break
		var p: Vector2 = c + Vector2.from_angle(rng.randf() * TAU) * r * rng.randf_range(0.2, 0.7)
		if field.room_value(index, p) > 0.25 and field.value_at(p) > 0.3:
			out.append(Vector3(p.x - c.x, 0.3, p.y - c.y))
	if out.is_empty():
		out.append(Vector3(0.0, 0.3, 0.0))
	return out


## Wards at both mouths of a tunnel, and its door when the link is a door.
func _link_pieces(t: Dictionary, wall_material: Material) -> void:
	var kind: DungeonPlan.Link = t["kind"]
	var width: float = t["width"]
	for end: String in ["a", "b"]:
		var room: int = t[end]
		var mouth: Vector2 = t["mouth_" + end]
		var dir: Vector2 = t["dir_" + end]
		var ward: DungeonWard = DungeonWard.new()
		ward.position = Vector3(mouth.x, 0.0, mouth.y)
		ward.rotation.y = atan2(dir.x, dir.y)
		add_child(ward)
		ward.setup(width * 2.0 + 2.5, field.roof_near(mouth, width + 1.5) + 0.5)
		_rooms[room].wards.append(ward)
	if kind == DungeonPlan.Link.DOOR:
		var mouth_b: Vector2 = t["mouth_b"]
		var dir_b: Vector2 = t["dir_b"]
		var door: DungeonDoor = DungeonDoor.new()
		# A little into the tunnel, facing the way the player comes from.
		var at: Vector2 = mouth_b + dir_b * 1.5
		door.position = Vector3(at.x, 0.0, at.y)
		door.rotation.y = atan2(dir_b.x, dir_b.y)
		add_child(door)
		door.setup(_theme.door_models[rng.randi() % _theme.door_models.size()], false)
		door.build_frame(wall_material, field.roof_near(at, DungeonDoor.HALF_WIDTH_M + 1.0))
		door.used.connect(_on_door_used)


func _double_door(e: Dictionary, wall_material: Material) -> void:
	var end_at: Vector2 = e["end"]
	var dir: Vector2 = e["dir"]
	var door: DungeonDoor = DungeonDoor.new()
	door.position = Vector3(end_at.x, 0.0, end_at.y)
	door.rotation.y = atan2(-dir.x, -dir.y)
	add_child(door)
	door.setup(DOUBLE_DOOR_MODEL, true)
	door.build_frame(wall_material, field.roof_near(end_at, DungeonDoor.HALF_WIDTH_M + 1.0))
	door.used.connect(_on_door_used)


func _hook_boss(room: BossRoom, boss: EnemyData, gate: GateData, level: int) -> void:
	var hook: Callable = func(enemy: Enemy) -> void:
		if enemy.data == boss:
			var phases: BossPhases = BossPhases.new()
			phases.add_data = _scaled(gate.enemy_pool[0], level) if not gate.enemy_pool.is_empty() else null
			enemy.add_child(phases)
			phases.attach(enemy)
	room.set_meta(&"spawn_hook", hook)


## Gate enemies keep up with the player (never far below their level).
func _scaled(data: EnemyData, player_level: int) -> EnemyData:
	var target: int = GateLayout.enemy_level(maxi(data.level, session.gate.level_floor), player_level, session.enemy_level_bonus)
	if target == data.level:
		return data
	var copy: EnemyData = data.duplicate() as EnemyData
	copy.level = target
	return copy


func _on_door_used(door: DungeonDoor) -> void:
	if door.is_double:
		door.open()
		Codex.anomaly(tr(&"CODEX_MSG_DOUBLE_HUM"), 0.1)
		get_tree().create_timer(DungeonDoor.OPEN_S).timeout.connect(func() -> void: ExitPortal.enter_double(get_tree()))
		return
	door.open()


func _on_player_respawned() -> void:
	_update_visibility(true)
	player.reset_physics_interpolation()
	player.camera_rig.snap_to(player.visual.rotation.y)


func _process(delta: float) -> void:
	_tick -= delta
	if _tick <= 0.0:
		_tick = VISIBILITY_TICK_S
		_update_visibility(false)


## Draws only the room the player is in and the rooms next to it.
func _update_visibility(force: bool) -> void:
	if field == null:
		return
	var here: int = field.room_at(Vector2(player.global_position.x, player.global_position.z))
	if here < 0 or (here == _current and not force):
		return
	_current = here
	var near: Array[int] = plan.neighbours(here)
	for i: int in _groups.size():
		_groups[i].visible = i == here or i in near


## Debug: stand in a room's centre (its fight starts as you arrive).
func debug_goto(index: int) -> void:
	if index < 0 or index >= _rooms.size():
		return
	var c: Vector2 = plan.center(index)
	player.global_position = Vector3(c.x, 0.3, c.y)
	player.velocity = Vector3.ZERO
	player.last_safe_position = player.global_position
	player.reset_physics_interpolation()
	player.camera_rig.snap_to(player.visual.rotation.y)
	_update_visibility(true)


## Debug: stand in the middle of a tunnel, looking along it towards room b.
func debug_tunnel(index: int) -> void:
	if index < 0 or index >= field.tunnels.size():
		return
	var points: PackedVector2Array = field.tunnels[index]["points"]
	var k: int = floori(float(points.size()) / 2.0)
	var at: Vector2 = points[k]
	var ahead: Vector2 = points[mini(k + 1, points.size() - 1)] - at
	player.global_position = Vector3(at.x, 0.3, at.y)
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = MovementMath.yaw_for_direction(Vector3(ahead.x, 0.0, ahead.y))
	player.reset_physics_interpolation()
	player.camera_rig.snap_to(player.visual.rotation.y)
	_update_visibility(true)


## Debug: stand in front of the first door (tunnel side), looking at it.
func debug_door() -> void:
	for t: Dictionary in field.tunnels:
		var kind: DungeonPlan.Link = t["kind"]
		if kind != DungeonPlan.Link.DOOR:
			continue
		var mouth: Vector2 = t["mouth_b"]
		var dir: Vector2 = t["dir_b"]
		var at: Vector2 = mouth + dir * 7.0
		player.global_position = Vector3(at.x, 0.3, at.y)
		player.velocity = Vector3.ZERO
		player.visual.rotation.y = MovementMath.yaw_for_direction(Vector3(-dir.x, 0.0, -dir.y))
		player.reset_physics_interpolation()
		player.camera_rig.snap_to(player.visual.rotation.y)
		_update_visibility(true)
		return


## Debug: clear the current room and jump to the next one.
func debug_next() -> void:
	var here: int = maxi(_current, 0)
	_rooms[here].enemies.clear()
	_rooms[here].start()
	for enemy: Node in get_children():
		if enemy is Enemy:
			enemy.queue_free()
	debug_goto(mini(here + 1, _rooms.size() - 1))


## Debug: every room shown, roofs hidden, the whole map from straight above.
func debug_overview() -> void:
	for g: Node3D in _groups:
		g.visible = true
	for node: Node in find_children("*", "StaticBody3D", true, false):
		if node.has_meta(&"ceiling"):
			(node as Node3D).visible = false
	set_process(false)
	var lo: Vector2 = field.origin
	var hi: Vector2 = field.origin + Vector2(field.size) * DungeonField.CELL_M
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(hi.x - lo.x, hi.y - lo.y)
	cam.far = 400.0
	add_child(cam)
	var mid: Vector2 = (lo + hi) * 0.5
	if get_meta(&"zoom", false):
		mid = Vector2(player.global_position.x, player.global_position.z)
		cam.size = 70.0
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)), Vector3(mid.x, 120.0, mid.y))
	cam.current = true
	var sun: DirectionalLight3D = get_node_or_null(^"Light") as DirectionalLight3D
	if sun != null:
		sun.light_energy = 1.0


## Under a roof the sky light only adds a soft fill; torches do the rest.
func _dim_sun() -> void:
	var sun: DirectionalLight3D = get_node_or_null(^"Light") as DirectionalLight3D
	if sun != null:
		sun.shadow_enabled = false
		sun.light_energy = 0.3


func _spawn_portal(at: Vector3, to_double: bool) -> ExitPortal:
	var portal: ExitPortal = (load(EXIT_PORTAL_SCENE) as PackedScene).instantiate() as ExitPortal
	portal.enters_double_gate = to_double
	portal.position = at
	add_child(portal)
	return portal


func _on_boss_cleared() -> void:
	var gate: GateData = session.gate
	session.cleared = true
	GameState.set_flag(StringName("gate_cleared_" + String(gate.id)))
	if gate.has_rule(&"double"):
		GameState.set_flag(&"double_gate_cleared")
	EventBus.gate_cleared.emit(gate.id)
	if session.world_gate_uid >= 0:
		WorldGates.remove(session.world_gate_uid)
	if session.trial_job != &"":
		JobTrial.complete(session.trial_job)
	var tracker: SecretTracker = SecretTracker.find(self)
	if gate.completes_secret != &"" and tracker != null:
		tracker.complete(gate.completes_secret)
	GuildRank.add_points(10 * (gate.rank + 1))
	if gate.reward_gold > 0:
		EventBus.gold_gained.emit(gate.reward_gold * (RED_REWARD_MULT if gate.has_rule(&"red") else 1))
	for item_id: StringName in gate.reward_items:
		GameState.inventory.add(item_id, gate.reward_items[item_id])
	Codex.notify(tr(&"CODEX_MSG_GATE_CLEARED"), &"reward")
	_spawn_exit()


func _spawn_exit() -> void:
	_spawn_portal(player.global_position + player.get_facing() * 3.0, false)
