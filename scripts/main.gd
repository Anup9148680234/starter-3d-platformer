extends Node3D

const PLAYER_MAX_HEALTH := 100
var tutorial_transition_active := false

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var hud: Control = get_node_or_null("HUD") as Control

func _ready() -> void:
	GameSave.transition_in_progress = false
	if player == null:
		push_error("Tutorial scene needs a Player child named Player.")
		return
	if hud != null:
		_connect_player_signal(&"coin_collected", Callable(hud, "_on_coin_collected"))
		_connect_player_signal(&"health_changed", Callable(hud, "_on_health_changed"))
		var checkpoint_callback := Callable(hud, "_on_checkpoint_reached")
		if not GameSave.checkpoint_reached.is_connected(checkpoint_callback):
			GameSave.checkpoint_reached.connect(checkpoint_callback)
	GameSave.restore_player(player)
	if hud != null:
		hud.call("_on_coin_collected", int(player.get("coins")))
		hud.call("_on_health_changed", int(player.get("health")), PLAYER_MAX_HEALTH)
		if not GameSave.checkpoint_id.is_empty():
			hud.call("_on_checkpoint_reached", GameSave.checkpoint_id)
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
		var sun := get_node_or_null("Sun") as DirectionalLight3D
		if sun != null:
			sun.light_energy = 0.24
			sun.shadow_opacity = 0.85
		var world_environment := get_node_or_null("Environment") as WorldEnvironment
		if world_environment != null and world_environment.environment != null:
			world_environment.environment.background_energy_multiplier = 0.25

func _connect_player_signal(signal_name: StringName, callback: Callable) -> void:
	if player.has_signal(signal_name) and not player.is_connected(signal_name, callback):
		player.connect(signal_name, callback)

func show_tutorial_complete_screen() -> void:
	if tutorial_transition_active:
		return
	tutorial_transition_active = true
	GameSave.transition_in_progress = true
	var pause_controller := get_node_or_null("PauseMenuController")
	if pause_controller != null:
		pause_controller.set_process_unhandled_input(false)
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.015, 0.025, 0.04, 0.86)
	background.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(background)
	var message := Label.new()
	message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.text = "Tutorial Complete!\nTravelling to World 1..."
	message.add_theme_font_size_override("font_size", 48)
	message.add_theme_color_override("font_color", Color(1.0, 0.91, 0.63))
	message.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	message.add_theme_constant_override("shadow_offset_x", 3)
	message.add_theme_constant_override("shadow_offset_y", 3)
	overlay.add_child(message)
	await get_tree().create_timer(3.0, true).timeout
	get_tree().paused = false
	get_tree().change_scene_to_file(GameSave.WORLD1_SCENE)
