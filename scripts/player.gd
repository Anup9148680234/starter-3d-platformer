extends CharacterBody3D

signal coin_collected(total_coins: int)
signal health_changed(current_health: int, maximum_health: int)
signal inventory_changed(items: Dictionary)
signal item_picked_up(item_id: StringName, quantity: int)

const ATTACK_ANIMATIONS: Array[StringName] = [&"PunchJab", &"PunchCross", &"PunchJab", &"PunchCross"]
const ATTACK_SOURCE_ANIMATIONS := {
	&"PunchJab": &"UAL/Punch_Jab",
	&"PunchCross": &"UAL/Punch_Cross",
	&"SwordIdle": &"UAL/Sword_Idle",
	&"SwordAttack": &"UAL/Sword_Attack",
}
const MAX_HEALTH := 100
const PUNCH_DAMAGE := 20
const PUNCH_REACH := 1.9
const PUNCH_HIT_TIME := 0.45
const ROLL_DURATION := 0.45
const ROLL_SPEED := 6.5
const UAL_IDLE: StringName = &"UAL/Idle_Loop"
const UAL_WALK: StringName = &"UAL/Walk_Loop"
const UAL_JOG: StringName = &"UAL/Jog_Fwd_Loop"
const UAL_ROLL: StringName = &"UAL/Roll"
const UAL_JUMP_START: StringName = &"UAL/Jump_Start"
const UAL_JUMP_LOOP: StringName = &"UAL/Jump_Loop"
const UAL_JUMP_LAND: StringName = &"UAL/Jump_Land"
const UAL_HIT: StringName = &"UAL/Hit_Chest"
const UAL_DEATH: StringName = &"UAL/Death01"
const UAL_SWORD_ATTACK: StringName = &"UAL/Sword_Attack"
const UAL_SWORD_IDLE: StringName = &"UAL/Sword_Idle"
const JUMP_START_BLEND_TIME := 0.28
const GLIDER_GRAVITY := 8.0
const GLIDER_MAX_FALL_SPEED := 2.8
const GLIDER_DEPLOY_DECELERATION := 20.0
const GLIDER_FORWARD_SPEED := 4.0
const GLIDER_ANIMATION_NAME: StringName = &"UAL/Jump_Loop"

@export_subgroup("Components")
@export var view: Node3D
@export_subgroup("Skins")
@export var available_skins: Array[PlayerSkin] = [preload("res://skins/player_default.tres"), preload("res://skins/player_black.tres")]
@export var starting_skin := 1
@export_subgroup("Properties")
@export var movement_speed := 250.0
@export var jump_strength := 7.0

var movement_velocity := Vector3.ZERO
var rotation_direction := 0.0
var gravity := 0.0
var jump_single := true
var jump_double := true
var coins := 0
var inventory_items: Dictionary = {}
var current_skin_index := -1
var health := MAX_HEALTH
var is_dead := false
var reaction_active := false
var attack_active := false
var is_rolling := false
var is_gliding := false
var sword_attack_active := false
var sword_mode_active := false
var jump_start_active := false
var jump_start_time_remaining := 0.0
var roll_move_time_remaining := 0.0
var roll_world_direction := Vector3.ZERO
var roll_start_yaw := 0.0
var combo_step := -1
var combo_input_buffered := false
var attack_hit_applied := false
var upper_body_animation: AnimationPlayer
var _base_materials: Dictionary = {}

@onready var particles_trail: GPUParticles3D = get_node_or_null("ParticlesTrail") as GPUParticles3D
@onready var sound_footsteps: AudioStreamPlayer = get_node_or_null("SoundFootsteps") as AudioStreamPlayer
@onready var model: Node3D = $Character
@onready var animation: AnimationPlayer = _find_animation_player(model)
@onready var rocket_pack: Node3D = model.get_node_or_null("Armature/GeneralSkeleton/backpackAttachment/rocket") as Node3D
@onready var glide_flame: Node3D = model.get_node_or_null("left_flame") as Node3D
@onready var sword: Node3D = model.get_node_or_null("Armature/GeneralSkeleton/SwordHandAttachment/Sword") as Node3D

