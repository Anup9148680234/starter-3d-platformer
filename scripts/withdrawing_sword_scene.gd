extends Node3D

const SOURCE_ANIMATION_SCENE: PackedScene = preload("res://newAnim/Withdrawing Sword.fbx")
const RETARGET_LIBRARY_NAME: StringName = &"Sword"
const RETARGET_ANIMATION_NAME: StringName = &"WithdrawingSword"

func _ready() -> void:
	var target_animation_player := _find_animation_player($Character)
	if target_animation_player == null:
		push_error("Character scene has no AnimationPlayer for the sword animation.")
		return
	var source_root := SOURCE_ANIMATION_SCENE.instantiate()
	var source_animation_player := _find_animation_player(source_root)
	if source_animation_player == null:
		source_root.free()
		push_error("Withdrawing Sword FBX has no AnimationPlayer.")
		return
	var source_animation_name := _find_sword_animation(source_animation_player)
	if source_animation_name == &"":
		source_root.free()
		push_error("Withdrawing Sword animation was not found in the FBX.")
		return
	var retargeted_animation := source_animation_player.get_animation(source_animation_name).duplicate(true) as Animation
	retargeted_animation.loop_mode = Animation.LOOP_NONE
	var library := AnimationLibrary.new()
	library.add_animation(RETARGET_ANIMATION_NAME, retargeted_animation)
	if target_animation_player.has_animation_library(RETARGET_LIBRARY_NAME):
		target_animation_player.remove_animation_library(RETARGET_LIBRARY_NAME)
	target_animation_player.root_node = source_animation_player.root_node
	target_animation_player.add_animation_library(RETARGET_LIBRARY_NAME, library)
	target_animation_player.stop()
	source_root.free()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key := event as InputEventKey
		if key.pressed and not key.echo and (key.physical_keycode == KEY_F or key.keycode == KEY_F):
			var animation_player := _find_animation_player($Character)
			if animation_player != null:
				animation_player.play(String(RETARGET_LIBRARY_NAME) + "/" + String(RETARGET_ANIMATION_NAME), 0.1, 1.0, false)
				get_viewport().set_input_as_handled()

func _find_sword_animation(animation_player: AnimationPlayer) -> StringName:
	for animation_name in animation_player.get_animation_list():
		var lowered_name := String(animation_name).to_lower()
		if lowered_name.contains("withdrawing") or lowered_name.contains("mixamo") or animation_player.get_animation(animation_name).resource_name.to_lower().contains("withdrawing"):
			return animation_name
	var available := animation_player.get_animation_list()
	return available[0] if not available.is_empty() else &""

func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node as AnimationPlayer
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found != null:
			return found
	return null
