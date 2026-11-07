class_name HintSign
extends Node3D
## Something readable in the world (graffiti, mailbox label, sign) that is a clue.

@export var text_key: StringName = &""
@export var hint_secret: StringName = &""
@export var hint_key: StringName = &""

@onready var interactable: Interactable = %Interactable


func _ready() -> void:
	interactable.prompt_key = &"PROMPT_READ"
	interactable.interacted.connect(_read)


func _read(_player: Player) -> void:
	var tracker: SecretTracker = SecretTracker.find(self)
	if tracker != null and hint_secret != &"":
		tracker.discover_hint(hint_secret, hint_key if hint_key != &"" else text_key)
	var box: DialogBox = DialogBox.find(self)
	if box != null:
		box.open("", [tr(text_key)] as Array[String], [] as Array[DialogChoice], Callable())