func _ready() -> void:
	add_to_group("player")
	if animation == null:
		push_error("Player Character must contain an AnimationPlayer.")
		set_physics_process(false)
		return
	model.scale = Vector3.ONE
	_set_loop(UAL_IDLE, Animation.LOOP_LINEAR)
	_set_loop(UAL_WALK, Animation.LOOP_LINEAR)
	_set_loop(UAL_JOG, Animation.LOOP_LINEAR)
	_set_loop(UAL_JUMP_LOOP, Animation.LOOP_LINEAR)
	_set_loop(UAL_ROLL, Animation.LOOP_NONE)
	_set_loop(UAL_JUMP_START, Animation.LOOP_NONE)
	_set_loop(UAL_JUMP_LAND, Animation.LOOP_NONE)
	_set_loop(UAL_HIT, Animation.LOOP_NONE)
	_set_loop(UAL_DEATH, Animation.LOOP_NONE)
	_set_loop(UAL_SWORD_ATTACK, Animation.LOOP_NONE)
	_set_loop(UAL_SWORD_IDLE, Animation.LOOP_LINEAR)
	_set_loop(GLIDER_ANIMATION_NAME, Animation.LOOP_LINEAR)
	for clip in ATTACK_ANIMATIONS:
		_set_loop(clip, Animation.LOOP_NONE)
	animation.animation_finished.connect(_on_animation_finished)
	_setup_upper_body_attacks()
	_setup_rocket_jetpack()
	if sword != null:
		sword.visible = false
	apply_skin(starting_skin)
	_set_gliding(false)
	health_changed.emit(health, MAX_HEALTH)

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null

func _resolve_animation_name(wanted: StringName) -> StringName:
	if animation == null:
		return &""
	if animation.has_animation(wanted):
		return wanted
	var suffix := String(wanted).to_lower()
	for candidate in animation.get_animation_list():
		var text := String(candidate).to_lower()
		if text.ends_with("/" + suffix) or text.ends_with(suffix):
			return candidate
	return &""

func _set_loop(wanted: StringName, loop_mode: Animation.LoopMode) -> void:
	var resolved := _resolve_animation_name(wanted)
	if resolved != &"":
		var clip: Animation = animation.get_animation(resolved)
		if clip != null:
			clip.loop_mode = loop_mode

func _setup_upper_body_attacks() -> void:
	upper_body_animation = AnimationPlayer.new()
	upper_body_animation.name = "UpperBodyAttackPlayer"
	upper_body_animation.root_node = NodePath("..")
	var upper_library := AnimationLibrary.new()
	for attack_name in ATTACK_SOURCE_ANIMATIONS:
		var source_name: StringName = _resolve_animation_name(ATTACK_SOURCE_ANIMATIONS[attack_name])
		if source_name == &"":
			continue
		var source_clip: Animation = animation.get_animation(source_name)
		if source_clip == null:
			continue
		var clip := source_clip.duplicate(true) as Animation
		if clip == null:
			continue
		for track_index in range(clip.get_track_count() - 1, -1, -1):
			var path := String(clip.track_get_path(track_index))
			var bone := path.get_slice(":", 1)
			var upper := bone in ["Spine", "Chest", "UpperChest", "Neck", "Head"] or bone.contains("Shoulder") or bone.contains("UpperArm") or bone.contains("LowerArm") or bone.contains("Hand") or bone.contains("Proximal") or bone.contains("Intermediate") or bone.contains("Distal") or bone.contains("Thumb")
			if not upper:
				clip.remove_track(track_index)
		if clip.get_track_count() > 0:
			clip.loop_mode = Animation.LOOP_LINEAR if attack_name == &"SwordIdle" else Animation.LOOP_NONE
			upper_library.add_animation(attack_name, clip)
	upper_body_animation.add_animation_library(&"", upper_library)
	model.add_child(upper_body_animation)
	upper_body_animation.animation_finished.connect(_on_animation_finished)

func _setup_rocket_jetpack() -> void:
	if rocket_pack != null:
		rocket_pack.visible = false
	else:
		push_warning("Rocket jetpack not found at backpackAttachment/rocket.")
	if glide_flame != null:
		glide_flame.visible = false
		_set_glide_flame_emitting(false)
	else:
		push_warning("Glide flame node 'left_flame' was not found in the character scene.")

func _input(event: InputEvent) -> void:
	if get_tree().paused or is_dead:
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.physical_keycode == KEY_E or key.keycode == KEY_E):
			_try_start_glide()
		elif key.pressed and not key.echo and (key.physical_keycode == KEY_F or key.keycode == KEY_F):
			_toggle_sword_mode()

