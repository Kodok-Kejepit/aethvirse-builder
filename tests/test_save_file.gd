extends GutTest

const DIR: String = "user://test_save_file"
const PATH: String = DIR + "/slot.save"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	for p: String in [PATH, PATH + ".bak", PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func _corrupt(path: String, keep_bytes: int, flip_at: int = -1) -> void:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	var bytes: PackedByteArray = f.get_buffer(f.get_length())
	f.close()
	if keep_bytes >= 0:
		bytes = bytes.slice(0, keep_bytes)
	if flip_at >= 0 and flip_at < bytes.size():
		bytes[flip_at] = bytes[flip_at] ^ 0xFF
	var w: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	w.store_buffer(bytes)
	w.close()


func test_roundtrip() -> void:
	assert_eq(SaveFile.write(PATH, '{"a": 1}'), OK)
	assert_eq(SaveFile.read(PATH), '{"a": 1}')
	assert_false(FileAccess.file_exists(PATH + ".tmp"), "tmp renamed away")


func test_truncated_file_is_rejected_quickly() -> void:
	SaveFile.write(PATH, JSON.stringify({"big": "x".repeat(5000)}))
	_corrupt(PATH, 40)
	var start: int = Time.get_ticks_msec()
	assert_eq(SaveFile.read(PATH), "")
	assert_lt(Time.get_ticks_msec() - start, 500, "no hang on broken files")


func test_flipped_byte_fails_checksum() -> void:
	SaveFile.write(PATH, JSON.stringify({"gold": 77}))
	_corrupt(PATH, -1, 20)
	assert_eq(SaveFile.read(PATH), "")


func test_foreign_or_legacy_file_is_ignored() -> void:
	var f: FileAccess = FileAccess.open_compressed(PATH, FileAccess.WRITE, FileAccess.COMPRESSION_GZIP)
	f.store_string('{"legacy": true}')
	f.close()
	assert_eq(SaveFile.read(PATH), "")


func test_backup_is_kept_and_used() -> void:
	SaveFile.write(PATH, '{"v": 1}')
	SaveFile.write(PATH, '{"v": 2}')
	assert_eq(SaveFile.read(PATH + ".bak"), '{"v": 1}')
	_corrupt(PATH, 10)
	var original: String = SaveManager.save_dir
	SaveManager.save_dir = DIR
	var data: Dictionary = SaveManager.read_slot("slot")
	SaveManager.save_dir = original
	var state: Dictionary = data.get("game_state", {})
	var v: int = state.get("v", 0)
	assert_eq(v, 1, "falls back to .bak (v0 data is migrated into game_state)")
