class_name EnemyState
extends State
## Base for enemy AI states; `enemy` is injected by Enemy before the machine starts.

const IDLE: StringName = &"Idle"
const CHASE: StringName = &"Chase"
const ATTACK: StringName = &"Attack"
const HURT: StringName = &"Hurt"
const RETURN: StringName = &"Return"
const DEAD: StringName = &"Dead"

var enemy: Enemy
