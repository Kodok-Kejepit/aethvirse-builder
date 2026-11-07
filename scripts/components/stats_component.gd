class_name StatsComponent
extends Node
## Player stats: progression (GameState) + class → DerivedStats → health/mana/combat/movement.
## Also owns timed buffs and XP intake.


@export var class_data: ClassData
@export var tuning: StatTuning
@export var player: Player
@export var health: HealthComponent
@export var mana: ManaComponent
@export var combat: PlayerCombat
@export var hurtbox: HurtboxComponent

var derived: DerivedStats = null
var primary: StatBlock = null
## Current job and the jobs before it (GameState.job_id), oldest first.
var jobs: Array[JobData] = []
## Each buff: {"stat": StringName, "amount": float, "until": float (seconds, real time)}.
var _buffs: Array[Dictionary] = []


const CLASS_DIR: String = "res://data/classes/%s.tres"


func _ready() -> void:
	# The chosen class (GameState.class_id) wins over the scene default.
	var wanted: StringName = GameState.class_id if GameState.class_id != &"" else class_data.id
	if wanted != class_data.id and ResourceLoader.exists(CLASS_DIR % wanted):
		class_data = load(CLASS_DIR % wanted) as ClassData
	combat.combo = class_data.combo
	if GameState.progression == null or GameState.class_id != class_data.id:
		GameState.new_game(class_data.id, tuning)
		PlayerItems.give_starter_kit(GameState.inventory, class_data.id)
	jobs = JobRegistry.lineage(GameState.job_id)
	ensure_skills_unlocked()
	recompute(true)
	EventBus.xp_gained.connect(add_xp)
	EventBus.player_respawned.connect(func() -> void: recompute(true))


func _physics_process(_delta: float) -> void:
	if _buffs.is_empty():
		return
	var now: float = _now()
	var before: int = _buffs.size()
	_buffs = _buffs.filter(func(b: Dictionary) -> bool:
		var until: float = b["until"]
		return until > now)
	if _buffs.size() != before:
		recompute(false)


func progression() -> Progression:
	return GameState.progression


func recompute(refill: bool) -> void:
	var prog: Progression = progression()
	var inv: Inventory = GameState.inventory
	primary = prog.primary_stats(class_data).plus(StatBlock.make(
		PlayerItems.equipment_bonus(inv, &"str"), PlayerItems.equipment_bonus(inv, &"agi"),
		PlayerItems.equipment_bonus(inv, &"int"), PlayerItems.equipment_bonus(inv, &"vit"),
		PlayerItems.equipment_bonus(inv, &"sen")))
	for job: JobData in jobs:
		if job.stat_bonus != null:
			primary = primary.plus(job.stat_bonus)
	derived = DerivedStats.compute(prog.level, primary, tuning, PlayerItems.weapon_attack(inv, prog.level))
	derived.defense += PlayerItems.equipment_defense(inv)
	derived.crit_chance = minf(tuning.crit_cap, derived.crit_chance + PlayerItems.equipment_bonus(inv, &"crit"))
	var job_atk: float = 0.0
	var job_def: float = 0.0
	var job_hp: float = 0.0
	for job: JobData in jobs:
		job_atk += job.attack_bonus
		job_def += job.defense_bonus
		job_hp += job.hp_bonus
	derived.max_hp = roundi(derived.max_hp * (1.0 + job_hp))
	derived.attack *= 1.0 + buff_total(&"attack") + passive_total(&"attack") + job_atk
	derived.magic_attack *= 1.0 + buff_total(&"attack") + passive_total(&"attack") + job_atk
	derived.defense *= 1.0 + buff_total(&"defense") + passive_total(&"defense") + job_def
	derived.crit_chance = minf(tuning.crit_cap, derived.crit_chance + buff_total(&"crit") + passive_total(&"crit"))
	derived.attack_speed += passive_total(&"aspd")
	derived.move_speed += passive_total(&"mspd") + buff_total(&"mspd")
	var combat_stats: CombatStats = derived.to_combat_stats(class_data.magic_damage)
	combat.stats = combat_stats
	hurtbox.stats = combat_stats
	health.set_max_health(derived.max_hp, refill)
	mana.regen_per_second = derived.mp_regen
	mana.set_max(derived.max_mp, refill)
	player.speed_multiplier = derived.move_speed
	player.attack_speed = derived.attack_speed
	EventBus.player_stats_changed.emit()


func add_xp(amount: int) -> void:
	var rank: ComboTracker.Rank = combat.tracker.get_rank(_now())
	var bonus: float = ComboTracker.RANK_BONUS[rank]
	var gained: int = progression().add_xp(roundi(amount * bonus))
	if gained > 0:
		ensure_skills_unlocked()
		recompute(true)
		EventBus.level_up.emit(progression().level)


func allocate(stat: StatBlock.Stat) -> bool:
	if not progression().allocate(stat):
		return false
	recompute(false)
	return true


func add_buff(stat: StringName, amount: float, duration_s: float) -> void:
	_buffs = _buffs.filter(func(b: Dictionary) -> bool: return b["stat"] != stat)
	_buffs.append({"stat": stat, "amount": amount, "until": _now() + duration_s})
	recompute(false)


