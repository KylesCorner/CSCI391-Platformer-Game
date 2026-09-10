extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

@export var max_health: int = 100
var health: int

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


enum State {
	NORMAL,
	ATTACKING,
	HURT,
	DEAD
}

var state: State = State.NORMAL


func _ready() -> void:
	health = max_health
	sprite.play("Idle")
	sprite.animation_finished.connect(_on_animation_finished)


func _physics_process(delta: float) -> void:
	# Don't allow normal controls while dead
	if state == State.DEAD:
		return

	# Gravity still applies while attacking/hurt
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Don't allow movement while attacking or hurt
	if state == State.ATTACKING or state == State.HURT:
		move_and_slide()
		return

	# Attack
	if Input.is_action_just_pressed("attack"):
		attack()
		move_and_slide()
		return

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Horizontal movement
	var direction := Input.get_axis("ui_left", "ui_right")

	if direction != 0:
		velocity.x = direction * SPEED
		sprite.play("Walk")

		if direction < 0:
			sprite.flip_h = true
		elif direction > 0:
			sprite.flip_h = false

	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		sprite.play("Idle")

	move_and_slide()


func attack() -> void:
	if state != State.NORMAL:
		return

	state = State.ATTACKING
	velocity.x = 0
	sprite.play("Attack")

	# Put attack hitbox / damage logic here later.


func take_damage(amount: int) -> void:
	if state == State.DEAD:
		return

	health -= amount
	health = max(health, 0)

	print("Health: ", health, "/", max_health)

	if health <= 0:
		die()
	else:
		hurt()


func hurt() -> void:
	state = State.HURT
	velocity.x = 0
	sprite.play("Hurt")


func die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	sprite.play("Death")


func _on_animation_finished() -> void:
	match sprite.animation:
		"Attack":
			state = State.NORMAL

		"Hurt":
			state = State.NORMAL

		"Death":
			# Stay dead.
			pass
