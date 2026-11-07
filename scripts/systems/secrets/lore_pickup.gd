class_name LorePickup
extends Node3D
## A readable note/diary/mural. Reading records the lore (Codex → Lore), optionally a hint.

@export var lore_id: StringName = &""
@export var hint_secret: StringName = &""
@export var hint_key: StringName = &""

@onready var interactable: Interactable = %Interactable


func _ready() -> void:
	interactable.prompt_key = &"PROMPT_READ"
	interactable.interacted.connect(_read)


func _read(_player: Player) -> void:
	var tracker: SecretTracker = SecretTracker.find(self)
	var box: DialogBox = DialogBox.find(self)
	if tracker == null:
		return
	var lore: LoreData = tracker.db.lore.get(lore_id, null)
	if lore != null and not lore_id in GameState.secrets.lore:
		var reward: RewardData = RewardData.new()
		reward.type = RewardData.Type.LORE
		reward.key = lore_id
		tracker.grant(reward)
	if hint_secret != &"":
		tracker.discover_hint(hint_secret, hint_key)
	if box != null and lore != null:
		box.open(tr(lore.title), [tr(lore.text)] as Array[String], [] as Array[DialogChoice], Callable())
