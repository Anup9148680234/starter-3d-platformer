extends Node3D

const PLAYER_MAX_HEALTH := 100

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var hud: Control = get_node_or_null("HUD") as Control


func _ready() -> void:
	GameSave.transition_in_progress = false
	if player == null:
		push_error("World1 needs a CharacterBody3D child named Player.")
		return

	if hud != null:
		if player.has_signal("coin_collected"):
			var coin_callback := Callable(hud, "_on_coin_collected")
			if not player.is_connected("coin_collected", coin_callback):
				player.connect("coin_collected", coin_callback)
		if player.has_signal("health_changed"):
			var health_callback := Callable(hud, "_on_health_changed")
			if not player.is_connected("health_changed", health_callback):
				player.connect("health_changed", health_callback)
		var checkpoint_callback := Callable(hud, "_on_checkpoint_reached")
		if not GameSave.checkpoint_reached.is_connected(checkpoint_callback):
			GameSave.checkpoint_reached.connect(checkpoint_callback)

	GameSave.restore_player(player)
	if hud != null:
		hud.call("_on_coin_collected", int(player.get("coins")))
		hud.call("_on_health_changed", int(player.get("health")), PLAYER_MAX_HEALTH)
		if not GameSave.checkpoint_id.is_empty():
			hud.call("_on_checkpoint_reached", GameSave.checkpoint_id)
