class_name CleanupTask
extends Node

signal completed
signal cancelled

@export_group("Player Control")
@export var lock_player_movement := true
@export var lock_camera_look := true
@export var show_mouse_cursor := false
@export var can_cancel := true

@export_group("Camera Collision")
@export_flags_3d_physics var camera_collision_mask := 1
@export var camera_collision_radius := 0.2
@export var camera_collision_margin := 0.05

var evidence: Evidence
var is_active := false


func begin(target_evidence: Evidence) -> void:
	evidence = target_evidence
	is_active = true


func complete() -> void:
	if not is_active:
		return

	is_active = false
	completed.emit()


func cancel() -> void:
	if not is_active or not can_cancel:
		return

	is_active = false
	cancelled.emit()


func get_safe_camera_transform(camera: Camera3D, desired_transform: Transform3D, focus_position: Vector3) -> Transform3D:
	var starting_position := camera.global_position
	var desired_position := desired_transform.origin
	var motion := desired_position - starting_position

	if motion.length() <= 0.001:
		return desired_transform.looking_at(focus_position, Vector3.UP)

	var sphere := SphereShape3D.new()
	sphere.radius = camera_collision_radius

	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis.IDENTITY, starting_position)
	query.motion = motion
	query.collision_mask = camera_collision_mask
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var result := camera.get_world_3d().direct_space_state.cast_motion(query)
	var safe_fraction := 1.0

	if result.size() >= 1:
		safe_fraction = result[0]

	var safe_distance := motion.length() * safe_fraction
	safe_distance = max(safe_distance - camera_collision_margin, 0.0)

	var safe_position := starting_position + motion.normalized() * safe_distance
	var safe_transform := Transform3D(desired_transform.basis, safe_position)

	if safe_position.distance_to(focus_position) > 0.01:
		safe_transform = safe_transform.looking_at(focus_position, Vector3.UP)

	return safe_transform
	
	
func request_cancel() -> void:
	cancel()
