extends CharacterBody2D


# ============================================================
# MOVEMENT
# ============================================================

@export_category("Movement")

@export var speed: float = 100.0

# Maximum Y difference before the player is considered
# to be on another platform.
@export var same_platform_tolerance: float = 40.0


# ============================================================
# MOUSE HOLES
# ============================================================

@export_category("Mouse Holes")

# Maximum vertical difference between the enemy and a mouse hole
# for that hole to count as being on the enemy's platform.
@export var hole_platform_tolerance: float = 100.0

# How close the enemy must get before entering the hole.
@export var mouse_hole_reach_distance: float = 25.0

# Underground travel speed in pixels per second.
@export var mouse_hole_travel_speed: float = 300.0

# Prevent very close holes from teleporting instantly.
@export var min_mouse_hole_travel_time: float = 0.25

# Prevent very distant holes from taking forever.
@export var max_mouse_hole_travel_time: float = 2.5

# Prevent immediate re-entry after emerging.
@export var teleport_cooldown: float = 0.35

# Vertical distance matters more than horizontal distance
# when choosing an exit near the player.
@export var exit_vertical_weight: float = 10.0


# ============================================================
# PLATFORM DETECTION
# ============================================================

@export_category("Platform Detection")

# Spacing between downward ground probes.
@export var ground_probe_spacing: float = 16.0

# Where the ground probe begins relative to enemy Y.
@export var ground_probe_start: float = 5.0

# How far downward each probe searches.
@export var ground_probe_depth: float = 80.0


# ============================================================
# ATTACK
# ============================================================

@export_category("Attack")

# Damage dealt by one slash.
@export var attack_damage: int = 25

# Enemy starts attacking when the player is this close
# horizontally.
@export var attack_range: float = 35.0

# Prevent attacking players far above/below the enemy.
@export var attack_vertical_tolerance: float = 15.0

# Delay between finished attacks.
@export var attack_cooldown: float = 1.0

# Position of the attack hitbox in front of the enemy.
@export var attack_hitbox_offset: float = 18.0

# Frames where the slash is actually dangerous.
#
# The attack can connect during frame 4 OR frame 5,
# but the player is only damaged once per attack.
@export var attack_active_frames: Array[int] = [4, 5]


# ============================================================
# AI STATE
# ============================================================

enum AIState {
	CHASING,
	SEEKING_HOLE,
	TELEPORTING,
	ATTACKING
}


var ai_state: AIState = AIState.CHASING


# ============================================================
# MOVEMENT STATE
# ============================================================

var movement_multiplier: float = 1.0

var slow_zone_count: int = 0
var slow_zone_multiplier: float = 1.0


# ============================================================
# MOUSE-HOLE STATE
# ============================================================

var target_hole: MouseHole = null

var teleport_cooldown_remaining: float = 0.0


# ============================================================
# ATTACK STATE
# ============================================================

var attack_cooldown_remaining: float = 0.0

# Prevents frames 4 and 5 from both damaging the player.
var attack_damage_applied: bool = false


# ============================================================
# PLAYER
# ============================================================

var player: CharacterBody2D = null

# Last Y position where the player was standing on ground.
#
# This means jumping does not look like a platform change.
var player_ground_y: float = 0.0


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

	#
	# Animation signals are used to synchronize attack damage.
	#
	sprite.frame_changed.connect(
		_on_sprite_frame_changed
	)

	sprite.animation_finished.connect(
		_on_sprite_animation_finished
	)

	#
	# The attack Area2D should detect bodies.
	#
	attack_hitbox.monitoring = true

	if player != null:
		player_ground_y = player.global_position.y


# ============================================================
# MAIN PHYSICS LOOP
# ============================================================

func _physics_process(delta: float) -> void:
	update_teleport_cooldown(delta)
	update_attack_cooldown(delta)

	#
	# While traveling through mouse holes, the enemy doesn't
	# physically exist in the level.
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

	update_player_ground_position()

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

func update_teleport_cooldown(delta: float) -> void:
	if teleport_cooldown_remaining <= 0.0:
		return

	teleport_cooldown_remaining -= delta

	if teleport_cooldown_remaining < 0.0:
		teleport_cooldown_remaining = 0.0


func update_attack_cooldown(delta: float) -> void:
	if attack_cooldown_remaining <= 0.0:
		return

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
# PLAYER PLATFORM TRACKING
# ============================================================

