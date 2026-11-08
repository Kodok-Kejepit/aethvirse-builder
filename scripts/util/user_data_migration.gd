class_name UserDataMigration
extends RefCounted
## The game was renamed, and Godot keeps player data in a folder named after the game.
## On first start under the new name, settings and saves are copied over from the old
## folder (desktop only: on Android the new package id is a separate app).

## The game's previous name, i.e. the old data folder. Only used to find old saves.
const LEGACY_FOLDER: String = "ASCENDANT"
const FILES: PackedStringArray = ["settings.cfg"]
const DIRS: PackedStringArray = ["saves"]


## Copies what is missing here from the legacy folder. Returns the number of files copied.
static func run(user_dir: String = OS.get_user_data_dir()) -> int:
	var legacy: String = user_dir.get_base_dir().path_join(LEGACY_FOLDER)
	if user_dir.get_file() == LEGACY_FOLDER or not DirAccess.dir_exists_absolute(legacy):
		return 0
	var copied: int = 0
	for file: String in FILES:
		copied += _copy_if_missing(legacy.path_join(file), user_dir.path_join(file))
	for dir: String in DIRS:
		var from: String = legacy.path_join(dir)
		if not DirAccess.dir_exists_absolute(from):
			continue
		DirAccess.make_dir_recursive_absolute(user_dir.path_join(dir))
		for file: String in DirAccess.get_files_at(from):
			copied += _copy_if_missing(from.path_join(file), user_dir.path_join(dir).path_join(file))
	return copied


static func _copy_if_missing(from: String, to: String) -> int:
	if not FileAccess.file_exists(from) or FileAccess.file_exists(to):
		return 0
	return 1 if DirAccess.copy_absolute(from, to) == OK else 0
