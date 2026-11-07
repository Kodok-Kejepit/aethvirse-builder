class_name RainGrate
extends StaticBody3D
## SEC-R1-01: a rusted grate that only gives way while it rains. Breathes steam in the rain.

@export var hint_secret: StringName = &"SEC-R1-01"
@export var hint_key: StringName = &"HINT_SEC_R1_01_2"
@export var hint_radius_m: float = 12.0

@onready var mesh: MeshInstance3D = %Mesh
@onready var steam: GPUParticles3D = %Steam


func _physics_process(_delta: float) -> void:
	var open: bool = GameState.weather.is_wet()
	collision_layer = 0 if open else 1
	mesh.transparency = 0.7 if open else 0.0
	steam.emitting = open
	if open:
		var player: Player = GameState.player as Player
		if player != null and player.global_position.distance_to(global_position) < hint_radius_m:
			var tracker: SecretTracker = SecretTracker.find(self)
			if tracker != null:
				tracker.discover_hint(hint_secret, hint_key)