func update_player_ground_position() -> void:
	#
	# Only update platform height while the player is actually
	# standing on something.
	#
	if player.is_on_floor():
		player_ground_y = player.global_position.y


# ============================================================
# CHASING
# ============================================================

func update_chasing() -> void:
	#
	# ATTACK HAS HIGHEST PRIORITY.
	#
	if can_attack_player():
		start_attack()
		return

	#
	# While the player is jumping, keep chasing horizontally.
	#
	# Do not interpret the jump as a platform change.
	#
	if not player.is_on_floor():
		chase_player_directly()
		return

	#
	# Player cannot be reached directly.
	#
	if should_use_mouse_hole():
		var hole: MouseHole = find_nearest_entry_hole()

		if hole != null:
			target_hole = hole
			ai_state = AIState.SEEKING_HOLE

			print(
				"Enemy committed to mouse hole: ",
				target_hole.name
			)

			update_seeking_hole()
			return

		print(
			"Enemy needs a mouse hole but cannot find "
			+ "a reachable one."
		)

		velocity.x = 0.0
		return

	#
	# Player is reachable normally.
	#
	chase_player_directly()


# ============================================================
# ATTACK
# ============================================================

func can_attack_player() -> bool:
	if player == null:
		return false

	if attack_cooldown_remaining > 0.0:
		return false

	var horizontal_distance: float = absf(
		player.global_position.x
		- global_position.x
	)

	var vertical_distance: float = absf(
		player.global_position.y
		- global_position.y
	)

	if horizontal_distance > attack_range:
		return false

	if vertical_distance > attack_vertical_tolerance:
		return false

	return true


func start_attack() -> void:
	if player == null:
		return

	ai_state = AIState.ATTACKING

	velocity.x = 0.0

	#
	# Allow one damage event during this attack.
	#
	attack_damage_applied = false

	#
	# Face the player before slashing.
	#
	var direction: float = signf(
		player.global_position.x
		- global_position.x
	)

	if direction != 0.0:
		set_facing_direction(direction)

	update_attack_hitbox_position(direction)

	#
	# Start the animation from the beginning.
	#
	sprite.play("Attack")


func update_attacking() -> void:
	#
	# Enemy remains stationary while attacking.
	#
	velocity.x = 0.0


func update_attack_hitbox_position(
	direction: float
) -> void:
	#
	# If the player is exactly centered, use the enemy's
	# current facing direction.
	#
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
# ATTACK ANIMATION EVENTS
# ============================================================

func _on_sprite_frame_changed() -> void:
	if ai_state != AIState.ATTACKING:
		return

	if sprite.animation != "Attack":
		return

	#
	# Frames 4 and 5 are the active slash frames.
	#
	if sprite.frame not in attack_active_frames:
		return

	#
	# Don't hit twice during one swing.
	#
	if attack_damage_applied:
		return

	#
	# Try to damage the player.
	#
	# IMPORTANT:
	#
	# If frame 4 doesn't hit anything, attack_damage_applied
	# stays false. Frame 5 therefore gets another chance.
	#
	try_apply_attack_damage()


func try_apply_attack_damage() -> void:
	if player == null:
		return

	var bodies: Array[Node2D] = (
		attack_hitbox.get_overlapping_bodies()
	)

	for body: Node2D in bodies:
		if body != player:
			continue

		if not body.has_method("take_damage"):
			continue

		body.take_damage(attack_damage)

		#
		# Attack has successfully connected.
		#
		attack_damage_applied = true

		print(
			"Enemy hit player for ",
			attack_damage,
			" damage."
		)

		return


func _on_sprite_animation_finished() -> void:
	if sprite.animation != "Attack":
		return

	if ai_state != AIState.ATTACKING:
		return

	#
	# Attack is finished.
	#
	attack_damage_applied = false

	attack_cooldown_remaining = attack_cooldown

	ai_state = AIState.CHASING


# ============================================================
# DIRECT CHASE
# ============================================================

func chase_player_directly() -> void:
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

	update_floor_check(direction)
	floor_check.force_raycast_update()

	if floor_check.is_colliding():
		velocity.x = (
			direction
			* speed
			* movement_multiplier
		)

	else:
		#
		# We hit an edge while pursuing the player.
		#
		# Switch to mouse-hole routing rather than stopping.
		#
		var hole: MouseHole = find_nearest_entry_hole()

		if hole != null:
			target_hole = hole
			ai_state = AIState.SEEKING_HOLE

			print(
				"Reached edge. Switching to mouse hole: ",
				hole.name
			)

			update_seeking_hole()

		else:
			velocity.x = 0.0