func _toggle_sword_mode() -> void:
	if is_dead or sword_attack_active or reaction_active:

		return
	sword_mode_active = not sword_mode_active
	if sword != null:
		sword.visible = sword_mode_active
	if sword_mode_active:
		_cancel_upper_body_attack()
		animation.speed_scale = 1.0
		if upper_body_animation.has_animation(&"SwordIdle"):
			upper_body_animation.play(&"SwordIdle", 0.12)
	else:
		if upper_body_animation.current_animation == &"SwordIdle":
			upper_body_animation.stop(true)

func _try_play_sword_attack() -> void:
	if sword_attack_active or is_dead or attack_active or reaction_active or not is_on_floor():
		return
	if not upper_body_animation.has_animation(&"SwordAttack"):
		return
	sword_attack_active = true
	_cancel_upper_body_attack()
	upper_body_animation.play(&"SwordAttack", 0.05)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if is_rolling:
		roll_move_time_remaining = maxf(roll_move_time_remaining - delta, 0.0)
		if roll_move_time_remaining <= 0.0:
			is_rolling = false
	var was_on_floor := is_on_floor()
	handle_controls(delta)
	if jump_start_active:
		jump_start_time_remaining = maxf(jump_start_time_remaining - delta, 0.0)
		if jump_start_time_remaining <= 0.0:
			jump_start_active = false
	handle_gravity(delta)
	handle_effects(delta)
	if is_rolling:
		var roll_velocity := roll_world_direction * ROLL_SPEED
		velocity = Vector3(roll_velocity.x, -gravity, roll_velocity.z)
	elif reaction_active:
		velocity = Vector3(0.0, -gravity, 0.0)
	elif is_gliding and not is_on_floor():
		var facing := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
		var glide_horizontal := movement_velocity
		if Vector2(glide_horizontal.x, glide_horizontal.z).length() < 0.1:
			glide_horizontal = facing * GLIDER_FORWARD_SPEED
		velocity.x = lerpf(velocity.x, glide_horizontal.x, 1.0 - exp(-2.5 * delta))
		velocity.z = lerpf(velocity.z, glide_horizontal.z, 1.0 - exp(-2.5 * delta))
		velocity.y = -gravity
	else:
		velocity = velocity.lerp(movement_velocity, delta * 10.0)
		velocity.y = -gravity
	move_and_slide()
	if is_gliding and is_on_floor():
		_set_gliding(false)
	process_punch_hit()
	if is_rolling:
		rotation.y = roll_start_yaw
	elif Vector2(velocity.x, velocity.z).length() > 0.05:
		rotation_direction = atan2(velocity.x, velocity.z)
		rotation.y = lerp_angle(rotation.y, rotation_direction, delta * 10.0)
	if global_position.y < -10.0:
		_set_gliding(false)
		is_dead = true
		velocity = Vector3.ZERO
		GameSave.begin_player_death()
		GameSave.show_you_died_screen()
		return
	if is_on_floor() and not was_on_floor and velocity.y <= 0.0:
		_set_gliding(false)
		is_rolling = false
		roll_move_time_remaining = 0.0
		model.scale = Vector3.ONE
		reaction_active = false
		jump_start_active = false
		jump_start_time_remaining = 0.0
		jump_single = true
		jump_double = true
		animation.speed_scale = 1.0
		_play_base_animation(UAL_JUMP_LAND, &"", &"", 2.5)
		Audio.play("res://sounds/land.ogg")

func handle_controls(delta: float) -> void:
	if reaction_active:
		movement_velocity = Vector3.ZERO
		return
	var input := Vector3(Input.get_axis("move_left", "move_right"), 0.0, Input.get_axis("move_forward", "move_back"))
	var moved := Input.is_action_just_pressed("move_left") or Input.is_action_just_pressed("move_right") or Input.is_action_just_pressed("move_forward") or Input.is_action_just_pressed("move_back")
	var world_input := input
	if view != null:
		world_input = input.rotated(Vector3.UP, view.global_rotation.y)
	if world_input.length() > 1.0:
		world_input = world_input.normalized()
	movement_velocity = world_input * movement_speed * delta
	# Allow either input order: press Shift while moving, or press a direction while Shift is held.
	var roll_requested := Input.is_action_just_pressed("roll") or (Input.is_action_pressed("roll") and moved)
	if roll_requested and not input.is_zero_approx():
		try_start_roll(Vector2(input.x, input.z), world_input)
	if Input.is_action_just_pressed("attack"):
		if sword_mode_active:
			_try_play_sword_attack()
		elif attack_active:
			var length := maxf(upper_body_animation.current_animation_length, 0.001)
			if combo_step < ATTACK_ANIMATIONS.size() - 1 and upper_body_animation.current_animation_position / length >= PUNCH_HIT_TIME:
				combo_input_buffered = true
		elif is_on_floor():
			start_attack(0)
	if Input.is_action_just_pressed("jump") and (jump_single or jump_double):
		_cancel_upper_body_attack()
		reaction_active = false
		jump()

