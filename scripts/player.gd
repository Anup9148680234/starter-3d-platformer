extends CharacterBody3D

const ITEM_CATALOG = preload("res://scripts/item_catalog.gd")

signal coin_collected(total_coins: int)
signal health_changed(current_health: int, maximum_health: int)
signal inventory_changed(items: Dictionary)
signal item_picked_up(item_id: StringName, quantity: int)
signal ability_slots_changed(slots: Array)

const ATTACK_ANIMATIONS: Array[StringName] = [&"PunchJab", &"PunchCross", &"PunchJab", &"PunchCross"]
const ATTACK_SOURCE_ANIMATIONS := {
	&"PunchJab": &"UAL/Punch_Jab",
	&"PunchCross": &"UAL/Punch_Cross",
	&"SwordIdle": &"UAL/Sword_Idle",
	&"SwordAttack": &"UAL/Sword_Attack",
	&"SwordRegularA": &"UAL/Sword_Regular_A",
	&"SwordRegularB": &"UAL/Sword_Regular_B",
	&"SwordRegularCombo": &"UAL/Sword_Regular_Combo",
	&"SwordHeavyCombo": &"UAL/Sword_Heavy_Combo",
	&"SwordBlock": &"UAL/Sword_Block",
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
const UAL_SWORD_HEAVY_COMBO: StringName = &"UAL/Sword_Heavy_Combo"
const HEAVY_COMBO_LUNGE_DURATION := 0.45
const HEAVY_COMBO_LUNGE_DISTANCE := 0.3
const SWORD_BUFFER_MAX_WINDOW := 0.24
const SWORD_BUFFER_EXPIRY_PAD := 0.04
const SWORD_HIT_REACH := 2.35
const SWORD_REGULAR_DAMAGE := 28
const SWORD_REGULAR_COMBO_DAMAGE := 20
const SWORD_HEAVY_COMBO_DAMAGE := 27
const SWORD_BLOCK_DAMAGE_MULTIPLIER := 0.2
const SWORD_BLOCK_ARC_DOT := 0.25
const JUMP_START_BLEND_TIME := 0.28
const GLIDER_GRAVITY := 8.0
const GLIDER_MAX_FALL_SPEED := 2.8
const GLIDER_DEPLOY_DECELERATION := 20.0
const GLIDER_FORWARD_SPEED := 4.0
const GLIDER_ANIMATION_NAME: StringName = &"UAL/Jump_Loop"
const SWORD_BLOCK_ANIMATION: StringName = &"SwordBlock"
const SWORD_BLOCK_HOLD_TIME := 0.64
const SWORD_BLOCK_IDLE_ANIMATION: StringName = &"block_idle"
const CHEST_PICKUP_ANIMATION: StringName = &"UAL/Fixing_Kneeling"
const CHEST_PICKUP_ANIMATION_SPEED := 1.5

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
var jump_double := false
var coins := 0
var inventory_items: Dictionary = {&"combo_punch": 1}
var equipped_ability_slots: Array[StringName] = [&"", &"", &"", &"", &""]
var current_skin_index := -1
var health := MAX_HEALTH
var is_dead := false
var reaction_active := false
var attack_active := false
var is_rolling := false
var is_gliding := false
var sword_attack_active := false
var sword_mode_active := false
var next_sword_regular_is_b := false
var queued_sword_attack: StringName = &""
var current_sword_attack: StringName = &""
var sword_attack_buffer_remaining := 0.0
var sword_hit_thresholds: Array[float] = []
var sword_hit_index := 0
var heavy_combo_lunge_started := false
var heavy_combo_lunge_remaining := 0.0
var sword_block_active := false
var sword_block_pose_held := false
var sword_block_releasing := false
var jump_start_active := false
var jump_start_time_remaining := 0.0
var roll_move_time_remaining := 0.0
var roll_world_direction := Vector3.ZERO
var roll_start_yaw := 0.0
var combo_step := -1
var combo_input_buffered := false
var attack_hit_applied := false
var interacting_chest: Node3D
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
			if attack_name == &"SwordBlock":
				var block_idle := _make_static_pose_animation(clip, SWORD_BLOCK_HOLD_TIME)
				if block_idle != null:
					upper_library.add_animation(SWORD_BLOCK_IDLE_ANIMATION, block_idle)
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


func _make_static_pose_animation(source: Animation, sample_time: float) -> Animation:
	var pose := source.duplicate(true) as Animation
	if pose == null:
		return null
	pose.resource_name = "block_idle"
	pose.length = SWORD_BLOCK_HOLD_TIME
	pose.loop_mode = Animation.LOOP_LINEAR
	for track_index in range(pose.get_track_count()):
		var track_type := pose.track_get_type(track_index)
		var sampled_value: Variant
		match track_type:
			Animation.TYPE_POSITION_3D:
				sampled_value = source.position_track_interpolate(track_index, sample_time)
			Animation.TYPE_ROTATION_3D:
				sampled_value = source.rotation_track_interpolate(track_index, sample_time)
			Animation.TYPE_SCALE_3D:
				sampled_value = source.scale_track_interpolate(track_index, sample_time)
			Animation.TYPE_VALUE:
				sampled_value = source.value_track_interpolate(track_index, sample_time)
			_:
				continue
		for key_index in range(pose.track_get_key_count(track_index) - 1, -1, -1):
			pose.track_remove_key(track_index, key_index)
		pose.track_set_interpolation_type(track_index, Animation.INTERPOLATION_LINEAR)
		pose.track_insert_key(track_index, 0.0, sampled_value)
		pose.track_insert_key(track_index, SWORD_BLOCK_HOLD_TIME, sampled_value)
	return pose

func _input(event: InputEvent) -> void:
	if get_tree().paused or is_dead:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_event.pressed:
				_start_sword_block()
			else:
				_release_sword_block()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.physical_keycode == KEY_E or key.keycode == KEY_E):
			if has_ability_equipped(&"glider"):
				_try_start_glide()
		elif key.pressed and not key.echo and (key.physical_keycode == KEY_F or key.keycode == KEY_F):
			if has_ability_equipped(&"sword"):
				_toggle_sword_mode()

