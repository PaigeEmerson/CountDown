class_name CounterfeitBurnTask
extends CleanupTask

@export_group("Burning")
@export var required_burn_distance := 4.0
@export var surface_width := 1.0
@export var surface_height := 0.7
@export var particle_surface_offset := 0.04
@export var maximum_step_distance := 0.15

@export_group("Burn Spots")
@export var burn_spot_scene: PackedScene
@export_range(0.02, 0.5, 0.01) var burn_spot_spacing := 0.1
@export_range(1, 100, 1) var maximum_burn_spots := 30

@export_group("Camera")
@export var camera_move_duration := 0.5

@export_group("Lighter")
@export var lighter_surface_offset := 0.08
@export var lighter_rotation_degrees := Vector3.ZERO

@onready var lighter_pivot: Node3D = $LighterPivot

var player_camera: Camera3D
var evidence_visual: Node3D
var burn_surface: Marker3D
var burn_effects: Node3D
var cleanup_view: Marker3D
var instruction_label: Label3D

var original_camera_transform: Transform3D
var original_visual_visibility := true

var burn_spots: Array[Node3D] = []
var last_burn_spot_position := Vector3.INF
var previous_burn_position := Vector3.INF
var next_reused_spot_index := 0
var burn_distance := 0.0

var mouse_held := false
var accepting_input := false
var is_finishing := false


func _ready() -> void:
	lock_player_movement = true
	lock_camera_look = true
	show_mouse_cursor = true
	can_cancel = true

	lighter_pivot.hide()


func begin(target_evidence: Evidence) -> void:
	super.begin(target_evidence)

	player_camera = get_viewport().get_camera_3d()
	evidence_visual = evidence.get_node_or_null("EvidenceVisual") as Node3D
	burn_surface = evidence.get_node_or_null("BurnSurface") as Marker3D
	burn_effects = evidence.get_node_or_null("BurnEffects") as Node3D
	cleanup_view = evidence.get_node_or_null("CleanupView") as Marker3D
	instruction_label = evidence.get_node_or_null("InstructionLabel") as Label3D

	if not player_camera or not evidence_visual or not burn_surface or not burn_effects or not cleanup_view:
		push_error("CounterfeitEvidence is missing one or more required nodes.")
		call_deferred("_cancel_after_setup_error")
		return

	if not burn_spot_scene:
		push_error("CounterfeitBurnTask requires a BurnSpot scene.")
		call_deferred("_cancel_after_setup_error")
		return

	original_camera_transform = player_camera.global_transform
	original_visual_visibility = evidence_visual.visible

	burn_distance = 0.0
	previous_burn_position = Vector3.INF
	last_burn_spot_position = Vector3.INF
	next_reused_spot_index = 0

	clear_burn_spots()

	if instruction_label:
		instruction_label.hide()

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

		if not mouse_held:
			reset_active_burn_position()

		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseMotion:
		update_burn_position(event.position)


func update_burn_position(mouse_position: Vector2) -> void:
	var ray_origin := player_camera.project_ray_origin(mouse_position)
	var ray_direction := player_camera.project_ray_normal(mouse_position)

	var surface_normal := burn_surface.global_transform.basis.z.normalized()
	var surface_plane := Plane(surface_normal, burn_surface.global_position)
	var hit_position = surface_plane.intersects_ray(ray_origin, ray_direction)

	if hit_position == null:
		lighter_pivot.hide()
		reset_active_burn_position()
		return

	var local_hit := burn_surface.to_local(hit_position)
	var half_width := surface_width * 0.5
	var half_height := surface_height * 0.5

	var is_inside: bool = (
		abs(local_hit.x) <= half_width
		and abs(local_hit.y) <= half_height
	)
		
	if not is_inside:
		lighter_pivot.hide()
		reset_active_burn_position()
		return

	update_lighter_position(hit_position, surface_normal)

	if not mouse_held:
		reset_active_burn_position()
		return

	try_create_burn_spot(hit_position, surface_normal)
	add_burn_progress(hit_position)

	if not mouse_held:
		reset_active_burn_position()
		return

	try_create_burn_spot(hit_position, surface_normal)
	add_burn_progress(hit_position)