# ============================================================
# SHOULD WE USE A MOUSE HOLE?
# ============================================================

func should_use_mouse_hole() -> bool:
	#
	# Player is obviously on another vertical level.
	#
	var vertical_distance: float = absf(
		player_ground_y
		- global_position.y
	)

	if vertical_distance > same_platform_tolerance:
		return true

	#
	# Platforms may be at similar heights but separated
	# by a gap.
	#
	if not has_continuous_ground_to_player():
		return true

	return false


# ============================================================
# GROUND CONNECTIVITY
# ============================================================

func has_continuous_ground_to_player() -> bool:
	return has_continuous_ground_between(
		global_position,
		player.global_position.x
	)


func has_continuous_ground_between(
	start_position: Vector2,
	target_x: float
) -> bool:
	var horizontal_distance: float = absf(
		target_x - start_position.x
	)

	if horizontal_distance <= ground_probe_spacing:
		return true

	var steps: int = maxi(
		1,
		ceili(
			horizontal_distance
			/ ground_probe_spacing
		)
	)

	var space_state: PhysicsDirectSpaceState2D = (
		get_world_2d().direct_space_state
	)

	for i: int in range(steps + 1):
		var amount: float = (
			float(i)
			/ float(steps)
		)

		var sample_x: float = lerpf(
			start_position.x,
			target_x,
			amount
		)

		var ray_start := Vector2(
			sample_x,
			start_position.y
			+ ground_probe_start
		)

		var ray_end := Vector2(
			sample_x,
			start_position.y
			+ ground_probe_depth
		)

		var query := (
			PhysicsRayQueryParameters2D.create(
				ray_start,
				ray_end
			)
		)

		#
		# Use the same floor layers as FloorCheck.
		#
		query.collision_mask = (
			floor_check.collision_mask
		)

		query.exclude = [
			get_rid()
		]

		var result: Dictionary = (
			space_state.intersect_ray(query)
		)

		#
		# No floor at one of our samples means there
		# is a gap.
		#
		if result.is_empty():
			return false

	return true


# ============================================================
# SEEKING MOUSE HOLE
# ============================================================

func update_seeking_hole() -> void:
	#
	# Once the enemy chooses a reachable mouse hole,
	# it commits to it.
	#
	if target_hole == null:
		recover_from_missing_hole()
		return

	if not is_instance_valid(target_hole):
		recover_from_missing_hole()
		return

	move_to_mouse_hole(target_hole)


func recover_from_missing_hole() -> void:
	target_hole = find_nearest_entry_hole()

	if target_hole == null:
		print("Lost mouse-hole target.")

		ai_state = AIState.CHASING
		velocity.x = 0.0


# ============================================================
# FIND ENTRY HOLE
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
		# Hole needs to be roughly on our current level.
		#
		var vertical_distance: float = absf(
			hole.global_position.y
			- global_position.y
		)

		if vertical_distance > hole_platform_tolerance:
			continue

		var horizontal_difference: float = (
			hole.global_position.x
			- global_position.x
		)

		var direction: float = signf(
			horizontal_difference
		)

		#
		# Don't require ground all the way underneath
		# the actual hole. The hole may be slightly inside
		# a wall or at the edge.
		#
		var approach_x: float = (
			hole.global_position.x
			- direction
			* mouse_hole_reach_distance
		)

		#
		# Ignore holes we physically cannot walk to.
		#
		if not has_continuous_ground_between(
			global_position,
			approach_x
		):
			continue

		var horizontal_distance: float = absf(
			horizontal_difference
		)

		if horizontal_distance < best_distance:
			best_distance = horizontal_distance
			best_hole = hole

	return best_hole


# ============================================================
# MOVE TO ENTRY HOLE
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

	var distance_to_hole: float = absf(
		horizontal_difference
	)

	#
	# Enemy has reached the hole.
	#
	if distance_to_hole <= mouse_hole_reach_distance:
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
	# We already checked that this hole was reachable.
	#
	# SEEKING_HOLE commits to the selected hole and doesn't
	# reconsider based on player distance.
	#
	velocity.x = (
		direction
		* speed
		* movement_multiplier
	)


