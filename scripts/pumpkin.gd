@tool
class_name Pumpkin
extends RigidBody2D


#
# ============================================================
# SETTINGS
# ============================================================
#

@export_category("Pumpkin")

#
# Weight controls:
#
# - physics mass
# - visible size
# - collision size
# - push difficulty
# - throw difficulty
# - stun duration
#
@export_range(0.25, 10.0, 0.05)
var weight: float = 1.0


@export var base_stun_duration: float = 1.0

@export var minimum_stun_speed: float = 35.0

@export var thrown_disarm_speed: float = 15.0

@export var thrown_disarm_delay: float = 0.20


#
# ============================================================
# SIZE
# ============================================================
#

@export_category("Size")

@export var scale_size_with_weight: bool = true


#
# 0.5 means sqrt(weight).
#
# Examples:
#
# weight 0.25 -> 0.50x
# weight 0.50 -> 0.71x
# weight 1.00 -> 1.00x
# weight 2.00 -> 1.41x
# weight 4.00 -> 2.00x
#
@export_range(0.1, 1.0, 0.05)
var weight_size_exponent: float = 0.5


#
# ============================================================
# STATE
# ============================================================
#

var held_by: Node2D = null

var is_thrown: bool = false

var is_being_destroyed: bool = false

var throw_age: float = 0.0


#
# ============================================================
# NODES
# ============================================================
#

@onready var sprite: AnimatedSprite2D = (
	$AnimatedSprite2D
)

@onready var collision_shape: CollisionShape2D = (
	$CollisionShape2D
)


#
# ============================================================
# READY
# ============================================================
#

func _ready() -> void:
	apply_weight_settings()


	#
	# Stop here when running inside the editor.
	#
	if Engine.is_editor_hint():
		return


	add_to_group("carryable")
	add_to_group("pumpkin")


	lock_rotation = true


	contact_monitor = true

	max_contacts_reported = 8


	if not body_entered.is_connected(
		_on_body_entered
	):
		body_entered.connect(
			_on_body_entered
		)


	if sprite.sprite_frames.has_animation(
		"Idle"
	):
		sprite.play(
			"Idle"
		)


#
# ============================================================
# EDITOR UPDATE
# ============================================================
#

func _process(
	_delta: float
) -> void:
	#
	# While editing the scene, continually synchronize
	# weight -> size.
	#
	# This makes changes visible immediately in the 2D editor.
	#
	if Engine.is_editor_hint():
		apply_weight_settings()


#
# ============================================================
# WEIGHT / SIZE
# ============================================================
#

func apply_weight_settings() -> void:
	#
	# --------------------------------------------------------
	# MASS
	# --------------------------------------------------------
	#

	mass = maxf(
		weight,
		0.01
	)


	#
	# --------------------------------------------------------
	# SIZE
	# --------------------------------------------------------
	#

	var size_multiplier: float = 1.0


	if scale_size_with_weight:
		size_multiplier = pow(
			maxf(
				weight,
				0.01
			),
			weight_size_exponent
		)


	#
	# IMPORTANT:
	#
	# Do NOT scale the RigidBody2D root.
	#
	# Scale the visual and collision children instead.
	#
	var sprite_node := (
		get_node_or_null(
			"AnimatedSprite2D"
		)
		as AnimatedSprite2D
	)


	if sprite_node != null:
		sprite_node.scale = Vector2(
			size_multiplier,
			size_multiplier
		)


	var collision_node := (
		get_node_or_null(
			"CollisionShape2D"
		)
		as CollisionShape2D
	)


	if collision_node != null:
		collision_node.scale = Vector2(
			size_multiplier,
			size_multiplier
		)


#
# ============================================================
# PHYSICS
# ============================================================
#

func _physics_process(
	delta: float
) -> void:
	if Engine.is_editor_hint():
		return


	if not is_thrown:
		return


	if is_being_destroyed:
		return


	throw_age += delta


	if throw_age < thrown_disarm_delay:
		return


	#
	# Once a thrown pumpkin settles down,
	# it becomes a normal pumpkin again.
	#
	if (
		linear_velocity.length()
		< thrown_disarm_speed
	):
		disarm_as_weapon()


