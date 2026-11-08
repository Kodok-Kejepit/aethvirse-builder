class_name GateDungeon
extends Node3D
## Builds a Gate instance from GameState.gate_session: a seeded, branching set of
## irregular roofed rooms (DungeonPlan + DungeonRoomBuilder) joined by doors, ending in a
## boss hall. Side branches hold treasure, cracked walls hide caches, and some runs have
## a sealed Double Gate door (needs a Gate Key). Size and enemy levels scale with the
## player (GateLayout). Handles door travel, rules, rewards and the exit.

## Rooms sit far apart: doors move the player between them (fade to black).
const ROOM_SPACING_M: float = 110.0
const DOOR_SHOVE_S: float = 0.4
const FADE_S: float = 0.35
const DARK_HOLD_S: float = 0.6
const FADE_LAYER: int = 110
const SCENE: String = "res://scenes/world/gates/gate_dungeon.tscn"
const EXIT_PORTAL_SCENE: String = "res://scenes/world/gates/exit_portal.tscn"

@export var fallback_gate: GateData

@onready var player: Player = %Player

var session: GateSession
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _theme: GateTheme
var _rooms: Array[GateRoom] = []
var _room_doors: Array[Array] = []
var _current: int = 0
var _busy: bool = false
var _fade: ColorRect = null


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
	_build()
	Codex.notify(tr(&"CODEX_MSG_GATE_ENTERED") % [GateData.Rank.keys()[session.gate.rank], tr(session.gate.display_name)], &"warning")
	for rule: StringName in session.gate.rules:
		Codex.notify(tr(StringName("GATE_RULE_" + String(rule).to_upper())), &"anomaly")


## Red Gates: harder monsters, triple gold (no way out but forward).
const RED_LEVEL_BONUS: int = 5
const RED_REWARD_MULT: int = 3


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
	var plan: DungeonPlan = DungeonPlan.make(main_rooms, per_room, rng.randi(), double_at)
	var builder: DungeonRoomBuilder = DungeonRoomBuilder.new(_theme, _theme.door_models)
	builder.level = level
	builder.chest_prefix = "%s_%d" % [gate.id, day]
	var boss: EnemyData = _scaled(gate.boss, level)
	for i: int in plan.rooms.size():
		var spec: DungeonPlan.Room = plan.rooms[i]
		var room: GateRoom = BossRoom.new() if spec.kind == DungeonPlan.Kind.BOSS else GateRoom.new()
		room.position = Vector3(float(i) * ROOM_SPACING_M, 0.0, 0.0)
		add_child(room)
		var doors: Array[DungeonDoor] = builder.build(room, spec, i)
		for d: int in doors.size():
			var door: DungeonDoor = doors[d]
			if door == null:
				continue
			room.doors.append(door)
			door.used.connect(_on_door_used)
			if d < spec.doors.size():
				var to: int = spec.doors[d]["to"]
				door.target_room = to
				door.target_door = plan.door_back(i, door.target_room)
		if spec.kind == DungeonPlan.Kind.BOSS:
			room.enemies.append(boss)
			room.cleared.connect(_on_boss_cleared)
			_hook_boss(room as BossRoom, boss, gate, level)
		else:
			for e: int in spec.enemy_count:
				room.enemies.append(_scaled(gate.enemy_pool[rng.randi() % gate.enemy_pool.size()], level))
		room.setup_trigger()
		_rooms.append(room)
		_room_doors.append(doors)
	_show_room(0)
	var start: DungeonPlan.Room = plan.rooms[0]
	player.global_position = Vector3(0.0, 0.2, start.radius * 0.45)
	# No way back out of a Double Gate: the exit only opens when its boss falls.


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
	var target: int = GateLayout.enemy_level(data.level, player_level, session.enemy_level_bonus)
	if target == data.level:
		return data
	var copy: EnemyData = data.duplicate() as EnemyData
	copy.level = target
	return copy


## Only the room the player is in is shown (lights, draw calls).
func _show_room(index: int) -> void:
	_current = index
	for i: int in _rooms.size():
		_rooms[i].visible = i == index


