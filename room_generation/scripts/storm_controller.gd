class_name StormController
extends Node

@export_group("Lightning Timing")
@export var minimum_flash_interval := 6.0
@export var maximum_flash_interval := 18.0
@export_range(0.0, 1.0) var double_flash_chance := 0.65

@export_group("Lightning Appearance")
@export var flash_attack_duration := 0.03
@export var flash_hold_duration := 0.15
@export var flash_fade_duration := 0.3
@export var secondary_flash_gap := 0.12

@export_group("Thunder")
@export var thunder_player: AudioStreamPlayer
@export var thunder_sounds: Array[AudioStream]
@export var minimum_thunder_delay := 0.5
@export var maximum_thunder_delay := 3.5
@export var minimum_thunder_volume_db := -5.0
@export var maximum_thunder_volume_db := 0.0

var random := RandomNumberGenerator.new()
var storm_running := true


func _ready() -> void:
	random.randomize()
	run_storm()


func run_storm() -> void:
	while storm_running and is_inside_tree():
		var flash_delay := random.randf_range(minimum_flash_interval, maximum_flash_interval)
		await get_tree().create_timer(flash_delay).timeout

		if not storm_running or not is_inside_tree():
			return

		play_lightning_flash()

		var thunder_delay := random.randf_range(minimum_thunder_delay, maximum_thunder_delay)
		await get_tree().create_timer(thunder_delay).timeout
		play_thunder()


func play_lightning_flash() -> void:
	var strength := random.randf_range(0.75, 1.0)

	await play_flash_pulse(strength)

	if random.randf() <= double_flash_chance:
		await get_tree().create_timer(secondary_flash_gap).timeout

		var secondary_strength := strength * random.randf_range(0.5, 0.85)
		await play_flash_pulse(secondary_strength)
		
		
func play_flash_pulse(strength: float) -> void:
	var attack_tween := create_tween()
	attack_tween.set_trans(Tween.TRANS_EXPO)
	attack_tween.set_ease(Tween.EASE_OUT)
	attack_tween.tween_method(set_window_flash_level, 0.0, strength, flash_attack_duration)

	await attack_tween.finished
	await get_tree().create_timer(flash_hold_duration).timeout

	var fade_tween := create_tween()
	fade_tween.set_trans(Tween.TRANS_SINE)
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.tween_method(set_window_flash_level, strength, 0.0, flash_fade_duration)

	await fade_tween.finished
	set_window_flash_level(0.0)


func set_window_flash_level(level: float) -> void:
	for receiver in get_tree().get_nodes_in_group("lightning_windows"):
		if receiver is WindowLightningReceiver:
			receiver.set_flash_level(level)


func play_thunder() -> void:
	if not thunder_player or thunder_sounds.is_empty():
		return

	thunder_player.stream = thunder_sounds[random.randi_range(0, thunder_sounds.size() - 1)]
	thunder_player.volume_db = random.randf_range(minimum_thunder_volume_db, maximum_thunder_volume_db)
	thunder_player.pitch_scale = random.randf_range(0.92, 1.05)
	thunder_player.play()
