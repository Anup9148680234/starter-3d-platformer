extends StaticBody3D

@export_range(1, 10, 1) var hits_to_break := 1
@export_range(1, 50, 1) var coin_reward := 10

const COIN_SCENE: PackedScene = preload("res://objects/coin.tscn")

@onready var block_visual: Node3D = $BlockModel
@onready var hit_detector: Area3D = $BottomDetector
@onready var coin_particles: GPUParticles3D = $CoinParticles
@onready var block_collision: CollisionShape3D = $CollisionShape3D

var hit_count := 0
var broken := false

func _ready() -> void:
	hit_detector.body_entered.connect(_on_bottom_hit)
	_setup_coin_particles()

func _setup_coin_particles() -> void:
	var coin_instance := COIN_SCENE.instantiate()
	var coin_mesh := coin_instance.find_child("Mesh", true, false) as MeshInstance3D
	if coin_mesh != null and coin_mesh.mesh != null:
		coin_particles.draw_pass_1 = coin_mesh.mesh
		coin_particles.material_override = coin_mesh.get_active_material(0)
	coin_instance.free()
	var particle_material := ParticleProcessMaterial.new()
	particle_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	particle_material.emission_sphere_radius = 0.25
	particle_material.direction = Vector3.UP
	particle_material.spread = 35.0
	particle_material.initial_velocity_min = 3.0
	particle_material.initial_velocity_max = 5.0
	particle_material.gravity = Vector3(0.0, -9.8, 0.0)
	particle_material.scale_min = 0.55
	particle_material.scale_max = 0.75
	coin_particles.process_material = particle_material
	coin_particles.amount = coin_reward
	coin_particles.lifetime = 1.0
	coin_particles.one_shot = true
	coin_particles.explosiveness = 1.0
	coin_particles.emitting = false

func _on_bottom_hit(body: Node3D) -> void:
	if broken or not body.is_in_group("player"):
		return
	hit_count += 1
	if hit_count >= hits_to_break:
		_break_open(body)

func _break_open(player: Node3D) -> void:
	if broken:
		return
	broken = true
	if player.has_method("collect_coin"):
		player.collect_coin(coin_reward)
	Audio.play("res://sounds/coin.ogg")
	block_visual.hide()
	block_collision.set_deferred("disabled", true)
	hit_detector.set_deferred("monitoring", false)
	coin_particles.restart()
	coin_particles.emitting = true
	await get_tree().create_timer(coin_particles.lifetime + 0.15).timeout
	queue_free()