func _toggle_sword_mode() -> void:
	if not has_ability_equipped(&"sword") or is_dead or reaction_active:
		return
	_cancel_sword_attack()
	_cancel_sword_block()
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
	if _sword_block_is_active() or is_dead or attack_active or reaction_active or not is_on_floor():
		return
	if sword_attack_active:
		_queue_sword_attack_from_input()
		return
	if Input.is_key_pressed(KEY_SHIFT) and _owns_item(&"sword_heavy_combo"):
		_play_sword_attack(&"SwordHeavyCombo")
	else:
		var regular_attack: StringName = &"SwordRegularB" if next_sword_regular_is_b else &"SwordRegularA"
		_play_sword_attack(regular_attack)


func _queue_sword_attack_from_input() -> void:
	var active_player := animation if current_sword_attack == &"SwordHeavyCombo" else upper_body_animation
	if not is_instance_valid(active_player) or not active_player.is_playing():
		return
	var clip_length := maxf(active_player.current_animation_length, 0.001)
	var progress := active_player.current_animation_position / clip_length
	var chain_start := maxf(0.45, 1.0 - minf(SWORD_BUFFER_MAX_WINDOW / clip_length, 0.55))
	if progress < chain_start or progress > 0.98:
		return
	if Input.is_key_pressed(KEY_SHIFT) and _owns_item(&"sword_heavy_combo"):
		queued_sword_attack = &"SwordHeavyCombo"
	elif current_sword_attack in [&"SwordRegularA", &"SwordRegularB"] and _owns_item(&"sword_regular_combo"):
		queued_sword_attack = &"SwordRegularCombo"
	else:
		queued_sword_attack = &"SwordRegularB" if next_sword_regular_is_b else &"SwordRegularA"
	sword_attack_buffer_remaining = minf(clip_length * (1.0 - progress) + SWORD_BUFFER_EXPIRY_PAD, SWORD_BUFFER_MAX_WINDOW + SWORD_BUFFER_EXPIRY_PAD)


func _update_sword_attack_buffer(delta: float) -> void:
	if queued_sword_attack == &"":
		return
	sword_attack_buffer_remaining = maxf(sword_attack_buffer_remaining - delta, 0.0)
	if sword_attack_buffer_remaining <= 0.0:
		queued_sword_attack = &""


