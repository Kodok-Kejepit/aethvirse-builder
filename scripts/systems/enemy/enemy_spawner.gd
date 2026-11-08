class_name EnemySpawner
extends Marker3D
## Spawns one enemy at this marker and respawns it some time after it is removed.

@export var enemy_scene: PackedScene
@export var enemy_data: EnemyData
@export var respawn_s: float = 6.0
@export var spawn_on_ready: bool = true
## > 0: spawn at this level instead of the data's (Region 1 sets it by zone).
@export var level: int = 0

var _levelled: EnemyData = null


func _ready() -> void:
	if spawn_on_ready:
		spawn.call_deferred()


func spawn() -> Enemy:
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	if enemy_data != null:
		enemy.data = _data_for_level()
	var at: Vector3 = global_position + Vector3.UP * TerrainPatch.height_at(get_tree(), global_position)
	# The enemy joins the spawner's parent (a chunk placed at chunk_x * 128 m).
	var parent_3d: Node3D = get_parent() as Node3D
	enemy.position = parent_3d.to_local(at) if parent_3d != null else at
	get_parent().add_child(enemy)
	enemy.tree_exited.connect(_on_enemy_removed, CONNECT_ONE_SHOT)
	return enemy


func _data_for_level() -> EnemyData:
	if level <= 0 and _region_bonus() > 0:
		level = enemy_data.level + _region_bonus()
	if level <= 0 or level == enemy_data.level:
		return enemy_data
	if _levelled == null:
		_levelled = enemy_data.duplicate() as EnemyData
		_levelled.level = level
	return _levelled


func _region_bonus() -> int:
	var region: RegionData = RegionData.load_region(GameState.current_region) if GameState.current_region != &"" else null
	return region.enemy_level_bonus if region != null else 0


func _on_enemy_removed() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(respawn_s).timeout
	if is_inside_tree():
		spawn()
