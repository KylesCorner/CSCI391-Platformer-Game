extends CharacterBody2D


# ============================================================
# MOVEMENT
# ============================================================

@export_category("Movement")

@export var speed: float = 115.0


# ============================================================
# MOUSE HOLES
# ============================================================

@export_category("Mouse Holes")

# How close the enemy needs to get to a hole before entering it.
@export var mouse_hole_reach_distance: float = 1.0

# Only consider entry holes roughly on the enemy's current level.
#
# This prevents a hole directly above/below the mouse from being
# considered the "nearest" entry hole.
@export var hole_vertical_tolerance: float = 15.0

# If the player and hole are roughly the same distance away,
# chase the player.
#
# A hole needs to beat the player by this many pixels before
# the enemy chooses the hole.
@export var chase_priority_margin: float = 5.0

# How long the enemy disappears while traveling underground.
@export var teleport_delay: float = 0.35

# Prevent immediately diving back into the hole after appearing.
@export var teleport_cooldown: float = 0.8


# ============================================================
# ATTACK
# ============================================================

@export_category("Attack")

@export var attack_damage: int = 25

# Horizontal attack distance.
@export var attack_range_x: float = 15.0

# Vertical attack distance.
@export var attack_range_y: float = 5.0

@export var attack_cooldown: float = 0.5

# Position of the attack hitbox in front of the enemy.
@export var attack_hitbox_offset: float = 18.0

# Animation frames during which the attack can deal damage.
@export var attack_active_frames: Array[int] = [4, 5]


# ============================================================
# AI
# ============================================================

enum AIState {
	CHASING,
	SEEKING_HOLE,
	TELEPORTING,
	ATTACKING
}


var ai_state: AIState = AIState.CHASING

var target_hole: MouseHole = null

var teleport_cooldown_remaining: float = 0.0
var attack_cooldown_remaining: float = 0.0

var attack_damage_applied: bool = false


# ============================================================
# MOVEMENT MODIFIERS
# ============================================================

var movement_multiplier: float = 1.0

var slow_zone_count: int = 0
var slow_zone_multiplier: float = 1.0


# ============================================================
# PLAYER
# ============================================================

var player: CharacterBody2D = null


# ============================================================
# NODES
# ============================================================

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

@onready var floor_check: RayCast2D = $FloorCheck

@onready var collision_shape: CollisionShape2D = (
	$CollisionShape2D
)

@onready var attack_hitbox: Area2D = (
	$AttackHitbox
)


# ============================================================
# READY
# ============================================================

func _ready() -> void:
	player = (
		get_tree().get_first_node_in_group("player")
		as CharacterBody2D
	)

	floor_snap_length = 10.0

	sprite.frame_changed.connect(
		_on_sprite_frame_changed
	)

	sprite.animation_finished.connect(
		_on_sprite_animation_finished
	)

	attack_hitbox.monitoring = true


# ============================================================
# PHYSICS
# ============================================================

func _physics_process(delta: float) -> void:
	update_timers(delta)

	#
	# Enemy does not physically move while underground.
	#
	if ai_state == AIState.TELEPORTING:
		velocity = Vector2.ZERO
		return

	apply_gravity(delta)

	if player == null:
		velocity.x = 0.0
		update_animation()
		move_and_slide()
		return

	match ai_state:
		AIState.CHASING:
			update_chasing()

		AIState.SEEKING_HOLE:
			update_seeking_hole()

		AIState.ATTACKING:
			update_attacking()

		AIState.TELEPORTING:
			pass

	update_animation()

	move_and_slide()


# ============================================================
# TIMERS
# ============================================================

func update_timers(delta: float) -> void:
	if teleport_cooldown_remaining > 0.0:
		teleport_cooldown_remaining -= delta

		if teleport_cooldown_remaining < 0.0:
			teleport_cooldown_remaining = 0.0

	if attack_cooldown_remaining > 0.0:
		attack_cooldown_remaining -= delta

		if attack_cooldown_remaining < 0.0:
			attack_cooldown_remaining = 0.0


# ============================================================
# GRAVITY
# ============================================================

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


# ============================================================
# CHASING
# ============================================================

func update_chasing() -> void:
	#
	# Attacking always wins.
	#
	if can_attack_player():
		start_attack()
		return

	var nearest_hole: MouseHole = find_nearest_entry_hole()

	#
	# No usable holes means we just chase.
	#
	if nearest_hole == null:
		chase_player()
		return

	#
	# During teleport cooldown, ignore mouse holes entirely.
	#
	if teleport_cooldown_remaining > 0.0:
		chase_player()
		return

	#
	# Compare distance to player against distance to nearest hole.
	#
	var player_distance: float = (
		global_position.distance_to(
			player.global_position
		)
	)

	var hole_distance: float = (
		global_position.distance_to(
			nearest_hole.global_position
		)
	)

	#
	# Player gets priority when distances are close.
	#
	# A hole must be clearly closer before we use it.
	#
	if (
		player_distance
		<= hole_distance + chase_priority_margin
	):
		chase_player()
		return

	#
	# Hole is clearly closer.
	#
	target_hole = nearest_hole
	ai_state = AIState.SEEKING_HOLE

	move_to_mouse_hole(target_hole)