func try_create_burn_spot(hit_position: Vector3, surface_normal: Vector3) -> void:
	if last_burn_spot_position != Vector3.INF:
		if last_burn_spot_position.distance_to(hit_position) < burn_spot_spacing:
			return

	var spot := get_available_burn_spot()

	if not spot:
		return

	var spot_transform := burn_surface.global_transform
	spot_transform.basis = spot_transform.basis.orthonormalized()
	spot_transform.origin = hit_position + surface_normal * particle_surface_offset
	spot.global_transform = spot_transform

	restart_burn_spot_particles(spot)
	last_burn_spot_position = hit_position


func get_available_burn_spot() -> Node3D:
	if burn_spots.size() < maximum_burn_spots:
		var spot := burn_spot_scene.instantiate() as Node3D

		if not spot:
			push_error("BurnSpot scene must have a Node3D root.")
			return null

		burn_effects.add_child(spot)
		burn_spots.append(spot)
		return spot

	if burn_spots.is_empty():
		return null

	var reused_spot := burn_spots[next_reused_spot_index]
	next_reused_spot_index = wrapi(
		next_reused_spot_index + 1,
		0,
		burn_spots.size()
	)

	return reused_spot


func restart_burn_spot_particles(spot: Node3D) -> void:
	for child in spot.find_children("*", "GPUParticles3D", true, false):
		var particles := child as GPUParticles3D
		particles.emitting = true
		particles.restart()


func add_burn_progress(current_position: Vector3) -> void:
	if previous_burn_position != Vector3.INF:
		var movement_distance := previous_burn_position.distance_to(current_position)

		if movement_distance <= maximum_step_distance:
			burn_distance += movement_distance

	previous_burn_position = current_position

	var completion: float = clamp(
		burn_distance / required_burn_distance,
		0.0,
		1.0
	)

	if completion >= 1.0:
		finish_task(true)


func reset_active_burn_position() -> void:
	previous_burn_position = Vector3.INF
	last_burn_spot_position = Vector3.INF


func stop_burn_spot_particles() -> void:
	for spot in burn_spots:
		if not spot or not is_instance_valid(spot):
			continue

		for child in spot.find_children("*", "GPUParticles3D", true, false):
			var particles := child as GPUParticles3D
			particles.emitting = false


func clear_burn_spots() -> void:
	for spot in burn_spots:
		if spot and is_instance_valid(spot):
			spot.queue_free()

	burn_spots.clear()
	last_burn_spot_position = Vector3.INF
	next_reused_spot_index = 0


func finish_task(success: bool) -> void:
	if is_finishing:
		return

	is_finishing = true
	accepting_input = false
	mouse_held = false
	set_process_input(false)
	lighter_pivot.hide()

	stop_burn_spot_particles()

	if instruction_label:
		instruction_label.hide()

	if success:
		evidence_visual.hide()
	else:
		evidence_visual.visible = original_visual_visibility

	var tween := create_tween()

	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(
		player_camera,
		"global_transform",
		original_camera_transform,
		camera_move_duration
	)

	if success:
		tween.tween_callback(_complete_after_camera_return)
	else:
		tween.tween_callback(_cancel_after_camera_return)


func _complete_after_camera_return() -> void:
	clear_burn_spots()
	complete()


func _cancel_after_camera_return() -> void:
	clear_burn_spots()
	cancel()


func _cancel_after_setup_error() -> void:
	lighter_pivot.hide()
	clear_burn_spots()
	cancel()
	
	
func update_lighter_position(hit_position: Vector3, surface_normal: Vector3) -> void:
	var lighter_transform := burn_surface.global_transform
	lighter_transform.basis = lighter_transform.basis.orthonormalized()

	var rotation_offset := Basis.from_euler(
		Vector3(
			deg_to_rad(lighter_rotation_degrees.x),
			deg_to_rad(lighter_rotation_degrees.y),
			deg_to_rad(lighter_rotation_degrees.z)
		)
	)

	lighter_transform.basis *= rotation_offset
	lighter_transform.origin = hit_position + surface_normal * lighter_surface_offset

	lighter_pivot.global_transform = lighter_transform
	lighter_pivot.show()
