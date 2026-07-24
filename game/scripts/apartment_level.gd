class_name ApartmentLevel
extends Node3D

@export var run_duration := 180.0

@onready var apartment_generator: ApartmentGenerator = $ApartmentGenerator


func _ready() -> void:
	var generation_succeeded := await apartment_generator.generate_apartment()

	if generation_succeeded:
		RunManager.start_run(run_duration)
	else:
		push_error("The apartment run could not start because generation failed.")
