extends CharacterBody2D


#
# ============================================================
# INPUT ACTIONS
# ============================================================
#

const ACTION_MOVE_LEFT: StringName = &"move_left"
const ACTION_MOVE_RIGHT: StringName = &"move_right"
const ACTION_JUMP: StringName = &"jump"
const ACTION_MOVE_DOWN: StringName = &"move_down"
const ACTION_INTERACT: StringName = &"interact"


#
# ============================================================
# MOVEMENT
# ============================================================
#

const SPEED: float = 100.0
const JUMP_VELOCITY: float = -315.0


@export_category("Player")

@export var max_health: int = 100

@export var ladder_speed: float = 180.0


#
# 2 = normal jump + one double jump.
#
@export var max_jumps: int = 2


#
# Smaller value = shorter tap jump.
#
@export_range(0.1, 1.0, 0.05)
var jump_cut_multiplier: float = 0.45


#
# ============================================================
# PHYSICS INTERACTION
# ============================================================
#

@export_category("Physics Interaction")


#
# Actual physical force applied to RigidBody2Ds.
#
# Because this is a force rather than a manually assigned
# velocity, RigidBody2D.mass actually matters.
#
@export var push_force: float = 1000.0


#
# Prevent props from accelerating forever.
#
@export var max_push_speed: float = 80.0


#
# ============================================================
# DOUBLE JUMP
# ============================================================
#

@export_category("Double Jump")

@export var double_jump_animation: StringName = &"DoubleJump"


#
# ============================================================
# PUMPKIN
# ============================================================
#

@export_category("Pumpkin")


@export var pickup_distance: float = 28.0

@export var hold_distance: float = 10.0


#
# These are now IMPULSES, not velocities.
#
# Weight 1.0 pumpkin:
# approximately the same response as before.
#
# Weight 2.0 pumpkin:
# receives roughly half the velocity.
#
@export var throw_horizontal_impulse: float = 350.0

@export var throw_upward_impulse: float = 120.0


#
# ============================================================
# PLAYER STATE
# ============================================================
#

var health: int


var movement_multiplier: float = 1.0


var slow_zone_count: int = 0

var slow_zone_multiplier: float = 1.0


var ladder_count: int = 0

var climbing: bool = false


var jumps_remaining: int = 0


#
#  1 = right
# -1 = left
#
var facing_direction: float = 1.0


var held_pumpkin: Pumpkin = null


#
# ============================================================
# NODES
# ============================================================
#

@onready var sprite: AnimatedSprite2D = (
	$AnimatedSprite2D
)


@onready var hold_point: Marker2D = (
	$HoldPoint
)


@onready var pickup_ray: RayCast2D = (
	$PickupRay
)


@onready var double_jump: AnimatedSprite2D = (
	$DoubleJump
)


#
# ============================================================
# SIGNALS
# ============================================================
#

signal died


signal health_changed(
	current_health: int,
	max_health: int
)


#
# ============================================================
# PLAYER STATE MACHINE
# ============================================================
#

enum State {
	NORMAL,
	HURT,
	DEAD
}


var state: State = State.NORMAL


#
# ============================================================
# READY
# ============================================================
#

func _ready() -> void:
	add_to_group(
		"player"
	)


	health = max_health

	jumps_remaining = max_jumps


	health_changed.emit(
		health,
		max_health
	)


	sprite.play(
		"Idle"
	)


	sprite.animation_finished.connect(
		_on_animation_finished
	)


	double_jump.visible = false


	double_jump.animation_finished.connect(
		_on_double_jump_animation_finished
	)


	#
	# Interaction detection.
	#
	pickup_ray.enabled = true

	pickup_ray.collide_with_bodies = true

	pickup_ray.collide_with_areas = true

	pickup_ray.exclude_parent = true


	update_interaction_direction()


#
# ============================================================
# PHYSICS
# ============================================================
#

