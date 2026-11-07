class_name SummonManager
extends Node
## Player-side summons: Summoner familiars (SUMMON skills), shadow binding of fallen enemies
## (SHADOW_EXTRACT) and calling the shadow army (SHADOW_CALL). Added to the player at runtime.

## A fallen enemy can be bound for this long after it dies...
const CORPSE_WINDOW_S: float = 10.0
## ...and only within this distance of the player.
const BIND_RANGE_M: float = 8.0
const SHADOW_DATA: SummonData = preload("res://data/summons/shadow_soldier.tres")
const SHADOW_SKILL_POWER_PER_LEVEL: float = 0.05
const ENEMY_DIR: String = "res://data/enemies/%s.tres"

var player: Player
## Each: {"id": StringName, "position": Vector3, "time": float}
var _corpses: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.summon_killed_enemy.connect(_on_summon_kill)
	EventBus.job_changed.connect(_on_job_changed)
	EventBus.secret_found.connect(_on_secret_found)


## Clues for the Summoner's sealed mission (SM-JOB-01): one on becoming a Summoner, one when
## the familiars have fed enough. The Journal keeps them.
func _on_job_changed(job_id: StringName) -> void:
	var tracker: SecretTracker = SecretTracker.find(self)
	if job_id == &"summoner" and tracker != null:
		tracker.discover_hint(&"SM-JOB-01:1", &"HINT_SM_JOB_01_1")


func _on_secret_found(secret_id: StringName) -> void:
	var tracker: SecretTracker = SecretTracker.find(self)
	if secret_id == &"SM-JOB-01:1" and tracker != null:
		tracker.discover_hint(&"SM-JOB-01:1", &"HINT_SM_JOB_01_2")
	elif secret_id == &"SM-JOB-01:2":
		Codex.notify(tr(&"JOB_HIDDEN_AVAILABLE"), &"secret")


func _on_enemy_killed(enemy_id: StringName, at: Vector3) -> void:
	if not JobRegistry.has_shadow_army(GameState.job_id):
		return
	if enemy_id == ECHO_KING_ID:
		_echo_king_answers()
	_corpses.append({"id": enemy_id, "position": at, "time": _now()})
	if _corpses.size() > 16:
		_corpses.pop_front()


## Shadow Sovereign chain step 4 (MYSTERY_BIBLE 5.6): the Echo King's shadow rises on its own
## and answers — the first named shadow, guaranteed (if a slot is free).
const ECHO_KING_ID: StringName = &"echo_king"


func _echo_king_answers() -> void:
	var level: int = GameState.progression.level if GameState.progression != null else 1
	if GameState.shadows.is_full(level):
		Codex.notify(tr(&"SHADOW_FULL") % ShadowArmy.slots_for_level(level), &"warning")
		return
	GameState.shadows.add(ECHO_KING_ID, tr(&"SHADOW_ECHO_KING"), 2, level)
	GameState.set_flag(&"echo_king_shadow")
	Codex.notify(tr(&"CODEX_MSG_ECHO_KING_ANSWERS"), &"anomaly")


func _on_summon_kill(_summon_id: StringName) -> void:
	var counters: Dictionary[StringName, int] = GameState.secrets.counters
	counters[&"familiar_kills"] = counters.get(&"familiar_kills", 0) + 1


## Called by SkillCaster for SUMMON / SHADOW_EXTRACT / SHADOW_CALL skills.
func cast(skill: SkillData, level: int) -> void:
	match skill.kind:
		SkillData.Kind.SUMMON:
			summon(skill, level)
		SkillData.Kind.SHADOW_EXTRACT:
			bind_nearest_corpse()
		SkillData.Kind.SHADOW_CALL:
			call_shadows(skill.summon_cap(level), level)


func active(summon_id: StringName) -> Array[Minion]:
	var out: Array[Minion] = []
	for child: Node in get_tree().get_nodes_in_group(&"minions"):
		var m: Minion = child as Minion
		if m != null and m.data.id == summon_id and m.owner_player == player:
			out.append(m)
	return out


