extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var credits: Control = $UI/GodotCredits


func _ready() -> void:
	player.died.connect(
		_on_player_died
	)


func _on_player_died() -> void:
	credits.show_credits()
