extends CanvasLayer


@onready var hud_root: Control = $HUDRoot

@onready var health_bar: AnimatedSprite2D = (
	$HUDRoot/HealthBar
)


var player: CharacterBody2D = null


func _ready() -> void:
	add_to_group("hud")
	#
	# Always draw the HUD above the game world.
	#
	layer = 10
	
	
	# ignore mouse input for credit screen
	hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	#
	# Make HUDRoot cover the entire game viewport.
	#
	hud_root.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	#
	# Put the health bar in the top-left corner.
	#
	# AnimatedSprite2D normally positions itself from its center.
	# Turning centered off makes (10, 10) mean the actual
	# top-left corner of the sprite.
	#
	health_bar.centered = false
	health_bar.position = Vector2(10, 10)
	health_bar.scale = Vector2(10.0, 5.0)
	health_bar.visible = true
	health_bar.z_index = 100

	health_bar.animation = "Health"
	health_bar.frame = 0

	#
	# Wait until Player has initialized.
	#
	await get_tree().process_frame

	player = (
		get_tree().get_first_node_in_group("player")
		as CharacterBody2D
	)

	if player == null:
		push_warning("HUD could not find the player.")
		return

	#
	# Listen for health changes.
	#
	player.health_changed.connect(
		_on_player_health_changed
	)

	#
	# Set initial health state.
	#
	_on_player_health_changed(
		player.health,
		player.max_health
	)


func _on_player_health_changed(
	current_health: int,
	max_health: int
) -> void:
	if max_health <= 0:
		return

	var frame_count: int = (
		health_bar.sprite_frames.get_frame_count(
			"Health"
		)
	)

	if frame_count <= 0:
		push_warning(
			"Health animation has no frames."
		)
		return

	var health_ratio: float = clampf(
		float(current_health)
		/ float(max_health),
		0.0,
		1.0
	)

	#
	# Frame 0 = full health.
	# Final frame = empty health.
	#
	var frame_index: int = roundi(
		(1.0 - health_ratio)
		* float(frame_count - 1)
	)

	frame_index = clampi(
		frame_index,
		0,
		frame_count - 1
	)

	health_bar.animation = "Health"
	health_bar.frame = frame_index
