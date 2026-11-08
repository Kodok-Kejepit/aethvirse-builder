class_name GateLayout
extends RefCounted
## Pure rules for how big a Gate run is: rooms and enemies grow with the player's level and
## the Gate's rank, enemies keep up with the player, and some runs hide a Double Gate.

const MAX_ROOMS: int = 12
const LEVELS_PER_EXTRA_ROOM: int = 5
const LEVELS_PER_EXTRA_ENEMY: int = 20
const MAX_ENEMIES_PER_ROOM: int = 7
## Gate enemies are never more than this many levels below the player.
const ENEMY_LEVEL_LAG: int = 2
const DOUBLE_GATE_CHANCE: float = 0.35
const DOUBLE_LEVEL_BONUS: int = 4
const DOUBLE_ROOMS: int = 2
const DOUBLE_RULES: Array[StringName] = [&"no_skills", &"no_potions"]


static func room_count(gate: GateData, player_level: int) -> int:
	var extra: int = floori(float(maxi(player_level, 1) - 1) / LEVELS_PER_EXTRA_ROOM) + int(gate.rank)
	return clampi(gate.room_count + extra, 1, MAX_ROOMS)


static func enemies_per_room(gate: GateData, player_level: int) -> int:
	var extra: int = floori(float(maxi(player_level, 1)) / LEVELS_PER_EXTRA_ENEMY)
	return mini(gate.enemies_per_room + extra, MAX_ENEMIES_PER_ROOM)


static func enemy_level(base_level: int, player_level: int, bonus: int = 0) -> int:
	return maxi(base_level, player_level - ENEMY_LEVEL_LAG) + bonus


## Deterministic per Gate and game day, so re-entering the same day finds the same layout.
static func has_double_gate(gate: GateData, day: int) -> bool:
	if gate.has_rule(&"double") or gate.has_rule(&"no_double"):
		return false
	# A Double Gate that was cleared is gone for good.
	if GameState.has_flag(StringName("gate_cleared_" + String(gate.id) + "_double")):
		return false
	return _roll(String(gate.id) + ":" + str(day)) < DOUBLE_GATE_CHANCE


## Which normal room (never the first) hides the cracked wall.
static func double_gate_room(rooms: int, day: int) -> int:
	if rooms <= 1:
		return -1
	return 1 + floori(_roll("room:" + str(day)) * (rooms - 1))


## The hidden Gate inside a Gate: short, harder, one strange rule, better rewards.
static func make_double(outer: GateData, day: int) -> GateData:
	var g: GateData = outer.duplicate() as GateData
	g.id = StringName(String(outer.id) + "_double")
	g.display_name = &"GATE_DOUBLE"
	g.rank = mini(int(outer.rank) + 1, GateData.Rank.S) as GateData.Rank
	g.seed_value = outer.seed_value * 7 + day
	g.room_count = DOUBLE_ROOMS
	g.rules = [&"double", DOUBLE_RULES[floori(_roll("rule:" + str(day)) * DOUBLE_RULES.size())]]
	# The Summoner's sealed mission ends here (conditions are checked by the tracker).
	g.completes_secret = &"SM-JOB-01:2"
	g.reward_gold = outer.reward_gold * 2
	g.reward_items = {&"mystery_box": 1}
	return g


## Session for the Double Gate: same way home as the outer Gate (leaving returns to the world).
static func double_session(outer: GateSession, day: int) -> GateSession:
	var inner: GateSession = GateSession.new()
	inner.gate = make_double(outer.gate, day)
	inner.return_scene = outer.return_scene
	inner.return_position = outer.return_position
	inner.enemy_level_bonus = DOUBLE_LEVEL_BONUS
	return inner


## Deterministic 0..1 roll for a key (hash() of similar keys is not uniform enough on its own).
static func _roll(key: String) -> float:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(key)
	return rng.randf()