# ============================================================
# CHASE PLAYER
# ============================================================

func chase_player() -> void:
	var horizontal_difference: float = (
		player.global_position.x
		- global_position.x
	)

	var direction: float = signf(
		horizontal_difference
	)

	if direction == 0.0:
		velocity.x = 0.0
		return

	set_facing_direction(direction)

	#
	# Check the floor directly in front of the enemy.
	#
	update_floor_check(direction)
	floor_check.force_raycast_update()

	#
	# Safe ground ahead.
	#
	if floor_check.is_colliding():
		velocity.x = (
			direction
			* speed
			* movement_multiplier
		)

		return

	#
	# There is a ledge.
	#
	# We cannot jump, so now a mouse hole becomes necessary.
	#
	velocity.x = 0.0

	if teleport_cooldown_remaining > 0.0:
		return

	var hole: MouseHole = find_nearest_entry_hole()

	if hole == null:
		return

	target_hole = hole
	ai_state = AIState.SEEKING_HOLE

	move_to_mouse_hole(target_hole)


# ============================================================
# SEEKING HOLE
# ============================================================

func update_seeking_hole() -> void:
	#
	# Player got close enough to attack while we were walking
	# toward the hole.
	#
	if can_attack_player():
		target_hole = null
		start_attack()
		return

	if target_hole == null:
		ai_state = AIState.CHASING
		return

	if not is_instance_valid(target_hole):
		target_hole = null
		ai_state = AIState.CHASING
		return

	#
	# If the player becomes the better target again,
	# abandon the hole.
	#
	var player_distance: float = (
		global_position.distance_to(
			player.global_position
		)
	)

	var hole_distance: float = (
		global_position.distance_to(
			target_hole.global_position
		)
	)

	if (
		player_distance
		<= hole_distance + chase_priority_margin
	):
		var direction_to_player: float = signf(
			player.global_position.x
			- global_position.x
		)

		#
		# Only abandon the hole if we can actually continue
		# walking toward the player.
		#
		if has_floor_ahead(direction_to_player):
			target_hole = null
			ai_state = AIState.CHASING

			chase_player()
			return

	move_to_mouse_hole(target_hole)


# ============================================================
# FIND NEAREST ENTRY HOLE
# ============================================================

func find_nearest_entry_hole() -> MouseHole:
	var best_hole: MouseHole = null
	var best_distance: float = INF

	var nodes: Array[Node] = (
		get_tree().get_nodes_in_group(
			"mouse_hole"
		)
	)

	for node: Node in nodes:
		var hole: MouseHole = node as MouseHole

		if hole == null:
			continue

		#
		# Entry hole should be approximately on our level.
		#
		var vertical_distance: float = absf(
			hole.global_position.y
			- global_position.y
		)

		if vertical_distance > hole_vertical_tolerance:
			continue

		var distance: float = (
			global_position.distance_to(
				hole.global_position
			)
		)

		if distance < best_distance:
			best_distance = distance
			best_hole = hole

	return best_hole


# ============================================================
# MOVE TO HOLE
# ============================================================

func move_to_mouse_hole(
	hole: MouseHole
) -> void:
	if hole == null:
		target_hole = null
		ai_state = AIState.CHASING
		return

	if not is_instance_valid(hole):
		target_hole = null
		ai_state = AIState.CHASING
		return

	var horizontal_difference: float = (
		hole.global_position.x
		- global_position.x
	)

	var horizontal_distance: float = absf(
		horizontal_difference
	)

	#
	# Reached the mouse hole.
	#
	if horizontal_distance <= mouse_hole_reach_distance:
		enter_mouse_hole(hole)
		return

	var direction: float = signf(
		horizontal_difference
	)

	if direction == 0.0:
		enter_mouse_hole(hole)
		return

	set_facing_direction(direction)

	#
	# Don't blindly walk off a cliff trying to reach a hole.
	#
	if not has_floor_ahead(direction):
		target_hole = null
		ai_state = AIState.CHASING
		velocity.x = 0.0
		return

	velocity.x = (
		direction
		* speed
		* movement_multiplier
	)


# ============================================================
# ENTER MOUSE HOLE
# ============================================================

