extends Node3D

const PLAYER_MAX_HEALTH := 100

@onready var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
@onready var hud: Control = get_node_or_null("HUD") as Control


func _ready() -> void:
	GameSave.transition_in_progress = false
	_bake_large_rock_collisions()
	_bake_tree_collisions()
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


func _bake_large_rock_collisions() -> void:
	for rock_name in ["Rock_Large_0", "Rock_Large_1", "Rock_Large_2", "Rock_Large_3"]:
		var rock := get_node_or_null(NodePath(rock_name))
		if rock == null:
			push_warning("World1 rock collision target not found: %s" % rock_name)
			continue
		_add_trimesh_collisions(rock)
		

const TREES := 37
const TREE_PREFIX := "TwistedTree_"


func _bake_tree_collisions() -> void:
	for index in range(1,TREES):
		var tree_name := "%s%d" % [TREE_PREFIX, index]
		var tree := get_node_or_null(NodePath(tree_name))

		if tree == null:
			push_warning("World1 rock collision target not found: %s" % tree_name)
			continue

		_add_trimesh_collisions(tree)


func _add_trimesh_collisions(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null and not _has_collision_body(mesh_instance):
			mesh_instance.create_trimesh_collision()
	for child in node.get_children():
		_add_trimesh_collisions(child)


func _has_collision_body(mesh_instance: MeshInstance3D) -> bool:
	for child in mesh_instance.get_children():
		if child is StaticBody3D:
			for body_child in child.get_children():
				if body_child is CollisionShape3D or body_child is CollisionPolygon3D:
					return true
	return false
