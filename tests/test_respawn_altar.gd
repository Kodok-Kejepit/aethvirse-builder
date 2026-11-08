extends GutTest
## Falling in battle brings you back to the last altar (waystone) you stood at.

const TUNING: StatTuning = preload("res://data/balancing/stat_tuning.tres")
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _region_before: StringName


func before_each() -> void:
	_region_before = GameState.current_region
	GameState.respawn_waystone = &""


func after_each() -> void:
	GameState.respawn_waystone = &""
	GameState.current_region = _region_before


func test_standing_at_an_altar_sets_the_respawn_point_once() -> void:
	assert_true(WorldTravel.set_respawn(&"r1_overpass"))
	assert_false(WorldTravel.set_respawn(&"r1_overpass"), "same altar: no new notice")
	assert_eq(GameState.respawn_waystone, &"r1_overpass")


func test_respawn_point_survives_save_and_new_game_clears_it() -> void:
	GameState.respawn_waystone = &"r1_overpass"
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.respawn_waystone = &""
	GameState.load_dict(data, TUNING)
	assert_eq(GameState.respawn_waystone, &"r1_overpass")
	GameState.new_game(GameState.class_id, TUNING)
	assert_eq(GameState.respawn_waystone, &"")


func test_player_rises_at_the_last_altar_in_this_region() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var player: Player = PLAYER_SCENE.instantiate() as Player
	world.add_child(player)
	await wait_physics_frames(2)
	GameState.current_region = &"r1_ashfall"
	GameState.respawn_waystone = &"r1_overpass"
	player.global_position = Vector3(500.0, 0.0, 500.0)
	player.respawn()
	var region: RegionData = RegionData.region_of_waystone(&"r1_overpass")
	var altar: Vector3 = region.waystones[&"r1_overpass"]
	assert_lt(Vector2(player.global_position.x - altar.x, player.global_position.z - altar.z).length(), 4.0)
	assert_false(player.health.is_dead(), "revived")


func test_without_an_altar_you_rise_at_the_camp() -> void:
	var world: Node3D = Node3D.new()
	add_child_autofree(world)
	var player: Player = PLAYER_SCENE.instantiate() as Player
	world.add_child(player)
	await wait_physics_frames(2)
	GameState.current_region = &"r1_ashfall"
	player.spawn_point = Vector3(3.0, 0.2, 4.0)
	player.global_position = Vector3(90.0, 0.0, 90.0)
	player.respawn()
	var camp: Vector3 = RegionData.load_region(&"r1_ashfall").waystones[WorldTravel.DEFAULT_ALTAR]
	assert_lt(Vector2(player.global_position.x - camp.x, player.global_position.z - camp.z).length(), 4.0, "owner: no altar yet -> the camp")
