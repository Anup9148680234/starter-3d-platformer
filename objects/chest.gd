extends Node3D

@export var reward_item_id: StringName = &"sword"
@export_range(1, 99, 1) var reward_quantity: int = 1

@onready var closed_model: Node3D = $ClosedModel
@onready var opened_model: Node3D = $OpenedModel

var interaction_prompt: Sprite3D

var _player_in_range := false
var _is_open := false
var _nearby_player: CharacterBody3D


func _ready() -> void:
	opened_model.visible = false
	_create_interaction_prompt()
	interaction_prompt.visible = false
	$InteractionArea.body_entered.connect(_on_body_entered)
	$InteractionArea.body_exited.connect(_on_body_exited)


func _create_interaction_prompt() -> void:
	# Render a small 2D keycap as a texture so it stays crisp and faces the camera.
	var prompt_viewport := SubViewport.new()
	prompt_viewport.name = "PromptViewport"
	prompt_viewport.size = Vector2i(320, 80)
	prompt_viewport.transparent_bg = true
	prompt_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(prompt_viewport)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	prompt_viewport.add_child(root)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	row.position = Vector2(-32, -32)
	row.size = Vector2(264, 64)
	row.add_theme_constant_override("separation", 12)
	root.add_child(row)

	var keycap := PanelContainer.new()
	keycap.custom_minimum_size = Vector2(58, 58)
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color(0.08, 0.09, 0.12, 0.96)
	key_style.border_color = Color(0.94, 0.96, 1.0, 1.0)
	key_style.set_border_width_all(3)
	key_style.set_corner_radius_all(8)
	key_style.set_content_margin_all(4)
	keycap.add_theme_stylebox_override("panel", key_style)
	row.add_child(keycap)

	var key_label := Label.new()
	key_label.text = "E"
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_label.add_theme_font_size_override("font_size", 32)
	key_label.add_theme_color_override("font_color", Color.WHITE)
	keycap.add_child(key_label)

	var action_label := Label.new()
	action_label.text = "OPEN"
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", 24)
	action_label.add_theme_color_override("font_color", Color.WHITE)
	row.add_child(action_label)

	interaction_prompt = Sprite3D.new()
	interaction_prompt.name = "InteractionPrompt"
	interaction_prompt.position = Vector3(0.0, 1.65, 0.0)
	interaction_prompt.texture = prompt_viewport.get_texture()
	interaction_prompt.pixel_size = 0.009
	interaction_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	interaction_prompt.no_depth_test = true
	interaction_prompt.shaded = false
	interaction_prompt.visible = false
	add_child(interaction_prompt)


func _unhandled_input(event: InputEvent) -> void:
	if _is_open or not _player_in_range or get_tree().paused:
		return
	if not is_instance_valid(_nearby_player) or not _nearby_player.is_on_floor():
		return
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.physical_keycode == KEY_E or key.keycode == KEY_E):
			open_chest()
			get_viewport().set_input_as_handled()


func open_chest() -> void:
	if _is_open:
		return
	_is_open = true
	closed_model.visible = false
	opened_model.visible = true
	interaction_prompt.visible = false
	if is_instance_valid(_nearby_player) and reward_item_id != &"" and reward_quantity > 0:
		_nearby_player.call("add_inventory_item", reward_item_id, reward_quantity)
		if has_node("/root/GameSave"):
			GameSave.sync_player_inventory(
				int(_nearby_player.get("coins")),
				_nearby_player.get("inventory_items")
			)


func _on_body_entered(body: Node3D) -> void:
	var player := body as CharacterBody3D
	if player != null and player.is_in_group("player") and not _is_open:
		_nearby_player = player
		_player_in_range = true
		interaction_prompt.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body == _nearby_player:
		_nearby_player = null
		_player_in_range = false
		interaction_prompt.visible = false
