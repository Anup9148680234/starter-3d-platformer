extends Control

signal closed

@onready var save_list: VBoxContainer = %SaveList
@onready var status_label: Label = %Status
@onready var delete_confirmation: ConfirmationDialog = $DeleteConfirmation

var pending_delete_id := ""


func _ready() -> void:
	refresh_saves()


func refresh_saves() -> void:
	for child in save_list.get_children():
		child.queue_free()
	var saves := GameSave.list_saves()
	if saves.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No saved games yet. Start a new game and reach a checkpoint to create a save."
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		save_list.add_child(empty_label)
		return
	for save_data in saves:
		_add_save_row(save_data)


func close_menu() -> void:
	closed.emit()
	hide()


func _add_save_row(save_data: Dictionary) -> void:
	var slot_id := str(save_data.get("slot_id", ""))
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := Label.new()
	var checkpoint_name := str(save_data.get("checkpoint_id", ""))
	var progress := "New game" if checkpoint_name.is_empty() else checkpoint_name.replace("_", " ")
	title.text = "%s · %s" % [save_data.get("label", slot_id), progress]
	title.add_theme_font_size_override("font_size", 23)
	info.add_child(title)
	var detail := Label.new()
	var player_data: Dictionary = save_data.get("player", {})
	var world_label := "Tutorial" if str(save_data.get("scene_path", "")).ends_with("main.tscn") else "World 1"
	detail.text = "%s  |  %d coins  |  Saved %s" % [world_label, int(player_data.get("coins", 0)), str(save_data.get("updated_at", ""))]
	info.add_child(detail)
	row.add_child(info)
	var load_button := Button.new()
	load_button.text = "Load"
	load_button.custom_minimum_size.x = 100.0
	load_button.pressed.connect(_load_slot.bind(slot_id))
	row.add_child(load_button)
	var delete_button := Button.new()
	delete_button.text = "Delete"
	delete_button.custom_minimum_size.x = 100.0
	delete_button.pressed.connect(_ask_delete.bind(slot_id))
	row.add_child(delete_button)
	save_list.add_child(row)


func _load_slot(slot_id: String) -> void:
	if not GameSave.load_slot(slot_id):
		status_label.text = "Could not load that save."
		return
	status_label.text = "Loading %s…" % GameSave.active_slot_label
	get_tree().call_deferred("change_scene_to_file", GameSave.current_scene_path)
	close_menu()


func _ask_delete(slot_id: String) -> void:
	pending_delete_id = slot_id
	delete_confirmation.popup_centered()


func _confirm_delete() -> void:
	if not pending_delete_id.is_empty() and GameSave.delete_slot(pending_delete_id):
		status_label.text = "Save deleted."
	else:
		status_label.text = "Could not delete that save."
	pending_delete_id = ""
	refresh_saves()