func _play_sword_attack(animation_name: StringName) -> void:
	var is_heavy_combo := animation_name == &"SwordHeavyCombo"
	if is_heavy_combo:
		var heavy_clip := _resolve_animation_name(UAL_SWORD_HEAVY_COMBO)
		if heavy_clip == &"":
			push_warning("Heavy sword combo animation is missing from the character animation player.")
			return
		upper_body_animation.stop(true)
		animation.speed_scale = 1.0
		animation.play(heavy_clip, 0.05)
		heavy_combo_lunge_started = false
		heavy_combo_lunge_remaining = 0.0
		movement_velocity = Vector3.ZERO
	else:
		if not upper_body_animation.has_animation(animation_name):
			push_warning("Sword animation is missing: %s" % animation_name)
			return
		upper_body_animation.play(animation_name, 0.05)
	sword_attack_active = true
	current_sword_attack = animation_name
	queued_sword_attack = &""
	sword_attack_buffer_remaining = 0.0
	sword_hit_index = 0
	match animation_name:
		&"SwordRegularA":
			next_sword_regular_is_b = true
			sword_hit_thresholds = [0.52]
		&"SwordRegularB":
			next_sword_regular_is_b = false
			sword_hit_thresholds = [0.50]
		&"SwordRegularCombo":
			sword_hit_thresholds = [0.24, 0.52, 0.80]
		&"SwordHeavyCombo":
			sword_hit_thresholds = [0.22, 0.48, 0.73, 0.90]
		_:
			sword_hit_thresholds = [0.5]


func _owns_item(item_id: StringName) -> bool:
	return int(inventory_items.get(item_id, 0)) > 0


func _cancel_sword_attack() -> void:
	var attack_clips: Array[StringName] = [&"SwordAttack", &"SwordRegularA", &"SwordRegularB", &"SwordRegularCombo", &"SwordHeavyCombo"]
	var upper_attack_playing := is_instance_valid(upper_body_animation) and upper_body_animation.current_animation in attack_clips
	var heavy_clip := _resolve_animation_name(UAL_SWORD_HEAVY_COMBO)
	var full_body_attack_playing := is_instance_valid(animation) and heavy_clip != &"" and animation.current_animation == heavy_clip
	if not sword_attack_active and current_sword_attack == &"" and not upper_attack_playing and not full_body_attack_playing:
		return
	var heavy_attack := current_sword_attack == &"SwordHeavyCombo" or full_body_attack_playing
	sword_attack_active = false
	current_sword_attack = &""
	queued_sword_attack = &""
	sword_attack_buffer_remaining = 0.0
	sword_hit_thresholds.clear()
	sword_hit_index = 0
	heavy_combo_lunge_started = false
	heavy_combo_lunge_remaining = 0.0
	if heavy_attack and is_instance_valid(animation):
		animation.stop(true)
	if (not heavy_attack or upper_attack_playing) and is_instance_valid(upper_body_animation):
		upper_body_animation.stop(true)
	if sword_mode_active and not is_dead and is_instance_valid(upper_body_animation) and upper_body_animation.has_animation(&"SwordIdle"):
		upper_body_animation.play(&"SwordIdle", 0.1)


func _process_sword_hits() -> void:
	if not sword_attack_active or sword_hit_index >= sword_hit_thresholds.size():
		return
	var active_player := animation if current_sword_attack == &"SwordHeavyCombo" else upper_body_animation
	if not is_instance_valid(active_player) or not active_player.is_playing():
		return
	var clip_length := maxf(active_player.current_animation_length, 0.001)
	var progress := active_player.current_animation_position / clip_length
	while sword_hit_index < sword_hit_thresholds.size() and progress >= sword_hit_thresholds[sword_hit_index]:
		_apply_sword_hit()
		sword_hit_index += 1


func _apply_sword_hit() -> void:
	var damage := SWORD_REGULAR_DAMAGE
	if current_sword_attack == &"SwordRegularCombo":
		damage = SWORD_REGULAR_COMBO_DAMAGE
	elif current_sword_attack == &"SwordHeavyCombo":
		damage = SWORD_HEAVY_COMBO_DAMAGE
	var forward := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	var origin := global_position + Vector3.UP * 0.75
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or not enemy.has_method("take_damage"):
			continue
		var offset: Vector3 = enemy.global_position - origin
		var horizontal := Vector3(offset.x, 0.0, offset.z)
		var distance := horizontal.length()
		if distance > SWORD_HIT_REACH or absf(offset.y) > 1.6:
			continue
		if distance > 0.01 and forward.dot(horizontal / distance) < 0.05:
			continue
		enemy.take_damage(damage)


