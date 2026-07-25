class_name CyberRecycleBin
extends TextureRect

signal folder_deleted(folder: CyberFolder)

@export var normal_color := Color.WHITE
@export var hover_color := Color(0.6, 1.0, 0.6)

var drag_is_hovering := false


func _ready() -> void:
	modulate = normal_color


func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	var can_accept := false

	if data is Dictionary:
		can_accept = data.get("type") == &"cyber_folder"

	modulate = hover_color if can_accept else normal_color
	drag_is_hovering = can_accept

	return can_accept


func _drop_data(_position: Vector2, data: Variant) -> void:
	modulate = normal_color
	drag_is_hovering = false

	if not data is Dictionary:
		return

	var folder := data.get("folder") as CyberFolder

	if not folder or not is_instance_valid(folder):
		return

	folder_deleted.emit(folder)
	folder.queue_free()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = normal_color
		drag_is_hovering = false
