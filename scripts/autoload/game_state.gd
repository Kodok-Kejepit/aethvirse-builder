extends Node
## Runtime player/world state (class, progression, skills, gold, world flags).
## SaveManager (M5) serializes this.

const DEFAULT_CLASS: StringName = &"vanguard"
const ULTIMATE_SLOT: int = 4
const SLOT_COUNT: int = 5

var class_id: StringName = DEFAULT_CLASS
## Current job (§8 job change); &"" = still the base class.
var job_id: StringName = &""
## Appearance (HeroData id), picked at New Game; independent of the class.
var hero_id: StringName = HeroData.DEFAULT_ID
var shadows: ShadowArmy = ShadowArmy.new()
var progression: Progression = null
## Skill id -> level (0 / missing = not learned yet).
var skill_levels: Dictionary[StringName, int] = {}
## Slots 0–3 = skills 1–4, slot 4 = ultimate.
var skill_slots: Array[StringName] = []
var gold: int = 0
var world_flags: Dictionary[StringName, bool] = {}
## Node currently controlled by the player; registered by the player scene (M1).
var player: Node3D = null
## Total play time in seconds (saved).
var playtime_s: float = 0.0
var items: ItemDatabase = null
var inventory: Inventory = null
var secrets: SecretState = SecretState.new()
var quests: QuestLog = QuestLog.new()
var guild_points: int = 0
var codex_points: int = 0
## Daily quest bookkeeping: {"day": int, "penalty_pending": bool}
var daily: Dictionary = {"day": 0, "penalty_pending": false}
var current_region: StringName = &""
## Last waystone (altar) the player stood at: falling in battle brings you back there.
var respawn_waystone: StringName = &""
## Dynamic world Gates (see WorldGates) and per-region spawn clocks.
var world_gates: Array[Dictionary] = []
var world_gate_clock: Dictionary = {}
var next_gate_uid: int = 0
## Explored map cells per region (RegionMap fog grid).
var map_fog: Dictionary[String, PackedByteArray] = {}
## Non-null while the player is inside a Gate.
var gate_session: GateSession = null
## Street spot outside an interior scene (metro station) while the player is inside it:
## saves keep this instead of interior coordinates.
var interior_return: Variant = null
var clock: WorldClock = WorldClock.new()
var weather: WeatherSystem = WeatherSystem.new()
## Set by SaveManager on load; the player moves here once when it spawns.
var pending_player_position: Variant = null


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--class="):
			class_id = StringName(arg.trim_prefix("--class="))
		elif arg.begins_with("--hero="):
			hero_id = StringName(arg.trim_prefix("--hero="))
	items = ItemDatabase.new()
	inventory = Inventory.new(items)
	EventBus.gold_gained.connect(func(amount: int) -> void: gold += amount)


func _process(delta: float) -> void:
	if player == null:
		return
	playtime_s += delta
	var previous_day: int = clock.day()
	var previous_hour: int = clock.hour()
	clock.advance(delta)
	if clock.hour() != previous_hour:
		EventBus.hour_changed.emit(clock.hour())
	if clock.day() != previous_day:
		EventBus.day_changed.emit(clock.day())
	if weather.update(clock.total_minutes):
		EventBus.weather_changed.emit(weather.current)


func set_weather(id: StringName, lock: bool = false) -> void:
	weather.force(id, clock.total_minutes, lock)
	EventBus.weather_changed.emit(weather.current)


func to_dict() -> Dictionary:
	var slots: Array[String] = []
	for id: StringName in skill_slots:
		slots.append(String(id))
	var levels: Dictionary = {}
	for id: StringName in skill_levels:
		levels[String(id)] = skill_levels[id]
	var flags: Dictionary = {}
	for flag: StringName in world_flags:
		flags[String(flag)] = world_flags[flag]
	var data: Dictionary = {
		"class_id": String(class_id),
		"job_id": String(job_id),
		"hero_id": String(hero_id),
		"region": String(current_region),
		"respawn_waystone": String(respawn_waystone),
		"world_gates": world_gates.duplicate(true),
		"world_gate_clock": world_gate_clock.duplicate(),
		"next_gate_uid": next_gate_uid,
		"map_fog": _fog_to_dict(),
		"shadows": shadows.to_dict(),
		"progression": progression.to_dict() if progression != null else {},
		"skill_levels": levels,
		"skill_slots": slots,
		"gold": gold,
		"world_flags": flags,
		"playtime_s": playtime_s,
		"time_minutes": clock.total_minutes,
		"weather": String(weather.current),
		"weather_change_at": weather.change_at,
		"inventory": inventory.to_dict() if inventory != null else {},
		"secrets": secrets.to_dict(),
		"quests": quests.to_dict(),
		"guild_points": guild_points,
		"codex_points": codex_points,
		"daily": daily,
	}
	if player != null and is_instance_valid(player):
		var p: Vector3 = player.global_position
		# Inside a Gate or an interior the region position is the way back out.
		if gate_session != null:
			p = gate_session.return_position
		elif interior_return is Vector3:
			p = interior_return
		data["player_position"] = [p.x, p.y, p.z]
	return data