func _is_sword_guarding_source(source: Node3D) -> bool:
	if not sword_mode_active or not (sword_block_active or sword_block_pose_held) or not is_instance_valid(source):
		return false
	var to_attacker := source.global_position - global_position
	to_attacker.y = 0.0
	if to_attacker.length_squared() < 0.0001:
		return true
	var forward := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	return forward.dot(to_attacker.normalized()) >= SWORD_BLOCK_ARC_DOT


func _apply_heavy_combo_lunge(delta: float) -> void:
	if current_sword_attack != &"SwordHeavyCombo" or delta <= 0.0:
		return
	var heavy_clip := _resolve_animation_name(UAL_SWORD_HEAVY_COMBO)
	if heavy_clip == &"" or animation.current_animation != heavy_clip or not animation.is_playing():
		return
	var clip_length := animation.current_animation_length
	var lunge_start := maxf(clip_length - HEAVY_COMBO_LUNGE_DURATION, 0.0)
	if not heavy_combo_lunge_started and animation.current_animation_position >= lunge_start:
		heavy_combo_lunge_started = true
		heavy_combo_lunge_remaining = minf(HEAVY_COMBO_LUNGE_DURATION, clip_length - animation.current_animation_position)
	if not heavy_combo_lunge_started or heavy_combo_lunge_remaining <= 0.0:
		return
	var active_step := minf(delta, heavy_combo_lunge_remaining)
	var speed := HEAVY_COMBO_LUNGE_DISTANCE / HEAVY_COMBO_LUNGE_DURATION
	var forward := Vector3(sin(rotation.y), 0.0, cos(rotation.y))
	var applied_velocity := speed * active_step / delta
	velocity.x = forward.x * applied_velocity
	velocity.z = forward.z * applied_velocity
	heavy_combo_lunge_remaining = maxf(heavy_combo_lunge_remaining - active_step, 0.0)


func _start_sword_block() -> void:
	if not sword_mode_active or not is_on_floor() or is_dead or attack_active or sword_attack_active or reaction_active or is_rolling or is_gliding:
		return
	if sword_block_releasing and upper_body_animation.current_animation == SWORD_BLOCK_ANIMATION:
		# Reverse direction immediately from the current pose if RMB is pressed
		# again before the release animation has finished.
		var resume_at := upper_body_animation.current_animation_position
		sword_block_active = true
		sword_block_pose_held = false
		sword_block_releasing = false
		upper_body_animation.play(SWORD_BLOCK_ANIMATION, 0.0, 1.0)
		upper_body_animation.seek(resume_at, true)
		return
	if _sword_block_is_active():
		return
	if not upper_body_animation.has_animation(SWORD_BLOCK_ANIMATION):
		push_warning("Sword block animation is missing from the upper-body animation library.")
		return
	if not upper_body_animation.has_animation(SWORD_BLOCK_IDLE_ANIMATION):
		push_warning("Static block_idle pose could not be created from Sword_Block.")
		return
	sword_block_active = true
	sword_block_pose_held = false
	sword_block_releasing = false
	upper_body_animation.play(SWORD_BLOCK_ANIMATION, 0.06)


func _release_sword_block() -> void:
	if not _sword_block_is_active():
		return
	var reverse_from := SWORD_BLOCK_HOLD_TIME
	if not sword_block_pose_held and upper_body_animation.current_animation == SWORD_BLOCK_ANIMATION:
		reverse_from = minf(upper_body_animation.current_animation_position, SWORD_BLOCK_HOLD_TIME)
	sword_block_active = false
	sword_block_pose_held = false
	sword_block_releasing = true
	upper_body_animation.play(SWORD_BLOCK_ANIMATION, 0.04, -1.0)
	upper_body_animation.seek(reverse_from, true)


