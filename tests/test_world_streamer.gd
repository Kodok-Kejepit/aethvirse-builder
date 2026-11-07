extends GutTest


func test_chunk_of() -> void:
	assert_eq(ChunkMath.chunk_of(Vector3(0, 0, 0)), Vector2i(0, 0))
	assert_eq(ChunkMath.chunk_of(Vector3(63.9, 0, -63.9)), Vector2i(0, 0))
	assert_eq(ChunkMath.chunk_of(Vector3(64.1, 0, 0)), Vector2i(1, 0))
	assert_eq(ChunkMath.chunk_of(Vector3(-130, 0, -200)), Vector2i(-1, -2))


func test_wanted_ring() -> void:
	assert_eq(ChunkMath.wanted(Vector2i.ZERO, 0).size(), 1)
	assert_eq(ChunkMath.wanted(Vector2i.ZERO, 1).size(), 9)
	assert_eq(ChunkMath.wanted(Vector2i(2, 2), 2).size(), 25)


func test_r1_chunks_exist() -> void:
	for x: int in [-1, 0, 1]:
		for z: int in [-1, 0, 1]:
			assert_true(ResourceLoader.exists("res://scenes/world/chunks/r1/chunk_%d_%d.tscn" % [x, z]), "%d,%d" % [x, z])


func test_ashfall_loads_and_player_stands() -> void:
	GameState.progression = null
	GameState.pending_player_position = null
	var region: RegionController = (load("res://scenes/world/regions/ashfall.tscn") as PackedScene).instantiate() as RegionController
	add_child_autofree(region)
	await wait_physics_frames(30)
	assert_gt(WorldStreamer.get_loaded_chunk_count(), 0)
	assert_true(region.player.is_on_floor(), "chunk ground loaded before the player fell")
	assert_eq(GameState.current_region, &"r1_ashfall")
	assert_eq(GameState.weather.table, region.region.weather)
