class_name WindowLightningReceiver
extends Node3D

@export var lightning_lights: Array[Light3D]

var maximum_energies: Array[float] = []
var window_active := false


func _ready() -> void:
	add_to_group("lightning_windows")

	for light in lightning_lights:
		maximum_energies.append(light.light_energy)
		light.light_energy = 0.0
		light.visible = false


func set_window_active(value: bool) -> void:
	window_active = value

	if not window_active:
		set_flash_level(0.0)


func set_flash_level(level: float) -> void:
	level = clamp(level, 0.0, 1.0)

	for index in range(lightning_lights.size()):
		var light := lightning_lights[index]

		if not light:
			continue

		light.light_energy = maximum_energies[index] * level
		light.visible = window_active and level > 0.001
