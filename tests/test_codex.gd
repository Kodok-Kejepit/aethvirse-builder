extends GutTest


func before_each() -> void:
	Codex.clear_history()


func test_notify_records_history_and_emits() -> void:
	watch_signals(EventBus)
	Codex.notify("Gate detected", &"warning")
	assert_eq(Codex.history.size(), 1)
	var text: String = Codex.history[0]["text"]
	assert_eq(text, "Gate detected")
	assert_signal_emitted(EventBus, "codex_message")


func test_unknown_kind_falls_back_to_info() -> void:
	Codex.notify("hello", &"nonsense")
	var kind: int = Codex.history[0]["kind"]
	assert_eq(kind, Codex.Kind.INFO)


func test_anomaly_keeps_clean_text() -> void:
	Codex.anomaly("the archive remembers", 0.5)
	var shown: String = Codex.history[0]["text"]
	var clean: String = Codex.history[0]["clean"]
	assert_eq(clean, "the archive remembers")
	assert_ne(shown, clean)
	assert_eq(shown.length(), clean.length())


func test_glitch_is_deterministic_and_respects_intensity() -> void:
	assert_eq(CodexText.glitch("abc def", 0.0), "abc def")
	assert_eq(CodexText.glitch("abc def", 0.6, 42), CodexText.glitch("abc def", 0.6, 42))
	var full: String = CodexText.glitch("abcdef", 1.0, 1)
	for c: String in full.split(""):
		assert_true(c in CodexText.GLITCH_CHARS)


func test_synth_generates_audio() -> void:
	for id: StringName in [&"ding", &"level_up", &"anomaly", &"error", &"hit"]:
		var stream: AudioStreamWAV = Synth.make(id)
		assert_gt(stream.data.size(), 1000, String(id))
		assert_gt(stream.get_length(), 0.1, String(id))


func test_audio_buses_exist() -> void:
	for bus: String in ["BGM", "SFX", "Voice", "UI"]:
		assert_ne(AudioServer.get_bus_index(bus), -1, bus)


func test_codex_panel_pauses_and_resumes() -> void:
	var panel: CodexPanel = CodexPanel.new()
	add_child_autofree(panel)
	var fake_player: Node3D = Node3D.new()
	add_child_autofree(fake_player)
	GameState.player = null
	panel.open()
	assert_false(panel.is_open(), "no player → no Codex")
	GameState.player = fake_player
	panel._status.set_process(false)
	panel._root.visible = false
	panel._was_paused = false
	get_tree().paused = true
	panel._root.visible = true
	panel.close()
	assert_false(get_tree().paused, "closing restores pause state")
	GameState.player = null


func test_status_refresh_is_coalesced() -> void:
	var tab: CodexStatusTab = CodexStatusTab.new()
	add_child_autofree(tab)
	tab.refresh()
	tab.refresh()
	tab.refresh()
	assert_true(tab._refresh_queued, "one rebuild queued, not three")
	await wait_process_frames(2)
	assert_false(tab._refresh_queued)
