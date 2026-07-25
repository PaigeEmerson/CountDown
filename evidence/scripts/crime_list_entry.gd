class_name CrimeListEntry
extends Control

@onready var crime_name: RichTextLabel = $CrimeName
@onready var count_label: Label = $CountLabel

var crime_type: CrimeTypeData


func setup(type: CrimeTypeData) -> void:
	crime_type = type
	update_count(0)


func update_count(count: int) -> void:
	if not crime_type:
		return

	if count <= 0:
		crime_name.text = "[s]%s[/s]" % crime_type.display_name
		count_label.text = "0"
		count_label.modulate.a = 0.45
	else:
		crime_name.text = crime_type.display_name
		count_label.text = "x" + str(count)
		count_label.modulate.a = 1.0
