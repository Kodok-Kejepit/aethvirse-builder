class_name EnemySpawner
extends Marker3D
## Spawns one enemy at this marker and respawns it some time after it is removed.

@export var enemy_scene: PackedScene
@export var enemy_data: EnemyData
@export var respawn_s: float = 6.0
@export var spawn_on_ready: bool = true


func _ready() -> void:
	if spawn_on_ready:
		spawn.call_deferred()


func spawn() -> Enemy:
	var enemy: Enemy = enemy_scene.instantiate() as Enemy
	if enemy_data != null:
		enemy.data = enemy_data
	var at: Vector3 = global_position + Vector3.UP * TerrainPatch.height_at(get_tree(), global_position)
	# The enemy joins the spawner's parent (a chunk placed at chunk_x * 128 m).
	var parent_3d: Node3D = get_parent() as Node3D
	enemy.position = parent_3d.to_local(at) if parent_3d != null else at
	get_parent().add_child(enemy)
	enemy.tree_exited.connect(_on_enemy_removed, CONNECT_ONE_SHOT)
	return enemy


func _on_enemy_removed() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(respawn_s).timeout
	if is_inside_tree():
		spawn()