func handle_gravity(delta: float) -> void:
	if is_gliding and not is_on_floor():
		if gravity < GLIDER_MAX_FALL_SPEED:
			gravity = minf(gravity + GLIDER_GRAVITY * delta, GLIDER_MAX_FALL_SPEED)
		else:
			gravity = move_toward(gravity, GLIDER_MAX_FALL_SPEED, GLIDER_DEPLOY_DECELERATION * delta)
	else:
		gravity += 25.0 * delta
	if gravity > 0.0 and is_on_floor():
		jump_single = true
		gravity = 0.0

func handle_effects(delta: float) -> void:
	if particles_trail != null:
		particles_trail.emitting = false
	if sound_footsteps != null:
		sound_footsteps.stream_paused = true
	if reaction_active or is_dead or is_rolling:
		return
	var jump_start := _resolve_animation_name(UAL_JUMP_START)
	if jump_start_active and animation.current_animation == jump_start and animation.is_playing():
		return
	var roll_animation := _resolve_animation_name(UAL_ROLL)
	if animation.current_animation == roll_animation and animation.is_playing():
		var has_movement_input := Vector2(movement_velocity.x, movement_velocity.z).length() > 0.05
		var starting_jump := Input.is_action_just_pressed("jump")
		if not has_movement_input and not starting_jump:
			return
	if is_gliding and not is_on_floor():
		_play_base_animation(GLIDER_ANIMATION_NAME)
		return
	if is_on_floor():
		var land := _resolve_animation_name(UAL_JUMP_LAND)
		var has_movement_input := Vector2(movement_velocity.x, movement_velocity.z).length() > 0.05
		if animation.current_animation == land and animation.is_playing() and not has_movement_input:
			return
		var planar_speed := maxf(Vector2(velocity.x, velocity.z).length(), Vector2(movement_velocity.x, movement_velocity.z).length())
		var expected_speed := maxf(movement_speed * delta, 0.001)
		var speed_factor := planar_speed / expected_speed
		if planar_speed > 0.15:
			var movement_clip := UAL_JOG if speed_factor >= 0.75 else UAL_WALK
			_play_base_animation(movement_clip, UAL_WALK)
			if sound_footsteps != null and speed_factor > 0.3:
				sound_footsteps.stream_paused = false
				sound_footsteps.pitch_scale = clampf(speed_factor, 0.7, 1.6)
			if particles_trail != null and speed_factor > 0.75:
				particles_trail.emitting = true
			if animation.current_animation == _resolve_animation_name(movement_clip):
				animation.speed_scale = clampf(speed_factor, 0.6, 1.8)
		else:
			animation.speed_scale = 1.0
			_play_base_animation(UAL_IDLE)
	else:
		jump_start_active = false
		_play_base_animation(UAL_JUMP_LOOP)

func _play_base_animation(primary: StringName, fallback: StringName = &"", alternate: StringName = &"", custom_speed: float = 1.0) -> void:
	var chosen := _resolve_animation_name(primary)
	if chosen == &"" and fallback != &"":
		chosen = _resolve_animation_name(fallback)
	if chosen == &"" and alternate != &"":
		chosen = _resolve_animation_name(alternate)
	if chosen != &"" and animation.current_animation != chosen:
		animation.play(chosen, 0.1, custom_speed)

func start_attack(step: int) -> void:
	if step < 0 or step >= ATTACK_ANIMATIONS.size() or not upper_body_animation.has_animation(ATTACK_ANIMATIONS[step]):
		return
	combo_step = step
	attack_active = true
	combo_input_buffered = false
	attack_hit_applied = false
	upper_body_animation.speed_scale = 1.0
	upper_body_animation.play(ATTACK_ANIMATIONS[step], 0.05)

