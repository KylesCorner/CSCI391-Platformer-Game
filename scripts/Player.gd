extends CharacterBody2D


const SPEED: float = 100.0
const JUMP_VELOCITY: float = -300.0


#
# ============================================================
# PLAYER SETTINGS
# ============================================================
#

@export_category("Player")

@export var max_health: int = 100
@export var ladder_speed: float = 180.0


#
# 2 = normal jump + one mid-air jump.
#
@export var max_jumps: int = 2


#
# Lower = shorter tap jump.
# Higher = smaller difference between tap and hold.
#
@export_range(0.1, 1.0, 0.05)
var jump_cut_multiplier: float = 0.45


#
# ============================================================
# DOUBLE JUMP EFFECT
# ============================================================
#

@export_category("Double Jump")

#
# Animation on the separate DoubleJump AnimatedSprite2D.
#
@export var double_jump_animation: StringName = &"DoubleJump"


#
# ============================================================
# PUMPKIN SETTINGS
# ============================================================
#

@export_category("Pumpkin")

@export var pickup_distance: float = 28.0

@export var hold_distance: float = 20.0

@export var throw_speed: float = 350.0

@export var throw_upward_speed: float = 120.0


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
#  1 = facing right
# -1 = facing left
#
var facing_direction: float = 1.0


#
# Pumpkin currently being carried.
#
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


#
# Separate double-jump effect.
#
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
# PLAYER STATES
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
	add_to_group("player")

	health = max_health

	jumps_remaining = max_jumps

	health_changed.emit(
		health,
		max_health
	)

	sprite.play("Idle")


	#
	# Main player animation finished signal.
	#
	sprite.animation_finished.connect(
		_on_animation_finished
	)


	#
	# Double-jump effect starts hidden.
	#
	double_jump.visible = false

	double_jump.animation_finished.connect(
		_on_double_jump_animation_finished
	)


	update_interaction_direction()


#
# ============================================================
# PHYSICS
# ============================================================
#

func _physics_process(delta: float) -> void:
	#
	# Keep carried pumpkin attached to HoldPoint.
	#
	update_held_pumpkin()


	if state == State.DEAD:
		return


	#
	# Keep pickup ray / hold point facing the
	# same direction as the player.
	#
	update_interaction_direction()


	#
	# ========================================================
	# PUMPKIN INTERACTION
	# ========================================================
	#

	if Input.is_action_just_pressed("interact"):
		if held_pumpkin != null:
			#
			# Down + interact = gently drop.
			#
			if Input.is_action_pressed("ui_down"):
				drop_pumpkin()

			#
			# Interact by itself = throw.
			#
			else:
				throw_pumpkin()

		else:
			try_pick_up_pumpkin()


	#
	# ========================================================
	# VERTICAL INPUT
	# ========================================================
	#

	var vertical_direction: float = Input.get_axis(
		"ui_up",
		"ui_down"
	)


	#
	# ========================================================
	# LADDER ENTRY
	# ========================================================
	#

	if (
		ladder_count > 0
		and vertical_direction != 0.0
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
			vertical_direction
		)

		move_and_slide()

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
		velocity += get_gravity() * delta


	#
	# ========================================================
	# HURT STATE
	# ========================================================
	#

	if state == State.HURT:
		move_and_slide()

		update_held_pumpkin()

		return


	#
	# ========================================================
	# JUMP / DOUBLE JUMP
	# ========================================================
	#

	if (
		Input.is_action_just_pressed("ui_up")
		and ladder_count == 0
		and jumps_remaining > 0
	):
		#
		# If we have already spent one jump,
		# this is the double jump.
		#
		var is_double_jump: bool = (
			jumps_remaining < max_jumps
		)

		velocity.y = JUMP_VELOCITY

		jumps_remaining -= 1


		if is_double_jump:
			play_double_jump_effect()


	#
	# ========================================================
	# VARIABLE JUMP HEIGHT
	# ========================================================
	#

	if (
		Input.is_action_just_released("ui_up")
		and velocity.y < 0.0
	):
		velocity.y *= jump_cut_multiplier


	#
	# ========================================================
	# HORIZONTAL MOVEMENT
	# ========================================================
	#

	handle_horizontal_movement()


	move_and_slide()


	#
	# Update the regular character animation after movement.
	#
	update_player_animation()


	update_held_pumpkin()


#
# ============================================================
# HORIZONTAL MOVEMENT
# ============================================================
#

