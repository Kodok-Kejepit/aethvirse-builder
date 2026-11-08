extends Node
## Save/load: 3 manual slots + autosave, gzip-compressed JSON with schema version + migrations.
## Data comes from GameState plus registered providers (inventory, quests, secrets, world...).

signal saved(slot: String)
signal loaded(slot: String)

const SCHEMA_VERSION: int = 1
const SAVE_DIR: String = "user://saves"
const AUTOSAVE_SLOT: String = "autosave"
const MANUAL_SLOTS: Array[String] = ["slot_1", "slot_2", "slot_3"]
const AUTOSAVE_INTERVAL_S: float = 300.0
const TUNING: StatTuning = preload("res://data/balancing/stat_tuning.tres")
const GAME_SCENE: String = "res://scenes/main/game.tscn"

## key -> {"save": Callable() -> Dictionary, "load": Callable(Dictionary) -> void}
var _providers: Dictionary[String, Dictionary] = {}
var _autosave_timer: float = 0.0
## Provider data read from a save, applied when the provider registers (after a scene reload).
var _pending_provider_data: Dictionary = {}
var save_dir: String = SAVE_DIR


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.autosave_requested.connect(func() -> void: autosave())
	get_tree().auto_accept_quit = true


## Android sends this when the app goes to the background (it may be killed after):
## save right away so nothing is lost.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and GameState.player != null:
		autosave()


func _process(delta: float) -> void:
	if GameState.player == null or get_tree().paused:
		return
	_autosave_timer += delta
	if _autosave_timer >= AUTOSAVE_INTERVAL_S:
		autosave()


func register_provider(key: String, save_fn: Callable, load_fn: Callable) -> void:
	_providers[key] = {"save": save_fn, "load": load_fn}
	if _pending_provider_data.has(key):
		var data: Dictionary = _pending_provider_data[key]
		_pending_provider_data.erase(key)
		load_fn.call(data)


func unregister_provider(key: String) -> void:
	_providers.erase(key)


func autosave() -> Error:
	_autosave_timer = 0.0
	return save_slot(AUTOSAVE_SLOT, false)


## Builds the full save dictionary (also used by tests).
func build_save() -> Dictionary:
	var providers: Dictionary = {}
	for key: String in _providers:
		var save_fn: Callable = _providers[key]["save"]
		providers[key] = save_fn.call()
	var prog: Progression = GameState.progression
	return {
		"schema": SCHEMA_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"summary": {
			"class_id": String(GameState.class_id),
			"hero_id": String(GameState.hero_id),
			"level": prog.level if prog != null else 1,
			"playtime_s": GameState.playtime_s,
		},
		"game_state": GameState.to_dict(),
		"providers": providers,
	}


func save_slot(slot: String, announce: bool = true) -> Error:
	DirAccess.make_dir_recursive_absolute(save_dir)
	var err: Error = SaveFile.write(_path(slot), JSON.stringify(build_save()))
	if err != OK:
		push_error("SaveManager: cannot write %s (%s)" % [_path(slot), error_string(err)])
		return err
	saved.emit(slot)
	if announce:
		Codex.notify(tr(&"CODEX_MSG_SAVED"), &"info")
	return OK


func read_slot(slot: String) -> Dictionary:
	for path: String in [_path(slot), _path(slot) + ".bak"]:
		var text: String = SaveFile.read(path)
		if text.is_empty():
			continue
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			var data: Dictionary = parsed
			return migrate(data)
	return {}


## Applies a save dictionary to GameState and queues provider data. Does not change scene.
func apply_save(data: Dictionary) -> void:
	var state: Dictionary = data.get("game_state", {})
	GameState.load_dict(state, TUNING)
	var providers: Dictionary = data.get("providers", {})
	_pending_provider_data = providers.duplicate(true)
	for key: String in _providers.keys():
		if _pending_provider_data.has(key):
			var load_fn: Callable = _providers[key]["load"]
			var provider_data: Dictionary = _pending_provider_data[key]
			_pending_provider_data.erase(key)
			load_fn.call(provider_data)


## Loads a slot and restarts the game scene with that state.
func load_slot(slot: String) -> Error:
	var data: Dictionary = read_slot(slot)
	if data.is_empty():
		return ERR_FILE_NOT_FOUND
	get_tree().paused = false
	apply_save(data)
	_autosave_timer = 0.0
	LoadingScreen.go(get_tree(), region_scene(GameState.current_region))
	loaded.emit(slot)
	return OK


## Scene of a region (falls back to the starting region).
func region_scene(region_id: StringName) -> String:
	var region: RegionData = RegionData.load_region(region_id)
	if region != null and region.scene_path != "":
		return region.scene_path
	return GAME_SCENE


func has_slot(slot: String) -> bool:
	return not SaveFile.read(_path(slot)).is_empty() or not SaveFile.read(_path(slot) + ".bak").is_empty()


func delete_slot(slot: String) -> void:
	for path: String in [_path(slot), _path(slot) + ".bak", _path(slot) + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## Most recently saved readable slot, or "".
func latest_slot() -> String:
	var latest: String = ""
	var latest_time: float = -1.0
	for slot: String in MANUAL_SLOTS + [AUTOSAVE_SLOT]:
		var info: Dictionary = slot_info(slot)
		var saved_at: float = info.get("saved_at", -1.0)
		if not info.is_empty() and saved_at > latest_time:
			latest = slot
			latest_time = saved_at
	return latest


## Small info for slot lists: {"level", "class_id", "playtime_s", "saved_at"} or {}.
func slot_info(slot: String) -> Dictionary:
	var data: Dictionary = read_slot(slot)
	if data.is_empty():
		return {}
	var summary: Dictionary = data.get("summary", {})
	var info: Dictionary = summary.duplicate()
	info["saved_at"] = data.get("saved_at", 0.0)
	return info


## Upgrades older save dictionaries step by step to SCHEMA_VERSION.
func migrate(data: Dictionary) -> Dictionary:
	var version: int = data.get("schema", 0)
	if version < 1:
		# v0 (pre-release prototype) stored GameState at the root and had no providers.
		data = {"schema": 1, "saved_at": data.get("saved_at", 0.0), "summary": {},
			"game_state": data, "providers": {}}
		version = 1
	data["schema"] = version
	return data


func _path(slot: String) -> String:
	return save_dir.path_join(slot + ".save")
