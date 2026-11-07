class_name DailyQuests
extends Node
## Codex daily quest (§10): three tasks per game day, scaled by level. Ignoring it until
## the day ends sends the player to the Penalty Zone. Also rolls emergency quests.

const PENALTY_SCENE: String = "res://scenes/world/gates/penalty_zone.tscn"
const PENALTY_WARNING_S: float = 10.0
const EMERGENCY_CHANCE_PER_HOUR: float = 0.12
const EMERGENCY_TIME_S: float = 180.0
const CODEX_POINTS: int = 10
enum Group { TRAINING, HUNTING, GATHERING }
## One task per group each day, so a day is never just "run 1500 m".
## [group, objective type, translation key, target, base count at Lv1, count per level, cap, min level]
const TEMPLATES: Array[Array] = [
	[Group.TRAINING, QuestObjective.Type.ATTACK, &"DAILY_ATTACKS", &"", 40, 2.0, 100, 1],
	[Group.TRAINING, QuestObjective.Type.DODGE, &"DAILY_DODGES", &"", 20, 1.0, 50, 1],
	[Group.TRAINING, QuestObjective.Type.DISTANCE, &"DAILY_RUN", &"", 1500, 120.0, 5000, 1],
	[Group.TRAINING, QuestObjective.Type.SKILL, &"DAILY_SKILLS", &"", 8, 0.5, 30, 1],
	[Group.HUNTING, QuestObjective.Type.KILL, &"DAILY_KILLS", &"", 8, 1.0, 30, 1],
	[Group.HUNTING, QuestObjective.Type.CLEAR_GATE, &"DAILY_GATE", &"", 1, 0.0, 1, 3],
	[Group.GATHERING, QuestObjective.Type.PICKUP, &"DAILY_PICKUPS", &"", 6, 0.5, 20, 1],
	[Group.GATHERING, QuestObjective.Type.PICKUP, &"DAILY_HERBS", &"herb", 3, 0.2, 8, 1],
	[Group.GATHERING, QuestObjective.Type.CRAFT, &"DAILY_CRAFT", &"", 1, 0.1, 3, 1],
	[Group.GATHERING, QuestObjective.Type.USE_ITEM, &"DAILY_USE_ITEMS", &"", 2, 0.0, 2, 1],
]

var system: QuestSystem
var _penalty_timer: float = -1.0


func _ready() -> void:
	system = get_parent().get_node(^"QuestSystem") as QuestSystem
	EventBus.day_changed.connect(_on_day_changed)
	EventBus.hour_changed.connect(_on_hour_changed)
	EventBus.quest_completed.connect(_on_completed)
	# Emergency quests are runtime-only; drop any left over in a save.
	for id: StringName in GameState.quests.active.keys():
		if String(id).begins_with("emergency_"):
			GameState.quests.fail(id)
	_on_day_changed.call_deferred(GameState.clock.day())


## Pure: the daily quest for a day + level (same day → same tasks).
static func build(day: int, level: int) -> QuestData:
	var q: QuestData = QuestData.new()
	q.id = StringName("daily_%d" % day)
	q.title = &"DAILY_TITLE"
	q.description = &"DAILY_DESC"
	q.kind = QuestData.Kind.DAILY
	for group: int in [Group.TRAINING, Group.HUNTING, Group.GATHERING]:
		q.objectives.append(_objective_for(group, day, level))
	var xp: RewardData = RewardData.new()
	xp.type = RewardData.Type.XP
	xp.amount = roundi(Progression.xp_needed(level, StatTuning.new()) * 0.15)
	q.rewards.append(xp)
	q.guild_points = 5
	return q


## Pure: the day's task for one group (deterministic per day).
static func _objective_for(group: int, day: int, level: int) -> QuestObjective:
	var options: Array[Array] = []
	for t: Array in TEMPLATES:
		var t_group: int = t[0]
		var min_level: int = t[7]
		if t_group == group and level >= min_level:
			options.append(t)
	var t: Array = options[absi(hash(day * 7919 + group * 104729)) % options.size()]
	var o: QuestObjective = QuestObjective.new()
	o.type = t[1]
	o.text = t[2]
	o.target = t[3]
	var base_count: int = t[4]
	var per_level: float = t[5]
	var cap: int = t[6]
	o.count = mini(base_count + floori(per_level * (level - 1)), cap)
	return o


func _on_day_changed(day: int) -> void:
	var log_state: QuestLog = GameState.quests
	var last_day: int = GameState.daily.get("day", 0)
	if last_day > 0 and last_day < day:
		var previous: StringName = StringName("daily_%d" % last_day)
		if log_state.active.has(previous):
			log_state.fail(previous)
			GameState.daily["penalty_pending"] = true
	var level: int = GameState.progression.level if GameState.progression != null else 1
	var today: QuestData = build(day, level)
	system.register(today)
	if last_day != day:
		GameState.daily["day"] = day
		system.start(today.id)
		AudioManager.play_ui(&"ding")
	if GameState.daily.get("penalty_pending", false):
		_schedule_penalty()


func _on_completed(quest_id: StringName) -> void:
	if String(quest_id).begins_with("daily_"):
		GameState.codex_points += CODEX_POINTS
		Codex.notify(tr(&"CODEX_MSG_CODEX_POINTS") % CODEX_POINTS, &"reward")


func _schedule_penalty() -> void:
	if GameState.gate_session != null or _penalty_timer >= 0.0:
		return
	_penalty_timer = PENALTY_WARNING_S
	Codex.anomaly(tr(&"CODEX_MSG_PENALTY"), 0.15)


func _process(delta: float) -> void:
	if _penalty_timer < 0.0:
		return
	_penalty_timer -= delta
	if _penalty_timer <= 0.0:
		_penalty_timer = -1.0
		var player: Player = GameState.player as Player
		var session: GateSession = GateSession.new()
		session.return_scene = get_tree().current_scene.scene_file_path
		session.return_position = player.global_position if player != null else Vector3.ZERO
		GameState.gate_session = session
		get_tree().change_scene_to_file.call_deferred(PENALTY_SCENE)


func _on_hour_changed(_hour: int) -> void:
	if GameState.gate_session != null or GameState.current_region == &"":
		return
	for id: StringName in GameState.quests.active:
		if String(id).begins_with("emergency_"):
			return
	if randf() < EMERGENCY_CHANCE_PER_HOUR:
		start_emergency()


func start_emergency() -> void:
	var q: QuestData = QuestData.new()
	q.id = StringName("emergency_%d" % Time.get_ticks_msec())
	q.title = &"EMERGENCY_TITLE"
	q.description = &"EMERGENCY_DESC"
	q.kind = QuestData.Kind.EMERGENCY
	q.time_limit_s = EMERGENCY_TIME_S
	var o: QuestObjective = QuestObjective.new()
	o.type = QuestObjective.Type.KILL
	o.text = &"EMERGENCY_KILLS"
	o.count = 6
	q.objectives.append(o)
	var gold: RewardData = RewardData.new()
	gold.type = RewardData.Type.GOLD
	gold.amount = 60 + 10 * (GameState.progression.level if GameState.progression != null else 1)
	q.rewards.append(gold)
	q.guild_points = 15
	system.register(q)
	system.start(q.id)
	Codex.notify(tr(&"CODEX_MSG_EMERGENCY"), &"warning")
