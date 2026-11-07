class_name QuestData
extends Resource
## A quest: stages of parallel (optionally optional) objectives + rewards.
## Kinds: STORY / SIDE / DAILY / EMERGENCY / BOUNTY.

@export var id: StringName = &""
@export var title: StringName = &""
@export var description: StringName = &""
enum Kind { STORY, SIDE, DAILY, EMERGENCY, BOUNTY }

@export var kind: Kind = Kind.SIDE
@export var auto_start: bool = false
## Auto-start only once these hold (checked when the world changes).
@export var start_conditions: Array[ConditionData] = []
## EMERGENCY: seconds to finish, 0 = no limit.
@export var time_limit_s: float = 0.0
@export var guild_points: int = 0
@export var objectives: Array[QuestObjective] = []
@export var rewards: Array[RewardData] = []


func stage_count() -> int:
	var top: int = -1
	for o: QuestObjective in objectives:
		top = maxi(top, o.stage)
	return top + 1


func objectives_in(stage: int) -> Array[int]:
	var out: Array[int] = []
	for i: int in objectives.size():
		if objectives[i].stage == stage:
			out.append(i)
	return out