func _physics_process(
	delta: float
) -> void:
	update_held_pumpkin()


	if state == State.DEAD:
		return


	update_interaction_direction()


	#
	# ========================================================
	# INPUT
	# ========================================================
	#

	var horizontal_input: float = Input.get_axis(
		ACTION_MOVE_LEFT,
		ACTION_MOVE_RIGHT
	)


	var vertical_input: float = Input.get_axis(
		ACTION_JUMP,
		ACTION_MOVE_DOWN
	)


	var jump_pressed: bool = (
		Input.is_action_just_pressed(
			ACTION_JUMP
		)
	)


	var jump_released: bool = (
		Input.is_action_just_released(
			ACTION_JUMP
		)
	)


	var down_held: bool = (
		Input.is_action_pressed(
			ACTION_MOVE_DOWN
		)
	)


	var interact_pressed: bool = (
		Input.is_action_just_pressed(
			ACTION_INTERACT
		)
	)


	#
	# ========================================================
	# INTERACTION
	# ========================================================
	#

	if interact_pressed:
		handle_interaction(
			down_held
		)


	#
	# ========================================================
	# LADDER ENTRY
	# ========================================================
	#

	if (
		ladder_count > 0
		and vertical_input != 0.0
		and state == State.NORMAL
	):
		climbing = true


	#
	# ========================================================
	# LADDER MOVEMENT
	# ========================================================
	#

	if (
		climbing
		and ladder_count > 0
		and state == State.NORMAL
	):
		handle_ladder_movement(
			horizontal_input,
			vertical_input
		)


		move_and_slide()


		push_rigid_bodies(
			horizontal_input
		)


		update_held_pumpkin()


		return


	#
	# ========================================================
	# RESET JUMPS
	# ========================================================
	#

	if is_on_floor():
		jumps_remaining = max_jumps


	#
	# ========================================================
	# GRAVITY
	# ========================================================
	#

	if not is_on_floor():
		velocity += (
			get_gravity()
			* delta
		)


	#
	# ========================================================
	# HURT
	# ========================================================
	#

	if state == State.HURT:
		move_and_slide()

		update_held_pumpkin()

		return


	#
	# ========================================================
	# JUMP
	# ========================================================
	#

	if (
		jump_pressed
		and ladder_count == 0
		and jumps_remaining > 0
	):
		perform_jump()


	#
	# ========================================================
	# VARIABLE JUMP HEIGHT
	# ========================================================
	#

	if (
		jump_released
		and velocity.y < 0.0
	):
		velocity.y *= (
			jump_cut_multiplier
		)


	#
	# ========================================================
	# HORIZONTAL MOVEMENT
	# ========================================================
	#

	handle_horizontal_movement(
		horizontal_input
	)


	move_and_slide()


	#
	# Push physics objects AFTER move_and_slide()
	# because that's when slide collisions are available.
	#
	push_rigid_bodies(
		horizontal_input
	)


	update_player_animation()


	update_held_pumpkin()


#
# ============================================================
# INTERACTION INPUT
# ============================================================
#

func handle_interaction(
	down_held: bool
) -> void:
	#
	# Holding pumpkin:
	#
	# E     = throw
	# S + E = drop
	#
	if held_pumpkin != null:
		if down_held:
			drop_pumpkin()

		else:
			throw_pumpkin()

		return


	try_interact()


#
# ============================================================
# JUMP
# ============================================================
#

func perform_jump() -> void:
	var is_double_jump: bool = (
		jumps_remaining
		< max_jumps
	)


	velocity.y = (
		JUMP_VELOCITY
	)


	jumps_remaining -= 1


	if is_double_jump:
		play_double_jump_effect()


#
# ============================================================
# HORIZONTAL MOVEMENT
# ============================================================
#

func handle_horizontal_movement(
	direction: float
) -> void:
	if direction != 0.0:
		velocity.x = (
			direction
			* SPEED
			* movement_multiplier
		)


		set_facing_direction(
			direction
		)


	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			SPEED
		)


#
# ============================================================
# FACING
# ============================================================
#

func set_facing_direction(
	direction: float
) -> void:
	if direction < 0.0:
		facing_direction = -1.0

		sprite.flip_h = true


	elif direction > 0.0:
		facing_direction = 1.0

		sprite.flip_h = false


