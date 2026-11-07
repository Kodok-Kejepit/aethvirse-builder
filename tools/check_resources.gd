extends SceneTree
## Loads every script, scene and resource in the project (except addons) and reports failures.

const SKIP_DIRS: PackedStringArray = ["res://addons", "res://.godot", "res://android", "res://build", "res://tools"]
const EXTENSIONS: PackedStringArray = ["gd", "tscn", "tres"]

var _failures: int = 0
var _checked: int = 0


func _initialize() -> void:
	_scan("res://")
	print("check_resources: %d checked, %d failed" % [_checked, _failures])
	quit(1 if _failures > 0 else 0)


func _scan(dir_path: String) -> void:
	for skip: String in SKIP_DIRS:
		if dir_path.trim_suffix("/") == skip:
			return
	for file_name: String in DirAccess.get_files_at(dir_path):
		if file_name.get_extension() in EXTENSIONS:
			_check(dir_path.path_join(file_name))
	for sub: String in DirAccess.get_directories_at(dir_path):
		_scan(dir_path.path_join(sub))


func _check(path: String) -> void:
	_checked += 1
	var res: Resource = ResourceLoader.load(path)
	if res == null:
		_failures += 1
		printerr("FAILED to load: ", path)
