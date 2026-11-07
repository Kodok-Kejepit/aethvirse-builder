class_name AttackTokenPool
extends Node
## Limits how many enemies may attack the player at the same time (fairness, §6).
## Put one in a level; enemies find it through the group. Without a pool, attacks are free.

const GROUP: StringName = &"attack_tokens"

@export var max_tokens: int = 2

var _holders: Array[Node] = []


func _ready() -> void:
	add_to_group(GROUP)


func request(holder: Node) -> bool:
	_holders = _holders.filter(func(n: Node) -> bool: return is_instance_valid(n))
	if holder in _holders:
		return true
	if _holders.size() >= max_tokens:
		return false
	_holders.append(holder)
	return true


func release(holder: Node) -> void:
	_holders.erase(holder)


func active_count() -> int:
	return _holders.size()


static func find(from: Node) -> AttackTokenPool:
	return from.get_tree().get_first_node_in_group(GROUP) as AttackTokenPool
