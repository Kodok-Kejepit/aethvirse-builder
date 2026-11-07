class_name DialogEffect
extends Resource
## Something a dialog choice (or showing an entry) does to the world.

enum Type { GIVE_ITEM, TAKE_ITEM, GIVE_GOLD, TAKE_GOLD, SET_FLAG, COMPLETE_SECRET, HINT, RECORD_DAILY, IDENTIFY }

@export var type: Type = Type.SET_FLAG
## Item id / flag / secret id / counter id.
@export var key: StringName = &""
@export var amount: int = 1
## HINT: hint key. IDENTIFY: method (&"appraiser").
@export var text: StringName = &""
