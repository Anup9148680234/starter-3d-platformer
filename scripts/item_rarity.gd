extends RefCounted
class_name ItemRarity

const COMMON := Color(0.36, 0.82, 0.48, 1.0)
const UNCOMMON := Color(0.35, 0.68, 1.0, 1.0)
const RARE := Color(0.72, 0.43, 1.0, 1.0)
const LEGENDARY := Color(1.0, 0.76, 0.24, 1.0)


static func color_for(item_id: StringName) -> Color:
	var item_key := str(item_id).to_lower()
	if item_key == "sword" or item_key.begins_with("uncommon_"):
		return UNCOMMON
	if item_key == "jetpack" or item_key.begins_with("rare_"):
		return RARE
	if item_key == "glider" or item_key.begins_with("legendary_"):
		return LEGENDARY
	return COMMON


static func display_name(item_id: StringName) -> String:
	match item_id:
		&"gold_coin":
			return "Coin"
		&"health_potion":
			return "Health Potion"
		_:
			return str(item_id).replace("_", " ").capitalize()
