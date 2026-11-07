extends GutTest


func before_all() -> void:
	DebugCommands.register_core()


func test_unknown_command() -> void:
	assert_string_contains(DebugConsole.run("nope"), "Unknown command")


func test_help_lists_core_commands() -> void:
	var help: String = DebugConsole.run("help")
	for cmd: String in ["tp", "god", "heal", "spawn", "kill_all", "timescale"]:
		assert_string_contains(help, cmd)


func test_custom_command_receives_args() -> void:
	DebugConsole.register("echo_test", func(args: PackedStringArray) -> String: return "|".join(args), "test")
	assert_eq(DebugConsole.run("echo_test a b"), "a|b")
	DebugConsole.unregister("echo_test")


func test_timescale_is_clamped() -> void:
	DebugConsole.run("timescale 99")
	assert_eq(Engine.time_scale, 4.0)
	DebugConsole.run("timescale 1")
	assert_eq(Engine.time_scale, 1.0)
