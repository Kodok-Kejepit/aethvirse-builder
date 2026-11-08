class_name GateRoom
extends Node3D
## One dungeon room: spawns its enemies when the player enters, locks the exit until cleared.
## Room challenges (DungeonArchetype.CHALLENGES): "waves" sends the enemies in 2-3 waves,
## "timed" reports whether the room was cleared inside `time_limit_s`. The dungeon handles
## the rest (traps, darkness, elites) through `started` / `cleared`.

signal cleared
signal started
## Timed rooms: true when cleared in time (the dungeon hands out the reward).
signal challenge_done(success: bool)

@export var enemies: Array[EnemyData] = []
@export var size: Vector2 = Vector2(24, 24)

var spawn_points: Array[Vector3] = []
var exit_door: StaticBody3D = null
## Red wards across this room's mouths: up while enemies are alive.
var wards: Array[DungeonWard] = []
var challenge: StringName = &""
var time_limit_s: float = 0.0
var _alive: int = 0
var _started: bool = false
var _done: bool = false
var _living: Array[Enemy] = []
var _check: float = 0.0
var _waves: Array[Array] = []
var _spawned: int = 0
var _elapsed: float = 0.0
var _between_waves: bool = false
var _warned: bool = false
## Enemies that wander out of the room (knockback, chasing, falling) are put back.
const STRAY_MARGIN_M: float = 3.0
const STRAY_CHECK_S: float = 1.0
const WAVE_DELAY_S: float = 1.5
var _enemy_scene: PackedScene = preload("res://scenes/enemies/enemy.tscn")


## The fight starts when the player enters a box around the room's centre: `extent`
## (default: the whole room minus a margin).
func setup_trigger(extent: Vector2 = Vector2.ZERO) -> void:
	var s: Vector2 = extent if extent != Vector2.ZERO else size
	var area: Area3D = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(s.x - 4.0, 4.0, s.y - 4.0)
	shape.shape = box
	shape.position = Vector3(0, 2, 0)
	area.add_child(shape)
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			# Deferred: spawning enemies (hit/hurtboxes) inside a physics callback is blocked.
			start.call_deferred())


func start() -> void:
	if _started:
		return
	_started = true
	if enemies.is_empty():
		_on_cleared()
		return
	_set_door_locked(true)
	started.emit()
	_waves = split_waves(enemies, challenge == &"waves")
	if challenge == &"timed":
		Codex.notify(tr(&"CHALLENGE_TIMED_START") % roundi(time_limit_s), &"warning")
	elif challenge == &"waves":
		Codex.notify(tr(&"CHALLENGE_WAVES_START") % _waves.size(), &"warning")
	var first: Array = _waves.pop_front()
	_spawn_wave(first)


## Waves: the enemies split into 2-3 groups (at least one each); otherwise one group.
static func split_waves(list: Array[EnemyData], waves: bool) -> Array[Array]:
	if not waves or list.size() < 2:
		return [list.duplicate()]
	var count: int = clampi(list.size(), 2, 3)
	var out: Array[Array] = []
	for _w: int in count:
		out.append([])
	for i: int in list.size():
		out[i % count].append(list[i])
	return out


func _spawn_wave(group: Array) -> void:
	_between_waves = false
	for data: EnemyData in group:
		var enemy: Enemy = _enemy_scene.instantiate() as Enemy
		enemy.data = data
		enemy.position = position + spawn_points[_spawned % spawn_points.size()]
		_spawned += 1
		get_parent().add_child(enemy)
		_alive += 1
		_living.append(enemy)
		# Dying counts at once; vanishing any other way (falling out, despawn) is noticed
		# on the next physics frame. Not via tree_exiting: when the whole Gate scene goes
		# away, a boss left alive would count as beaten.
		enemy.health.died.connect(_on_enemy_gone.bind(enemy), CONNECT_ONE_SHOT)
		_on_spawned(enemy)


## Hook for subclasses / boss rooms.
func _on_spawned(_enemy: Enemy) -> void:
	pass


func _on_enemy_gone(enemy: Enemy) -> void:
	if not _living.has(enemy):
		return
	_living.erase(enemy)
	_alive -= 1
	_check_done()


## Last enemy of a wave gone: the next wave comes, or the room is cleared.
func _check_done() -> void:
	if _alive > 0 or _between_waves or _done:
		return
	if not _waves.is_empty():
		_between_waves = true
		var group: Array = _waves.pop_front()
		Codex.notify(tr(&"CHALLENGE_NEXT_WAVE"), &"warning")
		get_tree().create_timer(WAVE_DELAY_S).timeout.connect(func() -> void:
			if is_inside_tree():
				_spawn_wave(group))
		return
	_on_cleared()


func _physics_process(delta: float) -> void:
	if _started and not _done:
		_elapsed += delta
		if challenge == &"timed" and not _warned and _elapsed > time_limit_s:
			_warned = true
			Codex.notify(tr(&"CHALLENGE_TIMED_LATE"), &"warning")
	if _living.is_empty():
		return
	for i: int in range(_living.size() - 1, -1, -1):
		if not is_instance_valid(_living[i]) or not _living[i].is_inside_tree():
			_living.remove_at(i)
			_alive -= 1
	if _alive <= 0:
		_check_done()
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = STRAY_CHECK_S
	var half: Vector2 = size * 0.5 + Vector2.ONE * STRAY_MARGIN_M
	for enemy: Enemy in _living:
		if not is_instance_valid(enemy) or enemy.health.is_dead():
			continue
		var local: Vector3 = enemy.global_position - global_position
		if absf(local.x) > half.x or absf(local.z) > half.y or local.y < -3.0:
			enemy.global_position = global_position + spawn_points[randi() % spawn_points.size()]
			enemy.velocity = Vector3.ZERO


func _on_cleared() -> void:
	if _done:
		return
	_done = true
	_set_door_locked(false)
	if challenge == &"timed":
		challenge_done.emit(_elapsed <= time_limit_s)
	cleared.emit()


func _set_door_locked(locked: bool) -> void:
	for ward: DungeonWard in wards:
		ward.set_active(locked)
	if exit_door == null:
		return
	exit_door.visible = locked
	exit_door.collision_layer = 1 if locked else 0
