extends Node


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	NewspaperInterface.show()
	NewspaperInterface.set_state_immediately(
		NewspaperUI.NewspaperState.MAIN_MENU
	)
