extends GutTest
## Owner model slots: monsters / NPCs / chests / waystones / gate themes use imported
## models when present and keep their old procedural look when not.


func test_creature_without_model_keeps_primitives() -> void:
	var body: CreatureBody = CreatureBody.new()
	add_child_autofree(body)
	assert_false(body.build_model(&"mob_does_not_exist", CreatureBody.Shape.QUADRUPED, 1.0))
	body.build(CreatureBody.Shape.QUADRUPED, Color.RED, Color.WHITE, 1.0)
	assert_false(body.has_model())
	assert_gt(body.parts.size(), 3)


func test_creature_with_model_animates_whole_model() -> void:
	var id: StringName = _any_prop()
	if id == &"":
		pass_test("no imported props in this checkout")
		return
	var body: CreatureBody = CreatureBody.new()
	add_child_autofree(body)
	assert_true(body.build_model(id, CreatureBody.Shape.HUMANOID, 1.0))
	assert_true(body.has_model())
	assert_false(body.parts.is_empty(), "model meshes get the hit-flash overlay")
	body.drive(3.0, true, 0.2)
	var model: Node3D = body.get_node(^"Model") as Node3D
	assert_lt(model.rotation.x, 0.0, "leans into the attack")


func test_gate_theme_falls_back_to_rank_colour() -> void:
	var theme: GateTheme = GateTheme.new(0, false)
	assert_not_null(theme.floor_material)
	assert_not_null(theme.wall_material)
	if not theme.has_textures():
		assert_ne(theme.floor_material.albedo_color, Color.WHITE)
	var red: GateTheme = GateTheme.new(2, true)
	assert_eq(red.pillar_model, GateTheme.RED[2])


func test_replace_mesh_needs_a_model() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	add_child_autofree(mi)
	assert_false(PropInstance.replace_mesh(mi, &"prop_missing_model", 1.0))
	assert_not_null(mi.mesh, "placeholder stays")


static func _any_prop() -> StringName:
	for f: String in DirAccess.get_files_at("res://data/props"):
		if f.ends_with(".tres"):
			var d: PropData = PropData.find(StringName(f.get_basename()))
			if d != null and ResourceLoader.exists(d.mesh_path):
				return d.id
	return &""
