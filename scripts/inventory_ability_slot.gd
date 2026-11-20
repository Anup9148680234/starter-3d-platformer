extends PanelContainer

const ITEM_CATALOG = preload("res://scripts/item_catalog.gd")

signal ability_dropped(slot_index: int, item_id: StringName)
signal ability_cleared(slot_index: int)

var slot_index := 0
var item_id: StringName = &""
var _index_label: Label
var _icon: TextureRect
var _name_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(54, 66)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 1)
	add_child(column)
	_index_label = Label.new()
	_index_label.text = str(slot_index + 1)
	_index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_index_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_index_label.add_theme_font_size_override("font_size", 9)
	_index_label.add_theme_color_override("font_color", Color(0.66, 0.72, 0.8, 1.0))
	column.add_child(_index_label)
	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(34, 32)
	_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_icon)
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override("font_size", 9)
	column.add_child(_name_label)
	_update_display()


func set_item_id(new_item_id: StringName) -> void:
	item_id = new_item_id
	_update_display()


func _update_display() -> void:
	if _name_label == null:
		return
	_name_label.text = "EMPTY" if item_id == &"" else ITEM_CATALOG.display_name(item_id).to_upper()
	_icon.texture = ITEM_CATALOG.icon_for(item_id) if item_id != &"" else null
	_icon.visible = _icon.texture != null
	var accent := Color(0.25, 0.34, 0.43, 1.0) if item_id == &"" else _rarity_color(item_id)
	var slot_style := StyleBoxFlat.new()
	slot_style.bg_color = Color(0.035, 0.05, 0.07, 0.96).lerp(accent, 0.13)
	var border := accent
	border.a = 0.75 if item_id != &"" else 0.4
	slot_style.border_color = border
	slot_style.set_border_width_all(1)
	slot_style.set_corner_radius_all(7)
	slot_style.set_content_margin_all(3)
	add_theme_stylebox_override("panel", slot_style)
	_name_label.add_theme_color_override("font_color", Color(0.94, 0.96, 1.0, 1.0) if item_id == &"" else accent)
	tooltip_text = "Right-click to clear" if item_id != &"" else "Drag an ability here"


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or str(data.get("type", "")) != "ability":
		return false
	return ITEM_CATALOG.is_ability(StringName(str(data.get("item_id", ""))))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	ability_dropped.emit(slot_index, StringName(str(data.get("item_id", ""))))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed and item_id != &"":
			ability_cleared.emit(slot_index)
			accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if item_id == &"":
		return null
	return {"type": "ability", "item_id": String(item_id)}


func _rarity_color(value: StringName) -> Color:
	match ITEM_CATALOG.rarity_for(value):
		"uncommon":
			return Color(0.35, 0.68, 1.0, 1.0)
		"rare":
			return Color(0.72, 0.43, 1.0, 1.0)
		"legendary":
			return Color(1.0, 0.76, 0.24, 1.0)
		_:
			return Color(0.36, 0.82, 0.48, 1.0)
