class_name Keybinds
extends RefCounted
## Keyboard / mouse bindings the player can change in Settings. Bindings are stored as
## short codes ("k:<physical keycode>", "m:<mouse button>"); gamepad events in the
## InputMap are never touched.

## Rebindable actions, in the order the Settings list shows them.
const ACTIONS: Array[StringName] = [
	&"move_forward", &"move_back", &"move_left", &"move_right", &"jump", &"sprint", &"dodge",
	&"attack_light", &"attack_heavy", &"skill_1", &"skill_2", &"skill_3", &"skill_4", &"ultimate",
	&"lock_on", &"interact", &"use_potion", &"codex", &"inventory", &"map",
]
## Bindings per action shown in Settings (primary + secondary).
const SLOTS: int = 2
## Actions whose mouse bindings follow the "attack with mouse click" setting.
const MOUSE_ATTACK_ACTIONS: Array[StringName] = [&"attack_light", &"attack_heavy"]


static func encode(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: InputEventKey = event
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return "k:%d" % code
	if event is InputEventMouseButton:
		return "m:%d" % (event as InputEventMouseButton).button_index
	return ""


static func decode(code: String) -> InputEvent:
	var value: int = code.substr(2).to_int()
	if code.begins_with("k:"):
		var key: InputEventKey = InputEventKey.new()
		key.physical_keycode = value as Key
		return key
	if code.begins_with("m:"):
		var mouse: InputEventMouseButton = InputEventMouseButton.new()
		mouse.button_index = value as MouseButton
		return mouse
	return null


static func is_bindable(event: InputEvent) -> bool:
	if event is InputEventKey:
		return (event as InputEventKey).pressed and not (event as InputEventKey).echo
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		return mb.pressed and mb.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
	return false


## Human-readable name of a code ("W", "Shift", "Mouse L").
static func label(code: String) -> String:
	if code.begins_with("m:"):
		match code.substr(2).to_int():
			MOUSE_BUTTON_LEFT:
				return "Mouse L"
			MOUSE_BUTTON_RIGHT:
				return "Mouse R"
			MOUSE_BUTTON_MIDDLE:
				return "Mouse M"
		return "Mouse %d" % code.substr(2).to_int()
	if code.begins_with("k:"):
		var physical: Key = code.substr(2).to_int() as Key
		var shown: Key = DisplayServer.keyboard_get_keycode_from_physical(physical) if DisplayServer.get_name() != "headless" else physical
		return OS.get_keycode_string(shown if shown != KEY_NONE else physical)
	return "—"


## Keyboard / mouse codes currently bound to an action.
static func current(action: StringName) -> PackedStringArray:
	var out: PackedStringArray = []
	for event: InputEvent in InputMap.action_get_events(action):
		var code: String = encode(event)
		if code != "":
			out.append(code)
	return out


## Replaces the keyboard / mouse bindings of an action (gamepad bindings stay).
static func apply(action: StringName, codes: PackedStringArray, allow_mouse: bool) -> void:
	if not InputMap.has_action(action):
		return
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			InputMap.action_erase_event(action, event)
	for code: String in codes:
		if code.begins_with("m:") and not allow_mouse:
			continue
		var event2: InputEvent = decode(code)
		if event2 != null:
			InputMap.action_add_event(action, event2)


## Binds `code` to slot `slot` of `action` in `binds` (action -> codes), removing it from
## every other action first so one key never does two things.
static func assign(binds: Dictionary, action: StringName, slot: int, code: String) -> void:
	for other: StringName in ACTIONS:
		var codes: PackedStringArray = binds.get(other, PackedStringArray())
		var at: int = codes.find(code)
		if at >= 0 and not (other == action and at == slot):
			codes.remove_at(at)
			binds[other] = codes
	var mine: PackedStringArray = binds.get(action, PackedStringArray())
	if code == "":
		if slot < mine.size():
			mine.remove_at(slot)
	elif slot < mine.size():
		mine[slot] = code
	else:
		mine.append(code)
	binds[action] = mine