func buff_total(stat: StringName) -> float:
	var total: float = 0.0
	for b: Dictionary in _buffs:
		if b["stat"] == stat:
			var amount: float = b["amount"]
			total += amount
	return total


## Permanent bonus from learned passive skills.
func passive_total(stat: StringName) -> float:
	var total: float = 0.0
	for skill: SkillData in all_skills():
		if skill.is_passive() and skill.buff_stat == stat:
			var level: int = GameState.skill_levels.get(skill.id, 0)
			if level > 0:
				total += skill.buff_at(level)
	return total


func remove_buff(stat: StringName) -> void:
	var before: int = _buffs.size()
	_buffs = _buffs.filter(func(b: Dictionary) -> bool: return b["stat"] != stat)
	if _buffs.size() != before:
		recompute(false)


func has_buff(stat: StringName) -> bool:
	return buff_total(stat) > 0.0


## Learns newly unlocked skills at level 1 and fills empty slots.
func ensure_skills_unlocked() -> void:
	var level: int = progression().level
	if GameState.skill_slots.size() < GameState.SLOT_COUNT:
		GameState.skill_slots.resize(GameState.SLOT_COUNT)
	for skill: SkillData in all_skills():
		if level < skill.unlock_level or GameState.skill_levels.get(skill.id, 0) > 0:
			continue
		GameState.skill_levels[skill.id] = 1
		_auto_slot(skill)


func level_up_skill(skill_id: StringName) -> bool:
	var skill: SkillData = find_skill(skill_id)
	var current: int = GameState.skill_levels.get(skill_id, 0)
	if skill == null or current <= 0 or current >= skill.max_level or progression().skill_points <= 0:
		return false
	progression().skill_points -= 1
	GameState.skill_levels[skill_id] = current + 1
	EventBus.player_stats_changed.emit()
	return true


## Class skills followed by the skills of every job taken so far.
func all_skills() -> Array[SkillData]:
	var out: Array[SkillData] = class_data.skills.duplicate()
	for job: JobData in jobs:
		out.append_array(job.skills)
	return out


func find_skill(skill_id: StringName) -> SkillData:
	for skill: SkillData in all_skills():
		if skill.id == skill_id:
			return skill
	return null


## MP cost after the current job's multiplier (Summoners are mana-hungry).
func mp_cost(skill: SkillData) -> int:
	var current: JobData = current_job()
	var mult: float = current.mp_cost_multiplier if current != null else 1.0
	return roundi(skill.mp_cost * mult)


func current_job() -> JobData:
	return jobs.back() if not jobs.is_empty() else null


## Job Change (§8). Returns false if the job is not on offer right now.
func change_job(job_id: StringName) -> bool:
	var offered: Array[JobData] = JobRegistry.options(class_data.id, GameState.job_id,
		progression().level, GameState.has_flag)
	var target: JobData = null
	for j: JobData in offered:
		if j.id == job_id:
			target = j
	if target == null:
		return false
	GameState.job_id = target.id
	GameState.set_flag(StringName("job_" + String(target.id)))
	jobs = JobRegistry.lineage(target.id)
	ensure_skills_unlocked()
	_slot_job_skills(target)
	recompute(true)
	EventBus.job_changed.emit(target.id)
	return true


## New job actives go straight onto the bar (slots 4, then 3) so they can be tried at once.
func _slot_job_skills(target: JobData) -> void:
	var slot: int = GameState.ULTIMATE_SLOT - 1
	for skill: SkillData in target.skills:
		if skill.is_passive() or GameState.skill_levels.get(skill.id, 0) <= 0:
			continue
		if skill.is_ultimate:
			assign_slot(skill.id, GameState.ULTIMATE_SLOT)
		elif slot >= 2 and not skill.id in GameState.skill_slots:
			assign_slot(skill.id, slot)
			slot -= 1


## Puts an active skill into a slot (0–3); the ultimate slot only takes ultimates.
func assign_slot(skill_id: StringName, slot: int) -> bool:
	var skill: SkillData = find_skill(skill_id)
	if skill == null or skill.is_passive() or GameState.skill_levels.get(skill_id, 0) <= 0:
		return false
	if slot < 0 or slot >= GameState.SLOT_COUNT or (slot == GameState.ULTIMATE_SLOT) != skill.is_ultimate:
		return false
	for i: int in GameState.skill_slots.size():
		if GameState.skill_slots[i] == skill_id:
			GameState.skill_slots[i] = &""
	GameState.skill_slots[slot] = skill_id
	EventBus.player_stats_changed.emit()
	return true


func _auto_slot(skill: SkillData) -> void:
	if skill.is_passive():
		return
	if skill.is_ultimate:
		if GameState.skill_slots[GameState.ULTIMATE_SLOT] == &"":
			GameState.skill_slots[GameState.ULTIMATE_SLOT] = skill.id
		return
	for i: int in GameState.ULTIMATE_SLOT:
		if GameState.skill_slots[i] == &"":
			GameState.skill_slots[i] = skill.id
			return


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
