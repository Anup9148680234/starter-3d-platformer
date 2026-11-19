extends Node

signal checkpoint_reached(checkpoint_id: String)

const SLOT_DIRECTORY := "user://save_slots"
const TUTORIAL_SCENE := "res://scenes/main.tscn"
const WORLD1_SCENE := "res://scenes/World1.tscn"
const MAX_PLAYER_HEALTH := 100
const WORLD1_SPAWN := Vector3(136, 5, -40)

var active_slot_id := ""
var active_slot_label := ""
var current_scene_path := TUTORIAL_SCENE
var transition_in_progress := false
var death_screen_active := false
var checkpoint_id := ""
var checkpoint_position := Vector3(0.0, 0.49277484, 0.0)
var checkpoint_rotation_y := 1.56496
var player_snapshot: Dictionary = {}
var global_coins := 0
var global_inventory_items: Dictionary = {}
var collected_coins_by_scene: Dictionary = {}
var pending_coins_by_scene: Dictionary = {}


func start_new_game() -> void:
	transition_in_progress = false
	death_screen_active = false
	active_slot_id = _find_next_slot_id()
	active_slot_label = "Save %02d" % int(active_slot_id.trim_prefix("slot_"))
	current_scene_path = TUTORIAL_SCENE
	checkpoint_id = ""
	checkpoint_position = Vector3(0.0, 0.49277484, 0.0)
	checkpoint_rotation_y = 1.56496
	global_coins = 0
	global_inventory_items.clear()
	player_snapshot = {
		"coins": 0,
		"health": MAX_PLAYER_HEALTH,
		"skin_index": 1,
		"inventory_items": {},
	}
	collected_coins_by_scene.clear()
	pending_coins_by_scene.clear()


func list_saves() -> Array[Dictionary]:
	var saves: Array[Dictionary] = []
	var directory := DirAccess.open(SLOT_DIRECTORY)
	if directory == null:
		return saves
	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(".json"):
			var save_data := _read_slot(file_name.trim_suffix(".json"))
			if not save_data.is_empty():
				saves.append(save_data)
		file_name = directory.get_next()
	directory.list_dir_end()
	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("updated_at", "")) > str(b.get("updated_at", "")))
	return saves


func load_slot(slot_id: String) -> bool:
	var save_data := _read_slot(slot_id)
	if save_data.is_empty():
		return false
	transition_in_progress = false
	death_screen_active = false
	active_slot_id = slot_id
	active_slot_label = str(save_data.get("label", slot_id))
	current_scene_path = str(save_data.get("scene_path", TUTORIAL_SCENE))
	if not ResourceLoader.exists(current_scene_path):
		current_scene_path = TUTORIAL_SCENE
	checkpoint_id = str(save_data.get("checkpoint_id", ""))
	checkpoint_position = _read_vector3(save_data.get("spawn_position", [0.0, 0.49277484, 0.0]))
	checkpoint_rotation_y = float(save_data.get("spawn_rotation_y", 1.56496))
	# Refresh old save-slot copies of the tutorial transition spawn so changes to WORLD1_SPAWN apply on load.
	if checkpoint_id == "tutorial_complete":
		checkpoint_position = WORLD1_SPAWN
	var saved_player: Variant = save_data.get("player", {})
	player_snapshot = saved_player if saved_player is Dictionary else {}
	global_coins = int(player_snapshot.get("coins", 0))
	global_inventory_items = _deserialize_items(player_snapshot.get("inventory_items", {}))
	var collected: Variant = save_data.get("collected_coins_by_scene", {})
	collected_coins_by_scene = collected if collected is Dictionary else {}
	pending_coins_by_scene.clear()
	return true


func delete_slot(slot_id: String) -> bool:
	var path := _slot_path(slot_id)
	if not FileAccess.file_exists(path):
		return false
	var absolute_path := ProjectSettings.globalize_path(path)
	return DirAccess.remove_absolute(absolute_path) == OK


