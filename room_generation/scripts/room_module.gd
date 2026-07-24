class_name RoomModule
extends Node3D

enum RoomSize {
	SMALL,
	MEDIUM,
	LARGE,
	HALLWAY
}

enum RoomRole {
	ENTRY,
	HUB,
	HALLWAY,
	STANDARD,
	DEAD_END
}

@export_group("Identity")
@export var room_name := "Room"
@export var room_size := RoomSize.MEDIUM
@export var room_role := RoomRole.STANDARD

@export_group("Generation")
@export var generation_weight := 1.0
@export var minimum_depth := 0
@export var maximum_depth := 99
@export var maximum_instances := 0

@export_group("Contents")
@export var minimum_crimes := 0
@export var maximum_crimes := 2

var generation_depth := 0
var parent_room: RoomModule


func get_connectors() -> Array[RoomConnector]:
	var connectors: Array[RoomConnector] = []

	for child in get_tree().get_nodes_in_group("room_connector"):
		if child is RoomConnector and is_ancestor_of(child):
			connectors.append(child)

	return connectors


func get_available_connectors() -> Array[RoomConnector]:
	var available: Array[RoomConnector] = []

	for connector in get_connectors():
		if connector.is_available():
			available.append(connector)

	return available


func get_generation_bounds() -> Array[CollisionShape3D]:
	var bounds: Array[CollisionShape3D] = []
	var bounds_root := get_node_or_null("GenerationBounds")

	if not bounds_root:
		return bounds

	for child in bounds_root.find_children("*", "CollisionShape3D", true, false):
		bounds.append(child)

	return bounds
