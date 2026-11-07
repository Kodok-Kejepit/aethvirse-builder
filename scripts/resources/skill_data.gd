class_name SkillData
extends Resource
## An active skill. Damaging skills reuse AttackData for their timeline + hitbox.

## SUMMON: call `summon` minions. SHADOW_EXTRACT: bind a fallen enemy as a shadow soldier.
## SHADOW_CALL: call stored shadow soldiers to fight (shadow job line only).
enum Kind { MELEE, DASH, AOE, BUFF, PROJECTILE, PASSIVE, SUMMON, SHADOW_EXTRACT, SHADOW_CALL }

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var kind: Kind = Kind.MELEE
@export var is_ultimate: bool = false
@export var icon_color: Color = Color(0.4, 0.7, 1.0)
@export var unlock_level: int = 1
@export var max_level: int = 10

@export_group("Cost")
@export var mp_cost: int = 10
@export var cooldown_s: float = 6.0

@export_group("Damage")
## Timeline + hitbox (+ element) for MELEE / DASH / AOE.
@export var attack: AttackData
@export var damage_multiplier: float = 1.5
## Added per skill level above 1.
@export var multiplier_per_level: float = 0.1

@export_group("Buff")
@export var buff_stat: StringName = &"attack"
## Multiplier added while active (0.2 = +20%).
@export var buff_amount: float = 0.2
@export var buff_duration_s: float = 10.0
@export var buff_amount_per_level: float = 0.02

@export_group("Summon")
@export var summon: SummonData
## How many of this skill's minions can be out at once (SUMMON) / shadows called (SHADOW_CALL).
@export var max_summons: int = 1
## Extra minion allowed every N skill levels (0 = never).
@export var extra_summon_every: int = 0


func multiplier_at(skill_level: int) -> float:
	return damage_multiplier + multiplier_per_level * float(maxi(skill_level, 1) - 1)


func buff_at(skill_level: int) -> float:
	return buff_amount + buff_amount_per_level * float(maxi(skill_level, 1) - 1)


func is_damaging() -> bool:
	return kind in [Kind.MELEE, Kind.DASH, Kind.AOE, Kind.PROJECTILE] and attack != null


## Instant skills resolve without entering the attack state.
func is_instant() -> bool:
	return kind in [Kind.BUFF, Kind.SUMMON, Kind.SHADOW_EXTRACT, Kind.SHADOW_CALL]


func summon_cap(skill_level: int) -> int:
	var extra: int = floori(float(maxi(skill_level, 1)) / extra_summon_every) if extra_summon_every > 0 else 0
	return max_summons + extra


func is_passive() -> bool:
	return kind == Kind.PASSIVE
