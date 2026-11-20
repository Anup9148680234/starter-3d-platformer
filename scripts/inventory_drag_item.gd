extends PanelContainer

const ITEM_CATALOG = preload("res://scripts/item_catalog.gd")

var item_id: StringName = &""


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not ITEM_CATALOG.is_ability(item_id):
		return null
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(110, 42)
	var preview_label := Label.new()
	preview_label.text = str(item_id).replace("_", " ").capitalize()
	preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.add_child(preview_label)
	set_drag_preview(preview)
	return {"type": "ability", "item_id": String(item_id)}