func process_punch_hit() -> void:
	if not attack_active or attack_hit_applied or not upper_body_animation.is_playing():
		return
	if upper_body_animation.current_animation_position < upper_body_animation.current_animation_length * PUNCH_HIT_TIME:
		return
	attack_hit_applied = true
	var forward := global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var origin := global_position + Vector3.UP * 0.65
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var offset: Vector3 = enemy.global_position - origin
		var horizontal := Vector3(offset.x, 0.0, offset.z)
		var distance := horizontal.length()
		if distance > PUNCH_REACH or absf(offset.y) > 1.25:
			continue
		if distance > 0.01 and forward.dot(horizontal / distance) < 0.15:
			continue
		enemy.take_damage(PUNCH_DAMAGE)

func _cancel_upper_body_attack() -> void:
	attack_active = false
	combo_step = -1
	combo_input_buffered = false
	attack_hit_applied = false
	if is_instance_valid(upper_body_animation):
		upper_body_animation.stop(true)

func try_start_roll(direction: Vector2, world_direction: Vector3) -> void:
	if is_rolling or not is_on_floor() or attack_active or reaction_active or is_dead or direction.is_zero_approx():
		return
	var roll_vector := Vector3(world_direction.x, 0.0, world_direction.z)
	if roll_vector.is_zero_approx():
		return
	is_rolling = true
	roll_move_time_remaining = ROLL_DURATION
	roll_world_direction = roll_vector.normalized()
	roll_start_yaw = atan2(roll_vector.x, roll_vector.z)
	movement_velocity = Vector3.ZERO
	var resolved := _resolve_animation_name(UAL_ROLL)
	if resolved != &"":
		animation.speed_scale = 1.0
		animation.play(resolved, 0.05, 2.0)

func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name == _resolve_animation_name(UAL_JUMP_LAND):
		animation.speed_scale = 1.0
		return
	if animation_name == &"SwordAttack":
		sword_attack_active = false
		if sword_mode_active and not is_dead:
			upper_body_animation.play(&"SwordIdle", 0.12)
		return
	if ATTACK_ANIMATIONS.has(animation_name):
		if combo_step == 2 and is_on_floor():
			upper_body_animation.stop(true)
			start_attack(3)
		elif combo_input_buffered and combo_step < ATTACK_ANIMATIONS.size() - 1 and is_on_floor():
			upper_body_animation.stop(true)
			start_attack(combo_step + 1)
		else:
			_cancel_upper_body_attack()
		return
	if animation_name == _resolve_animation_name(UAL_ROLL):
		is_rolling = false
		animation.speed_scale = 1.0
		return
	if animation_name == _resolve_animation_name(UAL_JUMP_START):
		jump_start_active = false
	elif animation_name == _resolve_animation_name(UAL_HIT):
		reaction_active = false
	elif is_dead and animation_name == _resolve_animation_name(UAL_DEATH):
		GameSave.show_you_died_screen()

func take_damage(amount: int) -> void:
	if is_dead or amount <= 0:
		return
	sword_attack_active = false
	jump_start_active = false
	jump_start_time_remaining = 0.0
	health = maxi(health - amount, 0)
	health_changed.emit(health, MAX_HEALTH)
	_cancel_upper_body_attack()
	_set_gliding(false)
	is_rolling = false
	roll_move_time_remaining = 0.0
	animation.speed_scale = 1.0
	if health == 0:
		is_dead = true
		sword_attack_active = false
		GameSave.begin_player_death()
		reaction_active = false
		movement_velocity = Vector3.ZERO
		var death := _resolve_animation_name(UAL_DEATH)
		if death != &"":
			animation.play(death, 0.05)
		else:
			GameSave.show_you_died_screen()
	else:
		sword_attack_active = false
		reaction_active = true
		var hit := _resolve_animation_name(UAL_HIT)
		if hit != &"":
			animation.play(hit, 0.05)
		else:
			reaction_active = false

func apply_skin(index: int) -> void:
	if index < 0 or index >= available_skins.size():
		return
	var skin := available_skins[index]
	if skin == null or skin.albedo_texture == null:
		return
	current_skin_index = index
	var ual_skeleton := model.find_child("GeneralSkeleton", true, false) as Skeleton3D
	for item in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := item as MeshInstance3D
		if ual_skeleton != null and mesh.name != "Mannequin":
			continue
		if mesh.mesh == null:
			continue
		for surface in range(mesh.mesh.get_surface_count()):
			var key := "%s:%d" % [mesh.get_path(), surface]
			if not _base_materials.has(key):
				_base_materials[key] = mesh.get_active_material(surface)
			var base := _base_materials[key] as Material
			if base is BaseMaterial3D:
				var material := (base as BaseMaterial3D).duplicate() as BaseMaterial3D
				if ual_skeleton != null:
					if skin.display_name.to_lower().contains("black"):
						material.albedo_color = Color(0.035, 0.035, 0.04) if base.resource_name == "M_Main" else Color(0.075, 0.075, 0.08)
						mesh.set_surface_override_material(surface, material)
					else:
						mesh.set_surface_override_material(surface, base)
				else:
					material.albedo_texture = skin.albedo_texture
					mesh.set_surface_override_material(surface, material)

