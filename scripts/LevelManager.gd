extends Node


var changing_level: bool = false


#
# The level selected from the main menu.
#
var starting_level: PackedScene = null


#
# ============================================================
# STARTING LEVEL
# ============================================================
#

func set_starting_level(
	level: PackedScene
) -> void:
	starting_level = level


func take_starting_level() -> PackedScene:
	var level: PackedScene = (
		starting_level
	)

	starting_level = null

	return level


#
# ============================================================
# CHANGE LEVEL
# ============================================================
#

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


	#
	# Level changes may be triggered during physics callbacks.
	# Delay the actual scene manipulation until it is safe.
	#
	call_deferred(
		"_change_level_deferred",
		next_level
	)


#
# ============================================================
# DEFERRED LEVEL CHANGE
# ============================================================
#

func _change_level_deferred(
	next_level: PackedScene
) -> void:
	var main: Node = (
		get_tree().current_scene
	)


	if main == null:
		push_error(
			"LevelManager could not find Main."
		)

		changing_level = false

		return


	#
	# ========================================================
	# FIND CURRENT LEVEL CONTAINER
	# ========================================================
	#

	var level_container: Node = (
		main.get_node_or_null(
			"CurrentLevel"
		)
	)


	if level_container == null:
		push_error(
			"Main does not contain CurrentLevel."
		)

		changing_level = false

		return


	#
	# ========================================================
	# FIND PLAYER
	# ========================================================
	#

	var player: CharacterBody2D = (
		get_tree().get_first_node_in_group(
			"player"
		)
		as CharacterBody2D
	)


	if player == null:
		push_error(
			"LevelManager could not find the player."
		)

		changing_level = false

		return


	#
	# ========================================================
	# REMOVE OLD LEVEL
	# ========================================================
	#

	for child: Node in level_container.get_children():
		child.queue_free()


	#
	# Allow queued nodes to actually be removed.
	#
	await get_tree().process_frame


	#
	# ========================================================
	# CREATE NEW LEVEL
	# ========================================================
	#

	var new_level: Node = (
		next_level.instantiate()
	)


	level_container.add_child(
		new_level
	)


	#
	# Allow the new scene to enter the tree.
	#
	await get_tree().process_frame


	#
	# ========================================================
	# FIND PLAYER SPAWN
	# ========================================================
	#

	var spawn: Marker2D = (
		new_level.get_node_or_null(
			"SpawnPoints/Start"
		)
		as Marker2D
	)


	if spawn == null:
		push_warning(
			"New level does not contain SpawnPoints/Start."
		)

	else:
		player.global_position = (
			spawn.global_position
		)

		player.velocity = (
			Vector2.ZERO
		)

		player.reset_physics_interpolation()


	changing_level = false
