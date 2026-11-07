class_name LootTable
extends Resource
## Weighted loot. Each entry: item id, weight, min/max count. `rolls` picks per open.

@export var id: StringName = &""
@export var entries: Array[Dictionary] = []
@export var rolls: int = 1
@export var gold_min: int = 0
@export var gold_max: int = 0


## Returns [{ "id": StringName, "count": int }], plus gold under id &"gold".
func roll(rng: RandomNumberGenerator) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var total: float = 0.0
	for e: Dictionary in entries:
		var w: float = e.get("weight", 1.0)
		total += w
	for i: int in rolls:
		var pick: float = rng.randf() * total
		for e: Dictionary in entries:
			var w: float = e.get("weight", 1.0)
			pick -= w
			if pick <= 0.0:
				var lo: int = e.get("min", 1)
				var hi: int = e.get("max", lo)
				var item: String = e.get("id", "")
				result.append({"id": StringName(item), "count": rng.randi_range(lo, hi)})
				break
	if gold_max > 0:
		result.append({"id": &"gold", "count": rng.randi_range(gold_min, gold_max)})
	return result
