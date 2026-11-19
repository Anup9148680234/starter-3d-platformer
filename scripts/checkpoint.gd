extends Node3D

@export var checkpoint_id := ""


func _ready() -> void:
	$Trigger.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player := body as CharacterBody3D
	if player == null or not player.is_in_group("player"):
		return
	var safe_spawn := global_position + Vector3.UP * 0.55
	var id := checkpoint_id if not checkpoint_id.is_empty() else str(get_path())
	if GameSave.activate_checkpoint(id, safe_spawn, player.rotation.y, player) and id == "checkpoint_2":
		GameSave.complete_tutorial(player)
