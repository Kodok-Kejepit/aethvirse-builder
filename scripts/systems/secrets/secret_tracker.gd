class_name SecretTracker
extends Node
## Evaluates secrets against the world, grants rewards, records hints/lore/titles.
## Lives in the game world scene; state lives in GameState.secrets (saved).

const GROUP: StringName = &"secret_tracker"
const EVAL_INTERVAL_S: float = 0.25
## Below this horizontal speed (and not attacking) the player counts as idle.
const IDLE_SPEED: float = 0.15

var db: SecretDatabase
var _areas: Array[StringName] = []
var _idle_s: float = 0.0
var _eval_timer: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


static func find(from: Node) -> SecretTracker:
	return from.get_tree().get_first_node_in_group(GROUP) as SecretTracker


func _ready() -> void:
	add_to_group(GROUP)
	_rng.randomize()
	db = SecretDatabase.new()
	EventBus.secret_area_entered.connect(func(id: StringName) -> void:
		if not id in _areas:
			_areas.append(id))
	EventBus.secret_area_exited.connect(func(id: StringName) -> void: _areas.erase(id))
	_register_cheats()


func _physics_process(delta: float) -> void:
	_update_idle(delta)
	_eval_timer += delta
	if _eval_timer >= EVAL_INTERVAL_S:
		_eval_timer = 0.0
		evaluate_all()


func state() -> SecretState:
	return GameState.secrets


func is_found(id: StringName) -> bool:
	return state().found.get(id, false)


func is_failed(id: StringName) -> bool:
	return state().failed.get(id, false)


func make_context() -> SecretContext:
	var ctx: SecretContext = SecretContext.new()
	ctx.flags = GameState.world_flags
	ctx.weather = GameState.weather.current
	ctx.hour = GameState.clock.hour()
	ctx.is_night = GameState.clock.is_night()
	ctx.areas = _areas
	ctx.idle_s = _idle_s
	ctx.counters = state().counters
	ctx.found = state().found
	ctx.inventory = GameState.inventory
	ctx.level = GameState.progression.level if GameState.progression != null else 1
	var player: Player = GameState.player as Player
	if player != null and player.stats.primary != null:
		var p: StatBlock = player.stats.primary
		ctx.stats = {&"str": p.strength, &"agi": p.agility, &"int": p.intelligence, &"vit": p.vitality, &"sen": p.sense}
	return ctx


func evaluate_all() -> void:
	var ctx: SecretContext = make_context()
	for secret: SecretData in db.secrets.values():
		if is_found(secret.id) or is_failed(secret.id):
			continue
		if not secret.fail_conditions.is_empty() and ConditionData.any_true(secret.fail_conditions, ctx):
			fail(secret.id)
			continue
		if secret.trigger == SecretData.Trigger.AUTO and ConditionData.all_true(secret.conditions, ctx):
			_complete(secret)
			ctx = make_context()


## For EVENT secrets (chests, bosses, dialog). Returns true if it completed now.
func complete(id: StringName) -> bool:
	var secret: SecretData = db.get_secret(id)
	if secret == null or is_found(id) or is_failed(id):
		return false
	if not ConditionData.all_true(secret.conditions, make_context()):
		return false
	_complete(secret)
	return true


func can_complete(id: StringName) -> bool:
	var secret: SecretData = db.get_secret(id)
	return secret != null and not is_found(id) and not is_failed(id) \
		and ConditionData.all_true(secret.conditions, make_context())


func discover_hint(secret_id: StringName, hint_key: StringName) -> void:
	if state().add_hint(secret_id, hint_key):
		EventBus.journal_updated.emit()


func fail(id: StringName) -> void:
	state().failed[id] = true
	var secret: SecretData = db.get_secret(id)
	if secret != null:
		EventBus.journal_updated.emit()
		JournalCompletion.check(self, secret.region)


## "Secrets 3/7 · Sealed missions 1/2" numbers for a region, counted from the secrets that
## exist in the game (a sealed mission counts once all its stages are done).
func region_progress(region_id: StringName) -> Vector4i:
	var out: Vector4i = Vector4i.ZERO
	for entry: Dictionary in RegionJournal.entries(db, region_id):
		var done: int = 1 if RegionJournal.is_resolved(entry, state().found, state().failed) else 0
		if entry["kind"] == SecretData.Kind.SEALED_MISSION:
			out.z += done
			out.w += 1
		else:
			out.x += done
			out.y += 1
	return out


