class_name CyberFolder
extends TextureRect

@onready var folder_name_label: Label = $FolderName

var folder_name := "Suspicious Files"


func setup(display_name: String) -> void:
	folder_name = display_name

	if is_node_ready():
		folder_name_label.text = folder_name


func _ready() -> void:
	folder_name_label.text = folder_name


func _get_drag_data(_position: Vector2) -> Variant:
	var preview := TextureRect.new()
	preview.texture = texture
	preview.custom_minimum_size = Vector2(72.0, 72.0)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.modulate.a = 0.8

	set_drag_preview(preview)

	return {
		"type": &"cyber_folder",
		"folder": self
	}
