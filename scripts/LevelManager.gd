extends Node


var changing_level: bool = false


func change_level(
	next_level: PackedScene
) -> void:
	if changing_level:
		return

	if next_level == null:
		push_error(
			"Attempted to load a null level."
		)
		return

	changing_level = true

	var main: Node = get_tree().current_scene

	if main == null:
		push_error(
			"LevelManager could not find Main."
		)

		changing_level = false
		return

	var level_container: Node = (
		main.get_node_or_null("CurrentLevel")
	)

	if level_container == null:
		push_error(
			"Main does not contain CurrentLevel."
		)

		changing_level = false
		return

	var player: CharacterBody2D = (
		get_tree().get_first_node_in_group("player")
		as CharacterBody2D
	)

	if player == null:
		push_error(
			"LevelManager could not find the player."
		)

		changing_level = false
		return

	#
	# Remove the current level.
	#
	for child: Node in level_container.get_children():
		level_container.remove_child(child)
		child.queue_free()

	#
	# Wait until the old level is actually gone.
	#
	await get_tree().process_frame

	#
	# Create the new level.
	#
	var new_level: Node = (
		next_level.instantiate()
	)

	level_container.add_child(
		new_level
	)

	#
	# Give the new level a frame to enter the tree and
	# register its groups.
	#
	await get_tree().process_frame

	#
	# Find the new level's player spawn.
	#
	var spawn: Marker2D = (
		get_tree().get_first_node_in_group(
			"player_spawn"
		)
		as Marker2D
	)

	if spawn == null:
		push_warning(
			"New level has no player_spawn."
		)
	else:
		player.global_position = (
			spawn.global_position
		)

		player.velocity = Vector2.ZERO

	changing_level = false