func _complete(secret: SecretData) -> void:
	state().found[secret.id] = true
	for reward: RewardData in secret.rewards:
		grant(reward)
	if secret.kind == SecretData.Kind.SEALED_MISSION and secret.mission != &"" and secret.id.ends_with(":1"):
		Codex.notify(tr(&"CODEX_MSG_SEALED_MISSION"), &"secret")
	elif secret.counts_as_secret():
		Codex.notify(tr(&"CODEX_MSG_SECRET_FOUND"), &"secret")
	EventBus.secret_found.emit(secret.id)
	EventBus.journal_updated.emit()
	JournalCompletion.check(self, secret.region)


func grant(reward: RewardData) -> void:
	match reward.type:
		RewardData.Type.ITEM:
			GameState.inventory.add(reward.key, reward.amount)
			Codex.notify(tr(&"CODEX_MSG_RECEIVED") % [_item_name(reward.key), reward.amount], &"reward")
		RewardData.Type.GOLD:
			EventBus.gold_gained.emit(reward.amount)
		RewardData.Type.XP:
			EventBus.xp_gained.emit(reward.amount)
		RewardData.Type.FLAG:
			GameState.set_flag(reward.key)
		RewardData.Type.TITLE:
			if not reward.key in state().titles:
				state().titles.append(reward.key)
				Codex.notify(tr(&"CODEX_MSG_TITLE") % tr(StringName("TITLE_" + String(reward.key).to_upper())), &"reward")
		RewardData.Type.LORE:
			if not reward.key in state().lore:
				state().lore.append(reward.key)
				Codex.notify(tr(&"CODEX_MSG_LORE"), &"info")
		RewardData.Type.CODEX_MESSAGE:
			Codex.notify(tr(reward.text), &"secret")
		RewardData.Type.ANOMALY:
			Codex.anomaly(tr(reward.text))
		RewardData.Type.LOOT_TABLE:
			var table: LootTable = load("res://data/loot_tables/%s.tres" % reward.key) as LootTable
			for drop: Dictionary in table.roll(_rng):
				var item_id: StringName = drop["id"]
				var count: int = drop["count"]
				var r: RewardData = RewardData.new()
				r.type = RewardData.Type.GOLD if item_id == &"gold" else RewardData.Type.ITEM
				r.key = item_id
				r.amount = count
				grant(r)


func _item_name(id: StringName) -> String:
	var item: ItemData = GameState.items.get_item(id)
	return item.display_name if item != null else String(id)


func _update_idle(delta: float) -> void:
	var player: Player = GameState.player as Player
	if player == null:
		_idle_s = 0.0
		return
	var moving: bool = player.get_horizontal_speed() > IDLE_SPEED
	var acting: bool = player.state_machine.get_state_name() not in [PlayerState.IDLE]
	_idle_s = 0.0 if moving or acting else _idle_s + delta


const CHEATS: Array[String] = ["list_secrets", "reveal_secrets", "secret", "counter"]


func _register_cheats() -> void:
	DebugConsole.register("list_secrets", _cheat_list, "list_secrets — all secrets and their status")
	DebugConsole.register("reveal_secrets", _cheat_reveal, "reveal_secrets — show debug markers on every secret")
	DebugConsole.register("secret", _cheat_secret, "secret <id> — force-complete a secret")
	DebugConsole.register("counter", _cheat_counter, "counter <id> <value> — set a secret counter")


func _exit_tree() -> void:
	for cheat: String in CHEATS:
		DebugConsole.unregister(cheat)


func _cheat_list(_a: PackedStringArray) -> String:
	var lines: PackedStringArray = []
	var ids: Array[StringName] = db.secrets.keys()
	ids.sort()
	for id: StringName in ids:
		var status: String = "-"
		if is_found(id):
			status = "FOUND"
		elif is_failed(id):
			status = "FAILED"
		elif can_complete(id):
			status = "ready"
		lines.append("%s  [%s]" % [id, status])
	return "\n".join(lines)


func _cheat_reveal(_a: PackedStringArray) -> String:
	var count: int = 0
	for node: Node in get_tree().get_nodes_in_group(SecretMarker.GROUP):
		var marker: SecretMarker = node as SecretMarker
		marker.set_revealed(true)
		count += 1
	return "revealed %d secret markers" % count


func _cheat_secret(a: PackedStringArray) -> String:
	if a.is_empty():
		return "usage: secret <id>"
	var secret: SecretData = db.get_secret(StringName(a[0]))
	if secret == null:
		return "unknown secret"
	_complete(secret)
	return "completed %s" % a[0]


func _cheat_counter(a: PackedStringArray) -> String:
	if a.size() < 2:
		return "usage: counter <id> <value>"
	state().counters[StringName(a[0])] = a[1].to_int()
	return "%s = %d" % [a[0], a[1].to_int()]
