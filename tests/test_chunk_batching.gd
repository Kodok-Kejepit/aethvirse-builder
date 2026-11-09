extends GutTest
## Chunk batching (graybox blocks + decor parts merged per material) and model prefetch.


func _block(parent: Node3D, size: Vector3, pos: Vector3, color: Color, solid: bool = true) -> GrayboxBlock:
	var b: GrayboxBlock = GrayboxBlock.new()
	b.size = size
	b.color = color
	b.solid = solid
	b.position = pos
	parent.add_child(b)
	return b


func _meshes(node: Node) -> int:
	return node.find_children("*", "MeshInstance3D", false, false).size()


func test_blocks_merge_and_keep_collision() -> void:
	var chunk: Node3D = Node3D.new()
	add_child_autofree(chunk)
	var grey: Color = Color(0.5, 0.5, 0.55)
	var a: GrayboxBlock = _block(chunk, Vector3(4, 4, 4), Vector3(2, 2, 2), grey)
	var b: GrayboxBlock = _block(chunk, Vector3(2, 6, 2), Vector3(10, 3, 5), grey)
	var ground: GrayboxBlock = _block(chunk, Vector3(128, 1, 128), Vector3(0, -0.5, 0), Color(0.3, 0.3, 0.3))
	var leaves: GrayboxBlock = _block(chunk, Vector3(3, 3, 3), Vector3(-8, 4, 0), Color(0.2, 0.6, 0.25), false)
	var hidden: GrayboxBlock = _block(chunk, Vector3(2, 2, 2), Vector3(20, 1, 0), grey)
	hidden.visible = false
	var merged: int = ChunkBatcher.batch(chunk)
	assert_eq(merged, 3, "two small blocks + the ground slab")
	await get_tree().process_frame
	for block: GrayboxBlock in [a, b, ground]:
		assert_eq(_meshes(block), 0, "own mesh gone")
		assert_eq(block.find_children("*", "CollisionShape3D", false, false).size(), 1, "collision stays")
	assert_eq(_meshes(leaves), 1, "leaves keep their swaying mesh")
	assert_eq(_meshes(hidden), 1, "hidden blocks are left alone")
	var batches: Array[Node] = chunk.find_children("Batch*", "MeshInstance3D", false, false)
	assert_eq(batches.size(), 2, "one batch for the grey cell, one for the ground")
	for n: Node in batches:
		var mi: MeshInstance3D = n as MeshInstance3D
		var aabb: AABB = mi.get_aabb()
		if aabb.size.x > 100.0:
			assert_eq(mi.visibility_range_end, 0.0, "ground is always drawn")
		else:
			assert_true(aabb.has_point(Vector3(2, 2, 2)) and aabb.has_point(Vector3(10, 5.9, 5)), "boxes in place")
			assert_gt(mi.visibility_range_end, 0.0, "small blocks still fade out")


func test_rebuilding_a_batched_block_keeps_it_meshless() -> void:
	var chunk: Node3D = Node3D.new()
	add_child_autofree(chunk)
	var a: GrayboxBlock = _block(chunk, Vector3(4, 4, 4), Vector3.ZERO, Color(0.5, 0.5, 0.55))
	ChunkBatcher.batch(chunk)
	await get_tree().process_frame
	a.size = Vector3(5, 5, 5)
	assert_eq(_meshes(a), 0)
	var shape: CollisionShape3D = a.find_children("*", "CollisionShape3D", false, false)[0] as CollisionShape3D
	assert_eq((shape.shape as BoxShape3D).size, Vector3(5, 5, 5), "collision follows the new size")


func test_decor_parts_join_the_batch_but_lights_stay() -> void:
	var chunk: Node3D = Node3D.new()
	add_child_autofree(chunk)
	var junk: DecorProp = DecorProp.new()
	junk.kind = &"junk"
	junk.position = Vector3(4, 0, 4)
	chunk.add_child(junk)
	var lamp: DecorProp = DecorProp.new()
	lamp.kind = &"streetlight"
	lamp.seed_value = 2
	chunk.add_child(lamp)
	var before: int = _meshes(junk)
	assert_gt(before, 3, "junk is built from several primitives")
	assert_gt(ChunkBatcher.batch(chunk), 3)
	await get_tree().process_frame
	assert_eq(_meshes(junk), 0, "all junk parts merged")
	for n: Node in lamp.find_children("*", "MeshInstance3D", false, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		assert_true((mi.mesh as PrimitiveMesh).material is StandardMaterial3D, "only the glowing bulb keeps its own mesh")


func test_prefetch_lists_the_camp_models() -> void:
	var scene: PackedScene = load("res://scenes/world/chunks/r1/chunk_0_0.tscn") as PackedScene
	var paths: PackedStringArray = AssetPrefetch.paths_for(scene)
	var tent: PropData = PropData.find(&"camp_tent_dome")
	assert_not_null(tent)
	assert_true(paths.has(tent.mesh_path), "tent model is loaded ahead")
	for p: String in paths:
		assert_true(ResourceLoader.exists(p), p)


func test_enemy_bodies_have_a_draw_distance() -> void:
	var root: Node3D = Node3D.new()
	add_child_autofree(root)
	var mi: MeshInstance3D = MeshInstance3D.new()
	root.add_child(mi)
	Enemy.limit_draw_distance(root, EnemyScaling.Tier.NORMAL)
	var normal: float = mi.visibility_range_end
	assert_gt(normal, 60.0)
	mi.visibility_range_end = 0.0
	Enemy.limit_draw_distance(root, EnemyScaling.Tier.BOSS)
	assert_gt(mi.visibility_range_end, normal, "bosses are seen from further away")


func test_procedural_trees_join_the_batch() -> void:
	var chunk: Node3D = Node3D.new()
	add_child_autofree(chunk)
	for i: int in 3:
		var t: TreeProp = TreeProp.new()
		t.kind = &"oak"
		t.seed_value = 10 + i
		t.position = Vector3(i * 6.0, 0, 0)
		chunk.add_child(t)
	var crystal: TreeProp = TreeProp.new()
	crystal.kind = &"crystal"
	chunk.add_child(crystal)
	await get_tree().process_frame
	var crystal_parts: int = _meshes(crystal)
	assert_gt(ChunkBatcher.batch(chunk), 10, "trunks and crowns merged")
	await get_tree().process_frame
	for n: Node in chunk.get_children():
		if n is TreeProp and (n as TreeProp).kind == &"oak":
			assert_eq(_meshes(n), 0, "oak drawn by the batch")
			assert_eq(n.find_children("*", "CollisionShape3D", false, false).size(), 1, "trunk still collides")
	assert_eq(_meshes(crystal), crystal_parts, "glowing crystals keep their own meshes")
