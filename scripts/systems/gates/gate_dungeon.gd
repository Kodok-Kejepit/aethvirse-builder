class_name GateDungeon
extends Node3D
## Builds a Gate instance from GameState.gate_session: a seeded chain of graybox room
## templates ending in a boss arena. Size and enemy levels scale with the player (GateLayout);
## some runs hide a Double Gate behind a cracked wall. Handles rules, rewards, exit.

const ROOM_SIZE: Vector2 = Vector2(24, 24)
const BOSS_SIZE: Vector2 = Vector2(36, 36)
const CORRIDOR_LENGTH: float = 8.0
const WALL_HEIGHT: float = 5.0
const TEMPLATES: Array[StringName] = [&"open", &"pillars", &"split"]
const SCENE: String = "res://scenes/world/gates/gate_dungeon.tscn"
const EXIT_PORTAL_SCENE: String = "res://scenes/world/gates/exit_portal.tscn"
const BREAKABLE_SCENE: String = "res://scenes/world/props/breakable_wall.tscn"
const ALCOVE_GAP: float = 3.0
const ALCOVE_DEPTH: float = 7.0

@export var fallback_gate: GateData

@onready var player: Player = %Player

var session: GateSession
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _material: StandardMaterial3D
var _theme: GateTheme
var _door_material: StandardMaterial3D


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
	_material = _theme.wall_material
	_door_material = StandardMaterial3D.new()
	_door_material.albedo_color = Color(0.8, 0.2, 0.25, 0.8)
	_door_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_build()
	Codex.notify(tr(&"CODEX_MSG_GATE_ENTERED") % [GateData.Rank.keys()[session.gate.rank], tr(session.gate.display_name)], &"warning")
	for rule: StringName in session.gate.rules:
		Codex.notify(tr(StringName("GATE_RULE_" + String(rule).to_upper())), &"anomaly")


## Red Gates: harder monsters, triple gold (no way out but forward).
const RED_LEVEL_BONUS: int = 5
const RED_REWARD_MULT: int = 3


func _build() -> void:
	var z: float = 0.0
	var gate: GateData = session.gate
	var level: int = GameState.progression.level if GameState.progression != null else 1
	var day: int = GameState.clock.day() if GameState.clock != null else 1
	var rooms: int = GateLayout.room_count(gate, level)
	var per_room: int = GateLayout.enemies_per_room(gate, level)
	if gate.has_rule(&"red"):
		session.enemy_level_bonus = maxi(session.enemy_level_bonus, RED_LEVEL_BONUS)
	var double_room: int = -1
	if session.force_double or GateLayout.has_double_gate(gate, day):
		double_room = GateLayout.double_gate_room(rooms, day)
	for i: int in rooms:
		var template: StringName = TEMPLATES[rng.randi() % TEMPLATES.size()]
		if i == double_room:
			template = &"open"
		var room: GateRoom = _make_room(ROOM_SIZE, z, template, i == 0, i == double_room)
		for e: int in (0 if i == 0 else per_room):
			room.enemies.append(_scaled(gate.enemy_pool[rng.randi() % gate.enemy_pool.size()], level))
		z -= ROOM_SIZE.y + CORRIDOR_LENGTH
	var boss_room: GateRoom = _make_room(BOSS_SIZE, z - (BOSS_SIZE.y - ROOM_SIZE.y) * 0.5, &"open", false, false)
	boss_room.exit_door = null
	var boss: EnemyData = _scaled(gate.boss, level)
	boss_room.enemies.append(boss)
	boss_room.cleared.connect(_on_boss_cleared)
	var hook: Callable = func(enemy: Enemy) -> void:
		if enemy.data == boss:
			var phases: BossPhases = BossPhases.new()
			phases.add_data = _scaled(gate.enemy_pool[0], level) if not gate.enemy_pool.is_empty() else null
			enemy.add_child(phases)
			phases.attach(enemy)
	boss_room.set_meta(&"spawn_hook", hook)
	player.global_position = Vector3(0, 0.2, ROOM_SIZE.y * 0.3)
	# No way back out of a Double Gate: the exit only opens when its boss falls.


## Gate enemies keep up with the player (never far below their level).
func _scaled(data: EnemyData, player_level: int) -> EnemyData:
	var target: int = GateLayout.enemy_level(data.level, player_level, session.enemy_level_bonus)
	if target == data.level:
		return data
	var copy: EnemyData = data.duplicate() as EnemyData
	copy.level = target
	return copy


