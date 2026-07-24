class_name Evidence
extends Interactable

signal cleanup_started(evidence: Evidence)
signal cleanup_completed(evidence: Evidence)
signal cleanup_cancelled(evidence: Evidence)

@export_group("Evidence")
@export var evidence_name := "Evidence"
@export var score_value := 100

@export_group("Cleanup")
@export var cleanup_task_scene: PackedScene
@export var remove_when_cleaned := true

var is_cleaned := false
var cleanup_in_progress := false

func _ready() -> void:
	add_to_group("crime_evidence")
	interaction_prompt = "Clean %s" % evidence_name


func can_interact()-> bool:
	return interaction_enabled and not is_cleaned and not cleanup_in_progress
	

func interact() -> void:
	if not can_interact():
		return
		
	super.interact()
	
	if CleanupManager.start_cleanup(self):
		cleanup_in_progress = true
		interaction_enabled = false
		cleanup_started.emit(self)
	

func complete_cleanup() -> void:
	if is_cleaned:
		return
		
	is_cleaned = true
	cleanup_in_progress = false
	interaction_enabled = false
	
	remove_from_group("crime_evidence")
	cleanup_completed.emit(self)
	
	if remove_when_cleaned:
		queue_free()
		
		
func cancel_cleanup() -> void:
	if is_cleaned:
		return
		
	cleanup_in_progress = false
	interaction_enabled = true
	cleanup_cancelled.emit(self)
