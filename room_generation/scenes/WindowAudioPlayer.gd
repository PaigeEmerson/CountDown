extends Node3D

@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

func _ready() -> void:
	visibility_changed.connect(_on_visibility_changed)
	
	_on_visibility_changed() 

func _on_visibility_changed() -> void:
	if visible:
		audio_player.play()
	else:
		audio_player.stop()
