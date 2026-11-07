class_name NpcData
extends Resource
## NPC definition: name, look, dialog entries (priority order), reaction to being attacked.

@export var id: StringName = &""
@export var display_name: StringName = &""
@export var body_color: Color = Color(0.6, 0.6, 0.6)
@export var entries: Array[DialogEntry] = []
## Flag set if the player hits this NPC (permanent consequences live in secret data).
@export var attacked_flag: StringName = &""
## The NPC disappears while this flag is set (e.g. Marrow leaves after being attacked).
@export var hidden_when_flag: StringName = &""
## Daily schedule: the NPC is away between these hours (e.g. 21 → 6 = closed at night).
## -1 = always present.
@export var away_from_hour: int = -1
@export var away_to_hour: int = -1


func is_away(hour: int) -> bool:
	if away_from_hour < 0:
		return false
	if away_from_hour <= away_to_hour:
		return hour >= away_from_hour and hour < away_to_hour
	return hour >= away_from_hour or hour < away_to_hour