func _update_sword_block(_delta: float) -> void:
	if not _sword_block_is_active() or not is_instance_valid(upper_body_animation):
		return
	if sword_block_active and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_release_sword_block()
	if sword_block_active and not sword_block_pose_held and upper_body_animation.current_animation == SWORD_BLOCK_ANIMATION:
		if upper_body_animation.current_animation_position >= SWORD_BLOCK_HOLD_TIME:
			if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
				upper_body_animation.seek(SWORD_BLOCK_HOLD_TIME, true)
				sword_block_pose_held = true
				sword_block_active = false
				upper_body_animation.play(SWORD_BLOCK_IDLE_ANIMATION, 0.0)
			else:
				_release_sword_block()


func _finish_sword_block() -> void:
	sword_block_active = false
	sword_block_pose_held = false
	sword_block_releasing = false
	if sword_mode_active and not is_dead and upper_body_animation.has_animation(&"SwordIdle"):
		upper_body_animation.play(&"SwordIdle", 0.12)


func _sword_block_is_active() -> bool:
	return sword_block_active or sword_block_pose_held or sword_block_releasing


func _cancel_sword_block() -> void:
	sword_block_active = false
	sword_block_pose_held = false
	sword_block_releasing = false
	if is_instance_valid(upper_body_animation) and upper_body_animation.current_animation in [SWORD_BLOCK_ANIMATION, SWORD_BLOCK_IDLE_ANIMATION]:
		upper_body_animation.stop(true)
		if sword_mode_active and not is_dead and upper_body_animation.has_animation(&"SwordIdle"):
			upper_body_animation.play(&"SwordIdle", 0.1)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if is_rolling:
		roll_move_time_remaining = maxf(roll_move_time_remaining - delta, 0.0)
		if roll_move_time_remaining <= 0.0:
			is_rolling = false
	var was_on_floor := is_on_floor()
	_update_sword_block(delta)
	_update_sword_attack_buffer(delta)
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
	_apply_heavy_combo_lunge(delta)
	move_and_slide()
	if is_gliding and is_on_floor():
		_set_gliding(false)
	process_punch_hit()
	_process_sword_hits()
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
		jump_double = has_ability_equipped(&"double_jump")
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
	if Input.is_action_just_pressed("attack") and not _sword_block_is_active():
		if sword_mode_active:
			_try_play_sword_attack()
		elif attack_active:
			var length := maxf(upper_body_animation.current_animation_length, 0.001)
			if combo_step < ATTACK_ANIMATIONS.size() - 1 and upper_body_animation.current_animation_position / length >= PUNCH_HIT_TIME:
				combo_input_buffered = true
		elif is_on_floor():
			start_attack(0)
	if Input.is_action_just_pressed("jump") and (jump_single or jump_double):
		_cancel_sword_attack()
		_cancel_sword_block()
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
	if current_sword_attack == &"SwordHeavyCombo" and animation.current_animation == _resolve_animation_name(UAL_SWORD_HEAVY_COMBO) and animation.is_playing():
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
	_cancel_sword_attack()
	_cancel_sword_block()
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
	if animation_name == _resolve_animation_name(CHEST_PICKUP_ANIMATION):
		animation.speed_scale = 1.0
		reaction_active = false
		var chest := interacting_chest
		interacting_chest = null
		if is_instance_valid(chest) and chest.has_method("finish_pickup_animation"):
			chest.call("finish_pickup_animation", self)
		return
	if animation_name == _resolve_animation_name(UAL_JUMP_LAND):
		animation.speed_scale = 1.0
		return
	if animation_name in [&"SwordAttack", &"SwordRegularA", &"SwordRegularB", &"SwordRegularCombo", &"SwordHeavyCombo"] or animation_name == _resolve_animation_name(UAL_SWORD_HEAVY_COMBO):
		sword_attack_active = false
		current_sword_attack = &""
		heavy_combo_lunge_started = false
		heavy_combo_lunge_remaining = 0.0
		if queued_sword_attack != &"" and sword_attack_buffer_remaining > 0.0 and sword_mode_active and not is_dead:
			var queued_attack := queued_sword_attack
			queued_sword_attack = &""
			sword_attack_buffer_remaining = 0.0
			_play_sword_attack(queued_attack)
		elif sword_mode_active and not is_dead:
			queued_sword_attack = &""
			sword_attack_buffer_remaining = 0.0
			upper_body_animation.play(&"SwordIdle", 0.12)
		return
	if animation_name == SWORD_BLOCK_ANIMATION:
		_finish_sword_block()
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

