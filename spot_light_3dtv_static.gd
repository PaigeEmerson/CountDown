extends Light3D 

@export var min_energy: float = 0.5
@export var max_energy: float = 2.0

func _process(_delta):
	light_energy = randf_range(min_energy, max_energy)
