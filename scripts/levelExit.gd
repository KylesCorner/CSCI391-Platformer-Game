extends Area2D

@export var next_level: PackedScene

var triggered: bool = false


func _ready() -> void:
	body_entered.connect(
		_on_body_entered
	)


func _on_body_entered(body: Node2D) -> void:
	#
	# Prevent the exit from triggering multiple times.
	#
	if triggered:
		return

	#
	# Only the player can activate the exit.
	#
	if not body.is_in_group("player"):
		return

	#
	# Make sure a destination was configured.
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
