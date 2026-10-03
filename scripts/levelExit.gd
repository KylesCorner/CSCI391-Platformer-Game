class_name LevelExit
extends StaticBody2D


@export var next_level: PackedScene


var triggered: bool = false


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("level_exit")


#
# ============================================================
# INTERACT
# ============================================================
#

func interact(
	player: Node
) -> void:
	#
	# Prevent multiple level changes.
	#
	if triggered:
		return


	#
	# Only the player should be able to use the door.
	#
	if player == null:
		return

	if not player.is_in_group("player"):
		return


	#
	# Make sure a destination was assigned.
	#
	if next_level == null:
		push_warning(
			"LevelExit has no next_level assigned."
		)

		return


	triggered = true


	LevelManager.change_level(
		next_level
	)
