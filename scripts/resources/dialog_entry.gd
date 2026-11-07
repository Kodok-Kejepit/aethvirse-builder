class_name DialogEntry
extends Resource
## One conversation option of an NPC. The NPC uses the first entry whose conditions hold.

@export var id: StringName = &""
@export var conditions: Array[ConditionData] = []
## Translation keys, spoken in order.
@export var lines: Array[StringName] = []
## If several variants, one is picked per game day (NPCs say something different each day).
@export var daily_variants: Array[StringName] = []
@export var on_show: Array[DialogEffect] = []
@export var choices: Array[DialogChoice] = []
