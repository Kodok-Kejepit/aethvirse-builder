extends GutTest
## Mystery Journal pages per region: completing every R1 entry finishes the page, opens
## the road on, and a failed sealed mission never blocks the page.

const TUNING: StatTuning = preload("res://data/balancing/stat_tuning.tres")

var tracker: SecretTracker


func before_each() -> void:
	GameState.player = null
	GameState.new_game(&"vanguard", TUNING)
	tracker = SecretTracker.new()
	add_child_autofree(tracker)
	tracker.set_physics_process(false)


func _resolve_all_but(region: StringName, keep: StringName) -> void:
	for entry: Dictionary in RegionJournal.entries(tracker.db, region):
		if entry["id"] == keep:
			continue
		var list: Array[SecretData] = entry["secrets"]
		for secret: SecretData in list:
			GameState.secrets.found[secret.id] = true


func test_r1_page_lists_real_entries() -> void:
	var p: Vector2i = RegionJournal.progress(tracker.db, &"r1_ashfall", GameState.secrets)
	assert_eq(p, Vector2i(0, 16), "13 secrets + 3 sealed missions")
	assert_eq(RegionJournal.current_page(), &"r1_ashfall")


func test_finishing_the_page_sets_the_flag_once() -> void:
	_resolve_all_but(&"r1_ashfall", &"")
	assert_true(RegionJournal.is_complete(tracker.db, &"r1_ashfall", GameState.secrets))
	assert_true(JournalCompletion.check(tracker, &"r1_ashfall"))
	assert_true(GameState.has_flag(RegionJournal.flag_for(&"r1_ashfall")))
	assert_false(JournalCompletion.check(tracker, &"r1_ashfall"), "runs once")
	for node: Node in tracker.get_children():
		if node is JournalCompletion:
			node.queue_free()
	assert_eq(RegionJournal.current_page(), &"r2_verdant")


func test_page_not_done_while_one_entry_is_open() -> void:
	_resolve_all_but(&"r1_ashfall", &"SM-R1-02")
	assert_false(JournalCompletion.check(tracker, &"r1_ashfall"))
	assert_false(GameState.has_flag(RegionJournal.flag_for(&"r1_ashfall")))


func test_a_failed_sealed_mission_closes_its_entry() -> void:
	_resolve_all_but(&"r1_ashfall", &"SM-R1-01")
	GameState.secrets.failed[&"SM-R1-01:1"] = true
	assert_true(RegionJournal.is_complete(tracker.db, &"r1_ashfall", GameState.secrets))


func test_road_to_region_2_waits_for_the_page() -> void:
	assert_false(RegionJournal.road_open(&"r2_verdant"))
	assert_true(RegionJournal.road_open(&"r1_ashfall"), "roads back are always open")
	GameState.set_flag(RegionJournal.flag_for(&"r1_ashfall"))
	assert_true(RegionJournal.road_open(&"r2_verdant"))
	assert_eq(RegionJournal.entry_waystone(&"r2_verdant"), &"r2_glade")