func activate_checkpoint(id: String, spawn_position: Vector3, player_yaw: float, player: CharacterBody3D) -> bool:
	if id.is_empty() or player == null or active_slot_id.is_empty():
		return false
	checkpoint_id = id
	checkpoint_position = spawn_position
	checkpoint_rotation_y = player_yaw
	_commit_pending_coins()
	player_snapshot = _capture_player(player)
	var active_scene := get_tree().current_scene
	current_scene_path = active_scene.scene_file_path if active_scene != null and not active_scene.scene_file_path.is_empty() else TUTORIAL_SCENE
	_save_active_slot()
	checkpoint_reached.emit(checkpoint_id)
	return true


func complete_tutorial(player: CharacterBody3D) -> void:
	if player == null or active_slot_id.is_empty():
		return
	if transition_in_progress:
		return
	transition_in_progress = true
	checkpoint_id = "tutorial_complete"
	current_scene_path = WORLD1_SCENE
	checkpoint_position = WORLD1_SPAWN
	checkpoint_rotation_y = player.rotation.y
	player_snapshot = _capture_player(player)
	_save_active_slot()
	checkpoint_reached.emit(checkpoint_id)
	var current_scene := get_tree().current_scene
	if current_scene != null and current_scene.has_method("show_tutorial_complete_screen"):
		current_scene.call_deferred("show_tutorial_complete_screen")
	else:
		get_tree().call_deferred("change_scene_to_file", WORLD1_SCENE)


func register_coin(scene_path: String, coin_path: String) -> void:
	if scene_path.is_empty() or coin_path.is_empty():
		return
	if not pending_coins_by_scene.has(scene_path):
		pending_coins_by_scene[scene_path] = {}
	var scene_coins: Dictionary = pending_coins_by_scene[scene_path]
	scene_coins[coin_path] = true
	pending_coins_by_scene[scene_path] = scene_coins


func is_coin_saved_as_collected(scene_path: String, coin_path: String) -> bool:
	var scene_coins: Dictionary = collected_coins_by_scene.get(scene_path, {})
	return bool(scene_coins.get(coin_path, false))


func sync_player_inventory(coins: int, items: Dictionary) -> void:
	global_coins = coins
	global_inventory_items = _deserialize_items(items)


func begin_player_death() -> void:
	transition_in_progress = true
	var current_scene := get_tree().current_scene
	if current_scene != null:
		var pause_controller := current_scene.get_node_or_null("PauseMenuController")
		if pause_controller != null:
			pause_controller.set_process_unhandled_input(false)


func show_you_died_screen() -> void:
	if death_screen_active:
		return
	death_screen_active = true
	transition_in_progress = true
	var tree := get_tree()
	var current_scene := tree.current_scene
	if current_scene == null:
		tree.reload_current_scene()
		return
	tree.paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	current_scene.add_child(overlay)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.025, 0.04, 0.86)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(backdrop)
	var message := Label.new()
	message.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.text = "You Died"
	message.add_theme_font_size_override("font_size", 48)
	message.add_theme_color_override("font_color", Color(1.0, 0.91, 0.63))
	message.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	message.add_theme_constant_override("shadow_offset_x", 3)
	message.add_theme_constant_override("shadow_offset_y", 3)
	overlay.add_child(message)
	await tree.create_timer(2.0, true).timeout
	tree.paused = false
	transition_in_progress = false
	death_screen_active = false
	if is_instance_valid(current_scene) and tree.current_scene == current_scene:
		tree.reload_current_scene()


