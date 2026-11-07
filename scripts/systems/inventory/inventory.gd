class_name Inventory
extends RefCounted
## Bag + equipment. Pure model (no nodes); GameState owns it and saves it.

signal changed

const CAPACITY: int = 60

var db: ItemDatabase
var stacks: Array[ItemStack] = []
## Equipment slot (ItemData.Slot as int) -> ItemStack.
var equipped: Dictionary[int, ItemStack] = {}


func _init(database: ItemDatabase) -> void:
	db = database


## Adds items; returns how many could not fit.
func add(item_id: StringName, amount: int = 1) -> int:
	var item: ItemData = db.get_item(item_id)
	if item == null or amount <= 0:
		return amount
	var left: int = amount
	if item.is_stackable():
		for stack: ItemStack in stacks:
			if stack.item_id == item_id and stack.count < item.max_stack and stack.identified and not stack.is_unique_instance():
				var moved: int = mini(left, item.max_stack - stack.count)
				stack.count += moved
				left -= moved
				if left == 0:
					break
	while left > 0 and stacks.size() < CAPACITY:
		var moved: int = mini(left, item.max_stack)
		stacks.append(ItemStack.make(item_id, moved, item))
		left -= moved
	changed.emit()
	return left


func count_of(item_id: StringName) -> int:
	var total: int = 0
	for stack: ItemStack in stacks:
		if stack.item_id == item_id:
			total += stack.count
	for stack: ItemStack in equipped.values():
		if stack.item_id == item_id:
			total += stack.count
	return total


func has(item_id: StringName, amount: int = 1) -> bool:
	return count_of(item_id) >= amount


## Removes from the bag (not equipment). Returns true if enough were present.
func remove(item_id: StringName, amount: int = 1) -> bool:
	var in_bag: int = 0
	for stack: ItemStack in stacks:
		if stack.item_id == item_id:
			in_bag += stack.count
	if in_bag < amount:
		return false
	var left: int = amount
	for i: int in range(stacks.size() - 1, -1, -1):
		var stack: ItemStack = stacks[i]
		if stack.item_id != item_id:
			continue
		var taken: int = mini(left, stack.count)
		stack.count -= taken
		left -= taken
		if stack.count <= 0:
			stacks.remove_at(i)
		if left == 0:
			break
	changed.emit()
	return true


func first_stack(item_id: StringName) -> ItemStack:
	for stack: ItemStack in stacks:
		if stack.item_id == item_id:
			return stack
	for stack: ItemStack in equipped.values():
		if stack.item_id == item_id:
			return stack
	return null


func equip(stack: ItemStack) -> bool:
	var item: ItemData = db.get_item(stack.item_id)
	if item == null or not item.is_equipment() or not stack in stacks:
		return false
	var slot: int = item.slot
	# Two ring slots: use the second if the first is taken.
	if slot == ItemData.Slot.RING and equipped.has(ItemData.Slot.RING) and not equipped.has(ItemData.Slot.RING_2):
		slot = ItemData.Slot.RING_2
	var current: ItemStack = equipped.get(slot, null)
	if current != null and not unequip(slot):
		return false
	stacks.erase(stack)
	equipped[slot] = stack
	changed.emit()
	return true


## Cursed items cannot be removed this way. Returns false if blocked or empty.
func unequip(slot: int) -> bool:
	var stack: ItemStack = equipped.get(slot, null)
	if stack == null or stacks.size() >= CAPACITY:
		return false
	var item: ItemData = db.get_item(stack.item_id)
	if item != null and item.cursed:
		return false
	equipped.erase(slot)
	stacks.append(stack)
	changed.emit()
	return true


## Removes a cursed item regardless (church in Haven, purification quests).
func force_unequip(slot: int) -> void:
	var stack: ItemStack = equipped.get(slot, null)
	if stack != null:
		equipped.erase(slot)
		stacks.append(stack)
		changed.emit()


func get_equipped(slot: int) -> ItemStack:
	return equipped.get(slot, null)


func get_equipped_item(slot: int) -> ItemData:
	var stack: ItemStack = get_equipped(slot)
	return db.get_item(stack.item_id) if stack != null else null


## Replaces a stack's item (evolution) keeping its slot and position.
func transform(stack: ItemStack, new_id: StringName) -> void:
	stack.item_id = new_id
	stack.kills = 0
	stack.identified = true
	changed.emit()


func identify(stack: ItemStack, method: StringName) -> void:
	stack.identified = true
	stack.identified_by = method
	changed.emit()


func display_name(stack: ItemStack) -> String:
	var item: ItemData = db.get_item(stack.item_id)
	if item == null:
		return String(stack.item_id)
	if not stack.identified:
		return item.unidentified_name
	if stack.identified_by == &"codex" and item.codex_identified_name != "":
		return item.codex_identified_name
	var prefix: String = ""
	var suffix: String = ""
	for affix: Dictionary in stack.affixes:
		var affix_name: String = affix["name"]
		var is_suffix: bool = affix["suffix"]
		if is_suffix and suffix == "":
			suffix = " " + affix_name
		elif not is_suffix and prefix == "":
			prefix = affix_name + " "
	var plus: String = " +%d" % stack.upgrade if stack.upgrade > 0 else ""
	return prefix + item.display_name + suffix + plus


## Adds an already-built stack (generated loot). Returns false if the bag is full.
func add_stack(stack: ItemStack) -> bool:
	if stacks.size() >= CAPACITY:
		return false
	stacks.append(stack)
	changed.emit()
	return true


func to_dict() -> Dictionary:
	var bag: Array[Dictionary] = []
	for stack: ItemStack in stacks:
		bag.append(stack.to_dict())
	var gear: Dictionary = {}
	for slot: int in equipped:
		gear[str(slot)] = equipped[slot].to_dict()
	return {"bag": bag, "equipped": gear}


func load_dict(d: Dictionary) -> void:
	stacks.clear()
	equipped.clear()
	var bag: Array = d.get("bag", [])
	for entry: Dictionary in bag:
		stacks.append(ItemStack.from_dict(entry))
	var gear: Dictionary = d.get("equipped", {})
	for key: String in gear:
		var entry: Dictionary = gear[key]
		equipped[key.to_int()] = ItemStack.from_dict(entry)
	changed.emit()
