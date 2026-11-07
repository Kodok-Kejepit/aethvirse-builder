extends Node
## The Codex "System": notifications (slide-in toasts + ding), message history,
## and the entry point other systems use to talk to the player in the Codex voice.

const TOASTS_SCENE: PackedScene = preload("res://scenes/ui/codex/codex_toasts.tscn")
const MAX_HISTORY: int = 200

enum Kind { INFO, LEVEL_UP, QUEST, SECRET, WARNING, ANOMALY, REWARD }

const KIND_IDS: Dictionary[StringName, Kind] = {
	&"info": Kind.INFO, &"level_up": Kind.LEVEL_UP, &"quest": Kind.QUEST, &"secret": Kind.SECRET,
	&"warning": Kind.WARNING, &"anomaly": Kind.ANOMALY, &"reward": Kind.REWARD,
}
const KIND_SOUNDS: Dictionary[Kind, StringName] = {
	Kind.INFO: &"ding", Kind.LEVEL_UP: &"level_up", Kind.QUEST: &"ding", Kind.SECRET: &"ding",
	Kind.WARNING: &"error", Kind.ANOMALY: &"anomaly", Kind.REWARD: &"ding",
}

## Each entry: {"text": String, "kind": Kind, "time": float (seconds since start)}.
var history: Array[Dictionary] = []
var _toasts: Node = null
## Item icon textures by "glyph:rarity" (ItemIcons draws them once).
var _icons: Dictionary[String, ImageTexture] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_toasts = TOASTS_SCENE.instantiate()
	add_child(_toasts)
	EventBus.level_up.connect(func(level: int) -> void: notify(tr(&"CODEX_MSG_LEVEL_UP") % level, &"level_up"))


func notify(text: String, kind: StringName = &"info") -> void:
	var k: Kind = KIND_IDS.get(kind, Kind.INFO)
	history.append({"text": text, "kind": k, "time": Time.get_ticks_msec() / 1000.0})
	if history.size() > MAX_HISTORY:
		history.pop_front()
	AudioManager.play_ui(KIND_SOUNDS[k])
	EventBus.codex_message.emit(text, kind)


## Shows a corrupted message (meta-mystery clue). The clean text is kept in history.
func anomaly(clean_text: String, intensity: float = 0.35) -> void:
	notify(CodexText.glitch(clean_text, intensity), &"anomaly")
	history[history.size() - 1]["clean"] = clean_text


func clear_history() -> void:
	history.clear()


func item_icon(glyph: StringName, rarity: int) -> Texture2D:
	var key: String = "%s:%d" % [glyph, rarity]
	if not _icons.has(key):
		_icons[key] = ImageTexture.create_from_image(ItemIcons.draw(glyph, rarity))
	return _icons[key]


## Icon for an inventory stack (unidentified items show "?" in white).
func icon_for_stack(stack: ItemStack) -> Texture2D:
	var item: ItemData = GameState.items.get_item(stack.item_id) if GameState.items != null else null
	if item == null or not stack.identified:
		return item_icon(&"unknown", ItemData.Rarity.UNKNOWN)
	return item_icon(ItemIcons.glyph_for(item), ItemStats.rarity_of(stack, item))


func _exit_tree() -> void:
	_icons.clear()
