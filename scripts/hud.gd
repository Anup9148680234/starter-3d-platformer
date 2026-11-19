extends Control

const ITEM_RARITY = preload("res://scripts/item_rarity.gd")

@onready var coins_label: Label = get_node_or_null("Coins") as Label
@onready var health_bar: ProgressBar = get_node_or_null("Health") as ProgressBar
@onready var health_label: Label = get_node_or_null("HealthLabel") as Label
@onready var checkpoint_status: Label = get_node_or_null("CheckpointStatus") as Label

var _pickup_toast: PanelContainer
var _pickup_icon: Label
var _pickup_text: Label
var _pickup_tween: Tween

func _ready() -> void:
	_create_pickup_toast()
	var player := get_parent().get_node_or_null("Player")
	if player != null and player.has_signal("item_picked_up"):
		player.connect("item_picked_up", _on_item_picked_up)

	if health_bar != null:
		var bar_background := StyleBoxFlat.new()
		bar_background.bg_color = Color(0.08, 0.09, 0.12, 0.95)
		bar_background.set_corner_radius_all(4)
		var bar_fill := StyleBoxFlat.new()
		bar_fill.bg_color = Color(0.82, 0.16, 0.18, 1.0)
		bar_fill.set_corner_radius_all(4)
		health_bar.add_theme_stylebox_override("background", bar_background)
		health_bar.add_theme_stylebox_override("fill", bar_fill)
		health_bar.show_percentage = false

func _create_pickup_toast() -> void:
	_pickup_toast = PanelContainer.new()
	_pickup_toast.name = "PickupToast"
	_pickup_toast.visible = false
	_pickup_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pickup_toast.anchor_left = 0.5
	_pickup_toast.anchor_right = 0.5
	_pickup_toast.anchor_top = 1.0
	_pickup_toast.anchor_bottom = 1.0
	_pickup_toast.offset_left = -170.0
	_pickup_toast.offset_right = 170.0
	_pickup_toast.offset_top = -112.0
	_pickup_toast.offset_bottom = -52.0
	add_child(_pickup_toast)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_pickup_toast.add_child(row)

	_pickup_icon = Label.new()
	_pickup_icon.text = "◆"
	_pickup_icon.custom_minimum_size = Vector2(30, 30)
	_pickup_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pickup_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pickup_icon.add_theme_font_size_override("font_size", 22)
	row.add_child(_pickup_icon)

	_pickup_text = Label.new()
	_pickup_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_pickup_text.add_theme_font_size_override("font_size", 19)
	_pickup_text.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0, 1.0))
	row.add_child(_pickup_text)

func _on_item_picked_up(item_id: StringName, quantity: int) -> void:
	if _pickup_toast == null or quantity <= 0:
		return
	var rarity_color := ITEM_RARITY.color_for(item_id)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.035, 0.045, 0.065, 0.94).lerp(rarity_color, 0.15)
	var toast_border := rarity_color.darkened(0.05)
	toast_border.a = 0.68
	card_style.border_color = toast_border
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(10)
	card_style.content_margin_left = 16.0
	card_style.content_margin_right = 18.0
	card_style.content_margin_top = 8.0
	card_style.content_margin_bottom = 8.0
	_pickup_toast.add_theme_stylebox_override("panel", card_style)
	_pickup_icon.add_theme_color_override("font_color", rarity_color)
	_pickup_text.text = "Picked up %s x %d" % [ITEM_RARITY.display_name(item_id), quantity]

	if _pickup_tween != null and _pickup_tween.is_running():
		_pickup_tween.kill()
	_pickup_toast.visible = true
	_pickup_toast.modulate.a = 0.0
	var target_position := _pickup_toast.position
	_pickup_toast.position = target_position + Vector2(0.0, 24.0)
	_pickup_tween = create_tween()
	_pickup_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_pickup_tween.set_parallel(true)
	_pickup_tween.tween_property(_pickup_toast, "modulate:a", 1.0, 0.22)
	_pickup_tween.tween_property(_pickup_toast, "position", target_position, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pickup_tween.set_parallel(false)
	_pickup_tween.tween_interval(3.0)
	_pickup_tween.set_parallel(true)
	_pickup_tween.tween_property(_pickup_toast, "modulate:a", 0.0, 0.38)
	_pickup_tween.tween_property(_pickup_toast, "position", target_position + Vector2(0.0, 28.0), 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_pickup_tween.set_parallel(false)
	_pickup_tween.tween_callback(_pickup_toast.hide)

func _on_coin_collected(total_coins: int) -> void:
	if coins_label != null:
		coins_label.text = str(total_coins)

func _on_health_changed(current_health: int, maximum_health: int) -> void:
	if health_bar != null:
		health_bar.max_value = maximum_health
		health_bar.value = current_health
	if health_label != null:
		health_label.text = "HP"

func _on_checkpoint_reached(id: String) -> void:
	if checkpoint_status != null:
		checkpoint_status.text = "Checkpoint saved: %s" % id.replace("_", " ")
		checkpoint_status.show()
