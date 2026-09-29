extends CharacterBody2D

const SPEED: float = 150.0
const JUMP_VELOCITY: float = -300.0


@export var max_health: int = 100
@export var ladder_speed: float = 180.0


var health: int

var movement_multiplier: float = 1.0
var slow_zone_count: int = 0
var slow_zone_multiplier: float = 1.0

var ladder_count: int = 0
var climbing: bool = false


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

signal died

enum State {
	NORMAL,
	ATTACKING,
	HURT,
	DEAD
}


var state: State = State.NORMAL


func _ready() -> void:
	add_to_group("player")

	health = max_health

	sprite.play("Idle")

	sprite.animation_finished.connect(
		_on_animation_finished
	)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	var vertical_direction: float = Input.get_axis(
		"ui_up",
		"ui_down"
	)

	#
	# LADDER
	#
	# If we're touching a ladder and press up/down,
	# start climbing.
	#
	if (
		ladder_count > 0
		and vertical_direction != 0.0
		and state == State.NORMAL
	):
		climbing = true

	#
	# Handle ladder movement before normal movement.
	#
	# This is important because pressing UP while touching
	# a ladder should climb instead of jump.
	#
	if (
		climbing
		and ladder_count > 0
		and state == State.NORMAL
	):
		handle_ladder_movement(vertical_direction)

		move_and_slide()
		return

	#
	# GRAVITY
	#
	if not is_on_floor():
		velocity += get_gravity() * delta

	#
	# No normal controls while attacking or hurt.
	#
	if (
		state == State.ATTACKING
		or state == State.HURT
	):
		move_and_slide()
		return

	#
	# ATTACK
	#
	if Input.is_action_just_pressed("attack"):
		attack()

		move_and_slide()
		return

	#
	# JUMP
	#
	# Up Arrow now jumps when we're NOT using a ladder.
	#
	if (
		Input.is_action_just_pressed("ui_up")
		and is_on_floor()
		and ladder_count == 0
	):
		velocity.y = JUMP_VELOCITY

	#
	# HORIZONTAL MOVEMENT
	#
	handle_horizontal_movement()

	move_and_slide()


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

		sprite.play("Walk")

		if direction < 0.0:
			sprite.flip_h = true

		elif direction > 0.0:
			sprite.flip_h = false

	else:
		velocity.x = move_toward(
			velocity.x,
			0.0,
			SPEED
		)

		sprite.play("Idle")


func handle_ladder_movement(
	vertical_direction: float
) -> void:
	#
	# ui_up produces -1
	# ui_down produces +1
	#
	# Because Godot's +Y direction is downward,
	# this naturally gives us:
	#
	# Up   -> negative Y
	# Down -> positive Y
	#
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

	elif horizontal_direction > 0.0:
		sprite.flip_h = false

	if (
		vertical_direction != 0.0
		or horizontal_direction != 0.0
	):
		sprite.play("Walk")
	else:
		sprite.play("Idle")


func enter_slow_zone(multiplier: float) -> void:
	slow_zone_count += 1

	slow_zone_multiplier = multiplier
	movement_multiplier = slow_zone_multiplier


func exit_slow_zone() -> void:
	slow_zone_count = maxi(
		slow_zone_count - 1,
		0
	)

	if slow_zone_count == 0:
		movement_multiplier = 1.0


func enter_ladder() -> void:
	ladder_count += 1


func exit_ladder() -> void:
	ladder_count = maxi(
		ladder_count - 1,
		0
	)

	#
	# Once we're no longer overlapping any ladder,
	# resume normal movement/gravity.
	#
	if ladder_count == 0:
		climbing = false


func attack() -> void:
	if state != State.NORMAL:
		return

	state = State.ATTACKING

	velocity.x = 0.0

	sprite.play("Attack")


func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return

	health -= amount

	health = maxi(
		health,
		0
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


func hurt() -> void:
	state = State.HURT

	velocity.x = 0.0

	sprite.play("Hurt")



func die() -> void:
	if state == State.DEAD:
		return

	state = State.DEAD
	velocity = Vector2.ZERO

	sprite.play("Death")

	await get_tree().create_timer(1.5).timeout

	died.emit()


func _on_animation_finished() -> void:
	match sprite.animation:
		"Attack":
			state = State.NORMAL

		"Hurt":
			state = State.NORMAL

		"Death":
			pass