func summon(skill: SkillData, level: int) -> void:
	if skill.summon == null:
		return
	var current: Array[Minion] = active(skill.summon.id)
	# At the cap, the oldest minion fades and a fresh one takes its place.
	if current.size() >= skill.summon_cap(level):
		current[0].queue_free()
	_spawn(skill.summon, 1.0 + skill.multiplier_per_level * float(level - 1), "")


func bind_nearest_corpse() -> void:
	var level: int = GameState.progression.level
	var now: float = _now()
	_corpses = _corpses.filter(func(c: Dictionary) -> bool:
		var t: float = c["time"]
		return now - t <= CORPSE_WINDOW_S)
	var best: int = -1
	var best_d: float = BIND_RANGE_M
	for i: int in _corpses.size():
		var corpse_pos: Vector3 = _corpses[i]["position"]
		var d: float = corpse_pos.distance_to(player.global_position)
		if d <= best_d:
			best_d = d
			best = i
	if best == -1:
		Codex.notify(tr(&"SHADOW_NO_CORPSE"), &"warning")
		return
	var corpse: Dictionary = _corpses[best]
	_corpses.remove_at(best)
	var enemy_id: StringName = corpse["id"]
	if GameState.shadows.is_full(level):
		Codex.notify(tr(&"SHADOW_FULL") % ShadowArmy.slots_for_level(level), &"warning")
		return
	var info: Array = _enemy_info(enemy_id)
	var display_name: String = info[0]
	var tier: int = info[1]
	if _rng.randf() > ShadowArmy.bind_chance(tier):
		Codex.notify(tr(&"SHADOW_BIND_FAILED") % display_name, &"warning")
		return
	GameState.shadows.add(enemy_id, display_name, tier, level)
	EventBus.shadow_bound.emit(enemy_id)
	Codex.notify(tr(&"SHADOW_BOUND") % display_name, &"reward")
	var pos: Vector3 = corpse["position"]
	var fresh: int = GameState.shadows.find_index(GameState.shadows.last_uid())
	_spawn_shadow(GameState.shadows.soldiers[fresh], 1.0, pos)


## Calls the strongest shadows (up to `count`) not already standing beside the player.
func call_shadows(count: int, skill_level: int) -> void:
	for m: Minion in active(SHADOW_DATA.id):
		m.queue_free()
	var roster: Array[Dictionary] = GameState.shadows.sorted_by_power()
	if roster.is_empty():
		Codex.notify(tr(&"SHADOW_EMPTY"), &"warning")
		return
	var bonus: float = 1.0 + SHADOW_SKILL_POWER_PER_LEVEL * float(skill_level - 1)
	for i: int in mini(count, roster.size()):
		_spawn_shadow(roster[i], bonus)
	Codex.notify(tr(&"SHADOW_CALLED"), &"anomaly")


func _spawn_shadow(soldier: Dictionary, bonus: float, at: Variant = null) -> Minion:
	var display_name: String = soldier["name"]
	var m: Minion = _spawn(SHADOW_DATA, ShadowArmy.soldier_power(soldier) * bonus, display_name, at)
	var uid: int = soldier.get("uid", -1)
	var soldier_rank: int = soldier.get("rank", 0)
	m.shadow_uid = uid
	m.apply_rank(soldier_rank)
	return m


func _spawn(data: SummonData, power: float, label: String, at: Variant = null) -> Minion:
	var m: Minion = Minion.create(data, player, power, label)
	m.add_to_group(Minion.GROUP)
	var parent: Node = player.get_parent()
	parent.add_child(m)
	var pos: Vector3 = at if at is Vector3 else player.global_position + player.get_facing() * -1.5
	m.global_position = pos + Vector3.UP * 0.2
	return m


## [display name, tier] for an enemy id (falls back to the id).
static func _enemy_info(enemy_id: StringName) -> Array:
	var path: String = ENEMY_DIR % enemy_id
	if ResourceLoader.exists(path):
		var data: EnemyData = load(path) as EnemyData
		return [data.display_name, int(data.tier)]
	return [String(enemy_id).capitalize(), 0]


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
