extends GutTest
## Models left out of every export (export_presets.cfg exclude_filter: test-only likenesses,
## e.g. the old statue) must not be used by any scene or data file that ships.

const SCAN_DIRS: PackedStringArray = ["res://scenes", "res://data"]


func test_excluded_props_are_not_placed_anywhere() -> void:
	var ids: PackedStringArray = _excluded_prop_ids()
	assert_gt(ids.size(), 0, "export presets exclude at least one test-only model")
	var hits: PackedStringArray = []
	for dir: String in SCAN_DIRS:
		_scan(dir, ids, hits)
	assert_eq(hits, PackedStringArray(), "excluded models still used: %s" % ", ".join(hits))


func _excluded_prop_ids() -> PackedStringArray:
	var out: PackedStringArray = []
	var cfg: ConfigFile = ConfigFile.new()
	assert_eq(cfg.load("res://export_presets.cfg"), OK)
	for section: String in cfg.get_sections():
		var filter: String = cfg.get_value(section, "exclude_filter", "")
		for raw: String in filter.split(",", false):
			var path: String = raw.strip_edges()
			if path.begins_with("assets/props/") and path.ends_with("/*"):
				var id: String = path.trim_prefix("assets/props/").trim_suffix("/*")
				if not out.has(id):
					out.append(id)
	return out


func _scan(dir: String, ids: PackedStringArray, hits: PackedStringArray) -> void:
	for sub: String in DirAccess.get_directories_at(dir):
		_scan(dir.path_join(sub), ids, hits)
	for file: String in DirAccess.get_files_at(dir):
		if not (file.ends_with(".tscn") or file.ends_with(".tres")):
			continue
		var text: String = FileAccess.get_file_as_string(dir.path_join(file))
		for id: String in ids:
			# The excluded model's own PropData sits in data/props and is excluded too.
			if file == id + ".tres":
				continue
			if text.contains("\"%s\"" % id):
				hits.append("%s (%s)" % [dir.path_join(file), id])
