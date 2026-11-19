extends CharacterBody3D

const ATTACK_ANIMATIONS: Array[StringName] = [
	&"UAL/Punch_Jab",
	&"UAL/Punch_Cross",
]
const IDLE_ANIMATION: StringName = &"UAL/Idle_Loop"
const RUN_ANIMATION: StringName = &"UAL/Jog_Fwd_Loop"
const HIT_ANIMATION: StringName = &"UAL/Hit_Chest"
const DEATH_ANIMATION: StringName = &"UAL/Death01"

@export var sight_range = 9.0
@export_range(45.0, 180.0, 1.0) var field_of_view_degrees = 120.0
@export var lose_interest_range = 22.0
@export var attack_range = 1.45
@export var move_speed = 3.2
@export var jump_strength = 7.0
@export var attack_damage = 10
@export var attack_cooldown = 1.1
@export var maximum_health = 60

var health = maximum_health
var target: CharacterBody3D
var has_spotted_player = false
var attack_active = false
var attack_hit_applied = false
var hurt_active = false
var is_dead = false
var attack_index = 0
var attack_cooldown_timer = 0.0
var jump_cooldown_timer = 0.0
var gravity = 25.0

@onready var model: Node3D = $Character
@onready var animation: AnimationPlayer = $Character/AnimationPlayer

func _ready():
	model.scale = Vector3.ONE
	health = maximum_health
	attack_cooldown_timer = 1.5
	target = get_tree().get_first_node_in_group("player") as CharacterBody3D
	for animation_name in [RUN_ANIMATION, IDLE_ANIMATION]:
		if animation.has_animation(animation_name):
			var clip = animation.get_animation(animation_name)
			clip.loop_mode = Animation.LOOP_LINEAR
	for animation_name in [HIT_ANIMATION, DEATH_ANIMATION] + ATTACK_ANIMATIONS:
		if animation.has_animation(animation_name):
			var clip = animation.get_animation(animation_name)
			clip.loop_mode = Animation.LOOP_NONE
	animation.animation_finished.connect(_on_animation_finished)

func _physics_process(delta):
	if is_dead:
		return

	attack_cooldown_timer = maxf(attack_cooldown_timer - delta, 0.0)
	jump_cooldown_timer = maxf(jump_cooldown_timer - delta, 0.0)
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as CharacterBody3D

	var to_target = Vector3.ZERO
	var distance_to_target = INF
	var horizontal_distance = INF
	if is_instance_valid(target):
		to_target = target.global_position - global_position
		to_target.y = 0.0
		horizontal_distance = to_target.length()
		distance_to_target = global_position.distance_to(target.global_position)
		if not has_spotted_player and _can_see_player(to_target, horizontal_distance):
			has_spotted_player = true
		elif has_spotted_player and horizontal_distance > lose_interest_range:
			has_spotted_player = false
			attack_active = false
			hurt_active = false

	var desired_velocity = Vector3.ZERO
	if has_spotted_player and is_instance_valid(target):
		var direction = Vector3.ZERO
		if horizontal_distance > 0.01:
			direction = to_target / horizontal_distance
			rotation.y = lerp_angle(rotation.y, Vector2(direction.z, direction.x).angle(), delta * 8.0)
		if distance_to_target > attack_range:
			if not attack_active and not hurt_active:
				desired_velocity = direction * move_speed
				if is_on_floor() and jump_cooldown_timer <= 0.0 and _needs_jump(direction):
					velocity.y = jump_strength
					jump_cooldown_timer = 0.8
		elif is_on_floor() and not attack_active and not hurt_active and attack_cooldown_timer <= 0.0:
			_start_attack()

	velocity.x = move_toward(velocity.x, desired_velocity.x, move_speed * 8.0 * delta)
	velocity.z = move_toward(velocity.z, desired_velocity.z, move_speed * 8.0 * delta)
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= gravity * delta

	move_and_slide()
	_process_attack_hit()
	_update_animation()
	if global_position.y < -10.0:
		queue_free()

func _can_see_player(to_target: Vector3, distance_to_target: float) -> bool:
	if distance_to_target > sight_range or distance_to_target <= 0.01:
		return false

	var forward = global_transform.basis.z.normalized()
	var direction = to_target / distance_to_target
	var minimum_dot = cos(deg_to_rad(field_of_view_degrees * 0.5))
	if forward.dot(direction) < minimum_dot:
		return false

	var eye_position = global_position + Vector3.UP * 0.9
	var target_position = target.global_position + Vector3.UP * 0.7
	var query = PhysicsRayQueryParameters3D.create(eye_position, target_position)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit = get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target

func _needs_jump(direction: Vector3) -> bool:
	if is_instance_valid(target) and target.global_position.y > global_position.y + 0.45:
		return true
	var check_start = global_position + direction * 0.8 + Vector3.UP * 0.7
	var query = PhysicsRayQueryParameters3D.create(check_start, check_start + Vector3.DOWN * 2.0)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	if is_instance_valid(target):
		query.exclude.append(target.get_rid())
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _start_attack():
	attack_active = true
	attack_hit_applied = false
	attack_cooldown_timer = attack_cooldown
	animation.speed_scale = 1.0
	animation.play(ATTACK_ANIMATIONS[attack_index], 0.05)
	attack_index = (attack_index + 1) % ATTACK_ANIMATIONS.size()

func _process_attack_hit():
	if not attack_active or attack_hit_applied:
		return
	if animation.current_animation_position < animation.current_animation_length * 0.45:
		return
	attack_hit_applied = true
	if is_instance_valid(target) and global_position.distance_to(target.global_position) <= attack_range + 0.25:
		if target.has_method("take_damage"):
			target.take_damage(attack_damage)

func _update_animation():
	if attack_active or hurt_active or is_dead:
		return
	if Vector2(velocity.x, velocity.z).length() > 0.15:
		if animation.current_animation != RUN_ANIMATION:
			animation.play(RUN_ANIMATION, 0.1)
	else:
		if animation.current_animation != IDLE_ANIMATION:
			animation.play(IDLE_ANIMATION, 0.1)

func _on_animation_finished(animation_name: StringName):
	if animation_name in ATTACK_ANIMATIONS:
		attack_active = false
	elif animation_name == HIT_ANIMATION:
		hurt_active = false
	elif animation_name == DEATH_ANIMATION and is_dead:
		queue_free()

func take_damage(amount: int):
	if is_dead:
		return
	health = maxi(health - amount, 0)
	attack_active = false
	attack_hit_applied = false
	if health == 0:
		is_dead = true
		hurt_active = false
		velocity = Vector3.ZERO
		collision_layer = 0
		collision_mask = 0
		animation.play(DEATH_ANIMATION, 0.05)
	else:
		hurt_active = true
		animation.play(HIT_ANIMATION, 0.05)
