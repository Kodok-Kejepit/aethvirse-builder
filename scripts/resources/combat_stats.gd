class_name CombatStats
extends Resource
## Flat combat numbers used by DamageCalculator. In M3 these are derived from StatsComponent.

@export var attack: float = 20.0
@export var defense: float = 5.0
@export_range(0.0, 1.0, 0.01) var crit_chance: float = 0.1
## Crit multiplier (1.5 = +50%).
@export var crit_damage: float = 1.5
## Affinity used for incoming element multipliers.
@export var element: Element.Type = Element.Type.PHYSICAL
