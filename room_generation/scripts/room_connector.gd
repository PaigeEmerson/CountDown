class_name RoomConnector
extends Marker3D

@export var connector_type := "door"
@export var closed_section: Node3D
@export var open_section: Node3D

var connected_connector: RoomConnector
var owns_connection_visual := false


func _ready() -> void:
	add_to_group("room_connector")
	set_connection_visuals(false, false)


func is_available() -> bool:
	return connected_connector == null


func is_compatible_with(other_connector: RoomConnector) -> bool:
	return connector_type == other_connector.connector_type


func connect_to(other_connector: RoomConnector, show_open_section: bool) -> void:
	connected_connector = other_connector
	owns_connection_visual = show_open_section
	set_connection_visuals(true, show_open_section)


func disconnect_connector() -> void:
	connected_connector = null
	owns_connection_visual = false
	set_connection_visuals(false, false)


func set_connection_visuals(is_connected: bool, show_open_section: bool) -> void:
	if closed_section:
		closed_section.visible = not is_connected
		set_collision_enabled(closed_section, not is_connected)

	if open_section:
		open_section.visible = is_connected and show_open_section
		set_collision_enabled(open_section, is_connected and show_open_section)


func set_collision_enabled(root: Node, enabled: bool) -> void:
	var collision_shapes := root.find_children("*", "CollisionShape3D", true, false)

	for shape in collision_shapes:
		shape.set_deferred("disabled", not enabled)
