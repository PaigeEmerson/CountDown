class_name CleanupTask
extends Node

signal completed
signal cancelled

@export_group("Player Control")
@export var lock_player_movement := true
@export var lock_camera_look := true
@export var show_mouse_cursor := false
@export var can_cancel := true

var evidence: Evidence
var is_active := false


func begin(target_evidence: Evidence) -> void:
	evidence = target_evidence
	is_active = true
	
func complete() -> void:
	if not is_active:
		return
		
	is_active = false
	completed.emit()
	
	
func cancel() -> void:
	if not is_active or not can_cancel:
		return
		
	is_active = false
	cancelled.emit()
