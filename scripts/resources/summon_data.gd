class_name SummonData
extends Resource
## A minion the player can call (Summoner familiars, Necromancer shadow soldiers).
## Its damage is a fraction of the player's own attack so it scales with gear and level.

@export var id: StringName = &""
@export var display_name: String = ""
@export var body_color: Color = Color(0.5, 0.8, 1.0, 0.85)
@export var height: float = 1.0
## Fraction of the player's ATK / M.ATK per hit.
@export var power: float = 0.25
@export var attack_range: float = 1.8
@export var attack_interval_s: float = 1.2
@export var move_speed: float = 6.5
## 0 = stays until dismissed or the area changes.
@export var duration_s: float = 20.0
## Minions look for enemies within this distance of the player.
@export var leash_m: float = 14.0
@export var element: Element.Type = Element.Type.PHYSICAL
## Minion HP as a share of the owner's max HP (enemies attack minions too).
@export_range(0.05, 2.0) var hp_share: float = 0.35
