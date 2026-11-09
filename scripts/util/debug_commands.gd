class_name DebugCommands
extends RefCounted
## Core cheat commands. Later systems add their own (give, level, time, weather, reveal_secrets).

const ENEMY_SCENE_PATH: String = "res://scenes/enemies/enemy.tscn"
const ENEMY_DATA_DIR: String = "res://data/enemies/"
const AUTOATTACK_INTERVAL_S: float = 0.18


static func register_core() -> void:
	DebugConsole.register("tp", _tp, "tp x y z — teleport the player")
	DebugConsole.register("god", _god, "god — toggle invulnerability")
	DebugConsole.register("heal", _heal, "heal — refill HP and stamina")
	DebugConsole.register("die", _die, "die — kill the player (tests death / respawn)")
	DebugConsole.register("kill_all", _kill_all, "kill_all — kill every enemy")
	DebugConsole.register("spawn", _spawn, "spawn <enemy_id> [count] — spawn enemies in front of the player")
	DebugConsole.register("timescale", _timescale, "timescale <0.05..4> — game speed")
	DebugConsole.register("lock", _lock, "lock — lock on to the best target")
	DebugConsole.register("autoattack", _autoattack, "autoattack — hold light attack (demo/testing)")
	DebugConsole.register("pos", _pos, "pos — print player position")
	DebugConsole.register("level", _level, "level <n> — set player level (keeps XP curve, grants points)")
	DebugConsole.register("xp", _xp, "xp <amount> — give XP")
	DebugConsole.register("nocd", _nocd, "nocd — reset skill cooldowns and refill MP")
	DebugConsole.register("gold", _gold, "gold <amount> — give gold")
	DebugConsole.register("save", _save, "save [slot_1|slot_2|slot_3|autosave] — save the game")
	DebugConsole.register("load", _load, "load [slot] — load a save")
	DebugConsole.register("time", _time, "time [HH:MM] — show or set game time")
	DebugConsole.register("day", _day, "day [+N] — show day or skip N days")
	DebugConsole.register("weather", _weather, "weather [clear|rain|fog|storm|auto] — set and lock weather")
	DebugConsole.register("loot", _loot, "loot <count> [rarity 0-5] — add random equipment")
	DebugConsole.register("codex", _codex, "codex <status|quests|inventory|journal|lore|log|system> — open a Codex tab")
	DebugConsole.register("newgame", _newgame, "newgame <vanguard|phantom|arcanist|ranger> — restart this scene as a new character")
	DebugConsole.register("press", _press, "press <action> — tap an input action (testing)")
	DebugConsole.register("hold", _hold, "hold <action> <seconds> — hold an input action (testing)")
	DebugConsole.register("job", _job, "job [id] — list job options, or force a job (ignores level/flags)")
	DebugConsole.register("pose", _pose, "pose [name|auto|off] — freeze the character on a pose (list without args)")
	DebugConsole.register("dragon", _dragon, "dragon [ult] — summon the spirit dragon effect")
	DebugConsole.register("model", _model, "model [heroine|graybox] — switch the player body")
	DebugConsole.register("travel", _travel, "travel [waystone_id] — list waystones, or unlock one and travel there")
	DebugConsole.register("worldgate", _worldgate, "worldgate [spawn|break|list] — force a dynamic Gate / Dungeon Break here")
	DebugConsole.register("flag", _flag, "flag <name> [off] — set or clear a world flag")
	DebugConsole.register("gearup", _gearup, "gearup <rarity 0-5> — equip one item of that rarity in every slot")
	DebugConsole.register("equip", _equip, "equip <item_id> — give and wear an item (costumes too)")
	DebugConsole.register("droploot", _droploot, "droploot — drop one item of every rarity in front of you")
	DebugConsole.register("trial", _trial, "trial <job_id> — start that job's Change trial now")
	DebugConsole.register("gate", _gate, "gate [gate_id] [double] [kind=<place>] [shape=<layout>] — enter a Gate (double = force the hidden Double Gate; kind: warrens/halls/ruins/grotto/crypt/rootdeep/ember/sandtomb/frost/sunken/void; shape: winding/spiral/loop/fork/hub)")
	DebugConsole.register("touchedit", _touchedit, "touchedit — open the touch button layout editor")
	DebugConsole.register("metro", _metro, "metro — go down into the Region 1 metro station")
	DebugConsole.register("dungeonmap", _dungeonmap, "dungeonmap [room|next|zoom|tunnel N] — inside a Gate: map from above (roofs off), jump to a room / tunnel")


