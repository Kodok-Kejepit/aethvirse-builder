extends Label
## HUD "[E] Talk to Marrow" style prompt.

const KEY_HINT: String = "[E]"


func _ready() -> void:
	text = ""
	EventBus.interaction_prompt_changed.connect(func(prompt: String) -> void:
		text = "" if prompt == "" else ("%s  %s" % [KEY_HINT, prompt] if not Settings.wants_touch_controls() else prompt))
