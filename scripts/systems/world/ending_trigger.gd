class_name EndingTrigger
extends Node3D
## Placed in the Hollow Throne: opens Vael's question after The Unwritten falls.


func _process(_delta: float) -> void:
	if Engine.get_process_frames() % 30 == 0:
		EndingPanel.watch(self)
