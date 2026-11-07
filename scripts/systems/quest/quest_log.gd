class_name QuestLog
extends RefCounted
## Saved quest progress. Pure: the QuestSystem node feeds it events.
## Per active quest: current stage + progress per objective index of that stage.

## quest id -> {"stage": int, "progress": {objective_index(String): int}, "started_at": float}
var active: Dictionary[StringName, Dictionary] = {}
var completed: Array[StringName] = []
var failed: Array[StringName] = []
var tracked: StringName = &""


func start(quest: QuestData, now_s: float = 0.0) -> bool:
	if active.has(quest.id) or quest.id in completed:
		return false
	active[quest.id] = {"stage": 0, "progress": {}, "started_at": now_s}
	if tracked == &"":
		tracked = quest.id
	return true


func stage_of(quest_id: StringName) -> int:
	return active[quest_id]["stage"] if active.has(quest_id) else -1


func objective_progress(quest_id: StringName, index: int) -> int:
	if not active.has(quest_id):
		return 0
	var progress_map: Dictionary = active[quest_id]["progress"]
	return progress_map.get(str(index), 0)


func is_objective_done(quest: QuestData, index: int) -> bool:
	return objective_progress(quest.id, index) >= quest.objectives[index].count


## Objectives of the current stage that are still open.
func open_objectives(quest: QuestData) -> Array[int]:
	var out: Array[int] = []
	if not active.has(quest.id):
		return out
	for i: int in quest.objectives_in(stage_of(quest.id)):
		if not is_objective_done(quest, i):
			out.append(i)
	return out


## Compatibility helper: first open required objective of the current stage.
func current_objective(quest: QuestData) -> QuestObjective:
	for i: int in open_objectives(quest):
		if not quest.objectives[i].optional:
			return quest.objectives[i]
	var open: Array[int] = open_objectives(quest)
	return quest.objectives[open[0]] if not open.is_empty() else null


func progress(quest_id: StringName) -> int:
	var q: Dictionary = active.get(quest_id, {})
	var p: Dictionary = q.get("progress", {})
	var best: int = 0
	for key: String in p:
		var v: int = p[key]
		best = maxi(best, v)
	return best


## Applies an event; returns true if the quest just completed.
func notify(quest: QuestData, type: QuestObjective.Type, target: StringName, amount: int = 1) -> bool:
	if not active.has(quest.id):
		return false
	var changed: bool = false
	var entry: Dictionary = active[quest.id]
	var progress_map: Dictionary = entry["progress"]
	for i: int in open_objectives(quest):
		var o: QuestObjective = quest.objectives[i]
		if o.type != type or (o.target != &"" and o.target != target):
			continue
		progress_map[str(i)] = mini(objective_progress(quest.id, i) + amount, o.count)
		changed = true
	if not changed:
		return false
	return _advance(quest)


func _advance(quest: QuestData) -> bool:
	var entry: Dictionary = active[quest.id]
	while true:
		var stage: int = entry["stage"]
		for i: int in quest.objectives_in(stage):
			if not quest.objectives[i].optional and not is_objective_done(quest, i):
				return false
		var next_stage: int = stage + 1
		if next_stage >= quest.stage_count():
			_finish(quest.id, true)
			return true
		entry["stage"] = next_stage
		entry["progress"] = {}
	return false


func fail(quest_id: StringName) -> void:
	if active.has(quest_id):
		_finish(quest_id, false)


func _finish(quest_id: StringName, success: bool) -> void:
	active.erase(quest_id)
	if success:
		completed.append(quest_id)
	else:
		failed.append(quest_id)
	if tracked == quest_id:
		tracked = active.keys()[0] if not active.is_empty() else &""


## Daily quests can be repeated: forget their completion.
func reset_repeatable(quest_id: StringName) -> void:
	completed.erase(quest_id)
	failed.erase(quest_id)
	active.erase(quest_id)


func to_dict() -> Dictionary:
	var a: Dictionary = {}
	for id: StringName in active:
		a[String(id)] = active[id]
	return {"active": a, "completed": _names(completed), "failed": _names(failed), "tracked": String(tracked)}


func load_dict(d: Dictionary) -> void:
	active.clear()
	completed.clear()
	failed.clear()
	var a: Dictionary = d.get("active", {})
	for key: String in a:
		var entry: Dictionary = a[key]
		var stage: int = entry.get("stage", entry.get("step", 0))
		var progress_map: Dictionary = {}
		var raw: Variant = entry.get("progress", {})
		if raw is Dictionary:
			var src: Dictionary = raw
			for k: String in src:
				var v: int = src[k]
				progress_map[k] = v
		var started: float = entry.get("started_at", 0.0)
		active[StringName(key)] = {"stage": stage, "progress": progress_map, "started_at": started}
	var done: Array = d.get("completed", [])
	for id: String in done:
		completed.append(StringName(id))
	var lost: Array = d.get("failed", [])
	for id: String in lost:
		failed.append(StringName(id))
	var t: String = d.get("tracked", "")
	tracked = StringName(t)


static func _names(list: Array[StringName]) -> Array[String]:
	var out: Array[String] = []
	for id: StringName in list:
		out.append(String(id))
	return out
