class_name RewardData
extends Resource
## What a secret / quest / dialog gives.

enum Type { ITEM, GOLD, XP, FLAG, TITLE, LORE, CODEX_MESSAGE, ANOMALY, LOOT_TABLE }

@export var type: Type = Type.ITEM
## Item id / flag / title id / lore id / loot table id.
@export var key: StringName = &""
@export var amount: int = 1
## Translation key (CODEX_MESSAGE / ANOMALY).
@export var text: StringName = &""
