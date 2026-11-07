class_name PropData
extends Resource
## An imported world model (tools/import_props.gd): building, landmark or small prop.
## PropInstance shows it; generators place it by id and fall back to graybox when missing.

enum Collision { NONE, BOX, CONVEX }

@export var id: StringName = &""
@export_file("*.res") var mesh_path: String = ""
@export_file("*.jpg", "*.png") var albedo_path: String = ""
## Footprint/height after import (metres) — used by generators to fit the model.
@export var size: Vector3 = Vector3.ONE
@export var collision: Collision = Collision.BOX
## Fraction of the platform view distance after which it is not drawn (0 = always).
@export var view_share: float = 0.6


static func path_for(prop_id: StringName) -> String:
	return "res://data/props/%s.tres" % prop_id


static func find(prop_id: StringName) -> PropData:
	var p: String = path_for(prop_id)
	return load(p) as PropData if ResourceLoader.exists(p) else null
