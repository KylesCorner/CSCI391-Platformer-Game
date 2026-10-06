extends Control


const MAIN_SCENE_PATH: String = "res://main.tscn"


const LEVEL_0: PackedScene = preload(
	"res://scenes/Level00.tscn"
)

const LEVEL_1: PackedScene = preload(
	"res://scenes/Level01.tscn"
)

const LEVEL_2: PackedScene = preload(
	"res://scenes/Level02.tscn"
)


@onready var level_0_button: Button = (
	$CenterContainer/VBoxContainer/Level0Button
)

@onready var level_1_button: Button = (
	$CenterContainer/VBoxContainer/Level1Button
)

@onready var level_2_button: Button = (
	$CenterContainer/VBoxContainer/Level2Button
)

@onready var quit_button: Button = (
	$CenterContainer/VBoxContainer/QuitButton
)


func _ready() -> void:
	level_0_button.pressed.connect(
		_on_level_0_button_pressed
	)

	level_1_button.pressed.connect(
		_on_level_1_button_pressed
	)


	quit_button.pressed.connect(
		_on_quit_button_pressed
	)


func _on_level_0_button_pressed() -> void:
	start_game(
		LEVEL_0
	)


func _on_level_1_button_pressed() -> void:
	start_game(
		LEVEL_1
	)



func start_game(
	level: PackedScene
) -> void:
	LevelManager.set_starting_level(
		level
	)

	get_tree().change_scene_to_file(
		MAIN_SCENE_PATH
	)


func _on_quit_button_pressed() -> void:
	get_tree().quit()
