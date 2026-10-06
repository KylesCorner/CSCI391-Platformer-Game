extends Node2D


@onready var player: CharacterBody2D = (
	$Player
)

@onready var credits: Control = (
	$UI/GodotCredits
)


func _ready() -> void:
	player.died.connect(
		_on_player_died
	)


	#
	# If the player selected a level from the main menu,
	# load that level now.
	#
	var starting_level: PackedScene = (
		LevelManager.take_starting_level()
	)


	if starting_level != null:
		LevelManager.change_level(
			starting_level
		)


func _on_player_died() -> void:
	credits.show_credits()
