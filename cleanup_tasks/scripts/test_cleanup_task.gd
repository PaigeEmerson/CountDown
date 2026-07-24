extends CleanupTask

@export var required_mouse_distance := 1000.0

var accumulated_mouse_distance := 0.0
var mouse_held := false


func _ready() -> void:
	lock_player_movement = true
	lock_camera_look = true
	show_mouse_cursor = false


func begin(target_evidence: Evidence) -> void:
	super.begin(target_evidence)
	accumulated_mouse_distance = 0.0
	print("Cleanup started. Hold left click and move the mouse.")


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return

	if event.is_action_pressed("release_mouse"):
		cancel()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_held = event.pressed

	if event is InputEventMouseMotion and mouse_held:
		accumulated_mouse_distance += event.relative.length()
		print("Cleanup progress: ", accumulated_mouse_distance, " / ", required_mouse_distance)

		if accumulated_mouse_distance >= required_mouse_distance:
			complete()
