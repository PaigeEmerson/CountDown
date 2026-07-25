extends Node3D

@export var pulse_speed := 0.1
@export var max_energy := 30.0

@onready var light_1: SpotLight3D = $SpotLight3D
@onready var light_2: SpotLight3D = $SpotLight3D2

func _ready() -> void:
	light_1.light_energy = 0.0
	light_2.light_energy = 0.0
	run_lights()

func run_lights() -> void:
	while is_inside_tree():
		await double_pulse(light_1)
		await double_pulse(light_2)

func double_pulse(light: SpotLight3D) -> void:
	var tween = create_tween()
	tween.tween_property(light, "light_energy", max_energy, pulse_speed)
	tween.tween_property(light, "light_energy", 0.0, pulse_speed)
	tween.tween_property(light, "light_energy", max_energy, pulse_speed)
	tween.tween_property(light, "light_energy", 0.0, pulse_speed)
	
	await tween.finished