# ============================================================
# MOUSE-HOLE TRAVEL TIME
# ============================================================

func calculate_mouse_hole_travel_time(
	entry_hole: MouseHole,
	exit_hole: MouseHole
) -> float:
	var distance: float = (
		entry_hole.global_position.distance_to(
			exit_hole.global_position
		)
	)

	var travel_time: float = (
		distance
		/ mouse_hole_travel_speed
	)

	return clampf(
		travel_time,
		min_mouse_hole_travel_time,
		max_mouse_hole_travel_time
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
		return

	var exit_hole: MouseHole = (
		find_best_exit_hole(
			entry_hole
		)
	)

	if exit_hole == null:
		print(
			"Could not find valid mouse-hole exit."
		)

		target_hole = null
		ai_state = AIState.CHASING

		return

	var travel_time: float = (
		calculate_mouse_hole_travel_time(
			entry_hole,
			exit_hole
		)
	)

	#
	# Enter teleport state immediately.
	#
	ai_state = AIState.TELEPORTING

	target_hole = null
	velocity = Vector2.ZERO

	print(
		"Entering ",
		entry_hole.name,
		" -> ",
		exit_hole.name,
		" | distance: ",
		entry_hole.global_position.distance_to(
			exit_hole.global_position
		),
		" | travel time: ",
		travel_time,
		" seconds"
	)

	#
	# Disappear into the hole.
	#
	sprite.visible = false

	collision_shape.set_deferred(
		"disabled",
		true
	)

	#
	# Wait according to underground distance.
	#
	await get_tree().create_timer(
		travel_time
	).timeout

	#
	# Appear at destination.
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

	teleport_cooldown_remaining = (
		teleport_cooldown
	)

	#
	# Resume chase.
	#
	ai_state = AIState.CHASING


# ============================================================
# FIND EXIT HOLE
# ============================================================

func find_best_exit_hole(
	entry_hole: MouseHole
) -> MouseHole:
	var best_hole: MouseHole = null
	var best_score: float = INF

	var nodes: Array[Node] = (
		get_tree().get_nodes_in_group(
			"mouse_hole"
		)
	)

	#
	# First pass:
	#
	# Try to find a hole that's actually connected to
	# the player's current platform.
	#
	for node: Node in nodes:
		var hole: MouseHole = node as MouseHole

		if hole == null:
			continue

		if hole == entry_hole:
			continue

		var exit_position: Vector2 = (
			hole.get_exit_position()
		)

		var vertical_distance: float = absf(
			exit_position.y
			- player_ground_y
		)

		if vertical_distance > hole_platform_tolerance:
			continue

		if not has_continuous_ground_between(
			exit_position,
			player.global_position.x
		):
			continue

		var horizontal_distance: float = absf(
			exit_position.x
			- player.global_position.x
		)

		var score: float = (
			vertical_distance
			* exit_vertical_weight
			+ horizontal_distance
		)

		if score < best_score:
			best_score = score
			best_hole = hole

	#
	# Connected destination found.
	#
	if best_hole != null:
		return best_hole

	#
	# Fallback:
	#
	# Pick the hole whose exit is closest to the player,
	# heavily prioritizing vertical distance.
	#
	best_score = INF

	for node: Node in nodes:
		var hole: MouseHole = node as MouseHole

		if hole == null:
			continue

		if hole == entry_hole:
			continue

		var exit_position: Vector2 = (
			hole.get_exit_position()
		)

		var vertical_distance: float = absf(
			exit_position.y
			- player_ground_y
		)

		var horizontal_distance: float = absf(
			exit_position.x
			- player.global_position.x
		)

		var score: float = (
			vertical_distance
			* exit_vertical_weight
			+ horizontal_distance
		)

		if score < best_score:
			best_score = score
			best_hole = hole

	return best_hole


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
# FLOOR CHECK
# ============================================================

func update_floor_check(
	direction: float
) -> void:
	floor_check.position.x = (
		18.0 * direction
	)


# ============================================================
# ANIMATION
# ============================================================

func update_animation() -> void:
	#
	# ATTACK controls its own animation.
	#
	if ai_state == AIState.ATTACKING:
		return

	#
	# Enemy is invisible while teleporting.
	#
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
	# Enemy is intentionally invulnerable.
	#
	pass
