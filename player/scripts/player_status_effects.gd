class_name PlayerStatusEffects
extends Node

@export var player_controller: CharacterBody3D
@export var player_camera: Camera3D
@export var inventory: CarryInventory

@export_group("Warped Vision")
@export var warp_roll_degrees := 4.0
@export var warp_fov_amount := 6.0
@export var warp_speed := 2.5

var speed_effect_end_time := 0.0
var warp_effect_end_time := 0.0
var capacity_effect_end_time := 0.0

var speed_multiplier := 1.0
var warp_strength := 0.0
var base_camera_fov := 75.0
var base_camera_roll := 0.0


func _ready() -> void:
	add_to_group("player_status_effects")

	if player_camera:
		base_camera_fov = player_camera.fov
		base_camera_roll = player_camera.rotation.z


func _process(_delta: float) -> void:
	var current_time := Time.get_ticks_msec() / 1000.0

	update_speed_effect(current_time)
	update_warp_effect(current_time)
	update_capacity_effect(current_time)


func apply_speed_boost(multiplier: float, duration: float) -> void:
	speed_multiplier = max(multiplier, 1.0)
	speed_effect_end_time = max(speed_effect_end_time, get_current_time() + duration)

	if player_controller and player_controller.has_method("set_movement_speed_multiplier"):
		player_controller.set_movement_speed_multiplier(speed_multiplier)


func apply_warped_vision(strength: float, duration: float) -> void:
	warp_strength = max(strength, 0.1)
	warp_effect_end_time = max(warp_effect_end_time, get_current_time() + duration)


func apply_capacity_boost(additional_slots: int, duration: float) -> void:
	capacity_effect_end_time = max(capacity_effect_end_time, get_current_time() + duration)

	if inventory:
		inventory.set_capacity_bonus(max(additional_slots, 0))


func update_speed_effect(current_time: float) -> void:
	if speed_effect_end_time <= 0.0:
		return

	if current_time < speed_effect_end_time:
		return

	speed_effect_end_time = 0.0
	speed_multiplier = 1.0

	if player_controller and player_controller.has_method("set_movement_speed_multiplier"):
		player_controller.set_movement_speed_multiplier(1.0)


func update_warp_effect(current_time: float) -> void:
	if not player_camera:
		return

	if warp_effect_end_time <= 0.0:
		return

	if current_time >= warp_effect_end_time:
		warp_effect_end_time = 0.0
		warp_strength = 0.0
		player_camera.rotation.z = base_camera_roll
		player_camera.fov = base_camera_fov
		return

	var wave := sin(current_time * warp_speed)
	var secondary_wave := sin(current_time * warp_speed * 0.65)

	player_camera.rotation.z = base_camera_roll + deg_to_rad(warp_roll_degrees * warp_strength * wave)
	player_camera.fov = base_camera_fov + warp_fov_amount * warp_strength * secondary_wave


func update_capacity_effect(current_time: float) -> void:
	if capacity_effect_end_time <= 0.0:
		return

	if current_time < capacity_effect_end_time:
		return

	capacity_effect_end_time = 0.0

	if inventory:
		inventory.set_capacity_bonus(0)


func get_current_time() -> float:
	return Time.get_ticks_msec() / 1000.0
