extends Node3D

@onready var omni_light: OmniLight3D = $OmniLight3D
@onready var spot_light: SpotLight3D = $SpotLight3D

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("flashlight_toggle"):
		omni_light.visible = not omni_light.visible
		spot_light.visible = not spot_light.visible