func _make_room(room_size: Vector2, center_z: float, template: StringName, is_first: bool, hides_double: bool) -> GateRoom:
	var room: GateRoom = GateRoom.new() if room_size != BOSS_SIZE else BossRoom.new()
	room.size = room_size
	room.position = Vector3(0, 0, center_z)
	add_child(room)
	_box(room, Vector3(room_size.x, 1.0, room_size.y + CORRIDOR_LENGTH), Vector3(0, -0.5, -CORRIDOR_LENGTH * 0.5), _theme.floor_material)
	var half: Vector2 = room_size * 0.5
	if hides_double:
		_build_double_alcove(room, room_size)
	else:
		_box(room, Vector3(1, WALL_HEIGHT, room_size.y), Vector3(-half.x, WALL_HEIGHT * 0.5, 0), _material)
	_box(room, Vector3(1, WALL_HEIGHT, room_size.y), Vector3(half.x, WALL_HEIGHT * 0.5, 0), _material)
	var side: float = (room_size.x - 4.0) * 0.5
	for sign_x: float in [-1.0, 1.0]:
		_box(room, Vector3(side, WALL_HEIGHT, 1), Vector3(sign_x * (2.0 + side * 0.5), WALL_HEIGHT * 0.5, -half.y), _material)
		if is_first:
			_box(room, Vector3(room_size.x, WALL_HEIGHT, 1), Vector3(0, WALL_HEIGHT * 0.5, half.y), _material)
	room.exit_door = _box(room, Vector3(4, WALL_HEIGHT, 0.6), Vector3(0, WALL_HEIGHT * 0.5, -half.y), _door_material)
	room.exit_door.visible = false
	room.exit_door.collision_layer = 0
	match template:
		&"pillars":
			for p: Vector3 in [Vector3(-5, 0, -5), Vector3(5, 0, -5), Vector3(-5, 0, 5), Vector3(5, 0, 5)]:
				_theme.dress_pillar(_box(room, Vector3(1.5, WALL_HEIGHT, 1.5), p + Vector3(0, WALL_HEIGHT * 0.5, 0), _material), WALL_HEIGHT)
		&"split":
			_box(room, Vector3(room_size.x * 0.5, 1.5, 1), Vector3(-room_size.x * 0.25, 0.75, 0), _material)
	_decorate(room, room_size)
	room.spawn_points = [Vector3(-6, 0.3, -6), Vector3(6, 0.3, -6), Vector3(0, 0.3, -8), Vector3(-6, 0.3, 4), Vector3(6, 0.3, 4)]
	room.setup_trigger()
	return room


## Left wall with a cracked (heavy-attack) section; behind it a small alcove with the
## Double Gate. Hints: the crack glows near the player and the Codex hums when the room clears.
func _build_double_alcove(room: GateRoom, room_size: Vector2) -> void:
	var half: Vector2 = room_size * 0.5
	var gap: float = ALCOVE_GAP
	var seg: float = (room_size.y - gap) * 0.5
	for sign_z: float in [-1.0, 1.0]:
		_box(room, Vector3(1, WALL_HEIGHT, seg), Vector3(-half.x, WALL_HEIGHT * 0.5, sign_z * (gap + seg) * 0.5), _material)
	_box(room, Vector3(1, WALL_HEIGHT - 3.0, gap), Vector3(-half.x, 3.0 + (WALL_HEIGHT - 3.0) * 0.5, 0), _material)
	var crack: Breakable = (load(BREAKABLE_SCENE) as PackedScene).instantiate() as Breakable
	crack.position = Vector3(-half.x, 0, 0)
	crack.rotation.y = PI * 0.5
	room.add_child(crack)
	var depth: float = ALCOVE_DEPTH
	var cx: float = -half.x - depth * 0.5
	_box(room, Vector3(depth, 1.0, gap + 4.0), Vector3(cx, -0.5, 0), _theme.floor_material)
	_box(room, Vector3(1, WALL_HEIGHT, gap + 4.0), Vector3(-half.x - depth, WALL_HEIGHT * 0.5, 0), _material)
	for sign_z: float in [-1.0, 1.0]:
		_box(room, Vector3(depth, WALL_HEIGHT, 1), Vector3(cx, WALL_HEIGHT * 0.5, sign_z * (gap * 0.5 + 2.0)), _material)
	var portal: ExitPortal = _spawn_portal(room.position + Vector3(cx, 0, 0), true)
	portal.visible = false
	crack.broken.connect(func() -> void: portal.visible = true)
	room.cleared.connect(func() -> void:
		Codex.anomaly(tr(&"CODEX_MSG_DOUBLE_HUM"), 0.1))


## Pillars along the side walls and lanterns in the corners (theme models when imported).
func _decorate(room: GateRoom, room_size: Vector2) -> void:
	var half: Vector2 = room_size * 0.5
	var along: float = half.y - 4.0
	for sign_x: float in [-1.0, 1.0]:
		for z: float in [-along, along]:
			var at: Vector3 = Vector3(sign_x * (half.x - 1.2), WALL_HEIGHT * 0.5, z)
			_theme.dress_pillar(_box(room, Vector3(1.4, WALL_HEIGHT, 1.4), at, _material), WALL_HEIGHT)
		var lamp: DecorProp = DecorProp.new()
		lamp.kind = &"lantern"
		lamp.tint = _theme.tint.lightened(0.3)
		lamp.position = Vector3(sign_x * (half.x - 2.6), 0.0, 0.0)
		room.add_child(lamp)


func _spawn_portal(at: Vector3, to_double: bool) -> ExitPortal:
	var portal: ExitPortal = (load(EXIT_PORTAL_SCENE) as PackedScene).instantiate() as ExitPortal
	portal.enters_double_gate = to_double
	portal.position = at
	add_child(portal)
	return portal


func _box(parent: Node3D, box_size: Vector3, pos: Vector3, material: Material) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.position = pos
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = box_size
	shape.shape = box
	body.add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = box_size
	box_mesh.material = material
	mesh.mesh = box_mesh
	body.add_child(mesh)
	parent.add_child(body)
	return body


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
