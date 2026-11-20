extends CharacterBody3D

@export_category("Enemy Stats")
@export_range(1, 10000, 1) var maximum_health: int = 60
@export_range(1, 1000, 1) var attack_strength: int = 10
@export_category("Enemy Behavior")
@export_range(0.5, 50.0, 0.1) var detection_range: float = 9.0
@export_range(0.5, 10.0, 0.1) var attack_range: float = 1.7
@export_range(0.1, 20.0, 0.1) var move_speed: float = 3.2
@export_range(0.1, 10.0, 0.1) var attack_cooldown: float = 1.2
@export_category("Model")
@export var model_scale: float = 1.0

var health: int
var _target: CharacterBody3D
var _animation_player: AnimationPlayer
var _animation_names: Dictionary = {}
var _state: StringName = &""
var _cooldown: float = 0.0
var _attack_active: bool = false
var _attack_hit_applied: bool = false
var _dead: bool = false
var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))

func _ready() -> void:
	add_to_group("enemy")
	health = maximum_health
	$Model.scale = Vector3.ONE * model_scale
	_animation_player = _find_animation_player(self)
	if _animation_player == null:
		push_warning("Enemy prefab has no AnimationPlayer: " + name)
		return
	_animation_names[&"idle"] = _find_animation(["idle"])
	_animation_names[&"run"] = _find_animation(["run", "walk"])
	_animation_names[&"attack"] = _find_animation(["attack"])
	_animation_names[&"hit"] = _find_animation(["hit", "hurt", "recieve", "receive"])
	_animation_names[&"die"] = _find_animation(["death", "die"])
	for key in _animation_names:
		var clip_name: StringName = _animation_names[key]
		if clip_name != &"":
			var clip := _animation_player.get_animation(clip_name)
			if clip:
				clip.loop_mode = Animation.LOOP_LINEAR if key in [&"idle", &"run"] else Animation.LOOP_NONE
	_animation_player.animation_finished.connect(_on_animation_finished)
	_play_state(&"idle")

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as CharacterBody3D
	var desired := Vector3.ZERO
	var distance := INF
	if is_instance_valid(_target):
		var offset := _target.global_position - global_position
		offset.y = 0.0
		distance = offset.length()
		if distance <= detection_range and distance > 0.01:
			var direction := offset / distance
			rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), delta * 6.0)
			if distance <= attack_range:
				if _cooldown <= 0.0 and not _attack_active:
					_start_attack()
			elif not _attack_active:
				desired = direction * move_speed
		else:
			_target = null
	velocity.x = move_toward(velocity.x, desired.x, move_speed * 8.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z, move_speed * 8.0 * delta)
	if is_on_floor():
		if velocity.y < 0.0:
			velocity.y = 0.0
	else:
		velocity.y -= _gravity * delta
	move_and_slide()
	if _attack_active:
		_apply_attack_hit()
	elif _animation_names.get(&"hit", &"") != _state:
		_play_state(&"run" if Vector2(velocity.x, velocity.z).length() > 0.15 else &"idle")

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null

func _find_animation(terms: Array[String]) -> StringName:
	if _animation_player == null:
		return &""
	for anim_name in _animation_player.get_animation_list():
		var lower := String(anim_name).to_lower()
		for term in terms:
			if lower.contains(term):
				return anim_name
	return &""

func _play_state(state: StringName) -> void:
	if _animation_player == null or _state == state:
		return
	var clip_name: StringName = _animation_names.get(state, &"")
	if clip_name == &"":
		return
	_state = state
	_animation_player.play(clip_name, 0.12)

func _start_attack() -> void:
	var clip_name: StringName = _animation_names.get(&"attack", &"")
	if clip_name == &"":
		return
	_attack_active = true
	_attack_hit_applied = false
	_cooldown = attack_cooldown
	_state = &"attack"
	_animation_player.play(clip_name, 0.08)

func _apply_attack_hit() -> void:
	if _attack_hit_applied or _animation_player == null:
		return
	if _animation_player.current_animation_position < _animation_player.current_animation_length * 0.45:
		return
	_attack_hit_applied = true
	if is_instance_valid(_target) and global_position.distance_to(_target.global_position) <= attack_range + 0.35 and _target.has_method("take_damage"):
		_target.take_damage(attack_strength, self)

func _on_animation_finished(anim_name: StringName) -> void:
	if _dead and anim_name == _animation_names.get(&"die", &""):
		queue_free()
	elif _attack_active and anim_name == _animation_names.get(&"attack", &""):
		_attack_active = false
		_state = &""
	elif anim_name == _animation_names.get(&"hit", &""):
		_state = &""

func take_damage(amount: int) -> void:
	if _dead or amount <= 0:
		return
	health = maxi(health - amount, 0)
	_attack_active = false
	if health == 0:
		_dead = true
		velocity = Vector3.ZERO
		collision_layer = 0
		collision_mask = 0
		var death_clip: StringName = _animation_names.get(&"die", &"")
		if death_clip != &"":
			_state = &"die"
			_animation_player.play(death_clip, 0.08)
		else:
			queue_free()
	else:
		var hit_clip: StringName = _animation_names.get(&"hit", &"")
		if hit_clip != &"":
			_state = &"hit"
			_animation_player.play(hit_clip, 0.08)


