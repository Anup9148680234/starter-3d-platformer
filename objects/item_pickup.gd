extends Area3D

const ITEM_CATALOG = preload("res://scripts/item_catalog.gd")
const ITEM_RARITY = preload("res://scripts/item_rarity.gd")

@export_enum(
	"Coin:gold_coin",
	"Combo Punch:combo_punch",
	"Sword Regular Combo:sword_regular_combo",
	"Sword Heavy Combo:sword_heavy_combo",
	"Double Jump:double_jump",
	"Sword:sword",
	"Glider:glider",
	"Jetpack:jetpack",
	"Health Potion:health_potion"
) var item_id := "gold_coin"
@export_range(1, 99, 1) var quantity := 1

@onready var icon: Sprite3D = $Icon
@onready var placeholder: MeshInstance3D = $Placeholder
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var _collected := false
var _elapsed := 0.0
var _start_height := 0.0


func _ready() -> void:
	_start_height = position.y
	body_entered.connect(_on_body_entered)
	var pickup_id := StringName(item_id)
	var definition := ITEM_CATALOG.get_definition(pickup_id)
	if definition == null:
		push_warning("Unknown pickup item id: %s" % item_id)
		return
	icon.texture = ITEM_CATALOG.icon_for(pickup_id)
	icon.visible = icon.texture != null
	placeholder.visible = not icon.visible
	var material := StandardMaterial3D.new()
	material.albedo_color = ITEM_RARITY.color_for(pickup_id)
	material.metallic = 0.18
	placeholder.material_override = material


func _process(delta: float) -> void:
	if _collected:
		return
	_elapsed += delta
	rotate_y(delta * 1.8)
	position.y = _start_height + sin(_elapsed * 2.5) * 0.12


func _on_body_entered(body: Node3D) -> void:
	var pickup_id := StringName(item_id)
	if _collected or not ITEM_CATALOG.has_item(pickup_id) or quantity <= 0:
		return
	if pickup_id == &"gold_coin" and body.has_method("collect_coin"):
		body.call("collect_coin", quantity)
	elif body.has_method("add_inventory_item"):
		body.call("add_inventory_item", pickup_id, quantity)
		if has_node("/root/GameSave"):
			GameSave.sync_player_inventory(int(body.get("coins")), body.get("inventory_items"))
	else:
		return
	_collected = true
	collision_shape.set_deferred("disabled", true)
	icon.hide()
	placeholder.hide()
	if pickup_id != &"gold_coin":
		Audio.play("res://sounds/coin.ogg")
	queue_free()
