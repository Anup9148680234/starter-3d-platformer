extends CanvasLayer

const ITEM_RARITY = preload("res://scripts/item_rarity.gd")
const HEALTH_POTION_COST := 5

@export var player_path: NodePath

var player: Node
var previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var preview_base_materials: Dictionary = {}

@onready var overlay: Control = $Overlay
@onready var item_grid: GridContainer = %ItemGrid
@onready var outfit_selector: OptionButton = %OutfitSelector
@onready var preview_character: Node3D = $Overlay/Frame/Margin/Layout/Body/CharacterPanel/CharacterLayout/PreviewContainer/PreviewViewport/PreviewCharacter
@onready var coin_count: Label = %CoinCount
@onready var shop_status: Label = %ShopStatus
@onready var buy_potion_button: Button = %BuyPotionButton


func _ready() -> void:
	overlay.hide()
	player = get_node_or_null(player_path)
	if player == null:
		push_warning("Inventory menu could not find the player at %s" % player_path)
		return
	if player.has_signal("inventory_changed"):
		player.connect("inventory_changed", _on_inventory_changed)
	if player.has_signal("coin_collected"):
		player.connect("coin_collected", _on_coin_collected)
	if player.has_signal("health_changed"):
		player.connect("health_changed", _on_health_changed)

	_populate_outfits()
	_start_preview_animation()
	_refresh_inventory()
	_update_shop()


func _process(delta: float) -> void:
	if overlay.visible:
		preview_character.rotate_y(delta * 0.28)


func _unhandled_key_input(event: InputEvent) -> void:
	if GameSave.transition_in_progress:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_TAB:
		if overlay.visible:
			close_inventory()
		elif not get_tree().paused:
			open_inventory()
		get_viewport().set_input_as_handled()
	elif overlay.visible and event.is_action_pressed("ui_cancel"):
		close_inventory()
		get_viewport().set_input_as_handled()


func open_inventory() -> void:
	if player == null or get_tree().paused or GameSave.transition_in_progress:
		return
	previous_mouse_mode = Input.get_mouse_mode()
	overlay.show()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_refresh_inventory()
	_update_shop()


func close_inventory() -> void:
	if not overlay.visible:
		return
	overlay.hide()
	get_tree().paused = false
	Input.set_mouse_mode(previous_mouse_mode)


func _populate_outfits() -> void:
	outfit_selector.clear()
	var skins: Array = player.get("available_skins")
	for index in range(skins.size()):
		var skin: PlayerSkin = skins[index] as PlayerSkin
		if skin != null:
			outfit_selector.add_item(skin.display_name, index)
	var selected_index := int(player.get("current_skin_index"))
	if skins.size() > 0:
		selected_index = clampi(selected_index, 0, skins.size() - 1)
		outfit_selector.select(selected_index)
		_apply_skin_to_preview(selected_index)


func _start_preview_animation() -> void:
	var animation_players := preview_character.find_children("*", "AnimationPlayer", true, false)
	if not animation_players.is_empty():
		var preview_animation: AnimationPlayer = animation_players[0] as AnimationPlayer
		if preview_animation.has_animation(&"UAL/Idle_Loop"):
			preview_animation.play(&"UAL/Idle_Loop")


func _on_outfit_selected(index: int) -> void:
	if player == null:
		return
	player.call("apply_skin", index)
	_apply_skin_to_preview(index)


func _apply_skin_to_preview(index: int) -> void:
	var skins: Array = player.get("available_skins")
	if index < 0 or index >= skins.size():
		return
	var skin: PlayerSkin = skins[index] as PlayerSkin
	if skin == null or skin.albedo_texture == null:
		return
	var ual_skeleton := preview_character.find_child("GeneralSkeleton", true, false) as Skeleton3D

	for node in preview_character.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance: MeshInstance3D = node as MeshInstance3D
		if mesh_instance == null or mesh_instance.mesh == null:
			continue
		if not preview_base_materials.has(mesh_instance):
			var materials_to_cache: Array[Material] = []
			for surface_index in range(mesh_instance.mesh.get_surface_count()):
				materials_to_cache.append(mesh_instance.get_active_material(surface_index))
			preview_base_materials[mesh_instance] = materials_to_cache
		var cached_materials: Array = preview_base_materials[mesh_instance]
		for surface_index in range(cached_materials.size()):
			var source_material: Material = cached_materials[surface_index]
			if source_material is BaseMaterial3D:
				var skin_material: BaseMaterial3D = source_material.duplicate() as BaseMaterial3D
				if ual_skeleton != null:
					if skin.display_name.to_lower().contains("black"):
						skin_material.albedo_color = Color(0.035, 0.035, 0.04) if source_material.resource_name == "M_Main" else Color(0.075, 0.075, 0.08)
						mesh_instance.set_surface_override_material(surface_index, skin_material)
					else:
						mesh_instance.set_surface_override_material(surface_index, source_material)
				else:
					skin_material.albedo_texture = skin.albedo_texture
					mesh_instance.set_surface_override_material(surface_index, skin_material)


