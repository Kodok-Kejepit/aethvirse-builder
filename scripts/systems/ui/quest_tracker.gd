extends Label
## HUD: tracked quest title + current objective.


func _ready() -> void:
	EventBus.quest_updated.connect(func(_id: StringName) -> void: refresh())
	refresh.call_deferred()


func refresh() -> void:
	var system: QuestSystem = QuestSystem.find(self) if is_inside_tree() else null
	var log_state: QuestLog = GameState.quests
	if system == null or log_state.tracked == &"" or not system.quests.has(log_state.tracked):
		text = ""
		return
	var q: QuestData = system.quests[log_state.tracked]
	text = "%s\n• %s" % [tr(q.title), system.objective_text(q)]