func _set_gliding(active: bool) -> void:
	is_gliding = active
	if not active and sword_attack_active:
		sword_attack_active = false
		if is_instance_valid(upper_body_animation) and upper_body_animation.current_animation == &"SwordAttack":
			upper_body_animation.stop(true)
		if sword_mode_active and is_instance_valid(upper_body_animation) and upper_body_animation.has_animation(&"SwordIdle"):
			upper_body_animation.play(&"SwordIdle", 0.12)
	if rocket_pack != null:
		rocket_pack.visible = active
	if glide_flame != null:
		glide_flame.visible = active
		_set_glide_flame_emitting(active)

func _set_glide_flame_emitting(active: bool) -> void:
	if glide_flame == null:
		return
	for particle in glide_flame.find_children("*", "GPUParticles3D", true, false):
		var emitter := particle as GPUParticles3D
		emitter.emitting = active
		if active:
			emitter.restart()
	var lights := glide_flame.get_node_or_null("Lights")
	if lights != null:
		lights.set("emitting", active)
		if active and lights.has_method("restart"):
			lights.call("restart")
	var audio := glide_flame.get_node_or_null("Audio") as AudioStreamPlayer3D
	if audio != null:
		if active:
			audio.play()
		else:
			audio.stop()

func _try_start_glide() -> void:
	if is_gliding or is_on_floor() or is_dead or attack_active or sword_attack_active or reaction_active or is_rolling:
		return
	var height := 1.0
	var collider := get_node_or_null("Collider") as CollisionShape3D
	if collider != null and collider.shape is CapsuleShape3D:
		height = (collider.shape as CapsuleShape3D).height
	# Cast far enough to find the surface even when the player is already well
	# above the required deployment height, then enforce the two-body-height rule.
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.05, global_position - Vector3.UP * 1000.0)
	query.exclude = [get_rid()]
	var ground_hit := get_world_3d().direct_space_state.intersect_ray(query)
	if ground_hit.is_empty() or global_position.y - Vector3(ground_hit["position"]).y < height * 2.0:
		return
	_set_gliding(true)
	jump_start_active = false
	jump_start_time_remaining = 0.0
	_play_base_animation(GLIDER_ANIMATION_NAME)

func collect_coin(amount: int = 1) -> void:
	if amount <= 0:
		return
	coins += amount
	add_inventory_item(&"gold_coin", amount)
	if has_node("/root/GameSave"):
		GameSave.sync_player_inventory(coins, inventory_items)
	coin_collected.emit(coins)
	Audio.play("res://sounds/coin.ogg")

func add_inventory_item(item_id: StringName, quantity: int = 1) -> void:
	if item_id == &"" or quantity <= 0:
		return
	inventory_items[item_id] = int(inventory_items.get(item_id, 0)) + quantity
	inventory_changed.emit(inventory_items.duplicate(true))
	item_picked_up.emit(item_id, quantity)

func spend_coins(amount: int) -> bool:
	if amount <= 0 or coins < amount:
		return false
	coins -= amount
	var remaining := int(inventory_items.get(&"gold_coin", 0)) - amount
	if remaining > 0:
		inventory_items[&"gold_coin"] = remaining
	else:
		inventory_items.erase(&"gold_coin")
	GameSave.sync_player_inventory(coins, inventory_items)
	coin_collected.emit(coins)
	inventory_changed.emit(inventory_items.duplicate(true))
	return true

func jump() -> void:
	Audio.play("res://sounds/jump.ogg")
	gravity = -jump_strength
	var jump_start := _resolve_animation_name(UAL_JUMP_START)
	jump_start_active = jump_start != &""
	jump_start_time_remaining = JUMP_START_BLEND_TIME if jump_start_active else 0.0
	if jump_start_active:
		animation.play(jump_start, 0.05)
	else:
		_play_base_animation(UAL_JUMP_LOOP)
	if jump_single:
		jump_single = false
		jump_double = true
	else:
		jump_double = false