func enter_mouse_hole(
	entry_hole: MouseHole
) -> void:
	if ai_state == AIState.TELEPORTING:
		return

	if teleport_cooldown_remaining > 0.0:
		target_hole = null
		ai_state = AIState.CHASING
		return

	var exit_hole: MouseHole = (
		find_exit_hole_closest_to_player(
			entry_hole
		)
	)

	if exit_hole == null:
		target_hole = null
		ai_state = AIState.CHASING
		return

	ai_state = AIState.TELEPORTING

	target_hole = null
	velocity = Vector2.ZERO

	#
	# Hide enemy while underground.
	#
	sprite.visible = false

	attack_hitbox.monitoring = false

	collision_shape.set_deferred(
		"disabled",
		true
	)

	await get_tree().create_timer(
		teleport_delay
	).timeout

	#
	# Appear at the hole nearest the player.
	#
	global_position = (
		exit_hole.get_exit_position()
	)

	velocity = Vector2.ZERO

	sprite.visible = true

	collision_shape.set_deferred(
		"disabled",
		false
	)

	attack_hitbox.monitoring = true

	#
	# Force the mouse to chase for a little while after
	# emerging instead of immediately selecting another hole.
	#
	teleport_cooldown_remaining = teleport_cooldown

	ai_state = AIState.CHASING


# ============================================================
# FIND EXIT CLOSEST TO PLAYER
# ============================================================

func find_exit_hole_closest_to_player(
	entry_hole: MouseHole
) -> MouseHole:
	var best_hole: MouseHole = null
	var best_distance: float = INF

	var nodes: Array[Node] = (
		get_tree().get_nodes_in_group(
			"mouse_hole"
		)
	)

	for node: Node in nodes:
		var hole: MouseHole = node as MouseHole

		if hole == null:
			continue

		#
		# Cannot exit from the same hole we entered.
		#
		if hole == entry_hole:
			continue

		var exit_position: Vector2 = (
			hole.get_exit_position()
		)

		var distance_to_player: float = (
			exit_position.distance_to(
				player.global_position
			)
		)

		if distance_to_player < best_distance:
			best_distance = distance_to_player
			best_hole = hole

	return best_hole


# ============================================================
# ATTACK
# ============================================================

func can_attack_player() -> bool:
	if player == null:
		return false

	if attack_cooldown_remaining > 0.0:
		return false

	var x_distance: float = absf(
		player.global_position.x
		- global_position.x
	)

	var y_distance: float = absf(
		player.global_position.y
		- global_position.y
	)

	#
	# BOTH dimensions must be within attack range.
	#
	if x_distance > attack_range_x:
		return false

	if y_distance > attack_range_y:
		return false

	return true


func start_attack() -> void:
	if player == null:
		return

	ai_state = AIState.ATTACKING

	target_hole = null
	velocity.x = 0.0

	attack_damage_applied = false

	var direction: float = signf(
		player.global_position.x
		- global_position.x
	)

	if direction != 0.0:
		set_facing_direction(direction)

	update_attack_hitbox_position(direction)

	sprite.play("Attack")


func update_attacking() -> void:
	velocity.x = 0.0


func update_attack_hitbox_position(
	direction: float
) -> void:
	if direction == 0.0:
		if sprite.flip_h:
			direction = -1.0
		else:
			direction = 1.0

	attack_hitbox.position.x = (
		attack_hitbox_offset
		* direction
	)


# ============================================================
# ATTACK ANIMATION
# ============================================================

func _on_sprite_frame_changed() -> void:
	if ai_state != AIState.ATTACKING:
		return

	if sprite.animation != "Attack":
		return

	if sprite.frame not in attack_active_frames:
		return

	if attack_damage_applied:
		return

	try_apply_attack_damage()


func try_apply_attack_damage() -> void:
	if player == null:
		return

	var bodies := (
		attack_hitbox.get_overlapping_bodies()
	)

	for body in bodies:
		if body != player:
			continue

		if not body.has_method("take_damage"):
			continue

		body.take_damage(
			attack_damage
		)

		attack_damage_applied = true

		return


func _on_sprite_animation_finished() -> void:
	if sprite.animation != "Attack":
		return

	if ai_state != AIState.ATTACKING:
		return

	attack_damage_applied = false

	attack_cooldown_remaining = (
		attack_cooldown
	)

	ai_state = AIState.CHASING


# ============================================================
# FLOOR CHECK
# ============================================================

func has_floor_ahead(
	direction: float
) -> bool:
	if direction == 0.0:
		return true

	update_floor_check(direction)

	floor_check.force_raycast_update()

	return floor_check.is_colliding()


func update_floor_check(
	direction: float
) -> void:
	floor_check.position.x = (
		18.0 * direction
	)


# ============================================================
# DIRECTION
# ============================================================

func set_facing_direction(
	direction: float
) -> void:
	if direction < 0.0:
		sprite.flip_h = true

	elif direction > 0.0:
		sprite.flip_h = false


# ============================================================
# ANIMATION
# ============================================================

func update_animation() -> void:
	if ai_state == AIState.ATTACKING:
		return

	if ai_state == AIState.TELEPORTING:
		return

	if absf(velocity.x) > 1.0:
		sprite.play("Run")

	else:
		sprite.play("Idle")


# ============================================================
# SLOW ZONES
# ============================================================

func enter_slow_zone(
	multiplier: float
) -> void:
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


# ============================================================
# DAMAGE
# ============================================================

func take_damage(
	_amount: int
) -> void:
	#
	# Enemy remains invulnerable.
	#
	pass
