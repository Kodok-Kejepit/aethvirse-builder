class_name QuestSystem
extends Node
## Loads quests, starts them (auto / conditions / dialog), feeds world events into the
## QuestLog, enforces emergency timers, grants rewards + guild points.

const GROUP: StringName = &"quest_system"
const QUEST_DIR: String = "res://data/quests/"
const CONDITION_CHECK_S: float = 1.0
const DISTANCE_REPORT_M: float = 10.0

var quests: Dictionary[StringName, QuestData] = {}
var _check_timer: float = 0.0
var _last_player_pos: Variant = null
var _distance_acc: float = 0.0


static func find(from: Node) -> QuestSystem:
	return from.get_tree().get_first_node_in_group(GROUP) as QuestSystem


func _ready() -> void:
	add_to_group(GROUP)
	for file: String in DirAccess.get_files_at(QUEST_DIR):
		var path: String = QUEST_DIR + file.trim_suffix(".remap")
		if path.ends_with(".tres"):
			var q: QuestData = load(path) as QuestData
			quests[q.id] = q
	EventBus.enemy_killed.connect(func(id: StringName, _p: Vector3) -> void: notify(QuestObjective.Type.KILL, id))
	EventBus.npc_talked.connect(func(id: StringName) -> void: notify(QuestObjective.Type.TALK, id))
	EventBus.secret_area_entered.connect(func(id: StringName) -> void: notify(QuestObjective.Type.REACH_AREA, id))
	EventBus.gate_cleared.connect(func(id: StringName) -> void: notify(QuestObjective.Type.CLEAR_GATE, id))
	EventBus.secret_found.connect(func(id: StringName) -> void: notify(QuestObjective.Type.SECRET, id))
	EventBus.player_attack_started.connect(func() -> void: notify(QuestObjective.Type.ATTACK, &""))
	EventBus.player_dodge_started.connect(func() -> void: notify(QuestObjective.Type.DODGE, &""))
	EventBus.item_picked.connect(func(id: StringName, amount: int) -> void: notify(QuestObjective.Type.PICKUP, id, amount))
	EventBus.item_crafted.connect(func(id: StringName) -> void: notify(QuestObjective.Type.CRAFT, id))
	EventBus.item_used.connect(func(id: StringName) -> void: notify(QuestObjective.Type.USE_ITEM, id))
	EventBus.skill_used.connect(func(id: StringName) -> void: notify(QuestObjective.Type.SKILL, id))
	GameState.inventory.changed.connect(_check_collect)
	_check_starts()


func quest_log() -> QuestLog:
	return GameState.quests


## Adds a runtime quest (daily / emergency) that has no file.
func register(q: QuestData) -> void:
	quests[q.id] = q


func start(id: StringName) -> void:
	var q: QuestData = quests.get(id, null)
	if q != null and quest_log().start(q, _now()):
		Codex.notify(tr(&"CODEX_MSG_QUEST_STARTED") % tr(q.title), &"quest")
		EventBus.quest_updated.emit(id)


func objective_text(q: QuestData) -> String:
	var lines: PackedStringArray = []
	for i: int in quest_log().open_objectives(q):
		var o: QuestObjective = q.objectives[i]
		var text: String = tr(o.text)
		if o.count > 1:
			text += "  %d/%d" % [quest_log().objective_progress(q.id, i), o.count]
		if o.optional:
			text = "(%s) %s" % [tr(&"QUEST_OPTIONAL"), text]
		lines.append(text)
	var remaining: float = time_left(q)
	if remaining >= 0.0:
		lines.append("⏱ %d:%02d" % [floori(remaining / 60.0), floori(remaining) % 60])
	return "\n• ".join(lines)


## Seconds left for timed quests, -1 if untimed.
func time_left(q: QuestData) -> float:
	if q.time_limit_s <= 0.0 or not quest_log().active.has(q.id):
		return -1.0
	var started: float = quest_log().active[q.id]["started_at"]
	return maxf(q.time_limit_s - (_now() - started), 0.0)


func notify(type: QuestObjective.Type, target: StringName, amount: int = 1) -> void:
	for id: StringName in quest_log().active.keys():
		var q: QuestData = quests.get(id, null)
		if q == null:
			continue
		var stage_before: int = quest_log().stage_of(id)
		var done: bool = quest_log().notify(q, type, target, amount)
		if done:
			_complete(q)
		elif quest_log().stage_of(id) != stage_before:
			Codex.notify(tr(&"CODEX_MSG_QUEST_STEP") % objective_text(q).split("\n")[0], &"quest")
		EventBus.quest_updated.emit(id)


func _process(delta: float) -> void:
	_track_distance()
	_check_timer += delta
	if _check_timer < CONDITION_CHECK_S:
		return
	_check_timer = 0.0
	_check_starts()
	for id: StringName in quest_log().active.keys():
		var q: QuestData = quests.get(id, null)
		if q != null and q.time_limit_s > 0.0:
			EventBus.quest_updated.emit(id)
			if time_left(q) <= 0.0:
				quest_log().fail(id)
				Codex.notify(tr(&"CODEX_MSG_QUEST_FAILED") % tr(q.title), &"warning")
				EventBus.quest_updated.emit(id)


func _check_starts() -> void:
	var tracker: SecretTracker = SecretTracker.find(self) if is_inside_tree() else null
	for q: QuestData in quests.values():
		if not q.auto_start or quest_log().active.has(q.id) or q.id in quest_log().completed or q.id in quest_log().failed:
			continue
		if q.start_conditions.is_empty() or (tracker != null and ConditionData.all_true(q.start_conditions, tracker.make_context())):
			start(q.id)


func _track_distance() -> void:
	var player: Node3D = GameState.player
	if player == null or not is_instance_valid(player):
		_last_player_pos = null
		return
	var pos: Vector3 = player.global_position
	if _last_player_pos is Vector3:
		var last: Vector3 = _last_player_pos
		var step: float = Vector2(pos.x - last.x, pos.z - last.z).length()
		if step < 20.0:  # ignore teleports
			_distance_acc += step
	_last_player_pos = pos
	if _distance_acc >= DISTANCE_REPORT_M:
		var meters: int = floori(_distance_acc)
		_distance_acc -= meters
		notify(QuestObjective.Type.DISTANCE, &"", meters)


func _check_collect() -> void:
	for id: StringName in quest_log().active.keys():
		var q: QuestData = quests.get(id, null)
		if q == null:
			continue
		for i: int in quest_log().open_objectives(q):
			var o: QuestObjective = q.objectives[i]
			if o.type == QuestObjective.Type.COLLECT and GameState.inventory.count_of(o.target) >= o.count:
				notify(QuestObjective.Type.COLLECT, o.target, o.count)


func _complete(q: QuestData) -> void:
	Codex.notify(tr(&"CODEX_MSG_QUEST_DONE") % tr(q.title), &"reward")
	var tracker: SecretTracker = SecretTracker.find(self)
	for r: RewardData in q.rewards:
		if tracker != null:
			tracker.grant(r)
	if q.guild_points > 0:
		GuildRank.add_points(q.guild_points)
	SystemRewards.on_quest(q)
	EventBus.quest_completed.emit(q.id)


func _now() -> float:
	return GameState.playtime_s