#
# ============================================================
# STUN
# ============================================================
#

func get_stun_duration() -> float:
	return (
		base_stun_duration
		* weight
	)


#
# ============================================================
# ENEMY QUERY
# ============================================================
#

func can_be_attacked_by_enemy() -> bool:
	if is_being_destroyed:
		return false


	if held_by != null:
		return false


	#
	# Flying pumpkins are weapons.
	#
	# Enemy should not attack one while it is flying.
	#
	if is_thrown:
		return false


	return true


func disarm_as_weapon() -> void:
	is_thrown = false

	throw_age = 0.0


#
# ============================================================
# PICK UP
# ============================================================
#

func pick_up(
	holder: Node2D
) -> void:
	if is_being_destroyed:
		return


	if held_by != null:
		return


	held_by = holder


	disarm_as_weapon()


	linear_velocity = Vector2.ZERO

	angular_velocity = 0.0


	#
	# No physics while held.
	#
	freeze_mode = (
		RigidBody2D.FREEZE_MODE_KINEMATIC
	)

	freeze = true


	#
	# No collision while carried.
	#
	collision_shape.set_deferred(
		"disabled",
		true
	)


#
# ============================================================
# RELEASE
# ============================================================
#

func release(
	release_impulse: Vector2
) -> void:
	if is_being_destroyed:
		return


	if held_by == null:
		return


	#
	# Player has already positioned the pumpkin at HoldPoint.
	#
	var release_transform: Transform2D = (
		global_transform
	)


	held_by = null


	linear_velocity = Vector2.ZERO

	angular_velocity = 0.0


	#
	# Zero impulse = drop.
	#
	# Non-zero impulse = throw.
	#
	if release_impulse.is_zero_approx():
		disarm_as_weapon()

	else:
		is_thrown = true

		throw_age = 0.0


	#
	# Restore physics.
	#
	freeze = false

	sleeping = false


	#
	# Preserve exact held position.
	#
	global_transform = release_transform


	reset_physics_interpolation()


	#
	# Restore collision.
	#
	collision_shape.set_deferred(
		"disabled",
		false
	)


	#
	# Actual physics impulse.
	#
	# Since mass = weight:
	#
	# heavier pumpkin = less velocity
	#
	if is_thrown:
		apply_central_impulse(
			release_impulse
		)


#
# ============================================================
# THROWN HIT
# ============================================================
#

func _on_body_entered(
	body: Node
) -> void:
	if is_being_destroyed:
		return


	#
	# Grounded/dropped pumpkins never stun.
	#
	if not is_thrown:
		return


	if not body.has_method(
		"stun"
	):
		return


	var impact_speed: float = (
		linear_velocity.length()
	)


	if (
		impact_speed
		< minimum_stun_speed
	):
		return


	#
	# Legitimate thrown-pumpkin hit.
	#
	disarm_as_weapon()


	body.stun(
		get_stun_duration()
	)


	destroy()


#
# ============================================================
# ENEMY DESTROY
# ============================================================
#

func destroy_by_enemy() -> void:
	if is_being_destroyed:
		return


	disarm_as_weapon()


	destroy()


#
# ============================================================
# DESTROY
# ============================================================
#

func destroy() -> void:
	if is_being_destroyed:
		return


	is_being_destroyed = true


	disarm_as_weapon()


	held_by = null


	#
	# Preserve exact current position.
	#
	var destroy_transform: Transform2D = (
		global_transform
	)


	#
	# Stop all physics.
	#
	linear_velocity = Vector2.ZERO

	angular_velocity = 0.0


	freeze_mode = (
		RigidBody2D.FREEZE_MODE_KINEMATIC
	)

	freeze = true


	global_transform = destroy_transform


	reset_physics_interpolation()


	#
	# Stop blocking objects while destroying.
	#
	collision_shape.set_deferred(
		"disabled",
		true
	)


	#
	# Play Destroy animation in place.
	#
	if sprite.sprite_frames.has_animation(
		"Destroy"
	):
		sprite.stop()

		sprite.frame = 0

		sprite.play(
			"Destroy"
		)


		await sprite.animation_finished


	queue_free()
