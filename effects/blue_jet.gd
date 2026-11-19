extends Node3D

## Simple animated mesh exhaust. The flame points along this node's local -Z axis.

var _elapsed: float = 0.0

@onready var outer_flame: MeshInstance3D = $OuterFlame
@onready var inner_flame: MeshInstance3D = $InnerFlame
@onready var core_flame: MeshInstance3D = $CoreFlame

func _process(delta: float) -> void:
	_elapsed += delta
	var outer_pulse: float = 0.92 + 0.08 * sin(_elapsed * 18.0)
	var inner_pulse: float = 0.94 + 0.06 * sin(_elapsed * 23.0 + 0.8)
	var core_pulse: float = 0.96 + 0.04 * sin(_elapsed * 29.0 + 1.7)
	outer_flame.scale = Vector3(outer_pulse, outer_pulse, outer_pulse)
	inner_flame.scale = Vector3(inner_pulse, inner_pulse, inner_pulse)
	core_flame.scale = Vector3(core_pulse, core_pulse, core_pulse)