func _refresh_inventory() -> void:
	for child in item_grid.get_children():
		item_grid.remove_child(child)
		child.queue_free()
	var items: Dictionary = player.get("inventory_items")
	coin_count.text = str(int(player.get("coins")))
	if items.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No items collected yet. Explore to find supplies."
		empty_label.custom_minimum_size = Vector2(320, 80)
		empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		item_grid.add_child(empty_label)
		return

	for key in items.keys():
		var item_id: StringName = StringName(str(key))
		var quantity: int = int(items[key])
		item_grid.add_child(_make_item_card(item_id, quantity))


func _make_item_card(item_id: StringName, quantity: int) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(122, 142)
	var rarity_color := ITEM_RARITY.color_for(item_id)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.045, 0.055, 0.07, 0.96).lerp(rarity_color, 0.12)
	var card_border := rarity_color
	card_border.a = 0.42
	card_style.border_color = card_border
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(7)
	card_style.set_content_margin_all(6)
	card.add_theme_stylebox_override("panel", card_style)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 5)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(content)

	if item_id == &"gold_coin":
		var icon := TextureRect.new()
		icon.texture = preload("res://sprites/coin.png")
		icon.custom_minimum_size = Vector2(42, 42)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		content.add_child(icon)
	else:
		var icon_label := Label.new()
		icon_label.text = "✚" if item_id == &"health_potion" else "◆"
		icon_label.custom_minimum_size = Vector2(42, 42)
		icon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_label.add_theme_font_size_override("font_size", 30)
		icon_label.add_theme_color_override("font_color", rarity_color)
		content.add_child(icon_label)

	var name_label := Label.new()
	name_label.text = _item_display_name(item_id)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(name_label)

	var quantity_label := Label.new()
	quantity_label.text = "× %d" % quantity
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quantity_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.36, 1.0))
	content.add_child(quantity_label)

	if item_id == &"health_potion":
		var use_button := Button.new()
		use_button.text = "USE"
		use_button.pressed.connect(_on_use_item_pressed.bind(item_id))
		content.add_child(use_button)
	return card


func _item_display_name(item_id: StringName) -> String:
	if item_id == &"gold_coin":
		return "Gold Coin"
	return ITEM_RARITY.display_name(item_id)


func _on_use_item_pressed(item_id: StringName) -> void:
	if player.call("use_inventory_item", item_id):
		shop_status.text = "Health restored."
	else:
		shop_status.text = "You cannot use that item right now."
	_refresh_inventory()


func _on_buy_potion_pressed() -> void:
	var purchased: bool = player.call("spend_coins", HEALTH_POTION_COST)
	if purchased:
		player.call("add_inventory_item", &"health_potion", 1)
	_refresh_inventory()
	_update_shop()
	shop_status.text = "Health potion added to your inventory." if purchased else "Collect more coins to buy this potion."


func _update_shop() -> void:
	if player == null:
		return
	var coins := int(player.get("coins"))
	buy_potion_button.disabled = coins < HEALTH_POTION_COST
	if coins < HEALTH_POTION_COST:
		var coins_needed := HEALTH_POTION_COST - coins
		var plural := "" if coins_needed == 1 else "s"
		shop_status.text = "Collect %d more coin%s to purchase." % [coins_needed, plural]
	else:
		shop_status.text = "Ready to purchase."


func _on_inventory_changed(_items: Dictionary) -> void:
	_refresh_inventory()
	_update_shop()


func _on_coin_collected(total_coins: int) -> void:
	coin_count.text = str(total_coins)
	_update_shop()


func _on_health_changed(_current_health: int, _maximum_health: int) -> void:
	_refresh_inventory()