#
# ============================================================
# RIGID BODY PUSHING
# ============================================================
#

func push_rigid_bodies(
	horizontal_input: float
) -> void:
	if is_zero_approx(
		horizontal_input
	):
		return


	var input_direction: float = signf(
		horizontal_input
	)


	for i in range(
		get_slide_collision_count()
	):
		var collision := (
			get_slide_collision(
				i
			)
		)


		var collider := (
			collision.get_collider()
		)


		#
		# Generic:
		# works on ALL RigidBody2Ds.
		#
		if not collider is RigidBody2D:
			continue


		var body := (
			collider as RigidBody2D
		)


		#
		# Don't push the pumpkin currently held.
		#
		if (
			held_pumpkin != null
			and body == held_pumpkin
		):
			continue


		var normal: Vector2 = (
			collision.get_normal()
		)


		#
		# Ignore almost-pure vertical collisions.
		#
		if absf(
			normal.x
		) < 0.05:
			continue


		var collision_direction: float = signf(
			-normal.x
		)


		#
		# Only push in the direction the player
		# is actually walking.
		#
		if (
			collision_direction
			!= input_direction
		):
			continue


		#
		# Wake sleeping objects.
		#
		body.sleeping = false


		#
		# Don't keep accelerating objects beyond
		# the desired platformer push speed.
		#
		if (
			absf(
				body.linear_velocity.x
			)
			>= max_push_speed
		):
			continue


		#
		# REAL PHYSICS FORCE.
		#
		# F = m * a
		#
		# Therefore:
		#
		# a = F / m
		#
		# Heavy pumpkins accelerate less than light
		# pumpkins automatically.
		#
		body.apply_central_force(
			Vector2(
				input_direction
				* push_force,
				0.0
			)
		)


#
# ============================================================
# PLAYER ANIMATION
# ============================================================
#

func update_player_animation() -> void:
	if state != State.NORMAL:
		return


	if not is_on_floor():
		if sprite.animation != "Jump":
			sprite.play(
				"Jump"
			)

		return


	if absf(
		velocity.x
	) > 1.0:
		sprite.play(
			"Walk"
		)

	else:
		sprite.play(
			"Idle"
		)


#
# ============================================================
# DOUBLE JUMP
# ============================================================
#

func play_double_jump_effect() -> void:
	double_jump.stop()

	double_jump.frame = 0

	double_jump.visible = true

	double_jump.flip_h = (
		sprite.flip_h
	)


	double_jump.play(
		double_jump_animation
	)


func _on_double_jump_animation_finished() -> void:
	double_jump.visible = false


#
# ============================================================
# LADDER MOVEMENT
# ============================================================
#

func handle_ladder_movement(
	horizontal_direction: float,
	vertical_direction: float
) -> void:
	velocity.y = (
		vertical_direction
		* ladder_speed
	)


	velocity.x = (
		horizontal_direction
		* SPEED
		* movement_multiplier
	)


	set_facing_direction(
		horizontal_direction
	)


	if (
		vertical_direction != 0.0
		or horizontal_direction != 0.0
	):
		sprite.play(
			"Walk"
		)

	else:
		sprite.play(
			"Idle"
		)


#
# ============================================================
# GENERIC INTERACTION
# ============================================================
#

func try_interact() -> void:
	pickup_ray.force_raycast_update()


	if not pickup_ray.is_colliding():
		return


	var collider := (
		pickup_ray.get_collider()
	)


	if collider == null:
		return


	#
	# ========================================================
	# CARRYABLE / PUMPKIN
	# ========================================================
	#

	if (
		collider.is_in_group(
			"carryable"
		)
		and collider.has_method(
			"pick_up"
		)
	):
		if collider is Pumpkin:
			held_pumpkin = (
				collider as Pumpkin
			)


			held_pumpkin.pick_up(
				self
			)


			update_held_pumpkin()


			return


	#
	# ========================================================
	# GENERIC INTERACTABLE
	# ========================================================
	#

	if (
		collider.is_in_group(
			"interactable"
		)
		and collider.has_method(
			"interact"
		)
	):
		collider.interact(
			self
		)


