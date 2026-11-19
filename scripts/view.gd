extends Node3D

@export_group("Target")
@export var target: Node3D
@export var target_height := 1.5
@export_range(0.1, 20.0, 0.1) var follow_speed := 5.0

@export_group("Mouse Camera")
@export_range(0.0005, 0.02, 0.0005) var mouse_sensitivity := 0.001
@export_range(5.0, 65.0, 1.0) var pitch_degrees := 15.0

@export_group("Zoom")
@export_range(2.0, 20.0, 0.5) var zoom_minimum := 3.0
@export_range(2.0, 20.0, 0.5) var zoom_maximum := 10.0
@export_range(0.1, 10.0, 0.1) var zoom_speed := 5.0

@onready var camera: Camera3D = $Camera
var zoom := 8.0
var _yaw := 0.0

func _ready() -> void:
	zoom = clampf(zoom, minf(zoom_minimum, zoom_maximum), maxf(zoom_minimum, zoom_maximum))
	if target != null:
		_yaw = target.global_rotation.y
		global_position = target.global_position + Vector3.UP * target_height
	rotation = Vector3(0.0, _yaw, 0.0)
	camera.top_level = true
	_update_orbit_camera(1.0, true)
	camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_yaw = wrapf(_yaw - motion.relative.x * mouse_sensitivity, -PI, PI)
		pitch_degrees = clampf(pitch_degrees - motion.relative.y * rad_to_deg(mouse_sensitivity), 5.0, 65.0)
		rotation.y = _yaw
	elif event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var follow_point := target.global_position + Vector3.UP * target_height
	global_position = global_position.lerp(follow_point, 1.0 - exp(-follow_speed * delta))
	rotation.y = _yaw
	var zoom_input := Input.get_axis("zoom_in", "zoom_out")
	zoom = clampf(zoom + zoom_input * zoom_speed * delta, minf(zoom_minimum, zoom_maximum), maxf(zoom_minimum, zoom_maximum))
	_update_orbit_camera(delta)

func _update_orbit_camera(delta: float, snap: bool = false) -> void:
	var pivot := global_position
	var elevation := deg_to_rad(pitch_degrees)
	var horizontal_radius := cos(elevation) * zoom
	var desired_position := pivot + Vector3(sin(_yaw) * horizontal_radius, sin(elevation) * zoom, cos(_yaw) * horizontal_radius)
	if is_instance_valid(target) and get_world_3d() != null:
		var query := PhysicsRayQueryParameters3D.create(pivot, desired_position)
		query.exclude = [target.get_rid()]
		var obstruction := get_world_3d().direct_space_state.intersect_ray(query)
		if not obstruction.is_empty():
			desired_position = obstruction["position"] + obstruction["normal"] * 0.2
	if snap:
		camera.global_position = desired_position
	else:
		camera.global_position = camera.global_position.lerp(desired_position, 1.0 - exp(-8.0 * delta))
	if camera.global_position.distance_squared_to(pivot) > 0.001:
		camera.look_at(pivot, Vector3.UP)
