class_name DialogChoice
extends Resource
## A player answer. Hidden unless its conditions hold; may cost gold.

@export var text: StringName = &""
@export var conditions: Array[ConditionData] = []
@export var effects: Array[DialogEffect] = []
## Lines the NPC says after this choice (translation keys).
@export var reply: Array[StringName] = []
@export var gold_cost: int = 0
