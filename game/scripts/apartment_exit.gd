class_name ApartmentExit
extends Interactable

var exit_used := false

func _ready() -> void:
	interaction_prompt = "Leave"


func can_interact()-> bool:
	return interaction_enabled and not exit_used and RunManager.run_active
	
	
func interact() -> void:
	if not can_interact():
		return
		
	super.interact()
	
	exit_used = true
	interaction_enabled = false
	RunManager.escape_apartment()
