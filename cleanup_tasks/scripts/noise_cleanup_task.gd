class_name NoiseCleanupTask
extends CleanupTask

@export_group("Knob")
@export_range(0.0001, 0.02, 0.0001) var drag_sensitivity := 0.003
@export var starting_angle_degrees := 135.0
@export var muted_angle_degrees := -135.0
@export_range(0.0, 1.0, 0.01) var completion_threshold := 0.98

@export_group("Audio")
@export var muted_volume_db := -60.0

@export_group("Camera")
@export var camera_move_duration := 0.5

var player_camera: Camera3D
var volume_knob: Node3D
var speaker_audio: AudioStreamPlayer3D
var cleanup_view: Marker3D
var instruction_label: Label3D

var original_camera_transform: Transform3D
var original_knob_rotation: Vector3
var original_volume_db := 0.0

var knob_progress := 0.0
var mouse_held := false
var accepting_input := false
var is_finishing := false


func _ready() -> void:
	lock_player_movement = true
	lock_camera_look = true
	show_mouse_cursor = true
	can_cancel = true


func begin(target_evidence: Evidence) -> void:
	super.begin(target_evidence)

	player_camera = get_viewport().get_camera_3d()
	volume_knob = evidence.get_node_or_null("Speaker/VolumeKnob") as Node3D
	speaker_audio = evidence.get_node_or_null("SpeakerAudio") as AudioStreamPlayer3D
	cleanup_view = evidence.get_node_or_null("CleanupView") as Marker3D
	instruction_label = evidence.get_node_or_null("InstructionLabel") as Label3D

	if not player_camera or not volume_knob or not speaker_audio or not cleanup_view:
		push_error("NoiseEvidence requires VolumeKnob, SpeakerAudio, CleanupView, and an active camera.")
		call_deferred("_cancel_after_setup_error")
		return

	original_camera_transform = player_camera.global_transform
	original_knob_rotation = volume_knob.rotation
	original_volume_db = speaker_audio.volume_db

	knob_progress = 0.0
	update_knob()
	move_camera_into_position()


func move_camera_into_position() -> void:
	var target_transform := cleanup_view.global_transform
	var tween := create_tween()

	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player_camera, "global_transform", target_transform, camera_move_duration)
	tween.tween_callback(_on_camera_arrived)


func _on_camera_arrived() -> void:
	accepting_input = true
	set_process_input(true)

	if instruction_label:
		instruction_label.show()


func _input(event: InputEvent) -> void:
	if not accepting_input or is_finishing:
		return

	if event.is_action_pressed("release_mouse"):
		get_viewport().set_input_as_handled()
		finish_task(false)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_held = event.pressed
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion and mouse_held:
		apply_mouse_drag(event.relative)
		get_viewport().set_input_as_handled()


func apply_mouse_drag(mouse_delta: Vector2) -> void:
	var progress_change := -mouse_delta.x * drag_sensitivity
	knob_progress = clamp(knob_progress + progress_change, 0.0, 1.0)

	update_knob()

	if knob_progress >= completion_threshold:
		knob_progress = 1.0
		update_knob()
		finish_task(true)


func update_knob() -> void:
	var new_angle: float = lerp(starting_angle_degrees, muted_angle_degrees, knob_progress)

	var updated_rotation := original_knob_rotation
	updated_rotation.x = deg_to_rad(new_angle)
	volume_knob.rotation = updated_rotation

	speaker_audio.volume_db = lerp(original_volume_db, muted_volume_db, knob_progress)


func finish_task(success: bool) -> void:
	if is_finishing:
		return

	is_finishing = true
	accepting_input = false
	mouse_held = false
	set_process_input(false)

	if instruction_label:
		instruction_label.hide()

	if not success:
		volume_knob.rotation = original_knob_rotation
		speaker_audio.volume_db = original_volume_db

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player_camera, "global_transform", original_camera_transform, camera_move_duration)

	if success:
		tween.tween_callback(_complete_after_camera_return)
	else:
		tween.tween_callback(_cancel_after_camera_return)


func _complete_after_camera_return() -> void:
	speaker_audio.stop()
	complete()


func _cancel_after_camera_return() -> void:
	cancel()


func _cancel_after_setup_error() -> void:
	cancel()
