extends GutTest


func after_each() -> void:
	GameState.world_flags.clear()


func test_flag_defaults_to_false() -> void:
	assert_false(GameState.has_flag(&"never_set"))


func test_set_flag_roundtrip() -> void:
	GameState.set_flag(&"gate_e_cleared")
	assert_true(GameState.has_flag(&"gate_e_cleared"))
	GameState.set_flag(&"gate_e_cleared", false)
	assert_false(GameState.has_flag(&"gate_e_cleared"))