func take_damage(amount: int, source: Node3D = null) -> void:
	if is_dead or amount <= 0:
		return
	_cancel_chest_pickup()
	var guarded := _is_sword_guarding_source(source)
	var applied_damage := maxi(roundi(float(amount) * SWORD_BLOCK_DAMAGE_MULTIPLIER), 1) if guarded else amount
	health = maxi(health - applied_damage, 0)
	health_changed.emit(health, MAX_HEALTH)
	if guarded and health > 0:
		return
	_cancel_sword_block()
	_cancel_sword_attack()
	jump_start_active = false
	jump_start_time_remaining = 0.0
	_cancel_upper_body_attack()
	_set_gliding(false)
	is_rolling = false
	roll_move_time_remaining = 0.0
	animation.speed_scale = 1.0
	if health == 0:
		is_dead = true
		sword_attack_active = false
		queued_sword_attack = &""
		current_sword_attack = &""
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
		queued_sword_attack = &""
		current_sword_attack = &""
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
		_cancel_sword_attack()
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
	if not has_ability_equipped(&"glider") or is_gliding or is_on_floor() or is_dead or attack_active or sword_attack_active or reaction_active or is_rolling or _sword_block_is_active():
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

func begin_chest_pickup(chest: Node3D) -> bool:
	if not is_instance_valid(chest) or not is_on_floor() or is_dead or reaction_active or attack_active or sword_attack_active or is_rolling or is_gliding:
		return false
	var pickup_animation := _resolve_animation_name(CHEST_PICKUP_ANIMATION)
	if pickup_animation == &"":
		push_warning("Chest pickup animation not found: %s" % CHEST_PICKUP_ANIMATION)
		return false
	_cancel_upper_body_attack()
	interacting_chest = chest
	reaction_active = true
	jump_start_active = false
	jump_start_time_remaining = 0.0
	movement_velocity = Vector3.ZERO
	velocity.x = 0.0
	velocity.z = 0.0
	animation.speed_scale = 1.0
	animation.play(pickup_animation, 0.12, CHEST_PICKUP_ANIMATION_SPEED)
	return true

func _cancel_chest_pickup() -> void:
	if is_instance_valid(interacting_chest) and interacting_chest.has_method("cancel_pickup_animation"):
		interacting_chest.call("cancel_pickup_animation", self)
	interacting_chest = null

func has_ability_equipped(ability_id: StringName) -> bool:
	for equipped_id in equipped_ability_slots:
		if _normalize_ability_id(equipped_id) == _normalize_ability_id(ability_id):
			return ability_id != &""
	return false

func set_ability_slot(slot_index: int, item_id: StringName) -> bool:
	if slot_index < 0 or slot_index >= equipped_ability_slots.size():
		return false
	if item_id != &"" and (not _is_ability_item(item_id) or int(inventory_items.get(item_id, 0)) <= 0):
		return false
	if item_id != &"":
		var normalized_id := _normalize_ability_id(item_id)
		for index in range(equipped_ability_slots.size()):
			if index != slot_index and _normalize_ability_id(equipped_ability_slots[index]) == normalized_id:
				equipped_ability_slots[index] = &""
	equipped_ability_slots[slot_index] = item_id
	jump_double = has_ability_equipped(&"double_jump")
	if sword_mode_active and not has_ability_equipped(&"sword"):
		_cancel_sword_attack()
		_cancel_sword_block()
		sword_mode_active = false
		if sword != null:
			sword.visible = false
		if is_instance_valid(upper_body_animation):
			upper_body_animation.stop(true)
	ability_slots_changed.emit(equipped_ability_slots.duplicate())
	return true

func _is_ability_item(item_id: StringName) -> bool:
	return ITEM_CATALOG.is_ability(item_id)

func _normalize_ability_id(item_id: StringName) -> StringName:
	return ITEM_CATALOG.ability_for(item_id) if ITEM_CATALOG.is_ability(item_id) else item_id

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
		jump_double = has_ability_equipped(&"double_jump")
	else:
		jump_double = false
