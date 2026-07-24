class_name Interactable
extends Area3D

signal interacted(interactable: Interactable)

@export var interaction_prompt := "Interact"
@export var interaction_enabled := true

func can_interact()-> bool:
	return interaction_enabled
	

func get_interaction_prompt() -> String:
	return interaction_prompt
	

func interact() -> void:
	if not can_interact():
		return
		
	interacted.emit(self)
	
	
func set_interaction_enabled(value: bool) -> void:
	interaction_enabled = value
