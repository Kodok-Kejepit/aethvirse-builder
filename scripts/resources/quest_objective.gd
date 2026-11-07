class_name QuestObjective
extends Resource
## One step of a quest.

## COLLECT = have N in the bag; PICKUP = pick N up (counted as they arrive).
enum Type { KILL, TALK, COLLECT, REACH_AREA, CLEAR_GATE, FLAG, ATTACK, DODGE, DISTANCE, SECRET,
	PICKUP, CRAFT, USE_ITEM, SKILL }

@export var type: Type = Type.KILL
## Enemy id / NPC id / item id / area id / gate id / flag.
@export var target: StringName = &""
@export var count: int = 1
## Translation key; "%d/%d" is appended for counted objectives.
@export var text: StringName = &""
## Objectives with the same stage run in parallel; the quest advances when every
## non-optional objective of the current stage is done.
@export var stage: int = 0
@export var optional: bool = false
