extends CharacterBody2D

const SPEED: float = 100.0
const JUMP_VELOCITY: float = -300.0


@export var max_health: int = 100
@export var ladder_speed: float = 180.0

# 2 = normal jump + one mid-air jump.
@export var max_jumps: int = 2

# Controls how strongly releasing jump cuts the jump short.
#
# Lower = shorter tap jump.
# Higher = smaller difference between tap and hold.
@export_range(0.1, 1.0, 0.05) var jump_cut_multiplier: float = 0.45


var health: int

var movement_multiplier: float = 1.0
var slow_zone_count: int = 0
var slow_zone_multiplier: float = 1.0

var ladder_count: int = 0
var climbing: bool = false

var jumps_remaining: int = 0


@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


signal died
signal health_changed(current_health: int, max_health: int)


enum State {
	NORMAL,
	HURT,
	DEAD
}


var state: State = State.NORMAL

func _ready() -> void:
	add_to_group("player")

	health = max_health
	jumps_remaining = max_jumps

	health_changed.emit(
		health,
		max_health
	)

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
	# LADDER ENTRY
	#
	if (
		ladder_count > 0
		and vertical_direction != 0.0
		and state == State.NORMAL
	):
		climbing = true

	#
	# LADDER MOVEMENT
	#
	# Ladder movement takes priority over jumping.
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
	# RESET JUMPS
	#
	if is_on_floor():
		jumps_remaining = max_jumps

	#
	# GRAVITY
	#
	if not is_on_floor():
		velocity += get_gravity() * delta

	#
	# HURT STATE
	#
	if state == State.HURT:
		move_and_slide()
		return

	#
	# JUMP / DOUBLE JUMP
	#
	if (
		Input.is_action_just_pressed("ui_up")
		and ladder_count == 0
		and jumps_remaining > 0
	):
		velocity.y = JUMP_VELOCITY
		jumps_remaining -= 1
		

	#
	# VARIABLE JUMP HEIGHT
	#
	# Releasing jump while moving upward cuts the
	# remaining upward velocity.
	#
	if (
		Input.is_action_just_released("ui_up")
		and velocity.y < 0.0
	):
		velocity.y *= jump_cut_multiplier

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

	if ladder_count == 0:
		climbing = false


func take_damage(amount: int) -> void:
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


func hurt() -> void:
	if state == State.DEAD:
		return

	state = State.HURT

	velocity.x = 0.0

	sprite.play("Hurt")


func die() -> void:
	if state == State.DEAD:
		return

	state = State.DEAD
	velocity = Vector2.ZERO

	sprite.play("Death")


func _on_animation_finished() -> void:
	match sprite.animation:
		"Hurt":
			state = State.NORMAL

		"Death":
			died.emit()
