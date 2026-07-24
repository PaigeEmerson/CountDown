class_name RoomConnector
extends Marker3D

@export_group("Connection")
@export var connector_type := "door"
@export var window_only := false
@export var closed_section: Node3D
@export var open_section: Node3D
@export var lightning_receiver: WindowLightningReceiver

@export_group("Window")
@export var allow_window := true
@export_range(0.0, 1.0, 0.05) var window_chance := 0.35
@export var window_section: Node3D
@export var window_clearance: Area3D

var connected_connector: RoomConnector
var owns_connection_visual := false
var finalized_as_window := false


func _ready() -> void:
	add_to_group("room_connector")
	show_closed_wall()


func is_available() -> bool:
	return connected_connector == null and not window_only


func is_compatible_with(other_connector: RoomConnector) -> bool:
	if window_only or other_connector.window_only:
		return false

	return connector_type == other_connector.connector_type


func connect_to(other_connector: RoomConnector, show_open_section: bool) -> void:
	if window_only:
		push_warning("%s is window-only and cannot connect to another room." % name)
		return

	connected_connector = other_connector
	owns_connection_visual = show_open_section
	finalized_as_window = false
	show_connected_state(show_open_section)


func disconnect_connector() -> void:
	connected_connector = null
	owns_connection_visual = false
	finalized_as_window = false
	show_closed_wall()


func finalize_unused_connector(random: RandomNumberGenerator) -> void:
	if connected_connector:
		return

	if window_only:
		if window_section:
			show_window()
		else:
			push_warning("%s is window-only but has no WindowSection assigned." % name)
			show_closed_wall()

		disable_window_clearance()
		return

	var should_use_window := allow_window
	should_use_window = should_use_window and window_section != null
	should_use_window = should_use_window and window_clearance != null
	should_use_window = should_use_window and random.randf() <= window_chance
	should_use_window = should_use_window and window_faces_clear_space()

	if should_use_window:
		show_window()
	else:
		show_closed_wall()

	disable_window_clearance()


func window_faces_clear_space() -> bool:
	if not window_clearance:
		return false

	var owning_room := get_owning_room()

	for overlapping_area in window_clearance.get_overlapping_areas():
		if owning_room and owning_room.is_ancestor_of(overlapping_area):
			continue

		return false

	return true


func get_owning_room() -> RoomModule:
	var current_node := get_parent()

	while current_node:
		if current_node is RoomModule:
			return current_node

		current_node = current_node.get_parent()

	return null


func show_connected_state(show_open_section: bool) -> void:
	set_section_enabled(closed_section, false)
	set_section_enabled(window_section, false)
	set_section_enabled(open_section, show_open_section)
	set_lightning_active(false)


func show_closed_wall() -> void:
	finalized_as_window = false
	set_section_enabled(closed_section, true)
	set_section_enabled(open_section, false)
	set_section_enabled(window_section, false)
	set_lightning_active(false)


func show_window() -> void:
	finalized_as_window = true
	set_section_enabled(closed_section, false)
	set_section_enabled(open_section, false)
	set_section_enabled(window_section, true)
	set_lightning_active(true)


func disable_window_clearance() -> void:
	if window_clearance:
		window_clearance.set_deferred("monitoring", false)
		
		
func set_lightning_active(value: bool) -> void:
	if lightning_receiver:
		lightning_receiver.set_window_active(value)


func set_section_enabled(section: Node3D, enabled: bool) -> void:
	if not section:
		return

	section.visible = enabled
	set_collision_enabled(section, enabled)


func set_collision_enabled(root: Node, enabled: bool) -> void:
	var collision_shapes := root.find_children("*", "CollisionShape3D", true, false)

	for shape in collision_shapes:
		shape.set_deferred("disabled", not enabled)
