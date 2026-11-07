extends GutTest
## Every UI/data string key exists in strings.csv with both English and Indonesian text.

const CSV_PATH: String = "res://assets/localization/strings.csv"
const SCAN_DIRS: Array[String] = ["res://scripts", "res://data"]
## Keys referenced as &"UPPER_CASE" in code/data that are not translation keys.
const NOT_KEYS: Array[String] = ["SEC-", "SM-", "MC-", "SI-", "LORE-"]

var _rows: Dictionary[String, PackedStringArray] = {}


func before_all() -> void:
	var f: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	f.get_csv_line()
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() >= 1 and row[0] != "":
			_rows[row[0]] = row


func test_rows_are_complete_and_unique() -> void:
	var f: FileAccess = FileAccess.open(CSV_PATH, FileAccess.READ)
	f.get_csv_line()
	var seen: Dictionary[String, bool] = {}
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() == 0 or row[0] == "":
			continue
		assert_false(seen.has(row[0]), "duplicate key %s" % row[0])
		seen[row[0]] = true
		assert_eq(row.size(), 3, "%s has en + id" % row[0])
		if row.size() == 3:
			assert_ne(row[1].strip_edges(), "", "%s en" % row[0])
			assert_ne(row[2].strip_edges(), "", "%s id" % row[0])


func test_referenced_keys_exist() -> void:
	var regex: RegEx = RegEx.new()
	regex.compile("&\"([A-Z][A-Z0-9_]{3,})\"")
	var missing: PackedStringArray = PackedStringArray()
	for dir: String in SCAN_DIRS:
		for path: String in _files(dir):
			var text: String = FileAccess.get_file_as_string(path)
			for m: RegExMatch in regex.search_all(text):
				var key: String = m.get_string(1)
				if _rows.has(key) or _ignored(key) or missing.has(key):
					continue
				missing.append("%s (%s)" % [key, path.get_file()])
	assert_eq(missing.size(), 0, "missing keys: %s" % ", ".join(missing))


func _ignored(key: String) -> bool:
	for p: String in NOT_KEYS:
		if key.begins_with(p):
			return true
	return false


func _files(dir: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return out
	for sub: String in d.get_directories():
		out.append_array(_files(dir.path_join(sub)))
	for file: String in d.get_files():
		if file.ends_with(".gd") or file.ends_with(".tres"):
			out.append(dir.path_join(file))
	return out
