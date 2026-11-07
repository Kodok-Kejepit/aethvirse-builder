class_name SecretContext
extends RefCounted
## Snapshot of the world that conditions are evaluated against (pure, easy to fake in tests).

var flags: Dictionary[StringName, bool] = {}
var weather: StringName = &"clear"
var hour: int = 12
var is_night: bool = false
var areas: Array[StringName] = []
var idle_s: float = 0.0
var counters: Dictionary[StringName, int] = {}
var found: Dictionary[StringName, bool] = {}
var stats: Dictionary[StringName, float] = {}
var level: int = 1
var inventory: Inventory = null


func has_flag(flag: StringName) -> bool:
	return flags.get(flag, false)


func hour_between(from_hour: int, to_hour: int) -> bool:
	if from_hour <= to_hour:
		return hour >= from_hour and hour < to_hour
	return hour >= from_hour or hour < to_hour


func counter(id: StringName) -> int:
	return counters.get(id, 0)


func is_found(id: StringName) -> bool:
	return found.get(id, false)


func stat(id: StringName) -> float:
	return stats.get(id, 0.0)


## identified_by empty = any; otherwise the stack must have been identified that way.
func has_item(item_id: StringName, count: int, identified_by: StringName) -> bool:
	if inventory == null or inventory.count_of(item_id) < count:
		return false
	if identified_by == &"":
		return true
	var stack: ItemStack = inventory.first_stack(item_id)
	return stack != null and stack.identified and stack.identified_by == identified_by