#
# ============================================================
# INTERACTION DIRECTION
# ============================================================
#

func update_interaction_direction() -> void:
	hold_point.position.x = (
		hold_distance
		* facing_direction
	)


	pickup_ray.target_position = Vector2(
		pickup_distance
			* facing_direction,
		0.0
	)


#
# ============================================================
# HELD PUMPKIN
# ============================================================
#

func update_held_pumpkin() -> void:
	if held_pumpkin == null:
		return

	if not is_instance_valid(
		held_pumpkin
	):
		held_pumpkin = null
		return

	#
	# Pumpkin physics is frozen while held,
	# so attach it directly to the player's HoldPoint.
	#
	held_pumpkin.global_position = (
		hold_point.global_position
	)

	held_pumpkin.global_rotation = 0.0

#
# ============================================================
# THROW PUMPKIN
# ============================================================
#

func throw_pumpkin() -> void:
	if held_pumpkin == null:
		return


	var pumpkin := (
		held_pumpkin
	)


	held_pumpkin = null


	#
	# SAME IMPULSE is applied to every pumpkin.
	#
	# Mass determines how much velocity the pumpkin gets.
	#
	var impulse := Vector2(
		facing_direction
			* throw_horizontal_impulse,
		-throw_upward_impulse
	)


	pumpkin.release(
		impulse
	)


#
# ============================================================
# DROP PUMPKIN
# ============================================================
#

func drop_pumpkin() -> void:
	if held_pumpkin == null:
		return


	var pumpkin := (
		held_pumpkin
	)


	held_pumpkin = null


	pumpkin.release(
		Vector2.ZERO
	)


#
# ============================================================
# HEAL
# ============================================================
#

func heal(
	amount: int
) -> void:
	if state == State.DEAD:
		return


	if amount <= 0:
		return


	health = mini(
		health + amount,
		max_health
	)


	health_changed.emit(
		health,
		max_health
	)


	print(
		"Health: ",
		health,
		"/",
		max_health
	)


#
# ============================================================
# SLOW ZONES
# ============================================================
#

func enter_slow_zone(
	multiplier: float
) -> void:
	slow_zone_count += 1


	slow_zone_multiplier = (
		multiplier
	)


	movement_multiplier = (
		slow_zone_multiplier
	)


func exit_slow_zone() -> void:
	slow_zone_count = maxi(
		slow_zone_count - 1,
		0
	)


	if slow_zone_count == 0:
		movement_multiplier = 1.0


#
# ============================================================
# LADDERS
# ============================================================
#

func enter_ladder() -> void:
	ladder_count += 1


func exit_ladder() -> void:
	ladder_count = maxi(
		ladder_count - 1,
		0
	)


	if ladder_count == 0:
		climbing = false


#
# ============================================================
# DAMAGE
# ============================================================
#

func take_damage(
	amount: int
) -> void:
	if state == State.DEAD:
		return


	health = maxi(
		health - amount,
		0
	)


	health_changed.emit(
		health,
		max_health
	)


	print(
		"Health: ",
		health,
		"/",
		max_health
	)


	if health <= 0:
		die()

	else:
		hurt()


#
# ============================================================
# HURT
# ============================================================
#

func hurt() -> void:
	if state == State.DEAD:
		return


	state = State.HURT


	velocity.x = 0.0


	sprite.play(
		"Hurt"
	)


#
# ============================================================
# DEATH
# ============================================================
#

func die() -> void:
	if state == State.DEAD:
		return


	state = State.DEAD


	velocity = Vector2.ZERO


	double_jump.stop()

	double_jump.visible = false


	drop_pumpkin()


	sprite.play(
		"Death"
	)


#
# ============================================================
# ANIMATION FINISHED
# ============================================================
#

func _on_animation_finished() -> void:
	match sprite.animation:
		"Hurt":
			state = State.NORMAL


		"Death":
			died.emit()
