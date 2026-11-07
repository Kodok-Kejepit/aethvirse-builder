extends GutTest

const TUNING: StatTuning = preload("res://data/balancing/stat_tuning.tres")
const TEST_DIR: String = "user://test_saves"

var _original_dir: String


func before_each() -> void:
	_original_dir = SaveManager.save_dir
	SaveManager.save_dir = TEST_DIR
	GameState.player = null
	GameState.new_game(&"vanguard", TUNING)


func after_each() -> void:
	for slot: String in SaveManager.MANUAL_SLOTS + [SaveManager.AUTOSAVE_SLOT]:
		SaveManager.delete_slot(slot)
	SaveManager.save_dir = _original_dir
	SaveManager.unregister_provider("test")


func test_game_state_roundtrip() -> void:
	GameState.progression.add_xp(1000)
	GameState.progression.allocate(StatBlock.Stat.AGI, 2)
	GameState.skill_levels[&"rending_slash"] = 4
	GameState.skill_slots = [&"rending_slash", &"", &"", &"", &""]
	GameState.gold = 77
	GameState.set_flag(&"met_marrow")
	GameState.playtime_s = 123.0
	var level_before: int = GameState.progression.level
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict()))
	GameState.new_game(&"vanguard", TUNING)
	GameState.load_dict(data, TUNING)
	assert_eq(GameState.progression.level, level_before)
	assert_gt(level_before, 1)
	assert_eq(GameState.progression.allocated.agility, 2.0)
	var slash: int = GameState.skill_levels.get(&"rending_slash", 0)
	assert_eq(slash, 4)
	assert_eq(GameState.skill_slots[0], &"rending_slash")
	assert_eq(GameState.gold, 77)
	assert_true(GameState.has_flag(&"met_marrow"))
	assert_eq(GameState.playtime_s, 123.0)


func test_file_roundtrip_with_provider() -> void:
	var store: Dictionary = {"value": 41}
	SaveManager.register_provider("test", func() -> Dictionary: return {"value": store["value"]},
		func(d: Dictionary) -> void:
			var v: int = d["value"]
			store["value"] = v)
	GameState.gold = 10
	assert_eq(SaveManager.save_slot("slot_2"), OK)
	assert_true(SaveManager.has_slot("slot_2"))
	store["value"] = 0
	GameState.gold = 0
	SaveManager.apply_save(SaveManager.read_slot("slot_2"))
	assert_eq(GameState.gold, 10)
	var restored: int = store["value"]
	assert_eq(restored, 41)
	var info: Dictionary = SaveManager.slot_info("slot_2")
	var level: int = info.get("level", 0)
	assert_eq(level, 1)


func test_missing_slot() -> void:
	assert_false(SaveManager.has_slot("slot_3"))
	assert_true(SaveManager.read_slot("slot_3").is_empty())


func test_migrates_v0_saves() -> void:
	var v0: Dictionary = {"class_id": "vanguard", "gold": 5}
	var migrated: Dictionary = SaveManager.migrate(v0)
	var schema: int = migrated["schema"]
	assert_eq(schema, SaveManager.SCHEMA_VERSION)
	var state: Dictionary = migrated["game_state"]
	var gold: int = state["gold"]
	assert_eq(gold, 5)


func test_provider_data_waits_for_late_registration() -> void:
	var data: Dictionary = SaveManager.build_save()
	data["providers"] = {"test": {"value": 9}}
	SaveManager.apply_save(data)
	var store: Dictionary = {"value": 0}
	SaveManager.register_provider("test", func() -> Dictionary: return store,
		func(d: Dictionary) -> void:
			var v: int = d["value"]
			store["value"] = v)
	var late: int = store["value"]
	assert_eq(late, 9)
