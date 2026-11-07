class_name DebugConsole
extends CanvasLayer
## Debug-only cheat console (` / ~). Pauses the game while open.
## Systems register commands with DebugConsole.register(name, callable, help).
## Commands can also run at startup: `-- --exec="tp -30 0 25;god;wait 3;press codex"`.

const TOGGLE_ACTION: StringName = &"debug_console"
const EXEC_ARG: String = "--exec="
const EXEC_DELAY_S: float = 0.5
const MAX_LOG_LINES: int = 200

static var _commands: Dictionary[String, Callable] = {}
static var _help: Dictionary[String, String] = {}

@onready var _panel: Control = %ConsolePanel
@onready var _log: RichTextLabel = %ConsoleLog
@onready var _input: LineEdit = %ConsoleInput

var _was_paused: bool = false
var _mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _history: PackedStringArray = []


static func register(command: String, callable: Callable, help: String) -> void:
	_commands[command] = callable
	_help[command] = help


static func unregister(command: String) -> void:
	_commands.erase(command)
	_help.erase(command)


## Runs a command line; returns the output text. Static so tests can call it.
static func run(line: String) -> String:
	var parts: PackedStringArray = line.strip_edges().split(" ", false)
	if parts.is_empty():
		return ""
	var command: String = parts[0].to_lower()
	if command == "help":
		var lines: PackedStringArray = []
		var names: Array[String] = _commands.keys()
		names.sort()
		for cmd: String in names:
			lines.append("%s — %s" % [cmd, _help[cmd]])
		return "\n".join(lines)
	if not _commands.has(command):
		return "Unknown command '%s' (try help)" % command
	var args: PackedStringArray = parts.slice(1)
	var result: Variant = _commands[command].call(args)
	return str(result) if result != null else "ok"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	_input.text_submitted.connect(_on_submitted)
	DebugCommands.register_core()
	var exec: String = _exec_arg()
	if not exec.is_empty():
		await get_tree().create_timer(EXEC_DELAY_S).timeout
		for line: String in exec.split(";", false):
			if line.strip_edges().begins_with("wait "):
				await get_tree().create_timer(line.strip_edges().substr(5).to_float(), true, false, true).timeout
				continue
			_print("> " + line + "\n" + run(line))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(TOGGLE_ACTION):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		_was_paused = get_tree().paused
		_mouse_mode = Input.mouse_mode
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_input.clear()
		_input.grab_focus()
	else:
		get_tree().paused = _was_paused
		Input.mouse_mode = _mouse_mode


func _on_submitted(text: String) -> void:
	_input.clear()
	if text.strip_edges() == "":
		return
	_history.append(text)
	_print("> " + text + "\n" + run(text))


func _print(text: String) -> void:
	_log.append_text(text + "\n")
	while _log.get_paragraph_count() > MAX_LOG_LINES:
		_log.remove_paragraph(0)
	print("[console] ", text)


static func _exec_arg() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(EXEC_ARG):
			return arg.trim_prefix(EXEC_ARG)
	return ""
