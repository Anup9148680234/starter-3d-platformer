extends "res://addons/maaacks_menus_template/base/nodes/menus/main_menu/main_menu.gd"

const SAVE_SLOTS_MENU := preload("res://scenes/save_slots_menu.tscn")


func new_game() -> void:
	GameSave.start_new_game()
	load_game_scene()


func _on_load_game_button_pressed() -> void:
	if sub_menu != null:
		return
	sub_menu = SAVE_SLOTS_MENU.instantiate()
	sub_menu.closed.connect(_close_sub_menu, CONNECT_ONE_SHOT)
	add_child(sub_menu)
	sub_menu_opened.emit()
