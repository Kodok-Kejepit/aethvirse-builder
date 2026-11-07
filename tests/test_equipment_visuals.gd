extends GutTest
## Worn gear and costumes appear on the character rig.

const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")

var _player: Player


func before_each() -> void:
	GameState.class_id = &"vanguard"
	_player = PLAYER_SCENE.instantiate() as Player
	add_child_autofree(_player)
	await wait_physics_frames(2)


func _gear() -> EquipmentVisuals:
	return _player.model.rig.find_child("EquipmentVisuals", false, false) as EquipmentVisuals


func test_costumes_are_cosmetic_slot_items() -> void:
	for id: StringName in [&"costume_starcloak", &"costume_wings_of_dawn", &"costume_void_halo"]:
		var item: ItemData = GameState.items.get_item(id)
		assert_not_null(item, String(id))
		assert_eq(item.slot, ItemData.Slot.COSTUME)
		assert_false(item.is_drop_base)


func test_equipping_adds_and_removes_pieces() -> void:
	var gear: EquipmentVisuals = _gear()
	assert_not_null(gear)
	var before: int = gear._parts.size()
	var inv: Inventory = GameState.inventory
	inv.add(&"costume_wings_of_dawn", 1)
	var stack: ItemStack = null
	for s: ItemStack in inv.stacks:
		if s.item_id == &"costume_wings_of_dawn":
			stack = s
	assert_true(inv.equip(stack))
	gear.rebuild()
	assert_gt(gear._parts.size(), before, "wings + legendary aura added")
	inv.unequip(ItemData.Slot.COSTUME)
	gear.rebuild()
	assert_eq(gear._parts.size(), before)
	inv.stacks.erase(stack)