func _on_door_used(door: DungeonDoor) -> void:
	if _busy:
		return
	if door.is_double:
		_busy = true
		door.shove()
		Codex.anomaly(tr(&"CODEX_MSG_DOUBLE_HUM"), 0.1)
		ExitPortal.enter_double(get_tree())
		return
	if door.target_room < 0 or door.target_room >= _rooms.size():
		return
	_travel(door)


## Shove the door, fade to black, move to the matching door of the next room, fade in.
func _travel(door: DungeonDoor) -> void:
	_busy = true
	door.shove()
	await get_tree().create_timer(DOOR_SHOVE_S).timeout
	var fade_in: Tween = _fader().create_tween()
	fade_in.tween_property(_fade, ^"color:a", 1.0, FADE_S)
	await fade_in.finished
	get_tree().paused = true
	var to_room: int = door.target_room
	_show_room(to_room)
	var target: DungeonDoor = _room_doors[to_room][door.target_door] if door.target_door >= 0 else null
	var facing: Vector3 = target.global_basis.z if target != null else Vector3.FORWARD
	player.global_position = target.arrival_point() if target != null else _rooms[to_room].global_position + Vector3.UP * 0.2
	player.velocity = Vector3.ZERO
	player.visual.rotation.y = MovementMath.yaw_for_direction(facing)
	player.reset_physics_interpolation()
	if player.camera_rig != null:
		player.camera_rig.snap_to(MovementMath.yaw_for_direction(facing))
	await get_tree().create_timer(DARK_HOLD_S).timeout
	get_tree().paused = false
	_rooms[to_room].start.call_deferred()
	var fade_out: Tween = _fader().create_tween()
	fade_out.tween_property(_fade, ^"color:a", 0.0, FADE_S)
	await fade_out.finished
	_busy = false


func _fader() -> ColorRect:
	if _fade == null:
		var layer: CanvasLayer = CanvasLayer.new()
		layer.layer = FADE_LAYER
		layer.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(layer)
		_fade = ColorRect.new()
		_fade.color = Color(0.0, 0.0, 0.0, 0.0)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_fade.process_mode = Node.PROCESS_MODE_ALWAYS
		layer.add_child(_fade)
	return _fade


## Debug: stand just inside the first door of a room (no fight starts).
func debug_goto(index: int) -> void:
	if index < 0 or index >= _rooms.size():
		return
	_show_room(index)
	var doors: Array[DungeonDoor] = []
	doors.assign(_room_doors[index])
	var door: DungeonDoor = doors[0] if not doors.is_empty() else null
	var facing: Vector3 = door.global_basis.z if door != null else Vector3.FORWARD
	player.global_position = door.arrival_point() if door != null else _rooms[index].global_position + Vector3.UP * 0.2
	player.visual.rotation.y = MovementMath.yaw_for_direction(facing)
	player.reset_physics_interpolation()
	player.camera_rig.snap_to(MovementMath.yaw_for_direction(facing))


## Debug: clear the current room and use its last door (normal travel, with the fade).
func debug_next() -> void:
	var doors: Array[DungeonDoor] = []
	doors.assign(_room_doors[_current])
	_rooms[_current].enemies.clear()
	_rooms[_current].start()
	if not doors.is_empty():
		_on_door_used(doors[doors.size() - 1])


## Debug: every room laid out on a grid, roofs hidden, seen from straight above.
func debug_overview() -> void:
	var cols: int = ceili(sqrt(float(_rooms.size())))
	var cell: float = 52.0
	for i: int in _rooms.size():
		_rooms[i].visible = true
		_rooms[i].position = Vector3(float(i % cols) * cell, 0.0, float(floori(float(i) / float(cols))) * cell)
	for node: Node in find_children("*", "StaticBody3D", true, false):
		if node.has_meta(&"ceiling"):
			(node as Node3D).visible = false
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = cell * float(cols)
	cam.far = 400.0
	add_child(cam)
	var mid: Vector3 = Vector3(cell * float(cols - 1) * 0.5, 120.0, cell * float(cols - 1) * 0.5)
	cam.global_transform = Transform3D(Basis.from_euler(Vector3(-PI * 0.5, 0.0, 0.0)), mid)
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