func restore_player(player: CharacterBody3D) -> bool:
	if active_slot_id.is_empty() or player_snapshot.is_empty() or player == null:
		return false
	pending_coins_by_scene.clear()
	player.global_position = checkpoint_position
	player.rotation.y = checkpoint_rotation_y
	player.velocity = Vector3.ZERO
	# Death and scene reloads roll back changes made after the latest checkpoint.
	# The live global values may include pickups collected since that checkpoint.
	global_coins = int(player_snapshot.get("coins", 0))
	global_inventory_items = _deserialize_items(player_snapshot.get("inventory_items", {}))
	player.set("coins", global_coins)
	player.set("health", clampi(int(player_snapshot.get("health", MAX_PLAYER_HEALTH)), 1, MAX_PLAYER_HEALTH))
	player.set("inventory_items", global_inventory_items.duplicate(true))
	player.set("is_dead", false)
	player.set("reaction_active", false)
	player.set("attack_active", false)
	player.set("is_rolling", false)
	player.set("roll_cooldown_timer", 0.0)
	player.set("combo_step", -1)
	player.set("combo_input_buffered", false)
	player.set("jump_single", true)
	player.set("jump_double", true)
	player.set("gravity", 0.0)
	player.call("apply_skin", int(player_snapshot.get("skin_index", player.get("starting_skin"))))
	player.emit_signal("coin_collected", player.get("coins"))
	player.emit_signal("health_changed", player.get("health"), MAX_PLAYER_HEALTH)
	player.emit_signal("inventory_changed", player.get("inventory_items").duplicate(true))
	return true


func get_active_save_summary() -> String:
	return "%s — %s" % [active_slot_label, checkpoint_id.replace("_", " ") if not checkpoint_id.is_empty() else "new game"]


func _find_next_slot_id() -> String:
	var index := 1
	while FileAccess.file_exists(_slot_path("slot_%d" % index)):
		index += 1
	return "slot_%d" % index


func _slot_path(slot_id: String) -> String:
	return "%s/%s.json" % [SLOT_DIRECTORY, slot_id]


func _read_slot(slot_id: String) -> Dictionary:
	if slot_id.is_empty() or not FileAccess.file_exists(_slot_path(slot_id)):
		return {}
	var file := FileAccess.open(_slot_path(slot_id), FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	return parsed if parsed is Dictionary else {}


func _save_active_slot() -> void:
	if active_slot_id.is_empty():
		return
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("save_slots"):
		dir.make_dir("save_slots")
	var now := Time.get_datetime_string_from_system()
	var existing := _read_slot(active_slot_id)
	var save_data := {
		"slot_id": active_slot_id,
		"label": active_slot_label,
		"created_at": str(existing.get("created_at", now)),
		"updated_at": now,
		"scene_path": current_scene_path,
		"checkpoint_id": checkpoint_id,
		"spawn_position": [checkpoint_position.x, checkpoint_position.y, checkpoint_position.z],
		"spawn_rotation_y": checkpoint_rotation_y,
		"player": player_snapshot,
		"collected_coins_by_scene": collected_coins_by_scene,
	}
	var file := FileAccess.open(_slot_path(active_slot_id), FileAccess.WRITE)
	if file == null:
		push_error("Could not write save slot %s: %s" % [active_slot_id, FileAccess.get_open_error()])
		return
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()


func _commit_pending_coins() -> void:
	for scene_path in pending_coins_by_scene:
		if not collected_coins_by_scene.has(scene_path):
			collected_coins_by_scene[scene_path] = {}
		var saved_coins: Dictionary = collected_coins_by_scene[scene_path]
		var new_coins: Dictionary = pending_coins_by_scene[scene_path]
		for coin_path in new_coins:
			saved_coins[coin_path] = true
		collected_coins_by_scene[scene_path] = saved_coins
	pending_coins_by_scene.clear()


func _capture_player(player: Node) -> Dictionary:
	var items: Dictionary = {}
	var inventory: Dictionary = player.get("inventory_items")
	global_coins = int(player.get("coins"))
	global_inventory_items = _deserialize_items(inventory)
	for item_id in inventory:
		items[String(item_id)] = int(inventory[item_id])
	return {
		"coins": int(player.get("coins")),
		"health": int(player.get("health")),
		"skin_index": int(player.get("current_skin_index")),
		"inventory_items": items,
	}


func _deserialize_items(serialized_items: Variant) -> Dictionary:
	var items: Dictionary = {}
	if serialized_items is Dictionary:
		for item_id in serialized_items:
			items[StringName(item_id)] = int(serialized_items[item_id])
	return items


func _read_vector3(value: Variant) -> Vector3:
	if value is Array and value.size() == 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3(0.0, 0.49277484, 0.0)
