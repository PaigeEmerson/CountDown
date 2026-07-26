class_name PoliceLights
extends Node3D

@export_group("Pulse")
@export_range(0.01, 1.0, 0.01) var pulse_speed := 0.1
@export var max_energy := 30.0
@export var delay_between_colors := 0.05
@export var delay_between_cycles := 0.15

@onready var light_1: SpotLight3D = $SpotLight3D
@onready var light_2: SpotLight3D = $SpotLight3D2

var lights_active := false
var sequence_id := 0


func _ready() -> void:
	set_lights_to_zero()
	hide()

	RunManager.run_started.connect(_on_run_started)
	RunManager.time_changed.connect(_on_time_changed)
	RunManager.run_escaped.connect(_on_run_escaped)
	CampaignManager.campaign_ended.connect(_on_campaign_ended)

	if RunManager.run_active:
		_on_time_changed(RunManager.time_remaining)


func _on_run_started(_starting_crimes: int) -> void:
	deactivate_lights()


func _on_time_changed(time_remaining: float) -> void:
	if lights_active:
		return

	if time_remaining <= RunManager.critical_time_threshold:
		activate_lights()


func _on_run_escaped(_remaining_crimes: int, _cleaned_crimes: int) -> void:
	deactivate_lights()


func _on_campaign_ended(_caught_by_police: bool) -> void:
	deactivate_lights()


func activate_lights() -> void:
	if lights_active:
		return

	lights_active = true
	sequence_id += 1
	show()

	run_lights(sequence_id)


func deactivate_lights() -> void:
	lights_active = false
	sequence_id += 1

	set_lights_to_zero()
	hide()


func run_lights(active_sequence: int) -> void:
	while lights_active and active_sequence == sequence_id and is_inside_tree():
		await double_pulse(light_1, active_sequence)

		if not is_sequence_active(active_sequence):
			break

		await wait_for_delay(delay_between_colors, active_sequence)

		if not is_sequence_active(active_sequence):
			break

		await double_pulse(light_2, active_sequence)

		if not is_sequence_active(active_sequence):
			break

		await wait_for_delay(delay_between_cycles, active_sequence)


func double_pulse(light: SpotLight3D, active_sequence: int) -> void:
	if not is_sequence_active(active_sequence):
		return

	var tween := create_tween()

	tween.tween_property(light, "light_energy", max_energy, pulse_speed)
	tween.tween_property(light, "light_energy", 0.0, pulse_speed)
	tween.tween_property(light, "light_energy", max_energy, pulse_speed)
	tween.tween_property(light, "light_energy", 0.0, pulse_speed)

	await tween.finished


func wait_for_delay(duration: float, active_sequence: int) -> void:
	if duration <= 0.0 or not is_sequence_active(active_sequence):
		return

	await get_tree().create_timer(duration).timeout


func is_sequence_active(active_sequence: int) -> bool:
	return (
		lights_active
		and active_sequence == sequence_id
		and is_inside_tree()
	)


func set_lights_to_zero() -> void:
	light_1.light_energy = 0.0
	light_2.light_energy = 0.0
