class_name CybercrimeCleanupTask
extends CleanupTask

@export_group("Folders")
@export var folder_scene: PackedScene
@export_range(1, 20, 1) var minimum_folder_count := 5
@export_range(1, 20, 1) var maximum_folder_count := 9
@export var suspicious_folder_names: Array[String] = [
	"Accounts",
	"Passwords",
	"Transfers",
	"Client Records",
	"Offshore",
	"Definitely Legal",
	"Tax Documents",
	"Encrypted Files"
]

@export_group("Desktop Clutter")
@export_range(0.0, 30.0, 1.0) var maximum_folder_rotation := 8.0
@export_range(0.0, 200.0, 1.0) var minimum_folder_spacing := 55.0
@export_range(1, 100, 1) var placement_attempts_per_folder := 20
@export var desktop_padding := Vector2(15.0, 15.0)

@export_group("Camera")
@export var camera_move_duration := 0.5

@onready var computer_viewport: SubViewport = $ComputerViewport
@onready var world_display: MeshInstance3D = $WorldDisplay
@onready var folder_desktop: Control = $ComputerViewport/Interface/Background/DestopFrame/FolderDesktop
@onready var recycle_bin := $ComputerViewport/Interface/Background/RecycleBin as CyberRecycleBin
@onready var remaining_label: Label = $ComputerViewport/Interface/Background/RemainingLabel

var player_camera: Camera3D
var ui_anchor: Marker3D
var cleanup_view: Marker3D

var original_camera_transform: Transform3D
var remaining_folders := 0
var task_finishing := false
var accepting_input := false
var folder_positions: Array[Vector2] = []

var random := RandomNumberGenerator.new()


func _ready() -> void:
	lock_player_movement = true
	lock_camera_look = true
	show_mouse_cursor = true
	can_cancel = true

	random.randomize()
	world_display.hide()

	if not recycle_bin:
		push_error("RecycleBin must have cyber_recycle_bin.gd attached.")
		return

	recycle_bin.folder_deleted.connect(_on_folder_deleted)


func begin(target_evidence: Evidence) -> void:
	super.begin(target_evidence)

	player_camera = get_viewport().get_camera_3d()
	ui_anchor = evidence.get_node_or_null("UIAnchor") as Marker3D
	cleanup_view = evidence.get_node_or_null("CleanupView") as Marker3D

	if not player_camera or not ui_anchor or not cleanup_view:
		push_error("Computer evidence requires UIAnchor, CleanupView, and an active camera.")
		call_deferred("_cancel_after_setup_error")
		return

	if not folder_scene:
		push_error("CybercrimeCleanupTask requires a folder scene.")
		call_deferred("_cancel_after_setup_error")
		return

	original_camera_transform = player_camera.global_transform
	world_display.global_transform = ui_anchor.global_transform
	world_display.show()

	call_deferred("create_suspicious_folders")
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
	Input.warp_mouse(get_viewport().get_visible_rect().size * 0.5)


func _input(event: InputEvent) -> void:
	if not accepting_input or task_finishing:
		return

	if event.is_action_pressed("release_mouse"):
		get_viewport().set_input_as_handled()
		finish_task(false)
		return

	if event is InputEventMouseMotion or event is InputEventMouseButton:
		forward_mouse_event(event)


func forward_mouse_event(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouse
	var viewport_position = screen_to_computer_viewport(mouse_event.position)

	if viewport_position == null:
		return

	var forwarded_event := event.duplicate() as InputEventMouse
	forwarded_event.position = viewport_position
	forwarded_event.global_position = viewport_position

	computer_viewport.push_input(forwarded_event)
	get_viewport().set_input_as_handled()


func screen_to_computer_viewport(screen_position: Vector2) -> Variant:
	var ray_origin := player_camera.project_ray_origin(screen_position)
	var ray_direction := player_camera.project_ray_normal(screen_position)

	var display_normal := world_display.global_transform.basis.z.normalized()
	var display_plane := Plane(display_normal, world_display.global_position)
	var hit_position = display_plane.intersects_ray(ray_origin, ray_direction)

	if hit_position == null:
		return null

	var local_hit := world_display.to_local(hit_position)
	var quad_mesh := world_display.mesh as QuadMesh

	if not quad_mesh:
		return null

	var half_size := quad_mesh.size * 0.5

	if abs(local_hit.x) > half_size.x or abs(local_hit.y) > half_size.y:
		return null

	var normalized_position := Vector2(
		(local_hit.x + half_size.x) / quad_mesh.size.x,
		(half_size.y - local_hit.y) / quad_mesh.size.y
	)

	return Vector2(
		normalized_position.x * computer_viewport.size.x,
		normalized_position.y * computer_viewport.size.y
	)


func create_suspicious_folders() -> void:
	if not is_active:
		return

	var lowest_count: int = min(minimum_folder_count, maximum_folder_count)
	var highest_count: int = max(minimum_folder_count, maximum_folder_count)
	var folder_count := random.randi_range(lowest_count, highest_count)

	remaining_folders = 0
	folder_positions.clear()

	for index in folder_count:
		var folder := folder_scene.instantiate() as CyberFolder

		if not folder:
			push_error("Folder scene must use CyberFolder.")
			continue

		folder_desktop.add_child(folder)
		folder.setup(get_random_folder_name(index))
		place_folder_on_desktop(folder)

		remaining_folders += 1

	update_remaining_label()

	if remaining_folders == 0:
		call_deferred("_cancel_after_setup_error")


func place_folder_on_desktop(folder: CyberFolder) -> void:
	var folder_size := folder.custom_minimum_size

	if folder_size.x <= 0.0 or folder_size.y <= 0.0:
		folder_size = Vector2(96.0, 96.0)

	folder.size = folder_size
	folder.pivot_offset = folder_size * 0.5

	var maximum_x: int = max(folder_desktop.size.x - folder_size.x - desktop_padding.x, desktop_padding.x)
	var maximum_y: int = max(folder_desktop.size.y - folder_size.y - desktop_padding.y, desktop_padding.y)

	var selected_position := Vector2.ZERO

	for attempt in placement_attempts_per_folder:
		var candidate := Vector2(
			random.randf_range(desktop_padding.x, maximum_x),
			random.randf_range(desktop_padding.y, maximum_y)
		)

		selected_position = candidate

		if position_has_enough_space(candidate):
			break

	folder.position = selected_position
	folder.rotation_degrees = random.randf_range(-maximum_folder_rotation, maximum_folder_rotation)
	folder_positions.append(selected_position)


func position_has_enough_space(candidate: Vector2) -> bool:
	for existing_position in folder_positions:
		if candidate.distance_to(existing_position) < minimum_folder_spacing:
			return false

	return true


func get_random_folder_name(index: int) -> String:
	if suspicious_folder_names.is_empty():
		return "Suspicious Folder %d" % (index + 1)

	var random_index := random.randi_range(0, suspicious_folder_names.size() - 1)
	return suspicious_folder_names[random_index]


func _on_folder_deleted(_folder: CyberFolder) -> void:
	if task_finishing:
		return

	remaining_folders = max(remaining_folders - 1, 0)
	update_remaining_label()

	if remaining_folders == 0:
		finish_task(true)


func update_remaining_label() -> void:
	remaining_label.text = "Suspicious folders remaining: %d" % remaining_folders


func finish_task(success: bool) -> void:
	if task_finishing:
		return

	task_finishing = true
	accepting_input = false
	set_process_input(false)

	if success:
		remaining_label.text = "Computer cleaned"
		await get_tree().create_timer(0.4).timeout

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
	if task_finishing:
		return

	finish_task(false)
