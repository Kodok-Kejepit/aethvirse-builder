class_name SkillCaster
extends Node
## Casts the slotted skills: input (keys, gamepad LB+face / LT+RT, touch), MP, cooldowns
## (reduced by CDR), skill combos, and hands damaging skills to the Attack state.

const SKILL_ACTIONS: Array[StringName] = [&"skill_1", &"skill_2", &"skill_3", &"skill_4", &"ultimate"]
const MODIFIER_ACTION: StringName = &"skill_modifier"
## Gamepad face actions used with the modifier held: X, Y, B, A → skills 1–4.
const MODIFIED_FACE_ACTIONS: Array[StringName] = [&"attack_light", &"attack_heavy", &"dodge", &"jump"]
const TRIGGER_THRESHOLD: float = 0.6
const INPUT_BUFFER_S: float = 0.3

enum CastResult { OK, EMPTY_SLOT, LOCKED, COOLDOWN, NO_MP, BUSY, FORBIDDEN }

@export var player: Player
@export var stats: StatsComponent
@export var mana: ManaComponent
@export var combat: PlayerCombat

## Remaining cooldown per skill id (seconds).
var cooldowns: Dictionary[StringName, float] = {}
var _buffered_slot: int = -1
var _buffer_timer: float = 0.0
var _last_skill: StringName = &""
var _last_skill_time: float = -INF
var _triggers_were_down: bool = false


func _physics_process(delta: float) -> void:
	for id: StringName in cooldowns.keys():
		cooldowns[id] = maxf(cooldowns[id] - delta, 0.0)
	_read_input()
	_buffer_timer = maxf(_buffer_timer - delta, 0.0)
	if _buffered_slot >= 0 and _buffer_timer > 0.0:
		if try_cast_slot(_buffered_slot) != CastResult.BUSY:
			_buffered_slot = -1


func is_modifier_held() -> bool:
	return Input.is_action_pressed(MODIFIER_ACTION)


func _read_input() -> void:
	for i: int in SKILL_ACTIONS.size():
		if Input.is_action_just_pressed(SKILL_ACTIONS[i]):
			_buffer(i)
	if is_modifier_held():
		for i: int in MODIFIED_FACE_ACTIONS.size():
			if Input.is_action_just_pressed(MODIFIED_FACE_ACTIONS[i]):
				_buffer(i)
	var triggers_down: bool = Input.get_action_strength(&"trigger_left") > TRIGGER_THRESHOLD \
		and Input.get_action_strength(&"trigger_right") > TRIGGER_THRESHOLD
	if triggers_down and not _triggers_were_down:
		_buffer(GameState.ULTIMATE_SLOT)
	_triggers_were_down = triggers_down


func _buffer(slot: int) -> void:
	_buffered_slot = slot
	_buffer_timer = INPUT_BUFFER_S


func get_slot_skill(slot: int) -> SkillData:
	if slot < 0 or slot >= GameState.skill_slots.size():
		return null
	var id: StringName = GameState.skill_slots[slot]
	return stats.find_skill(id) if id != &"" else null


func get_cooldown_ratio(skill: SkillData) -> float:
	if skill == null:
		return 0.0
	var remaining: float = cooldowns.get(skill.id, 0.0)
	var total: float = skill.cooldown_s * (1.0 - stats.derived.cooldown_reduction)
	return remaining / total if total > 0.0 else 0.0


func get_cooldown_remaining(skill: SkillData) -> float:
	return cooldowns.get(skill.id, 0.0) if skill != null else 0.0


func can_act_now() -> bool:
	var state: StringName = player.state_machine.get_state_name()
	if state in [PlayerState.IDLE, PlayerState.MOVE, PlayerState.AIR]:
		return true
	if state == PlayerState.DODGE:
		return player.dodge_cancel_open
	return state == PlayerState.ATTACK and combat.can_cancel_into_skill()


func try_cast_slot(slot: int) -> CastResult:
	var skill: SkillData = get_slot_skill(slot)
	if skill == null:
		return CastResult.EMPTY_SLOT
	if GameState.gate_session != null and GameState.gate_session.has_rule(&"no_skills"):
		Codex.notify(tr(&"GATE_RULE_NO_SKILLS"), &"anomaly")
		return CastResult.FORBIDDEN
	var level: int = GameState.skill_levels.get(skill.id, 0)
	if level <= 0 or skill.is_passive():
		return CastResult.LOCKED
	if cooldowns.get(skill.id, 0.0) > 0.0:
		return CastResult.COOLDOWN
	if not mana.can_pay(stats.mp_cost(skill)):
		return CastResult.NO_MP
	if not can_act_now():
		return CastResult.BUSY
	_cast(skill, level)
	return CastResult.OK


func _cast(skill: SkillData, level: int) -> void:
	mana.try_pay(stats.mp_cost(skill))
	cooldowns[skill.id] = skill.cooldown_s * (1.0 - stats.derived.cooldown_reduction)
	var now: float = Time.get_ticks_msec() / 1000.0
	var combo: SkillComboData = find_combo(_last_skill, now - _last_skill_time, skill.id)
	_last_skill = skill.id
	_last_skill_time = now
	if combo != null:
		EventBus.skill_combo_triggered.emit(combo.display_name)
	EventBus.skill_used.emit(skill.id)
	if skill.kind == SkillData.Kind.BUFF:
		stats.add_buff(skill.buff_stat, skill.buff_at(level), skill.buff_duration_s)
		return
	if skill.is_instant():
		player.summons.cast(skill, level)
		return
	combat.queue_skill(skill, level, combo)
	player.state_machine.transition_to(PlayerState.ATTACK)


func find_combo(previous: StringName, elapsed_s: float, next: StringName) -> SkillComboData:
	for combo: SkillComboData in stats.class_data.skill_combos:
		if combo.matches(previous, elapsed_s, next):
			return combo
	return null


func reset_cooldowns() -> void:
	cooldowns.clear()
