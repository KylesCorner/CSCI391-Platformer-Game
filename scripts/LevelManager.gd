extends Node


var changing_level: bool = false


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
	# LevelExit.body_entered() happens during a physics callback.
	#
	# Do not remove collision objects until that callback has
	# finished.
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
	var main: Node = get_tree().current_scene

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
		#
		# queue_free() is deferred and safe.
		#
		# Do NOT manually remove_child() here.
		#
		child.queue_free()


	#
	# Give Godot time to actually delete the old level.
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
	# Give the new scene time to enter the tree.
	#
	await get_tree().process_frame


	#
	# ========================================================
	# FIND PLAYER SPAWN
	# ========================================================
	#
	# Every level should contain:
	#
	# Level
	# └── SpawnPoints
	#     └── Start
	#
	# This is much more reliable than searching the entire
	# scene tree for whichever player_spawn happens to appear
	# first.
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
		#
		# Move persistent player into the new level.
		#
		player.global_position = (
			spawn.global_position
		)

		player.velocity = Vector2.ZERO

		#
		# Prevent interpolation from visually smearing the
		# player from the old position to the new position.
		#
		player.reset_physics_interpolation()


	changing_level = false
