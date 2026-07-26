class_name LaunderingCleanupTask
extends CleanupTask

@export_group("Damage")
@export_range(1, 20, 1) var required_hits := 5
@export_range(0.5, 1.0, 0.05) var hit_threshold := 0.85
@export var machine_shake_distance := 0.04
@export var machine_shake_duration := 0.12

@export_group("Swing")
@export_range(0.001, 0.05, 0.001) var swing_sensitivity := 0.01
@export var left_swing_angle := -65.0
@export var right_swing_angle := 65.0
@export var return_speed := 5.0

@export_group("Camera")
@export var camera_move_duration := 0.5

@onready var bat_pivot: Node3D = $BatPivot
@onready var bat_visual: Node3D = $BatPivot/BatVisual

var player_camera: Camera3D
var machine_model: Node3D
var damage_stages: Node3D
var cleanup_view: Marker3D
var bat_anchor: Marker3D
var hit_audio: AudioStreamPlayer3D
var money_mesh: Node3D
var instruction_label: Label3D
var original_money_visibility := true

var original_camera_transform: Transform3D
var original_machine_position: Vector3

var current_hits := 0
var swing_position := 0.0
var last_hit_side := 0
var mouse_held := false
var accepting_input := false
var is_finishing := false


func _ready() -> void:
	lock_player_movement = true
	lock_camera_look = true
	show_mouse_cursor = true
	can_cancel = true

	bat_visual.hide()


func _process(delta: float) -> void:
	if not accepting_input or mouse_held or is_finishing:
		return

	swing_position = move_toward(swing_position, 0.0, return_speed * delta)
	update_bat_rotation()


func begin(target_evidence: Evidence) -> void:
	super.begin(target_evidence)

	player_camera = get_viewport().get_camera_3d()
	machine_model = evidence.get_node_or_null("MachineModel") as Node3D
	damage_stages = evidence.get_node_or_null("DamageStages") as Node3D
	cleanup_view = evidence.get_node_or_null("CleanupView") as Marker3D
	bat_anchor = evidence.get_node_or_null("BatAnchor") as Marker3D
	hit_audio = evidence.get_node_or_null("HitAudio") as AudioStreamPlayer3D
	money_mesh = evidence.get_node_or_null("MoneyMesh") as Node3D
	instruction_label = evidence.get_node_or_null("InstructionLabel") as Label3D

	if not player_camera or not machine_model or not money_mesh or not damage_stages or not cleanup_view or not bat_anchor:
		push_error("MoneyLaunderingEvidence requires MachineModel, MoneyMesh, DamageStages, CleanupView, BatAnchor, and an active camera.")
		call_deferred("_cancel_after_setup_error")
		return

	original_camera_transform = player_camera.global_transform
	original_machine_position = machine_model.position
	original_money_visibility = money_mesh.visible

	current_hits = 0
	swing_position = 0.0
	last_hit_side = 0

	hide_all_damage_stages()

	bat_pivot.global_transform = bat_anchor.global_transform
	update_bat_rotation()
	move_camera_into_position()


func move_camera_into_position() -> void:
	var tween := create_tween()

	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player_camera, "global_transform", cleanup_view.global_transform, camera_move_duration)
	tween.tween_callback(_on_camera_arrived)


func _on_camera_arrived() -> void:
	accepting_input = true
	set_process_input(true)
	bat_visual.show()

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
		apply_swing_motion(event.relative.y)
		get_viewport().set_input_as_handled()


func apply_swing_motion(horizontal_motion: float) -> void:
	swing_position = clamp(swing_position + horizontal_motion * swing_sensitivity, -1.0, 1.0)
	update_bat_rotation()
	check_for_hit()


func update_bat_rotation() -> void:
	var normalized_position := (swing_position + 1.0) * 0.5
	var swing_angle: float = lerp(left_swing_angle, right_swing_angle, normalized_position)

	var updated_rotation := bat_pivot.rotation
	updated_rotation.z = deg_to_rad(swing_angle)
	bat_pivot.rotation = updated_rotation


func check_for_hit() -> void:
	if swing_position >= hit_threshold and last_hit_side != 1:
		last_hit_side = 1
		register_hit()
	elif swing_position <= -hit_threshold and last_hit_side != -1:
		last_hit_side = -1
		register_hit()


func register_hit() -> void:
	current_hits += 1

	if hit_audio:
		hit_audio.pitch_scale = randf_range(0.9, 1.1)
		hit_audio.play()

	update_damage_stage()
	shake_machine()

	if current_hits >= required_hits:
		finish_task(true)


func update_damage_stage() -> void:
	var stages := get_damage_stage_nodes()

	if stages.is_empty():
		return

	var completion := float(current_hits) / float(required_hits)
	var stage_index := clampi(ceil(completion * stages.size()) - 1, 0, stages.size() - 1)

	for index in stages.size():
		stages[index].visible = index == stage_index


func shake_machine() -> void:
	machine_model.position = original_machine_position

	var shake_offset := Vector3(
		randf_range(-machine_shake_distance, machine_shake_distance),
		randf_range(-machine_shake_distance, machine_shake_distance),
		0.0
	)

	var tween := create_tween()
	tween.tween_property(machine_model, "position", original_machine_position + shake_offset, machine_shake_duration * 0.5)
	tween.tween_property(machine_model, "position", original_machine_position, machine_shake_duration * 0.5)


func get_damage_stage_nodes() -> Array[Node3D]:
	var stages: Array[Node3D] = []

	for child in damage_stages.get_children():
		if child is Node3D:
			stages.append(child)

	return stages


func hide_all_damage_stages() -> void:
	for stage in get_damage_stage_nodes():
		stage.hide()


func finish_task(success: bool) -> void:
	if is_finishing:
		return

	is_finishing = true
	accepting_input = false
	mouse_held = false
	set_process_input(false)
	bat_visual.hide()

	if instruction_label:
		instruction_label.hide()

	if success:
		money_mesh.hide()
	else:
		current_hits = 0
		swing_position = 0.0
		last_hit_side = 0
		machine_model.position = original_machine_position
		money_mesh.visible = original_money_visibility
		hide_all_damage_stages()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player_camera, "global_transform", original_camera_transform, camera_move_duration)

	if success:
		tween.tween_callback(_complete_after_camera_return)
	else:
		tween.tween_callback(_cancel_after_camera_return)


func _complete_after_camera_return() -> void:
	complete()


func _cancel_after_camera_return() -> void:
	cancel()


func _cancel_after_setup_error() -> void:
	cancel()
	
	
func request_cancel() -> void:
	if is_finishing:
		return

	finish_task(false)
