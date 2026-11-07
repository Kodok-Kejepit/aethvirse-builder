class_name ItemDatabase
extends RefCounted
## Loads every ItemData in data/items/ once. Owned by GameState (no static Resource caches).

const ITEM_DIR: String = "res://data/items/"

var _items: Dictionary[StringName, ItemData] = {}


func _init() -> void:
	for file: String in DirAccess.get_files_at(ITEM_DIR):
		var path: String = ITEM_DIR + file.trim_suffix(".remap")
		if not path.ends_with(".tres"):
			continue
		var item: ItemData = load(path) as ItemData
		if item != null:
			_items[item.id] = item


func get_item(id: StringName) -> ItemData:
	return _items.get(id, null)


func has(id: StringName) -> bool:
	return _items.has(id)


func all_ids() -> Array[StringName]:
	return _items.keys()
