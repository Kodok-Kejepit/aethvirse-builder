class_name ItemStack
extends RefCounted
## One inventory entry: item id + count + per-instance state (identified, kills, ...).

var item_id: StringName = &""
var count: int = 1
var identified: bool = true
## How it was identified (&"appraiser", &"codex", ...); secrets check this.
var identified_by: StringName = &""
var kills: int = 0
## Generated equipment: rarity override (-1 = item default), level, affixes, upgrade (+0..+15).
var rarity: int = -1
var item_level: int = 0
## Each: {"stat": String, "value": float, "name": String, "suffix": bool}
var affixes: Array[Dictionary] = []
var upgrade: int = 0


static func make(id: StringName, amount: int, item: ItemData) -> ItemStack:
	var stack: ItemStack = ItemStack.new()
	stack.item_id = id
	stack.count = amount
	stack.identified = item == null or not item.unidentified
	return stack


func to_dict() -> Dictionary:
	return {"id": String(item_id), "count": count, "identified": identified,
		"identified_by": String(identified_by), "kills": kills, "rarity": rarity,
		"item_level": item_level, "affixes": affixes, "upgrade": upgrade}


## Generated equipment never stacks with other stacks.
func is_unique_instance() -> bool:
	return rarity >= 0 or not affixes.is_empty() or upgrade > 0


static func from_dict(d: Dictionary) -> ItemStack:
	var stack: ItemStack = ItemStack.new()
	var id: String = d.get("id", "")
	var amount: int = d.get("count", 1)
	var ident: bool = d.get("identified", true)
	var by: String = d.get("identified_by", "")
	var k: int = d.get("kills", 0)
	stack.item_id = StringName(id)
	stack.count = amount
	stack.identified = ident
	stack.identified_by = StringName(by)
	stack.kills = k
	var r: int = d.get("rarity", -1)
	var lvl: int = d.get("item_level", 0)
	var up: int = d.get("upgrade", 0)
	stack.rarity = r
	stack.item_level = lvl
	stack.upgrade = up
	var raw: Array = d.get("affixes", [])
	for a: Dictionary in raw:
		var stat: String = a.get("stat", "")
		var value: float = a.get("value", 0.0)
		var affix_name: String = a.get("name", "")
		var suffix: bool = a.get("suffix", false)
		stack.affixes.append({"stat": stat, "value": value, "name": affix_name, "suffix": suffix})
	return stack
