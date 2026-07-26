extends Node

signal cleanup_started(task: CleanupTask)
signal cleanup_ended
signal cleanup_completed(evidence: Evidence)
signal cleanup_cancelled(evidence: Evidence)

var active_task: CleanupTask
var active_evidence: Evidence


func start_cleanup(evidence: Evidence) -> bool:
	if active_task:
		return false
		
	if not evidence:
		return false
		
	if not evidence.cleanup_task_scene:
		push_warning("No cleanup task assigned to evidence: %s" % evidence.name)
		return false
		
	var task_instance := evidence.cleanup_task_scene.instantiate()
	
	if not task_instance is CleanupTask:
		push_error("Cleanup task scene must have a script that inherits from CleanupTask.")
		task_instance.queue_free()
		return false
		
	active_evidence = evidence
	active_task = task_instance
	
	get_tree().current_scene.add_child(active_task)
	
	active_task.completed.connect(_on_task_completed)
	active_task.cancelled.connect(_on_task_cancelled)
	
	active_task.begin(active_evidence)
	cleanup_started.emit(active_task)
	
	if active_task.show_mouse_cursor:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	return true
	
	
func _on_task_completed() -> void:
	var completed_evidence := active_evidence
	complete_evidence(completed_evidence)
	close_active_task()
	
	
func _on_task_cancelled() -> void:
	var cancelled_evidence := active_evidence
	
	if cancelled_evidence and is_instance_valid(cancelled_evidence):
		cancelled_evidence.cancel_cleanup()
		
	cleanup_cancelled.emit(cancelled_evidence)
	close_active_task()
	
	
func close_active_task() -> void:
	if active_task and is_instance_valid(active_task):
		active_task.queue_free()
		
	active_task = null
	active_evidence = null
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	cleanup_ended.emit()
	
	
func has_active_task() -> bool:
	return active_task != null
	
	
func complete_evidence(evidence: Evidence) -> void:
	if not evidence or not is_instance_valid(evidence):
		return

	if evidence.is_cleaned:
		return

	evidence.complete_cleanup()
	cleanup_completed.emit(evidence)
	
	
func cancel_active_cleanup() -> void:
	if not active_task or not is_instance_valid(active_task):
		return

	active_task.request_cancel()
