class_name DebugCapture
extends Node
## Debug-only automated screenshot: run the game with
##   -- --capture=/abs/path.png [--capture-delay=4.0] [--capture-overlay]
## It saves one frame after the delay and quits. Used to verify builds (Linux, Wine) headlessly.

const ARG_PATH: String = "--capture="
const ARG_DELAY: String = "--capture-delay="
const ARG_OVERLAY: String = "--capture-overlay"
const DEFAULT_DELAY_S: float = 4.0

signal overlay_requested


static func parse_path(args: PackedStringArray) -> String:
	for arg: String in args:
		if arg.begins_with(ARG_PATH):
			return arg.trim_prefix(ARG_PATH)
	return ""


static func parse_delay(args: PackedStringArray) -> float:
	for arg: String in args:
		if arg.begins_with(ARG_DELAY) and arg.trim_prefix(ARG_DELAY).is_valid_float():
			return arg.trim_prefix(ARG_DELAY).to_float()
	return DEFAULT_DELAY_S


func start(args: PackedStringArray) -> void:
	var path: String = parse_path(args)
	if path.is_empty():
		return
	if ARG_OVERLAY in args:
		overlay_requested.emit()
	# Real time: hit-stop / slow motion must not hold the shot back.
	await get_tree().create_timer(parse_delay(args), true, false, true).timeout
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var err: Error = image.save_png(path)
	print("DebugCapture: saved %s (%s)" % [path, error_string(err)])
	get_tree().quit(0 if err == OK else 1)
