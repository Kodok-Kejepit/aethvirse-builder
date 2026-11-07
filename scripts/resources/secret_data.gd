class_name SecretData
extends Resource
## A secret from ascendant-dev/docs/MYSTERY_BIBLE.md (same IDs). See §4 there.

enum Kind { LOCATION, SEALED_MISSION, SECRET_ITEM, CHEST, PUZZLE, LORE, MASTER_CLUE }
enum Tier { SMALL, MEDIUM, LARGE }
## AUTO: tracker completes it as soon as all conditions hold.
## EVENT: a world script calls SecretTracker.complete(id); conditions are checked then.
enum Trigger { AUTO, EVENT }

@export var id: StringName = &""
## Translation key.
@export var display_name: StringName = &""
@export var kind: Kind = Kind.LOCATION
@export var tier: Tier = Tier.SMALL
@export var region: StringName = &"r1_ashfall"
@export var trigger: Trigger = Trigger.AUTO
## For sealed-mission stages ("SM-R1-01:2"): the mission id; counted once in the tracker.
@export var mission: StringName = &""
@export var conditions: Array[ConditionData] = []
## Translation keys, ≥ 2 (fairness rule §9.5).
@export var hints: Array[StringName] = []
@export var rewards: Array[RewardData] = []
@export var unlocks: Array[StringName] = []
@export var fail_conditions: Array[ConditionData] = []
@export var hidden_from_tracker: bool = false


func counts_as_secret() -> bool:
	return kind in [Kind.LOCATION, Kind.SECRET_ITEM, Kind.CHEST, Kind.PUZZLE] and not hidden_from_tracker
