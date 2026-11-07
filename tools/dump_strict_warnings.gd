extends SceneTree
## Writes override.cfg that promotes every GDScript warning currently set to WARN into ERROR.
## Used by tools/validate.sh so headless runs fail on script warnings.

const PREFIX: String = "debug/gdscript/warnings/"
const LEVEL_WARN: int = 1
const LEVEL_ERROR: int = 2


func _initialize() -> void:
	var lines: PackedStringArray = ["[debug]", ""]
	for prop: Dictionary in ProjectSettings.get_property_list():
		var key: String = prop["name"]
		var value: Variant = ProjectSettings.get_setting(key)
		if key.begins_with(PREFIX) and value is int and value == LEVEL_WARN:
			lines.append("%s=%d" % [key.trim_prefix("debug/"), LEVEL_ERROR])
	var file: FileAccess = FileAccess.open("res://override.cfg", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	quit(0)