static func _player() -> Player:
	return GameState.player as Player


static func _tp(args: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null or args.size() < 3:
		return "usage: tp x y z"
	p.global_position = Vector3(args[0].to_float(), args[1].to_float(), args[2].to_float())
	p.velocity = Vector3.ZERO
	return "teleported to %s" % p.global_position


static func _god(_args: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null:
		return "no player"
	p.god_mode = not p.god_mode
	return "god %s" % ("ON" if p.god_mode else "OFF")


static func _heal(_args: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null:
		return "no player"
	p.health.revive_full()
	p.stamina.reset()
	return "healed"


static func _die(_args: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null:
		return "no player"
	p.god_mode = false
	var info: DamageInfo = DamageInfo.new()
	info.amount = p.health.current + 1
	p.health.take_damage(info)
	return "player down"


static func _kill_all(_args: PackedStringArray) -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var count: int = 0
	for node: Node in tree.get_nodes_in_group(LockOnTargeter.GROUP):
		var enemy: Enemy = node as Enemy
		if enemy != null and not enemy.health.is_dead():
			var info: DamageInfo = DamageInfo.new()
			info.amount = enemy.health.current
			enemy.health.take_damage(info)
			count += 1
	return "killed %d" % count


static func _spawn(args: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null or args.is_empty():
		return "usage: spawn <enemy_id> [count]"
	var data_path: String = ENEMY_DATA_DIR + args[0] + ".tres"
	if not ResourceLoader.exists(data_path):
		return "no enemy data at %s" % data_path
	var data: EnemyData = load(data_path) as EnemyData
	var scene: PackedScene = load(ENEMY_SCENE_PATH) as PackedScene
	var count: int = clampi(args[1].to_int(), 1, 20) if args.size() > 1 else 1
	for i: int in count:
		var enemy: Enemy = scene.instantiate() as Enemy
		enemy.data = data
		var offset: Vector3 = p.get_facing() * 6.0 + Vector3(float(i) * 1.5 - float(count) * 0.75, 0.2, 0.0)
		enemy.position = p.global_position + offset
		p.get_parent().add_child(enemy)
	return "spawned %d %s" % [count, args[0]]


static func _timescale(args: PackedStringArray) -> String:
	if args.is_empty():
		return "time_scale = %.2f" % Engine.time_scale
	Engine.time_scale = clampf(args[0].to_float(), 0.05, 4.0)
	return "time_scale = %.2f" % Engine.time_scale


static func _lock(_args: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null:
		return "no player"
	p.lock_on.set_target(p.lock_on.pick_best(null))
	var target_name: String = "none"
	if p.lock_on.target != null:
		target_name = p.lock_on.target.name
	return "locked: %s" % target_name


static var _autoattack_timer: Timer = null


static func _autoattack(_args: PackedStringArray) -> String:
	if _autoattack_timer != null and is_instance_valid(_autoattack_timer):
		_autoattack_timer.queue_free()
		_autoattack_timer = null
		return "autoattack OFF"
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	_autoattack_timer = Timer.new()
	_autoattack_timer.wait_time = AUTOATTACK_INTERVAL_S
	_autoattack_timer.timeout.connect(func() -> void:
		Input.action_press(&"attack_light")
		tree.create_timer(0.05).timeout.connect(func() -> void: Input.action_release(&"attack_light")))
	tree.root.add_child(_autoattack_timer)
	_autoattack_timer.start()
	return "autoattack ON"


static func _pos(_args: PackedStringArray) -> String:
	var p: Player = _player()
	return "no player" if p == null else str(p.global_position)


static func _level(args: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null or args.is_empty():
		return "usage: level <n>"
	var target: int = clampi(args[0].to_int(), 1, GameState.progression.tuning.level_cap)
	while GameState.progression.level < target:
		p.stats.add_xp(GameState.progression.xp_to_next() - GameState.progression.xp)
	return "level %d" % GameState.progression.level


static func _xp(args: PackedStringArray) -> String:
	if _player() == null or args.is_empty():
		return "usage: xp <amount>"
	EventBus.xp_gained.emit(args[0].to_int())
	return "level %d, xp %d" % [GameState.progression.level, GameState.progression.xp]


static func _nocd(_args: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null:
		return "no player"
	p.skills.reset_cooldowns()
	p.mana.refill()
	return "cooldowns reset"


static func _gold(args: PackedStringArray) -> String:
	if args.is_empty():
		return "gold %d" % GameState.gold
	EventBus.gold_gained.emit(args[0].to_int())
	return "gold %d" % GameState.gold


static func _press(args: PackedStringArray) -> String:
	if args.is_empty() or not InputMap.has_action(StringName(args[0])):
		return "usage: press <input action>"
	var action: StringName = StringName(args[0])
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	Input.action_press(action)
	tree.create_timer(0.1, true, false, true).timeout.connect(func() -> void: Input.action_release(action))
	return "pressed %s" % action


static func _hold(args: PackedStringArray) -> String:
	if args.size() < 2 or not InputMap.has_action(StringName(args[0])):
		return "usage: hold <input action> <seconds>"
	var action: StringName = StringName(args[0])
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	Input.action_press(action)
	tree.create_timer(args[1].to_float(), true, false, true).timeout.connect(func() -> void: Input.action_release(action))
	return "holding %s" % action


static func _job(args: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null:
		return "no player"
	if args.is_empty():
		var ids: PackedStringArray = []
		for j: JobData in JobRegistry.all():
			ids.append(String(j.id))
		return "current: %s · all: %s" % [GameState.job_id, ", ".join(ids)]
	var job: JobData = JobRegistry.get_job(StringName(args[0]))
	if job == null:
		return "unknown job"
	if job.required_flag != &"":
		GameState.set_flag(job.required_flag)
	while GameState.progression.level < job.required_level:
		p.stats.add_xp(GameState.progression.xp_to_next() - GameState.progression.xp)
	for step: JobData in JobRegistry.lineage(job.id):
		if step.required_flag != &"":
			GameState.set_flag(step.required_flag)
		while GameState.progression.level < step.required_level:
			p.stats.add_xp(GameState.progression.xp_to_next() - GameState.progression.xp)
		if GameState.job_id != step.id and not p.stats.change_job(step.id):
			return "could not take %s" % step.id
	return "job %s" % GameState.job_id


static func _pose(args: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null or p.model == null:
		return "no character model"
	if args.is_empty():
		return "poses: %s | auto | off" % ", ".join(PackedStringArray(CharacterPoses.NAMES))
	var id: StringName = StringName(args[0])
	if id == &"off":
		p.model.stop_showcase()
		return "pose: live"
	if id == &"auto":
		p.model.start_showcase()
		return "pose: cycling all"
	if not CharacterPoses.NAMES.has(id):
		return "unknown pose"
	p.model.forced_pose = id
	if id == &"ultimate":
		p.model.summon_dragon(true)
	return "pose: %s" % id


static func _dragon(args: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null or p.model == null:
		return "no character model"
	if not p.model.has_dragon():
		return "this character has no dragon"
	p.model.summon_dragon(not args.is_empty() and args[0] == "ult")
	return "dragon summoned"


static func _model(args: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null or p.model == null:
		return "no character model"
	var graybox: bool = not args.is_empty() and args[0] == "graybox"
	p.set_graybox_visible(graybox)
	return "model: %s" % ("graybox" if graybox else "heroine")


static func _travel(args: PackedStringArray) -> String:
	if args.is_empty():
		var ids: PackedStringArray = PackedStringArray()
		for rid: StringName in RegionData.IDS:
			var region: RegionData = RegionData.load_region(rid)
			for wid: StringName in region.waystones:
				ids.append(String(wid) + ("" if WorldTravel.is_unlocked(wid) else " (locked)"))
		return "waystones: " + ", ".join(ids)
	var id: StringName = StringName(args[0])
	if RegionData.region_of_waystone(id) == null:
		return "unknown waystone"
	WorldTravel.unlock(id)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return "travelling to %s" % id if WorldTravel.travel(tree, id) else "cannot travel now"


static func _worldgate(args: PackedStringArray) -> String:
	var region: RegionData = RegionData.load_region(GameState.current_region)
	if region == null:
		return "not in a region"
	var mode: String = args[0] if not args.is_empty() else "list"
	var now: float = GameState.clock.total_minutes
	if mode == "spawn":
		GameState.world_gate_clock.erase(String(region.id))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 1
		var entry: Dictionary = {}
		for _i: int in 20:
			GameState.world_gate_clock.erase(String(region.id))
			entry = WorldGates.try_spawn(region, now, rng)
			if not entry.is_empty():
				break
		return "spawned %s (reload or wait a second)" % entry.get("gate", "nothing") if not entry.is_empty() else "region full"
	if mode == "break":
		for e: Dictionary in WorldGates.entries_in(region.id):
			e["opened_at"] = now - WorldGates.BREAK_AFTER_MIN - 1.0
		return "every Gate here breaks on the next tick"
	var rows: PackedStringArray = PackedStringArray()
	for e: Dictionary in WorldGates.entries_in(region.id):
		rows.append("%s#%d%s" % [e["gate"], WorldGates.uid_of(e), " BROKEN" if WorldGates.is_broken(e) else ""])
	return "world gates: " + (", ".join(rows) if not rows.is_empty() else "none")


static func _flag(args: PackedStringArray) -> String:
	if args.is_empty():
		return "usage: flag <name> [off]"
	var on: bool = args.size() < 2 or args[1] != "off"
	GameState.set_flag(StringName(args[0]), on)
	return "%s = %s" % [args[0], on]


static func _trial(args: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null or args.is_empty():
		return "usage: trial <job_id>"
	var job: JobData = JobRegistry.get_job(StringName(args[0]))
	if job == null:
		return "unknown job"
	if not JobTrial.needs_trial(job):
		return "this job has no trial"
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	return "entering trial" if JobTrial.start(tree, p, job) else "cannot start now"


static func _touchedit(_args: PackedStringArray) -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var controls: Node = tree.get_first_node_in_group(&"mobile_controls")
	if controls == null:
		return "no touch controls"
	controls.call(&"begin_edit")
	return "arranging touch buttons"


static func _metro(_args: PackedStringArray) -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	GameState.interior_return = Vector3(-112.0, 0.3, -99.0)
	LoadingScreen.go(tree, MetroStation.SCENE)
	return "down to the metro"


static func _dungeonmap(args: PackedStringArray) -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var dungeon: GateDungeon = tree.current_scene as GateDungeon
	if dungeon == null:
		return "not in a Gate"
	if args.size() > 1 and args[0] == "tunnel":
		dungeon.debug_tunnel(args[1].to_int())
		return "tunnel %s" % args[1]
	if not args.is_empty() and args[0] == "door":
		dungeon.debug_door()
		return "at a door"
	if not args.is_empty() and args[0] == "zoom":
		dungeon.set_meta(&"zoom", true)
		dungeon.debug_overview()
		return "zoomed overview"
	if not args.is_empty() and args[0] == "next":
		dungeon.debug_next()
		return "through the next door"
	if not args.is_empty():
		dungeon.debug_goto(args[0].to_int())
		return "room %s" % args[0]
	dungeon.debug_overview()
	return "overview"


static func _gate(args: PackedStringArray) -> String:
	var gate_id: String = args[0] if not args.is_empty() and args[0] != "double" and not "=" in args[0] else "gate_r1_e_overpass"
	var path: String = "res://data/gates/%s.tres" % gate_id
	if not ResourceLoader.exists(path):
		return "unknown gate"
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var session: GateSession = GateSession.new()
	session.gate = load(path) as GateData
	session.force_double = "double" in args
	for arg: String in args:
		if arg.begins_with("kind=") and DungeonArchetype.ALL.has(StringName(arg.trim_prefix("kind="))):
			session.force_kind = StringName(arg.trim_prefix("kind="))
		elif arg.begins_with("shape=") and StringName(arg.trim_prefix("shape=")) in DungeonPlan.LAYOUTS:
			session.force_layout = StringName(arg.trim_prefix("shape="))
	var p: Player = _player()
	var in_gate: bool = GameState.gate_session != null
	session.return_scene = GameState.gate_session.return_scene if in_gate else tree.current_scene.scene_file_path
	session.return_position = GameState.gate_session.return_position if in_gate else (p.global_position if p != null else Vector3.ZERO)
	GameState.gate_session = session
	tree.change_scene_to_file.call_deferred(GateDungeon.SCENE)
	return "entering %s" % gate_id


static func _save(args: PackedStringArray) -> String:
	var slot: String = args[0] if not args.is_empty() else SaveManager.MANUAL_SLOTS[0]
	return "saved %s: %s" % [slot, error_string(SaveManager.save_slot(slot))]


static func _load(args: PackedStringArray) -> String:
	var slot: String = args[0] if not args.is_empty() else SaveManager.MANUAL_SLOTS[0]
	return "load %s: %s" % [slot, error_string(SaveManager.load_slot(slot))]


static func _time(args: PackedStringArray) -> String:
	var clock: WorldClock = GameState.clock
	if not args.is_empty():
		var parts: PackedStringArray = args[0].split(":")
		clock.set_time_of_day(parts[0].to_int(), parts[1].to_int() if parts.size() > 1 else 0)
		EventBus.hour_changed.emit(clock.hour())
	return "day %d %s" % [clock.day(), clock.format()]


static func _day(args: PackedStringArray) -> String:
	var clock: WorldClock = GameState.clock
	if not args.is_empty():
		var days: int = maxi(args[0].trim_prefix("+").to_int(), 0)
		for i: int in days:
			clock.total_minutes += WorldClock.MINUTES_PER_DAY
			EventBus.day_changed.emit(clock.day())
	return "day %d %s" % [clock.day(), clock.format()]


static func _weather(args: PackedStringArray) -> String:
	if args.is_empty():
		return "weather %s%s" % [GameState.weather.current, " (locked)" if GameState.weather.locked else ""]
	if args[0] == "auto":
		GameState.weather.locked = false
		return "weather auto"
	if not args[0] in [WeatherSystem.CLEAR, WeatherSystem.RAIN, WeatherSystem.FOG, WeatherSystem.STORM]:
		return "usage: weather clear|rain|fog|storm|auto"
	GameState.set_weather(StringName(args[0]), true)
	return "weather %s (locked)" % args[0]


static func _loot(args: PackedStringArray) -> String:
	var count: int = clampi(args[0].to_int(), 1, 30) if not args.is_empty() else 5
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var gen: EquipmentGenerator = EquipmentGenerator.new(GameState.items, rng)
	var level: int = GameState.progression.level if GameState.progression != null else 1
	var rules: LootRules = load("res://data/balancing/loot_rules.tres") as LootRules
	for i: int in count:
		var rarity: int = args[1].to_int() if args.size() > 1 else rules.roll_rarity(EnemyScaling.Tier.ELITE, rng)
		GameState.inventory.add_stack(gen.generate(level, rarity))
	return "added %d items" % count


static func _gearup(args: PackedStringArray) -> String:
	var inv: Inventory = GameState.inventory
	if inv == null:
		return "no inventory"
	var rarity: int = clampi(args[0].to_int(), 0, 5) if not args.is_empty() else 4
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var gen: EquipmentGenerator = EquipmentGenerator.new(GameState.items, rng)
	var level: int = GameState.progression.level if GameState.progression != null else 1
	var done: Dictionary[int, bool] = {}
	for base: ItemData in gen.bases():
		if done.has(base.slot):
			continue
		done[base.slot] = true
		var stack: ItemStack = gen.generate_from(base, level, rarity)
		inv.add_stack(stack)
		inv.equip(stack)
	return "equipped %d pieces" % done.size()


static func _equip(args: PackedStringArray) -> String:
	var inv: Inventory = GameState.inventory
	if inv == null or args.is_empty():
		return "usage: equip <item_id>"
	var id: StringName = StringName(args[0])
	if inv.db.get_item(id) == null:
		return "unknown item"
	inv.add(id, 1)
	for stack: ItemStack in inv.stacks:
		if stack.item_id == id:
			inv.equip(stack)
			return "wearing %s" % id
	return "could not equip"


static func _droploot(_args: PackedStringArray) -> String:
	var p: Player = _player()
	if p == null:
		return "no player"
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var gen: EquipmentGenerator = EquipmentGenerator.new(GameState.items, rng)
	var level: int = GameState.progression.level if GameState.progression != null else 1
	var forward: Vector3 = p.get_facing()
	var side: Vector3 = forward.cross(Vector3.UP).normalized()
	for r: int in ItemData.Rarity.MYTHIC + 1:
		var at: Vector3 = p.global_position + forward * 4.0 + side * (float(r) - 2.5) * 1.6
		WorldPickup.spawn(p.get_parent(), at, gen.generate(level, r))
	return "dropped 6 items"


static func _codex(args: PackedStringArray) -> String:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	var panel: CodexPanel = tree.get_first_node_in_group(CodexPanel.GROUP) as CodexPanel
	if panel == null:
		return "no Codex in this scene"
	panel.open()
	if not args.is_empty():
		panel.select_tab(StringName("CODEX_TAB_" + args[0].to_upper()))
	return "codex open"


static func _newgame(args: PackedStringArray) -> String:
	var class_id: StringName = StringName(args[0]) if not args.is_empty() else &"vanguard"
	if not ResourceLoader.exists("res://data/classes/%s.tres" % class_id):
		return "unknown class"
	GameState.class_id = class_id
	GameState.progression = null
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	tree.reload_current_scene.call_deferred()
	return "new %s" % class_id
