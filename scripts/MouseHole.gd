class_name MouseHole
extends Marker2D

@onready var exit_point: Marker2D = $ExitPoint


func _ready() -> void:
	add_to_group("mouse_hole")


func get_exit_position() -> Vector2:
	return exit_point.global_position
