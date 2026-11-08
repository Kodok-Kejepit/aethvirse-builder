extends GutTest
## Renamed game: old settings and saves are copied into the new data folder once.

const ROOT: String = "user://migration_test"


func before_each() -> void:
	_wipe(ProjectSettings.globalize_path(ROOT))
	var legacy: String = ProjectSettings.globalize_path(ROOT).path_join(UserDataMigration.LEGACY_FOLDER)
	DirAccess.make_dir_recursive_absolute(legacy.path_join("saves"))
	_write(legacy.path_join("settings.cfg"), "old settings")
	_write(legacy.path_join("saves/slot_1.json"), "old save")


func after_all() -> void:
	_wipe(ProjectSettings.globalize_path(ROOT))


func test_copies_settings_and_saves_into_the_new_folder() -> void:
	var fresh: String = ProjectSettings.globalize_path(ROOT).path_join("AETHVIRSE")
	DirAccess.make_dir_recursive_absolute(fresh)
	assert_eq(UserDataMigration.run(fresh), 2)
	assert_eq(FileAccess.get_file_as_string(fresh.path_join("settings.cfg")), "old settings")
	assert_eq(FileAccess.get_file_as_string(fresh.path_join("saves/slot_1.json")), "old save")


func test_never_overwrites_newer_data() -> void:
	var fresh: String = ProjectSettings.globalize_path(ROOT).path_join("AETHVIRSE")
	DirAccess.make_dir_recursive_absolute(fresh)
	_write(fresh.path_join("settings.cfg"), "new settings")
	assert_eq(UserDataMigration.run(fresh), 1)
	assert_eq(FileAccess.get_file_as_string(fresh.path_join("settings.cfg")), "new settings")
	assert_eq(UserDataMigration.run(fresh), 0, "second start copies nothing")


func _write(path: String, text: String) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _wipe(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for d: String in DirAccess.get_directories_at(path):
		_wipe(path.path_join(d))
	for f: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(f))
	DirAccess.remove_absolute(path)
