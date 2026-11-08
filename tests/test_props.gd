extends GutTest
## Imported world models and asset slots.

const IMPORT_TOOL: GDScript = preload("res://tools/import_props.gd")


func _prefix(id: String) -> String:
	var cat: Array = IMPORT_TOOL.call(&"category", id)
	var p: String = cat[0]
	return p


func test_categories_from_prefix() -> void:
	assert_eq(_prefix("prop_barrel"), "prop_")
	assert_eq(_prefix("bld_refugee_tent"), "bld_")
	assert_eq(_prefix("r1_apartment_a"), "bld_", "region prefix counts as a building")
	assert_eq(_prefix("something"), "")


func test_missing_asset_uses_graybox_slot() -> void:
	var slot: PropInstance = PropInstance.new()
	slot.prop_id = &"bld_does_not_exist"
	slot.fallback_size = Vector3(4, 3, 4)
	add_child_autofree(slot)
	var block: GrayboxBlock = slot.find_children("*", "GrayboxBlock", false, false)[0] as GrayboxBlock
	assert_not_null(block)
	assert_eq(block.size, Vector3(4, 3, 4))
	assert_false(PropInstance.attach_model(slot, &"prop_nothing", 1.0))


func test_imported_model_fits_its_slot() -> void:
	if PropData.find(&"rock_monolith_moss") == null:
		pending("model not imported")
		return
	var slot: PropInstance = PropInstance.new()
	slot.prop_id = &"rock_monolith_moss"
	slot.fallback_size = Vector3(1, 3, 1)
	add_child_autofree(slot)
	var meshes: Array[Node] = slot.find_children("*", "MeshInstance3D", false, false)
	assert_eq(meshes.size(), 1)
	var mi: MeshInstance3D = meshes[0] as MeshInstance3D
	assert_almost_eq(mi.mesh.get_aabb().size.y * mi.scale.y, 3.0, 0.05)
