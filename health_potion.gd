class_name HealthPotion
extends RigidBody2D


@export var heal_amount: int = 25


var consumed: bool = false


@onready var sprite: AnimatedSprite2D = (
	$AnimatedSprite2D
)

@onready var collision_shape: CollisionShape2D = (
	$CollisionShape2D
)


func _ready() -> void:
	add_to_group("interactable")
	add_to_group("health_potion")

	sprite.play("Idle")


func interact(
	player: Node
) -> void:
	if consumed:
		return

	if player == null:
		return

	if not player.has_method("heal"):
		return

	if player.health >= player.max_health:
		return

	consumed = true


	#
	# Heal the player.
	#
	player.heal(
		heal_amount
	)


	#
	# Stop all potion physics immediately.
	#
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true


	#
	# Disable collision so it can't be interacted
	# with or pushed again.
	#
	collision_shape.set_deferred(
		"disabled",
		true
	)


	#
	# Play drink animation while staying
	# exactly where it was consumed.
	#
	if sprite.sprite_frames.has_animation(
		"Drink"
	):
		sprite.stop()
		sprite.frame = 0

		sprite.play(
			"Drink"
		)

		await sprite.animation_finished


	queue_free()
