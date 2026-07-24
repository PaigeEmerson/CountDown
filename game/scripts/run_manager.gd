extends Node

signal run_started(starting_crimes: int)
signal time_changed(time_remaining: float)
signal evidence_count_changed(remaining: int, cleaned: int)
signal run_escaped(remiaining_crimes: int, cleaned_crimes: int)
signal police_arrived

var run_duration := 15.0
var time_remaining := 0.0
var starting_crime_count := 0
var run_active := false
var player_escaped := false

func _ready() -> void:
	CleanupManager.cleanup_completed.connect(_on_cleanup_completed)


func _process(delta: float) -> void:
	if not run_active or CampaignManager.game_over:
		return
		
	time_remaining = max(time_remaining - delta, 0.0)
	time_changed.emit(time_remaining)
	
	if time_remaining <= 0.0:
		handle_police_arrival()
	

func start_run(duration: float) -> void:
	if CampaignManager.game_over:
		return
		
	run_duration = duration
	time_remaining = run_duration
	starting_crime_count = get_remaining_crime_count()
	run_active = true
	player_escaped = false
	
	run_started.emit(starting_crime_count)
	time_changed.emit(time_remaining)
	update_evidence_count()
	
	
func escape_apartment() -> void:
	if not run_active or player_escaped:
		return
		
	player_escaped = true
	run_active = false
	
	var remaining_crimes := get_remaining_crime_count()
	var cleaned_crimes: int = max(starting_crime_count - remaining_crimes, 0)
	
	CampaignManager.add_convictions(remaining_crimes)
	run_escaped.emit(remaining_crimes, cleaned_crimes)
	
	
func handle_police_arrival() -> void:
	if not run_active:
		return
		
	run_active = false
	time_remaining = 0.0
	
	time_changed.emit(time_remaining)
	police_arrived.emit()
	CampaignManager.end_campaign(true)
	
	
func get_remaining_crime_count() -> int:
	return get_tree().get_nodes_in_group("crime_evidence").size()
	
	
func get_cleaned_crime_count() -> int:
	return max(starting_crime_count - get_remaining_crime_count(), 0)
	

func update_evidence_count() -> void:
	var remaining := get_remaining_crime_count()
	var cleaned: int = max(starting_crime_count - remaining, 0)
	evidence_count_changed.emit(remaining,cleaned)


func _on_cleanup_completed(_evidence: Evidence) -> void:
	update_evidence_count()