func load_dict(data: Dictionary, tuning: StatTuning) -> void:
	var cls: String = data.get("class_id", String(DEFAULT_CLASS))
	new_game(StringName(cls), tuning)
	var prog: Dictionary = data.get("progression", {})
	progression.load_dict(prog)
	var job: String = data.get("job_id", "")
	job_id = StringName(job)
	var wg: Array = data.get("world_gates", [])
	for e: Variant in wg:
		var entry: Dictionary = e
		world_gates.append(_clean_gate_entry(entry))
	var clock_in: Dictionary = data.get("world_gate_clock", {})
	world_gate_clock = clock_in.duplicate()
	var uid: int = data.get("next_gate_uid", 0)
	next_gate_uid = uid
	var fog_in: Dictionary = data.get("map_fog", {})
	for key: String in fog_in:
		var b64: String = fog_in[key]
		map_fog[key] = Marshalls.base64_to_raw(b64)
	var region_id: String = data.get("region", "")
	current_region = StringName(region_id)
	var altar: String = data.get("respawn_waystone", "")
	respawn_waystone = StringName(altar)
	var hero: String = data.get("hero_id", String(HeroData.DEFAULT_ID))
	hero_id = StringName(hero)
	_match_hero_to_class()
	var army: Dictionary = data.get("shadows", {})
	shadows.load_dict(army)
	var levels: Dictionary = data.get("skill_levels", {})
	for key: String in levels:
		var lvl: int = levels[key]
		skill_levels[StringName(key)] = lvl
	var slots: Array = data.get("skill_slots", [])
	for id: String in slots:
		skill_slots.append(StringName(id))
	var g: int = data.get("gold", 0)
	gold = g
	var flags: Dictionary = data.get("world_flags", {})
	for key: String in flags:
		var value: bool = flags[key]
		world_flags[StringName(key)] = value
	var t: float = data.get("playtime_s", 0.0)
	playtime_s = t
	var minutes: float = data.get("time_minutes", WorldClock.START_MINUTES)
	clock.total_minutes = minutes
	var w: String = data.get("weather", "clear")
	var change: float = data.get("weather_change_at", 0.0)
	weather.current = StringName(w)
	weather.change_at = change
	var inv: Dictionary = data.get("inventory", {})
	inventory.load_dict(inv)
	var sec: Dictionary = data.get("secrets", {})
	secrets.load_dict(sec)
	var qst: Dictionary = data.get("quests", {})
	quests.load_dict(qst)
	var gp: int = data.get("guild_points", 0)
	var cp: int = data.get("codex_points", 0)
	guild_points = gp
	codex_points = cp
	var dl: Dictionary = data.get("daily", {})
	var dday: int = dl.get("day", 0)
	var pending: bool = dl.get("penalty_pending", false)
	daily = {"day": dday, "penalty_pending": pending}
	var pos: Array = data.get("player_position", [])
	pending_player_position = null
	if pos.size() == 3:
		var x: float = pos[0]
		var y: float = pos[1]
		var z: float = pos[2]
		pending_player_position = Vector3(x, y, z)


func new_game(class_name_id: StringName, tuning: StatTuning) -> void:
	class_id = class_name_id
	job_id = &""
	shadows = ShadowArmy.new()
	progression = Progression.new(tuning)
	skill_levels.clear()
	skill_slots.clear()
	gold = 0
	world_flags.clear()
	respawn_waystone = &""
	playtime_s = 0.0
	pending_player_position = null
	clock = WorldClock.new()
	weather = WeatherSystem.new()
	secrets = SecretState.new()
	quests = QuestLog.new()
	guild_points = 0
	codex_points = 0
	daily = {"day": 0, "penalty_pending": false}
	world_gates.clear()
	world_gate_clock.clear()
	next_gate_uid = 0
	map_fog.clear()
	if items != null:
		inventory = Inventory.new(items)


func _fog_to_dict() -> Dictionary:
	var out: Dictionary = {}
	for key: String in map_fog:
		out[key] = Marshalls.raw_to_base64(map_fog[key])
	return out


## JSON turns ints into floats: normalise a loaded world Gate entry.
static func _clean_gate_entry(e: Dictionary) -> Dictionary:
	var uid: int = e.get("uid", -1)
	var point: int = e.get("point", 0)
	var opened: float = e.get("opened_at", 0.0)
	var broken: bool = e.get("broken", false)
	var gate: String = e.get("gate", "")
	var region: String = e.get("region", "")
	return {"uid": uid, "gate": gate, "region": region, "point": point, "opened_at": opened, "broken": broken}


func set_flag(flag: StringName, value: bool = true) -> void:
	world_flags[flag] = value


func has_flag(flag: StringName) -> bool:
	return world_flags.get(flag, false)


## Each class has its own hero: saves made before a hero changed class get the hero who
## plays that class now (Nocturne moved from Assassin to Marksman).
func _match_hero_to_class() -> void:
	if HeroData.load_hero(hero_id).class_id == class_id:
		return
	var hero: StringName = HeroData.hero_for_class(class_id)
	if hero != &"":
		hero_id = hero
