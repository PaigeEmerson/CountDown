class_name PlayerInteractionController
extends Node

signal target_changed(target: Interactable)
signal interaction_started(target: Interactable)

@export var interaction_ray: RayCast3D
@export var prompt_label: Label

var current_target: Interactable
var interaction_enabled := true


func _ready() -> void:
	prompt_label.hide()
	CleanupManager.cleanup_started.connect(_on_cleanup_started)
	CleanupManager.cleanup_ended.connect(_on_cleanup_ended)
	RunManager.run_escaped.connect(_on_run_escaped)
	CampaignManager.campaign_ended.connect(_on_campaign_ended)
	

func _process(delta: float) -> void:
	update_target()
	
	
func _unhandled_input(event: InputEvent) -> void:
	if not interaction_enabled:
		return
		
	if event.is_action_pressed("interact") and current_target:
		interact_with_current_target()
		get_viewport().set_input_as_handled()
		
		
func update_target() -> void:
	var new_target := get_target_from_ray()
	
	if new_target == current_target:
		return
		
	current_target = new_target
	target_changed.emit(current_target)
	update_prompt()
	
	
func get_target_from_ray() -> Interactable:
	if not interaction_ray.is_colliding():
		return null
		
	var collider := interaction_ray.get_collider()
	
	if collider is Interactable and collider.can_interact():
		return collider
		
	return null
	
	
func update_prompt() -> void:
	if not current_target:
		prompt_label.hide()
		return
		
	prompt_label.text = "[E] %s" % current_target.get_interaction_prompt()
	prompt_label.show()
		
		
func interact_with_current_target() -> void:
	if not current_target.can_interact():
		return
		
	var target := current_target
	interaction_started.emit(target)
	target.interact()
	
	
func _on_cleanup_started(_task: CleanupTask) -> void:
	interaction_enabled = false
	current_target = null
	prompt_label.hide()
	
	
func _on_cleanup_ended() -> void:
	interaction_enabled = true
	
	
func _on_run_escaped(_remaining_crimes: int, _cleaned_crimes: int) -> void:
	disable_for_results()


func _on_campaign_ended(_caught_by_police: bool) -> void:
	disable_for_results()


func disable_for_results() -> void:
	interaction_enabled = false
	current_target = null
	prompt_label.hide()
