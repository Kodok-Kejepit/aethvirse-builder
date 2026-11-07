class_name SecretDatabase
extends RefCounted
## Loads SecretData (data/secrets/**), LoreData (data/lore/) and RegionData (data/regions/).

const SECRET_DIR: String = "res://data/secrets/"
const LORE_DIR: String = "res://data/lore/"
const REGION_DIR: String = "res://data/regions/"

var secrets: Dictionary[StringName, SecretData] = {}
var lore: Dictionary[StringName, LoreData] = {}
var regions: Dictionary[StringName, RegionData] = {}


func _init() -> void:
	for res: Resource in _load_all(SECRET_DIR):
		var s: SecretData = res as SecretData
		if s != null:
			secrets[s.id] = s
	for res: Resource in _load_all(LORE_DIR):
		var l: LoreData = res as LoreData
		if l != null:
			lore[l.id] = l
	for res: Resource in _load_all(REGION_DIR):
		var r: RegionData = res as RegionData
		if r != null:
			regions[r.id] = r


func get_secret(id: StringName) -> SecretData:
	return secrets.get(id, null)


static func _load_all(dir: String) -> Array[Resource]:
	var out: Array[Resource] = []
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for file: String in DirAccess.get_files_at(dir):
		var path: String = dir.path_join(file.trim_suffix(".remap"))
		if path.ends_with(".tres"):
			out.append(load(path))
	for sub: String in DirAccess.get_directories_at(dir):
		out.append_array(_load_all(dir.path_join(sub)))
	return out
