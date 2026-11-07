extends GutTest

const TUNING: StatTuning = preload("res://data/balancing/stat_tuning.tres")

var tracker: SecretTracker
var runner: DialogRunner
var marrow: NpcData = load("res://data/dialogs/marrow.tres") as NpcData
var appraiser: NpcData = load("res://data/dialogs/appraiser.tres") as NpcData


func before_each() -> void:
	GameState.player = null
	GameState.new_game(&"vanguard", TUNING)
	GameState.inventory.add(&"bread", 5)
	tracker = SecretTracker.new()
	add_child_autofree(tracker)
	tracker.set_physics_process(false)
	runner = DialogRunner.new(tracker)


func _ctx() -> SecretContext:
	return tracker.make_context()


func test_all_npc_data_loads_and_is_translated() -> void:
	TranslationServer.set_locale("en")
	for file: String in DirAccess.get_files_at("res://data/dialogs/"):
		if not file.ends_with(".tres"):
			continue
		var npc: NpcData = load("res://data/dialogs/" + file) as NpcData
		assert_not_null(npc, file)
		assert_ne(tr(npc.display_name), String(npc.display_name), "%s name translated" % file)
		for entry: DialogEntry in npc.entries:
			for key: StringName in entry.lines + entry.daily_variants:
				assert_ne(tr(key), String(key), "%s line %s translated" % [file, key])


func test_marrow_default_offers_bread() -> void:
	var entry: DialogEntry = runner.pick_entry(marrow, _ctx())
	assert_eq(entry.id, &"default")
	var choices: Array[DialogChoice] = DialogRunner.available_choices(entry, _ctx(), GameState.gold)
	assert_eq(choices.size(), 1)


func test_marrow_says_something_different_each_day() -> void:
	var entry: DialogEntry = runner.pick_entry(marrow, _ctx())
	assert_ne(DialogRunner.lines_for(entry, 1)[0], DialogRunner.lines_for(entry, 2)[0])


func test_feeding_marrow_three_days_starts_the_mission() -> void:
	var entry: DialogEntry = runner.pick_entry(marrow, _ctx())
	var give: DialogChoice = DialogRunner.available_choices(entry, _ctx(), 0)[0]
	for day: int in 3:
		runner.choose(give)
		GameState.clock.total_minutes += WorldClock.MINUTES_PER_DAY
	tracker.evaluate_all()
	assert_true(tracker.is_found(&"SM-R1-01:1"))
	assert_eq(GameState.inventory.count_of(&"bread"), 2)


func test_marrow_gives_license_only_at_night() -> void:
	GameState.secrets.found[&"SM-R1-01:1"] = true
	GameState.clock.set_time_of_day(12, 0)
	assert_eq(runner.pick_entry(marrow, _ctx()).id, &"stage1_day")
	GameState.clock.set_time_of_day(22, 0)
	var entry: DialogEntry = runner.pick_entry(marrow, _ctx())
	assert_eq(entry.id, &"stage2_night")
	runner.apply(entry.on_show)
	assert_true(GameState.inventory.has(&"rusted_license"))
	assert_true(tracker.is_found(&"SM-R1-01:2"))


func test_honest_appraisal_completes_stage_3() -> void:
	GameState.secrets.found[&"SM-R1-01:2"] = true
	GameState.inventory.add(&"rusted_license")
	GameState.gold = 50
	var entry: DialogEntry = runner.pick_entry(appraiser, _ctx())
	var choices: Array[DialogChoice] = DialogRunner.available_choices(entry, _ctx(), GameState.gold)
	assert_eq(choices.size(), 1)
	runner.choose(choices[0])
	assert_eq(GameState.gold, 40)
	tracker.evaluate_all()
	assert_true(tracker.is_found(&"SM-R1-01:3"))
	assert_true(&"listener" in GameState.secrets.titles)


func test_appraiser_cannot_fix_codex_identification() -> void:
	GameState.inventory.add(&"rusted_license")
	GameState.inventory.identify(GameState.inventory.first_stack(&"rusted_license"), &"codex")
	var entry: DialogEntry = runner.pick_entry(appraiser, _ctx())
	assert_eq(DialogRunner.available_choices(entry, _ctx(), 99).size(), 0)


func test_dialog_shows_record_hints() -> void:
	var entry: DialogEntry = runner.pick_entry(marrow, _ctx())
	runner.apply(entry.on_show)
	assert_true(GameState.secrets.hints.has(&"SM-R1-01:1"))
