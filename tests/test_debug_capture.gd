extends GutTest


func test_parse_path_found() -> void:
	assert_eq(DebugCapture.parse_path(["--foo", "--capture=/tmp/a.png"]), "/tmp/a.png")


func test_parse_path_missing() -> void:
	assert_eq(DebugCapture.parse_path(["--foo"]), "")


func test_parse_delay_default_and_custom() -> void:
	assert_eq(DebugCapture.parse_delay([]), DebugCapture.DEFAULT_DELAY_S)
	assert_eq(DebugCapture.parse_delay(["--capture-delay=2.5"]), 2.5)
	assert_eq(DebugCapture.parse_delay(["--capture-delay=abc"]), DebugCapture.DEFAULT_DELAY_S)
