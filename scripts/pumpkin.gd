class_name Pumpkin
extends RigidBody2D


@export var minimum_stun_speed: float = 100.0
@export var stun_duration: float = 2.0


var held_by: Node2D = null
var is_thrown: bool = false

var is_being_destroyed: bool = false


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var collision_shape: CollisionShape2D = (
	$CollisionShape2D
)


func _ready() -> void:
	add_to_group("carryable")
	add_to_group("pumpkin")

	lock_rotation = true

	contact_monitor = true
	max_contacts_reported = 8

	body_entered.connect(
		_on_body_entered
	)

	sprite.play("Idle")


func pick_up(holder: Node2D) -> void:
	if held_by != null:
		return

	if is_being_destroyed:
		return

	held_by = holder

	is_thrown = false

	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	freeze = true

	add_collision_exception_with(
		holder
	)


func release(
	release_velocity: Vector2
) -> void:
	if held_by == null:
		return

	if is_being_destroyed:
		return

	var previous_holder := held_by

	held_by = null

	is_thrown = (
		release_velocity.length()
		>= minimum_stun_speed
	)

	freeze = false

	linear_velocity = release_velocity

	await get_tree().create_timer(
		0.15
	).timeout

	if is_instance_valid(previous_holder):
		remove_collision_exception_with(
			previous_holder
		)


func _on_body_entered(
	body: Node
) -> void:
	if is_being_destroyed:
		return

	if not is_thrown:
		return

	if not body.has_method("stun"):
		return

	#
	# Stun the enemy.
	#
	body.stun(
		stun_duration
	)

	#
	# Destroy pumpkin after successful hit.
	#
	destroy()


func destroy() -> void:
	if is_being_destroyed:
		return

	is_being_destroyed = true

	is_thrown = false
	held_by = null

	#
	# Stop all pumpkin physics.
	#
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0

	freeze = true

	#
	# Disable collision immediately so the destroyed
	# pumpkin cannot block or hit anything.
	#
	collision_shape.set_deferred(
		"disabled",
		true
	)

	#
	# Play destruction animation.
	#
	sprite.play("Destroy")

	#
	# Wait for the animation before deleting the pumpkin.
	#
	await sprite.animation_finished

	queue_free()
