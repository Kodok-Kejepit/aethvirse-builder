extends GutTest
## Procedural creature bodies: shape mapping and build.


func test_shape_from_enemy_id() -> void:
	assert_eq(CreatureBody.shape_for(&"ash_hound"), CreatureBody.Shape.QUADRUPED)
	assert_eq(CreatureBody.shape_for(&"moss_brute"), CreatureBody.Shape.BRUTE)
	assert_eq(CreatureBody.shape_for(&"sand_wraith"), CreatureBody.Shape.WRAITH)
	assert_eq(CreatureBody.shape_for(&"ice_wyvernling"), CreatureBody.Shape.WYVERN)
	assert_eq(CreatureBody.shape_for(&"crimson_burrower"), CreatureBody.Shape.SERPENT)
	assert_eq(CreatureBody.shape_for(&"gate_husk"), CreatureBody.Shape.HUMANOID)


func test_every_shape_builds_and_animates() -> void:
	for s: int in CreatureBody.Shape.values():
		var body: CreatureBody = CreatureBody.new()
		add_child_autofree(body)
		body.build(s as CreatureBody.Shape, Color.RED, Color.WHITE, 1.2)
		assert_gt(body.parts.size(), 3, "shape %d has parts" % s)
		body.drive(4.0, true, 0.1)
		assert_almost_eq(body.scale.x, 1.2, 0.001)
