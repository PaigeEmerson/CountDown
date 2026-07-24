class_name BloodScrubTask
extends CleanupTask

@export_group("Scrubbing")
@export var required_scrub_distance := 5.0
@export var cloth_surface_offset := 0.025

@export_group("Camera")
@export var camera_move_duration := 0.5

@onready var cleaning_cloth: MeshInstance3D = $CleaningCloth

var player_camera: Camera3D
var stain_surface: Decal
var cleanup_view: Marker3D

var original_camera_transform: Transform3D
var original_decal_modulate: Color
var previous_scrub_position := Vector3.INF
var scrub_distance := 0.0
var mouse_held := false
var accepting_input := false
var is_finishing := false


func _ready() -> void:
	lock_player_movement = true
	lock_camera_look = true
	show_mouse_cursor = true
	can_cancel = true
	cleaning_cloth.hide()


func begin(target_evidence: Evidence) -> void:
	super.begin(target_evidence)

	player_camera = get_viewport().get_camera_3d()
	stain_surface = evidence.get_node_or_null("StainSurface") as Decal
	cleanup_view = evidence.get_node_or_null("CleanupView") as Marker3D

	if not player_camera or not stain_surface or not cleanup_view:
		push_error("Blood evidence requires an active camera, Decal named StainSurface, and CleanupView.")
		call_deferred("_cancel_after_setup_error")
		return

	original_camera_transform = player_camera.global_transform
	original_decal_modulate = stain_surface.modulate
	previous_scrub_position = Vector3.INF
	scrub_distance = 0.0

	move_camera_into_position()


func move_camera_into_position() -> void:
	var target_transform := cleanup_view.global_transform.looking_at(stain_surface.global_position, Vector3.UP)
	var tween := create_tween()

	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(player_camera, "global_transform", target_transform, camera_move_duration)
	tween.tween_callback(_on_camera_arrived)


func _on_camera_arrived() -> void:
	accepting_input = true
	set_process_input(true)
	Input.warp_mouse(get_viewport().get_visible_rect().size * 0.5)


func _input(event: InputEvent) -> void:
	if not accepting_input or is_finishing:
		return

	if event.is_action_pressed("release_mouse"):
		finish_task(false)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_held = event.pressed

		if not mouse_held:
			previous_scrub_position = Vector3.INF

		get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		update_cloth_position(event.position)


func update_cloth_position(mouse_position: Vector2) -> void:
	var ray_origin := player_camera.project_ray_origin(mouse_position)
	var ray_direction := player_camera.project_ray_normal(mouse_position)

	var surface_normal := stain_surface.global_transform.basis.y.normalized()
	var surface_plane := Plane(surface_normal, stain_surface.global_position)
	var hit_position = surface_plane.intersects_ray(ray_origin, ray_direction)

	if hit_position == null:
		hide_cloth_and_reset_position()
		return

	var local_hit := stain_surface.to_local(hit_position)
	var half_width := stain_surface.size.x * 0.5
	var half_height := stain_surface.size.z * 0.5
	var is_inside: bool = abs(local_hit.x) <= half_width and abs(local_hit.z) <= half_height

	if not is_inside:
		hide_cloth_and_reset_position()
		return

	cleaning_cloth.show()
	cleaning_cloth.global_transform = Transform3D(stain_surface.global_transform.basis, hit_position + surface_normal * cloth_surface_offset)

	if mouse_held:
		add_scrub_progress(hit_position)
	else:
		previous_scrub_position = Vector3.INF


func hide_cloth_and_reset_position() -> void:
	cleaning_cloth.hide()
	previous_scrub_position = Vector3.INF


func add_scrub_progress(current_position: Vector3) -> void:
	if previous_scrub_position != Vector3.INF:
		scrub_distance += previous_scrub_position.distance_to(current_position)

		var completion_percentage: float = clamp(scrub_distance / required_scrub_distance, 0.0, 1.0)
		var updated_modulate := original_decal_modulate
		updated_modulate.a = original_decal_modulate.a * (1.0 - completion_percentage)
		stain_surface.modulate = updated_modulate

		if completion_percentage >= 1.0:
			finish_task(true)

	previous_scrub_position = current_position


func finish_task(success: bool) -> void:
	if is_finishing:
		return

	is_finishing = true
	accepting_input = false
	set_process_input(false)
	mouse_held = false
	cleaning_cloth.hide()

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
	stain_surface.modulate = original_decal_modulate
	cancel()


func _cancel_after_setup_error() -> void:
	cancel()
