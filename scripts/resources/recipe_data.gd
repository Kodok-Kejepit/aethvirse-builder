class_name RecipeData
extends Resource
## Crafting / alchemy recipe.

@export var id: StringName = &""
@export var inputs: Dictionary[StringName, int] = {}
@export var output: StringName = &""
@export var output_count: int = 1
@export var gold_cost: int = 0