func handle_horizontal_movement() -> void:
	var direction: float = Input.get_axis(
		"ui_left",
		"ui_right"
	)


	if direction != 0.0:
		velocity.x = (
			direction
			* SPEED
			* movement_multiplier
		)


		if direction < 0.0:
			sprite.flip_h = true

			facing_direction = -1.0


		elif direction > 0.0:
			sprite.flip_h = false

			facing_direction = 1.0


	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			SPEED
		)


#
# ============================================================
# PLAYER ANIMATION
# ============================================================
#

func update_player_animation() -> void:
	if state == State.HURT:
		return

	if state == State.DEAD:
		return


	#
	# Airborne player uses the normal Jump animation.
	#
	if not is_on_floor():
		if sprite.animation != "Jump":
			sprite.play("Jump")

		return


	#
	# Ground animation.
	#
	if absf(velocity.x) > 1.0:
		sprite.play("Walk")

	else:
		sprite.play("Idle")


#
# ============================================================
# DOUBLE JUMP EFFECT
# ============================================================
#

func play_double_jump_effect() -> void:
	#
	# Make sure we restart the effect from the beginning
	# every time the second jump occurs.
	#
	double_jump.stop()

	double_jump.frame = 0

	double_jump.visible = true


	#
	# Match the player's facing direction if the effect
	# artwork has a direction.
	#
	double_jump.flip_h = sprite.flip_h


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
	vertical_direction: float
) -> void:
	velocity.y = (
		vertical_direction
		* ladder_speed
	)


	var horizontal_direction: float = Input.get_axis(
		"ui_left",
		"ui_right"
	)


	velocity.x = (
		horizontal_direction
		* SPEED
		* movement_multiplier
	)


	if horizontal_direction < 0.0:
		sprite.flip_h = true

		facing_direction = -1.0


	elif horizontal_direction > 0.0:
		sprite.flip_h = false

		facing_direction = 1.0


	if (
		vertical_direction != 0.0
		or horizontal_direction != 0.0
	):
		sprite.play("Walk")

	else:
		sprite.play("Idle")


#
# ============================================================
# PUMPKIN INTERACTION DIRECTION
# ============================================================
#

func update_interaction_direction() -> void:
	#
	# Move HoldPoint to the side the player
	# is currently facing.
	#
	hold_point.position.x = (
		hold_distance
		* facing_direction
	)


	#
	# Point pickup ray in the same direction.
	#
	pickup_ray.target_position = Vector2(
		pickup_distance * facing_direction,
		0.0
	)


#
# ============================================================
# PICK UP PUMPKIN
# ============================================================
#

func try_pick_up_pumpkin() -> void:
	if held_pumpkin != null:
		return


	pickup_ray.force_raycast_update()


	if not pickup_ray.is_colliding():
		return


	var collider := (
		pickup_ray.get_collider()
	)


	if collider is Pumpkin:
		held_pumpkin = collider

		held_pumpkin.pick_up(
			self
		)

		update_held_pumpkin()


#
# ============================================================
# UPDATE HELD PUMPKIN
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


	held_pumpkin.global_position = (
		hold_point.global_position
	)


#
# ============================================================
# THROW PUMPKIN
# ============================================================
#

func throw_pumpkin() -> void:
	if held_pumpkin == null:
		return


	var pumpkin := held_pumpkin

	held_pumpkin = null


	var throw_velocity := Vector2(
		facing_direction * throw_speed,
		-throw_upward_speed
	)


	pumpkin.release(
		throw_velocity
	)


#
# ============================================================
# DROP PUMPKIN
# ============================================================
#

func drop_pumpkin() -> void:
	if held_pumpkin == null:
		return


	var pumpkin := held_pumpkin

	held_pumpkin = null


	pumpkin.release(
		Vector2.ZERO
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

	slow_zone_multiplier = multiplier

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


	health -= amount


	health = maxi(
		health,
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


	#
	# Hide any double-jump effect if the player
	# dies while it is playing.
	#
	double_jump.stop()

	double_jump.visible = false


	#
	# Don't leave a pumpkin floating in the air
	# if the player dies while holding one.
	#
	drop_pumpkin()


	sprite.play(
		"Death"
	)


#
# ============================================================
# MAIN PLAYER ANIMATION FINISHED
# ============================================================
#

func _on_animation_finished() -> void:
	match sprite.animation:
		"Hurt":
			state = State.NORMAL


		"Death":
			died.emit()
